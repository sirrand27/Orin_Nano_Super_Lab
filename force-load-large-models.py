#!/usr/bin/env python3
"""
Force-Load Large Models on Jetson Orin Nano
Bypasses Ollama's memory check by directly calling llama.cpp
"""

import subprocess
import json
import sys
import os
import time
from pathlib import Path

class JetsonLargeModelLoader:
    def __init__(self):
        self.jetson_host = "192.168.100.191"
        self.ollama_models_path = "/root/.ollama/models/blobs"
        
    def run_ssh(self, command):
        """Execute command on Jetson via SSH"""
        result = subprocess.run(
            ["ssh", "jetson", command],
            capture_output=True,
            text=True
        )
        return result.stdout, result.stderr, result.returncode
    
    def list_models(self):
        """List available Ollama models"""
        stdout, stderr, code = self.run_ssh("docker exec ollama-orin ollama list")
        print(stdout)
        return stdout
    
    def find_model_blob(self, model_name):
        """Find the actual model file for a given model name"""
        print(f"Finding blob for {model_name}...")
        
        # Get model info
        stdout, stderr, code = self.run_ssh(
            f"docker exec ollama-orin ollama show {model_name} --modelfile"
        )
        
        if code != 0:
            print(f"Error: Model {model_name} not found")
            return None
        
        # Parse the modelfile for the blob hash
        for line in stdout.split('\n'):
            if line.startswith('FROM'):
                # Extract blob name from "FROM @sha256:..."
                parts = line.split()
                if len(parts) >= 2:
                    blob_ref = parts[1]
                    if blob_ref.startswith('@'):
                        blob_hash = blob_ref[1:]  # Remove @
                        return blob_hash
        
        # Fallback: search for large files
        print("Searching for large model files...")
        stdout, stderr, code = self.run_ssh(
            f"docker exec ollama-orin find {self.ollama_models_path} -type f -size +10G"
        )
        
        files = stdout.strip().split('\n')
        if files and files[0]:
            print(f"Found {len(files)} large model files")
            for f in files:
                print(f"  - {f}")
            return files[0]
        
        return None
    
    def get_llama_binary(self):
        """Find llama.cpp binary in the container"""
        # Check common locations
        locations = [
            "/build/ollama/llm/build/linux/arm64/cuda/bin/llama-server",
            "/build/ollama/llm/build/linux/arm64/cuda/bin/llama-cli",
            "/usr/local/bin/llama-server",
            "/usr/local/bin/llama-cli"
        ]
        
        for loc in locations:
            stdout, stderr, code = self.run_ssh(
                f"docker exec ollama-orin test -f {loc} && echo 'found'"
            )
            if 'found' in stdout:
                print(f"Found llama binary: {loc}")
                return loc
        
        # Search for it
        print("Searching for llama binary...")
        stdout, stderr, code = self.run_ssh(
            "docker exec ollama-orin find /build -name 'llama-*' -type f 2>/dev/null | head -10"
        )
        
        binaries = stdout.strip().split('\n')
        for binary in binaries:
            if 'server' in binary or 'cli' in binary:
                print(f"Found: {binary}")
                return binary
        
        return None
    
    def force_load_model(self, model_name, gpu_layers=25, context_size=4096):
        """Force load a large model with explicit GPU layer limit"""
        print(f"\n{'='*60}")
        print(f"Force Loading: {model_name}")
        print(f"GPU Layers: {gpu_layers} (rest will use CPU + 128GB swap)")
        print(f"Context Size: {context_size}")
        print(f"{'='*60}\n")
        
        # Find model blob
        model_blob = self.find_model_blob(model_name)
        if not model_blob:
            print("ERROR: Could not find model file")
            return False
        
        print(f"Model blob: {model_blob}")
        
        # Determine model path
        if model_blob.startswith('sha256'):
            model_path = f"{self.ollama_models_path}/{model_blob}"
        else:
            model_path = model_blob
        
        # Find llama binary
        llama_bin = self.get_llama_binary()
        if not llama_bin:
            print("ERROR: Could not find llama.cpp binary")
            print("The Ollama container may not have exposed llama.cpp tools")
            return False
        
        # Determine if it's server or cli
        is_server = 'server' in llama_bin
        
        if is_server:
            print("\nStarting llama.cpp server mode...")
            command = f"""docker exec -d ollama-orin {llama_bin} \\
                --model {model_path} \\
                --host 0.0.0.0 \\
                --port 8080 \\
                --ctx-size {context_size} \\
                --threads 6 \\
                --n-gpu-layers {gpu_layers} \\
                --parallel 1
            """.replace('\n', ' ')
        else:
            print("\nStarting llama.cpp CLI mode...")
            print("Note: CLI mode is for single queries only")
            return llama_bin, model_path
        
        stdout, stderr, code = self.run_ssh(command)
        
        if code == 0:
            print("\n✓ Server started successfully!")
            print(f"Access at: http://{self.jetson_host}:8080")
            print("\nTest with:")
            print(f"  curl http://{self.jetson_host}:8080/v1/chat/completions \\")
            print('    -H "Content-Type: application/json" \\')
            print('    -d \'{"messages":[{"role":"user","content":"Hello"}]}\'')
            return True
        else:
            print(f"\n✗ Error starting server")
            print(f"STDOUT: {stdout}")
            print(f"STDERR: {stderr}")
            return False
    
    def query_direct(self, model_name, prompt, gpu_layers=25):
        """Query model directly using llama-cli"""
        print(f"\nQuerying {model_name} with prompt: {prompt}")
        
        result = self.force_load_model(model_name, gpu_layers)
        if isinstance(result, tuple):
            llama_bin, model_path = result
            
            command = f"""docker exec ollama-orin {llama_bin} \\
                --model {model_path} \\
                --prompt "{prompt}" \\
                --ctx-size 4096 \\
                --threads 6 \\
                --n-gpu-layers {gpu_layers} \\
                --temp 0.7 \\
                --n-predict 512
            """.replace('\n', ' ')
            
            print("\nExecuting query...")
            stdout, stderr, code = self.run_ssh(command)
            
            print("\n" + "="*60)
            print("RESPONSE:")
            print("="*60)
            print(stdout)
            
            if stderr:
                print("\nDebug info:")
                print(stderr)
            
            return stdout
        else:
            return result

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 force-load-large-models.py list")
        print("  python3 force-load-large-models.py server <model_name> [gpu_layers]")
        print("  python3 force-load-large-models.py query <model_name> <prompt> [gpu_layers]")
        print("")
        print("Examples:")
        print("  python3 force-load-large-models.py list")
        print("  python3 force-load-large-models.py server deepseek-coder:33b 25")
        print("  python3 force-load-large-models.py query deepseek-coder:33b 'Write hello world' 25")
        sys.exit(1)
    
    loader = JetsonLargeModelLoader()
    command = sys.argv[1]
    
    if command == "list":
        loader.list_models()
    
    elif command == "server":
        if len(sys.argv) < 3:
            print("Error: model name required")
            sys.exit(1)
        model_name = sys.argv[2]
        gpu_layers = int(sys.argv[3]) if len(sys.argv) > 3 else 25
        loader.force_load_model(model_name, gpu_layers)
    
    elif command == "query":
        if len(sys.argv) < 4:
            print("Error: model name and prompt required")
            sys.exit(1)
        model_name = sys.argv[2]
        prompt = sys.argv[3]
        gpu_layers = int(sys.argv[4]) if len(sys.argv) > 4 else 25
        loader.query_direct(model_name, prompt, gpu_layers)
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()
