# 🚀 SynthifAI vLLM Deployment Script

A robust, ultra-fast deployment script to set up an OpenAI-compatible AI inference server using **vLLM** and **Caddy** — optimized for cloud GPUs and production use.

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation & Usage](#installation--usage)
  - [Interactive Mode](#interactive-mode)
  - [Automated Mode (CI)](#automated-mode-ci)
- [Flags](#flags)
- [Connecting to the API](#connecting-to-the-api)
  - [Python Client Example](#python-client-example)
  - [curl Example](#curl-example)
- [Troubleshooting](#troubleshooting)
- [System Internals](#system-internals)

---

## 🔥 Features

- ⚡ **Blazing Fast** — Uses `uv` (Rust-based pip alternative) for instant dependency resolution.
- 🛡️ **Crash-Proof** — Fixes for shared memory (`/dev/shm`) limits and other cloud-specific failures.
- 🔌 **OpenAI Compatible** — Drop-in replacement for the OpenAI API in your apps.
- 🤖 **Universal Model Support** — Llama 3, Gemma 2, Mistral, Qwen, DeepSeek, and more.
- 🔍 **Smart Diagnostics** — Detects gated models and GPU OOM conditions.
- 🔄 **Auto-Healing** — Systemd service auto-restarts on failures.

---

## 📋 Prerequisites

- **OS:** Ubuntu 20.04, 22.04, or 24.04 (LTS recommended)
- **Hardware:** NVIDIA GPU with CUDA drivers installed
- **Account:** Hugging Face account + access token

---

## 🛠️ Installation & Usage

1. Save the setup script as `setup.sh` (from this repo or chat)
2. Make it executable:

```bash
chmod +x setup.sh
```

### Interactive Mode

The interactive installer prompts for your token and model selection.

```bash
sudo ./setup.sh
```

### Automated Mode (CI / Scripts)

Pass flags to skip prompts:

```bash
sudo ./setup.sh --token "hf_YourTokenHere" --model "google/gemma-2-2b-it"
```

#### Quick remote install

You can also download and run the remote deployment script in one line:

```bash
curl -L -o vllm-deployement.sh https://raw.githubusercontent.com/nilupulmanodya/render-langfuse/deployment/vllm/vllm-deployement.sh && chmod +x vllm-deployement.sh && ./vllm-deployement.sh
```

---

## ⚙️ Flags

| Flag | Description | Default |
|------|-------------|---------|
| `-t`, `--token` | Your Hugging Face Read-Token | `None` |
| `-m`, `--model` | The Model ID to load | `meta-llama/Meta-Llama-3-8B-Instruct` |

---

## 🔌 Connecting to the API

After setup, the script prints the server Public IP and a generated API key.

### Python Client Example

Save this as `client.py` and update `BASE_URL`, `API_KEY`, and `MODEL_NAME` from the setup output:

```python
import requests

BASE_URL = "http://YOUR_SERVER_IP/v1"
API_KEY = "sk-xxxxxxxxxxxxxxxx"
MODEL_NAME = "google/gemma-2-2b-it"  # must match the model installed

headers = {
    "Authorization": f"Bearer {API_KEY}",
    "Content-Type": "application/json",
}

payload = {
    "model": MODEL_NAME,
    "messages": [{"role": "user", "content": "Explain quantum computing in one sentence."}],
    "temperature": 0.7,
}

resp = requests.post(f"{BASE_URL}/chat/completions", headers=headers, json=payload)
if resp.status_code == 200:
    print("🤖 AI Response:", resp.json()['choices'][0]['message']['content'])
else:
    print(f"❌ Error {resp.status_code}: {resp.text}")
```

### curl Example

```bash
curl http://YOUR_SERVER_IP/v1/chat/completions \
  -H "Authorization: Bearer sk-your-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-2-2b-it",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## 🔧 Troubleshooting

1. **HTTP 400 Bad Request**
   - Cause: Requested model name doesn't match the running server model.
   - Fix: Ensure `MODEL_NAME` in your client matches the `--model` used in setup exactly.
   - Cause: You're using a *base* model (e.g., `gemma-2-2b`) instead of an *instruct* variant.
   - Fix: Re-run setup with the `-it` (instruct) version (e.g., `google/gemma-2-2b-it`).

2. **HTTP 401 / 403 Unauthorized (During Setup)**
   - Cause: Model is gated on Hugging Face and requires license acceptance.
   - Fix: Visit the model page (e.g., `https://huggingface.co/google/gemma-2-2b`) and click **Accept license**; then restart the service:

```bash
sudo systemctl restart vllm
```

3. **RuntimeError: Engine core initialization failed / fatal error: Python.h**
   - Cause: Missing `python3-dev` headers or shared memory issues in cloud images.
   - Fix: The installer auto-installs `python3-dev` and sets `VLLM_WORKER_MULTIPROC_METHOD=spawn`. If you still see the error, ensure your environment has development headers and enough shared memory.

---

## 📂 System Internals

- **Service Location:** `/etc/systemd/system/vllm.service`
- **Virtualenv:** `~/synthifai-vllm` (managed by `uv`)
- **Logs:** `sudo journalctl -u vllm -f`
- **Web Server:** Caddy (reverse proxy on port 80)

---
