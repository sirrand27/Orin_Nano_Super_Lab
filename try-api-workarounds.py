#!/usr/bin/env python3
"""
Try to force-load models using Ollama API with explicit parameters
"""

import requests
import json
import sys

OLLAMA_API = "http://192.168.100.191:11434"

def try_load_with_api(model_name, prompt="test"):
    """Try various API parameters to force model loading"""
    
    print(f"Attempting to load {model_name} via API...")
    
    # Try 1: Basic generate with low GPU layers hint
    try:
        print("\n[Attempt 1] Standard API call...")
        response = requests.post(
            f"{OLLAMA_API}/api/generate",
            json={
                "model": model_name,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "num_gpu": 20,  # Limit GPU layers
                    "num_thread": 6,
                    "num_ctx": 2048,
                }
            },
            timeout=300
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✓ SUCCESS!")
            print(f"Response: {result.get('response', '')[:200]}")
            return True
        else:
            print(f"✗ Failed: {response.status_code}")
            print(f"Error: {response.text}")
    except Exception as e:
        print(f"✗ Error: {e}")
    
    # Try 2: Use create API to make a custom model with low GPU layers
    try:
        print("\n[Attempt 2] Creating custom model with GPU limits...")
        
        modelfile = f"""FROM {model_name}
PARAMETER num_gpu 20
PARAMETER num_thread 6
"""
        
        response = requests.post(
            f"{OLLAMA_API}/api/create",
            json={
                "name": f"{model_name}-cpu",
                "modelfile": modelfile,
                "stream": False
            },
            timeout=600
        )
        
        if response.status_code == 200:
            print("✓ Custom model created!")
            
            # Try to run it
            response = requests.post(
                f"{OLLAMA_API}/api/generate",
                json={
                    "model": f"{model_name}-cpu",
                    "prompt": prompt,
                    "stream": False
                },
                timeout=300
            )
            
            if response.status_code == 200:
                result = response.json()
                print("✓ SUCCESS with custom model!")
                print(f"Response: {result.get('response', '')[:200]}")
                return True
            else:
                print(f"✗ Custom model failed: {response.text}")
        else:
            print(f"✗ Create failed: {response.text}")
    except Exception as e:
        print(f"✗ Error: {e}")
    
    # Try 3: Chat API
    try:
        print("\n[Attempt 3] Using chat API...")
        response = requests.post(
            f"{OLLAMA_API}/api/chat",
            json={
                "model": model_name,
                "messages": [{"role": "user", "content": prompt}],
                "stream": False,
                "options": {
                    "num_gpu": 15,
                }
            },
            timeout=300
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✓ SUCCESS via chat!")
            print(f"Response: {result.get('message', {}).get('content', '')[:200]}")
            return True
        else:
            print(f"✗ Failed: {response.text}")
    except Exception as e:
        print(f"✗ Error: {e}")
    
    print("\n✗ All attempts failed")
    return False

if __name__ == "__main__":
    model = sys.argv[1] if len(sys.argv) > 1 else "deepseek-coder:33b"
    prompt = sys.argv[2] if len(sys.argv) > 2 else "Write hello world in Python"
    
    print(f"Target: {model}")
    print(f"Prompt: {prompt}")
    print("="*60)
    
    try_load_with_api(model, prompt)
