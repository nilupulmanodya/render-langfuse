#!/bin/bash

# --- CONFIGURATION ---
DEFAULT_MODEL="meta-llama/Meta-Llama-3-8B-Instruct"
# 0.85 is the sweet spot for cloud GPUs to avoid OOM
GPU_UTIL="0.85" 

HF_TOKEN=""
MODEL_ID=""

# --- 1. ARGUMENT PARSING ---
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--token) HF_TOKEN="$2"; shift ;;
        -m|--model) MODEL_ID="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# --- 2. INTERACTIVE PROMPTS ---
if [[ -z "$HF_TOKEN" ]]; then
    echo "--------------------------------------------------------"
    echo ">>> CONFIGURATION REQUIRED"
    echo "--------------------------------------------------------"
    echo "Please enter your Hugging Face Token (starts with hf_...)"
    read -s -p "HF Token: " HF_TOKEN
    echo ""
fi

if [[ -z "$HF_TOKEN" ]]; then
    echo "ERROR: Token cannot be empty. Exiting."
    exit 1
fi

if [[ -z "$MODEL_ID" ]]; then
    echo "--------------------------------------------------------"
    echo "Which model do you want to load?"
    echo "Press [ENTER] to use default: $DEFAULT_MODEL"
    read -p "Model ID: " USER_MODEL_INPUT
    MODEL_ID="${USER_MODEL_INPUT:-$DEFAULT_MODEL}"
fi

# --- 3. SETUP BEGINS ---
API_KEY="sk-$(openssl rand -hex 16)"

if [ -n "$SUDO_USER" ]; then
    REAL_USER=$SUDO_USER
    REAL_HOME=$(getent passwd $SUDO_USER | cut -d: -f6)
else
    REAL_USER=$USER
    REAL_HOME=$HOME
fi

echo "--------------------------------------------------------"
echo ">>> CONFIGURATION LOCKED"
echo "User:  $REAL_USER"
echo "Model: $MODEL_ID"
echo "--------------------------------------------------------"
echo ">>> Starting Setup..."

# 4. System Updates
# FIX ADDED: python3-dev is REQUIRED for vLLM compilation
echo ">>> Installing System Dependencies..."
sudo apt update && sudo apt install -y git curl python3-dev build-essential

# 5. Install uv
if ! command -v uv &> /dev/null; then
    echo ">>> Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sudo env UV_INSTALL_DIR="/usr/local/bin" sh
fi

# 6. Install Caddy
if ! command -v caddy &> /dev/null; then
    echo ">>> Installing Caddy..."
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install caddy -y
fi

# 7. Setup Python Environment
VENV_DIR="$REAL_HOME/synthifai-vllm"

if [ ! -d "$VENV_DIR" ]; then
    echo ">>> Creating Virtual Env with uv..."
    sudo -u $REAL_USER uv venv $VENV_DIR
fi

echo ">>> Installing vLLM and dependencies with uv..."
sudo -u $REAL_USER uv pip install --upgrade --python "$VENV_DIR/bin/python" vllm huggingface_hub[hf_transfer]

# 8. Configure Caddy
PUBLIC_IP=$(curl -s ifconfig.me)

sudo bash -c "cat > /etc/caddy/Caddyfile <<EOF
http://$PUBLIC_IP {
    reverse_proxy 127.0.0.1:8000
}
EOF"

if systemctl is-active --quiet caddy; then
    sudo systemctl reload caddy
else
    sudo systemctl enable caddy
    sudo systemctl restart caddy
fi

# 9. Create vLLM Service (Optimized for Stability)
sudo bash -c "cat > /etc/systemd/system/vllm.service <<EOF
[Unit]
Description=vLLM Backend Service
After=network.target

[Service]
User=$REAL_USER
Group=$REAL_USER
WorkingDirectory=$REAL_HOME
Environment=\"HUGGING_FACE_HUB_TOKEN=$HF_TOKEN\"
# This variable helps prevent the shared memory crash
Environment=\"VLLM_WORKER_MULTIPROC_METHOD=spawn\"

ExecStart=$VENV_DIR/bin/python -m vllm.entrypoints.openai.api_server \\
    --model $MODEL_ID \\
    --host 127.0.0.1 \\
    --port 8000 \\
    --gpu-memory-utilization $GPU_UTIL \\
    --distributed-executor-backend mp \\
    --api-key \"$API_KEY\"

Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF"

# 10. Start vLLM
sudo systemctl daemon-reload
sudo systemctl enable vllm
sudo systemctl restart vllm

# --- 11. SMART WAIT ---
echo "--------------------------------------------------------"
echo ">>> Setup Done. Waiting for Model to Load..."
echo "--------------------------------------------------------"

MAX_RETRIES=40
COUNT=0
SUCCESS=false

while [ $COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://127.0.0.1:8000/v1/models > /dev/null; then
        SUCCESS=true
        break
    fi

    if ! systemctl is-active --quiet vllm; then
        echo ""
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "ERROR: The vLLM service crashed."
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        LOGS=$(sudo journalctl -u vllm -n 30 --no-pager)
        echo "$LOGS"
        exit 1
    fi

    echo -n "."
    sleep 5
    COUNT=$((COUNT+1))
done

if [ "$SUCCESS" = true ]; then
    echo ""
    echo ">>> SUCCESS! Model is Online."
    echo "--------------------------------------------------------"
    echo "URL:     http://$PUBLIC_IP/v1/chat/completions"
    echo "API KEY: $API_KEY"
    echo "--------------------------------------------------------"
fi
