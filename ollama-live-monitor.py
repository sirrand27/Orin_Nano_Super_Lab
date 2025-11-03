#!/usr/bin/env python3
"""
Real-time Ollama Token Monitor
Shows live token generation and speed
"""

import requests
import json
import time
from datetime import datetime

def monitor_generation(model="llama3.2:1b", prompt="Explain quantum computing"):
    url = "http://localhost:11434/api/generate"
    
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": True
    }
    
    print(f"\n{'='*60}")
    print(f"Ollama Real-Time Token Monitor")
    print(f"{'='*60}")
    print(f"Model: {model}")
    print(f"Time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"{'='*60}\n")
    print("Response:\n")
    
    token_count = 0
    start_time = time.time()
    response_text = ""
    
    try:
        with requests.post(url, json=payload, stream=True) as response:
            for line in response.iter_lines():
                if line:
                    data = json.loads(line)
                    
                    if 'response' in data:
                        chunk = data['response']
                        response_text += chunk
                        print(chunk, end='', flush=True)
                        token_count += 1
                    
                    if data.get('done', False):
                        elapsed = time.time() - start_time
                        
                        print(f"\n\n{'='*60}")
                        print("METRICS")
                        print(f"{'='*60}")
                        print(f"Total tokens generated: {token_count}")
                        print(f"Total time: {elapsed:.2f} seconds")
                        print(f"Average speed: {token_count/elapsed:.2f} tokens/second")
                        
                        if 'prompt_eval_count' in data:
                            print(f"Input tokens: {data['prompt_eval_count']}")
                        if 'eval_count' in data:
                            print(f"Output tokens: {data['eval_count']}")
                        if 'eval_duration' in data:
                            actual_speed = data['eval_count'] / (data['eval_duration'] / 1e9)
                            print(f"Actual generation speed: {actual_speed:.2f} tokens/second")
                        
                        print(f"{'='*60}\n")
                        
    except KeyboardInterrupt:
        print("\n\nMonitoring stopped by user")
    except Exception as e:
        print(f"\nError: {e}")

if __name__ == "__main__":
    import sys
    
    model = sys.argv[1] if len(sys.argv) > 1 else "llama3.2:1b"
    prompt = sys.argv[2] if len(sys.argv) > 2 else "Write a detailed explanation of machine learning"
    
    monitor_generation(model, prompt)
