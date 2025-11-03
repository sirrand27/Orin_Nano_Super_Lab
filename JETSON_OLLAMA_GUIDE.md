# Ollama on Jetson Orin Nano - Setup Guide

## Overview

This guide builds Ollama with CUDA support optimized for the NVIDIA Jetson Orin Nano running JetPack 36.4.7 (L4T R36.4.0).

## Hardware Requirements

- **Device**: Jetson Orin Nano (8GB recommended)
- **JetPack**: 36.4.7 (L4T R36.4.0)
- **Storage**: 20GB+ free space
- **Compute**: CUDA Compute Capability 8.7 (Ampere)

## Prerequisites

### 1. Install Docker (if not already installed)

```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

Log out and back in for group changes to take effect.

### 2. Install NVIDIA Container Runtime

```bash
sudo apt-get update
sudo apt-get install -y nvidia-container-runtime
sudo systemctl restart docker
```

### 3. Verify CUDA Installation

```bash
nvcc --version
# Should show CUDA 12.6 for JetPack 36.4.7
```

## Quick Start

### 1. Download Files

```bash
# Transfer Dockerfile.jetson-ollama and build-ollama-jetson.sh to your Jetson
```

### 2. Make Build Script Executable

```bash
chmod +x build-ollama-jetson.sh
```

### 3. Run Build Script

```bash
./build-ollama-jetson.sh
```

This will:
- Verify prerequisites
- Build the Docker image (30-60 minutes)
- Start Ollama container
- Test the installation

## Manual Build Steps

If you prefer manual control:

### Build the Image

```bash
docker build \
    --tag ollama-jetson:orin-nano-jp36.4 \
    --file Dockerfile.jetson-ollama \
    .
```

### Run the Container

```bash
docker run -d \
    --name ollama-orin \
    --runtime nvidia \
    --gpus all \
    --network host \
    --restart unless-stopped \
    -v ollama-data:/root/.ollama \
    ollama-jetson:orin-nano-jp36.4
```

## Using Ollama

### Pull a Model

```bash
# Lightweight models recommended for 8GB Orin Nano
docker exec ollama-orin ollama pull llama3.2:1b
docker exec ollama-orin ollama pull phi3:mini
docker exec ollama-orin ollama pull gemma2:2b
```

### Interactive Chat

```bash
docker exec -it ollama-orin ollama run llama3.2:1b
```

### API Usage

```bash
# Generate completion
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:1b",
  "prompt": "Explain what is machine learning",
  "stream": false
}'

# Chat completion
curl http://localhost:11434/api/chat -d '{
  "model": "llama3.2:1b",
  "messages": [
    {
      "role": "user",
      "content": "Hello! How are you?"
    }
  ]
}'
```

### List Models

```bash
docker exec ollama-orin ollama list
```

### Remove a Model

```bash
docker exec ollama-orin ollama rm llama3.2:1b
```

## Recommended Models for Jetson Orin Nano 8GB

| Model | Size | Memory Usage | Speed | Quality |
|-------|------|--------------|-------|---------|
| **tinyllama:1.1b** | 637MB | ~1.5GB | Very Fast | Basic |
| **qwen2.5:1.5b** | 934MB | ~2GB | Fast | Good |
| **llama3.2:1b** | 1.3GB | ~2.5GB | Fast | Very Good |
| **gemma2:2b** | 1.6GB | ~3GB | Medium | Excellent |
| **phi3:mini** | 2.3GB | ~4GB | Medium | Excellent |
| **llama3.2:3b** | 2.0GB | ~4GB | Medium | Excellent |

**Note**: Avoid models >3B parameters due to 8GB RAM constraint.

## Performance Optimization

### Monitor GPU Usage

```bash
# Real-time Jetson stats
sudo tegrastats

# Docker container stats
docker stats ollama-orin
```

### Increase Swap (if needed)

```bash
# Create 8GB swap file
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Make permanent
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

### Power Mode

```bash
# Max performance (15W mode for Orin Nano)
sudo nvpmodel -m 0
sudo jetson_clocks
```

