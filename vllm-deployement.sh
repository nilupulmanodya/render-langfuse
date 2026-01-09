#!/bin/bash

# --- CONFIGURATION ---
# 1. PASTE YOUR HUGGING FACE TOKEN BELOW:
HF_TOKEN="ENTER_YOUR_HF_TOKEN_HERE" 

# 2. CONFIG
API_KEY="sk-$(openssl rand -hex 16)"
MODEL_ID="meta-llama/Meta-Llama-3-8B-Instruct"

# --- SAFETY CHECK ---
if [[ "$HF_TOKEN" == "ENTER_YOUR_HF_TOKEN_HERE" ]]; then
    echo "ERROR: You must edit this script and paste your Hugging Face Token first!"
    exit 1
fi

# --- USER DETECTION ---
if [ -n "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
    REAL_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
else
    REAL_USER=$USER
    REAL_HOME=$HOME
fi

echo ">>> Detected User: $REAL_USER"
echo ">>> Starting Robust SynthifAI Setup..."

# 1. System Updates
sudo apt update && sudo apt install -y python3-pip python3-venv git curl

# 2. Install Caddy (Only if missing)
if ! command -v caddy &> /dev/null; then
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install caddy -y
fi

# 3. Setup Python Environment
VENV_DIR="$REAL_HOME/synthifai-vllm"
if [ ! -d "$VENV_DIR" ]; then
    echo ">>> Creating Virtual Env..."
    sudo -u $REAL_USER python3 -m venv $VENV_DIR
fi

source "$VENV_DIR/bin/activate"
pip install vllm huggingface_hub[hf_transfer]

# 4. Configure Caddy (Robust Mode)
PUBLIC_IP=$(curl -s ifconfig.me)

# Force HTTP (Port 80) and IPv4 (127.0.0.1)
sudo bash -c "cat > /etc/caddy/Caddyfile <<EOF
http://$PUBLIC_IP {
    reverse_proxy 127.0.0.1:8000
}
EOF"

# FIX: Restart instead of reload if service is dead
if systemctl is-active --quiet caddy; then
    sudo systemctl reload caddy
else
    sudo systemctl enable caddy
    sudo systemctl restart caddy
fi

# 5. Create vLLM Service (With [Install] Fix)
sudo bash -c "cat > /etc/systemd/system/vllm.service <<EOF
[Unit]
Description=vLLM Backend Service
After=network.target

[Service]
User=$REAL_USER
Group=$REAL_USER
WorkingDirectory=$REAL_HOME
Environment=\"HUGGING_FACE_HUB_TOKEN=$HF_TOKEN\"
ExecStart=$VENV_DIR/bin/python3 -m vllm.entrypoints.openai.api_server \\
    --model $MODEL_ID \\
    --host 127.0.0.1 \\
    --port 8000 \\
    --gpu-memory-utilization 0.90 \\
    --api-key \"$API_KEY\"

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF"

# 6. Start vLLM
sudo systemctl daemon-reload
sudo systemctl enable vllm
sudo systemctl restart vllm

# 7. Wait for Model to Load (The Anti-502 Check)
echo "--------------------------------------------------------"
echo ">>> Setup Done. Waiting for Model to Load (approx 60s)..."
echo ">>> This prevents the '502 Bad Gateway' error."

# Loop until port 8000 responds
for i in {1..20}; do
    if curl -s http://127.0.0.1:8000/v1/models > /dev/null; then
        echo ">>> SUCCESS! Model is Online."
        break
    fi
    echo -n "."
    sleep 5
done

echo ""
echo "--------------------------------------------------------"
echo ">>> COPY THIS FOR YOUR PYTHON SCRIPT:"
echo "--------------------------------------------------------"
echo "URL:     http://$PUBLIC_IP/v1/chat/completions"
echo "API KEY: $API_KEY"
echo "--------------------------------------------------------"
