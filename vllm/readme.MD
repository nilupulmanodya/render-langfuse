# 🚀 SynthifAI vLLM Deployment Script

A robust, ultra-fast deployment script to set up an OpenAI-compatible AI inference server using **vLLM** and **Caddy** — optimized for cloud GPUs and production use.

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation & Usage](#installation--usage)
  - [Interactive Mode](#interactive-mode-recommended)
  - [Automated Mode (CI / Scripts)](#automated-mode-ci--scripts)
- [Flags](#flags)
- [Connecting to the API](#connecting-to-the-api)
  - [Python Client Example](#python-client-example)
  - [curl Example](#curl-example)
- [Troubleshooting](#troubleshooting)
- [System Internals](#system-internals)

---

## 🔥 Features

- ⚡ **Blazing Fast** — Uses `uv` (Rust-based pip alternative) for instant dependency resolution.
- 🛡️ **Crash-Proof** — Automatically handles shared memory (`/dev/shm`) limits and cloud-specific failures.
- 🔌 **OpenAI Compatible** — Drop-in replacement for the OpenAI API in your apps.
- 🤖 **Universal Model Support** — Llama 3, Gemma 2, Mistral, Qwen, DeepSeek, and more.
- 🔐 **Auto-Security** — Generates a secure, random API Key on every install.
- 🔄 **Auto-Healing** — Systemd service auto-restarts on failures.

---

## 📋 Prerequisites

- **OS:** Ubuntu 20.04, 22.04, or 24.04 (LTS recommended)
- **Hardware:** NVIDIA GPU with CUDA drivers installed
- **Account:** Hugging Face account + access token

---

## 🛠️ Installation & Usage

### Interactive Mode (Recommended)

Run a single command. The script will automatically prompt you for your Hugging Face token and Model ID.

```bash
curl -sL https://raw.githubusercontent.com/nilupulmanodya/render-langfuse/deployment/vllm/vllm-deployement.sh | bash
```

---

### Automated Mode (CI / Scripts)

You can pass arguments directly to the script by piping to `bash -s --`.

```bash
curl -sL https://raw.githubusercontent.com/nilupulmanodya/render-langfuse/deployment/vllm/vllm-deployement.sh | bash -s -- \
  --token "hf_YourTokenHere" \
  --model "google/gemma-2-2b-it"
```

---

## ⚙️ Flags

| Flag | Description | Default |
|-----|------------|---------|
| `-t, --token` | Hugging Face read token | Prompt if missing |
| `-m, --model` | Model ID to load | meta-llama/Meta-Llama-3-8B-Instruct |

---

## 🔌 Connecting to the API

The script prints your **Public IP** and **Generated API Key** at the end of installation.

---

## 🐍 Python Client Example

```python
import requests

BASE_URL = "http://YOUR_SERVER_IP/v1"
API_KEY = "sk-xxxxxxxxxxxxxxxx"
MODEL_NAME = "google/gemma-2-2b-it"

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
    print(resp.json()["choices"][0]["message"]["content"])
else:
    print(resp.text)
```

---

## 🔧 curl Example

```bash
curl http://YOUR_SERVER_IP/v1/chat/completions \
  -H "Authorization: Bearer sk-your-generated-key" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "google/gemma-2-2b-it",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

---

## 🔧 Troubleshooting

### HTTP 400 Bad Request
- Model name mismatch
- Using base model instead of instruct model

### HTTP 401 / 403
- Hugging Face gated model
- Accept license and restart service

```bash
sudo systemctl restart vllm
```

---

## 📂 System Internals

- **Service:** `/etc/systemd/system/vllm.service`
- **Virtualenv:** `~/synthifai-vllm`
- **Logs:** `sudo journalctl -u vllm -f`
- **Proxy:** Caddy (80 → 8000)