## Troubleshooting

### Build Fails with "CUDA not found"

```bash
# Verify CUDA installation
ls /usr/local/cuda/bin/nvcc
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
```

### Container Won't Start

```bash
# Check logs
docker logs ollama-orin

# Verify NVIDIA runtime
docker run --rm --runtime nvidia nvcr.io/nvidia/l4t-base:36.4.0 nvidia-smi
```

### Out of Memory Errors

- Use smaller models (1B-2B parameters)
- Enable swap space
- Close other applications
- Reduce context length in API calls

### Slow Performance

```bash
# Enable max performance mode
sudo nvpmodel -m 0
sudo jetson_clocks

# Check if GPU is being used
docker exec ollama-orin nvidia-smi
```

## Container Management

```bash
# View logs
docker logs -f ollama-orin

# Stop container
docker stop ollama-orin

# Start container
docker start ollama-orin

# Restart container
docker restart ollama-orin

# Remove container
docker rm -f ollama-orin

# Remove container and data
docker rm -f ollama-orin
docker volume rm ollama-data
```

## Advanced Configuration

### Custom Port

```bash
docker run -d \
    --name ollama-orin \
    --runtime nvidia \
    --gpus all \
    -p 8080:11434 \
    -e OLLAMA_HOST=0.0.0.0:11434 \
    -v ollama-data:/root/.ollama \
    ollama-jetson:orin-nano-jp36.4
```

### Multiple GPU Contexts

```bash
# Set concurrent processing
docker run -d \
    --name ollama-orin \
    --runtime nvidia \
    --gpus all \
    -e OLLAMA_NUM_PARALLEL=2 \
    -v ollama-data:/root/.ollama \
    ollama-jetson:orin-nano-jp36.4
```

### Enable Debug Logging

```bash
docker run -d \
    --name ollama-orin \
    --runtime nvidia \
    --gpus all \
    -e OLLAMA_DEBUG=1 \
    -v ollama-data:/root/.ollama \
    ollama-jetson:orin-nano-jp36.4
```

## Integration Examples

### Python Client

```python
import requests
import json

def chat(prompt, model="llama3.2:1b"):
    response = requests.post(
        "http://localhost:11434/api/generate",
        json={
            "model": model,
            "prompt": prompt,
            "stream": False
        }
    )
    return response.json()["response"]

result = chat("What is the capital of France?")
print(result)
```

### Node.js Client

```javascript
const axios = require('axios');

async function chat(prompt, model = 'llama3.2:1b') {
    const response = await axios.post('http://localhost:11434/api/generate', {
        model: model,
        prompt: prompt,
        stream: false
    });
    return response.data.response;
}

chat("Explain quantum computing").then(console.log);
```

## Benchmarking

```bash
# Simple throughput test
time docker exec ollama-orin ollama run llama3.2:1b "Count from 1 to 100"

# Monitor during inference
watch -n 1 'docker exec ollama-orin nvidia-smi'
```

## Backup and Restore

### Backup Models

```bash
docker run --rm \
    -v ollama-data:/data \
    -v $(pwd):/backup \
    ubuntu \
    tar czf /backup/ollama-models-backup.tar.gz -C /data .
```

### Restore Models

```bash
docker run --rm \
    -v ollama-data:/data \
    -v $(pwd):/backup \
    ubuntu \
    tar xzf /backup/ollama-models-backup.tar.gz -C /data
```

## Resources

- **Ollama Documentation**: https://ollama.ai/docs
- **Jetson Software**: https://developer.nvidia.com/embedded/jetpack
- **Model Library**: https://ollama.ai/library
- **Jetson Forums**: https://forums.developer.nvidia.com/c/agx-autonomous-machines/jetson-embedded-systems/

## Support

For issues specific to:
- **Ollama**: https://github.com/ollama/ollama/issues
- **Jetson**: https://forums.developer.nvidia.com/c/agx-autonomous-machines/jetson-embedded-systems/
- **Docker**: https://docs.docker.com/

## License

This setup is provided as-is. Ollama is licensed under the MIT License.
