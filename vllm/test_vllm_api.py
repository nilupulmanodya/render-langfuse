import urllib.request
import json

# CONFIGURATION
# Note: changed to http://
url = "http://localhost/chat/completions" 
api_key = "sk-xxxx"

# DATA
payload = {
    "model": "meta-llama/Meta-Llama-3-8B-Instruct",
    "messages": [{"role": "user", "content": "Tell me a fun fact about space."}],
    "max_tokens": 100
}

# PREPARE REQUEST
headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {api_key}"
}

data = json.dumps(payload).encode("utf-8")
req = urllib.request.Request(url, data=data, headers=headers)

# SEND
try:
    print("Sending request to server...")
    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode("utf-8"))
        print("\nSUCCESS! Response from Server:\n")
        print(result['choices'][0]['message']['content'])
except Exception as e:
    print(f"\nERROR: {e}")
