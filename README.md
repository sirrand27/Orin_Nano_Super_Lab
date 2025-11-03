# Jetson Orin Nano Super Lab

Complete setup and optimization scripts for running Ollama with CUDA on NVIDIA Jetson Orin Nano Super.

## Hardware Specs
- **Device**: Jetson Orin Nano Super
- **RAM**: 8GB
- **Storage**: 1TB Samsung 990 PRO NVMe SSD
- **Swap**: 128GB (136GB total memory)
- **JetPack**: 36.4.7 (L4T R36.4.0, CUDA 12.6)
- **Architecture**: ARM64, Ampere (compute 8.7)

## Quick Start

### 1. Build Ollama with CUDA Support
```bash
chmod +x build-ollama-jetson.sh
./build-ollama-jetson.sh
```

### 2. Migrate to SSD (if needed)
```bash
chmod +x migrate-to-ssd.sh
./migrate-to-ssd.sh
```

### 3. Optimize with Large Swap
```bash
chmod +x optimize-swap.sh
sudo ./optimize-swap.sh
```

### 4. Install Open WebUI
```bash
docker run -d --network=host \
  --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data \
  -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:main
```

Access at: http://YOUR_JETSON_IP:3000

## Scripts

### Setup Scripts
- **`build-ollama-jetson.sh`** - Build Ollama Docker image with CUDA support
- **`migrate-to-ssd.sh`** - Migrate system from SD card to NVMe SSD
- **`fix-ssd-boot.sh`** - Fix boot configuration for SSD
- **`optimize-swap.sh`** - Create 128GB swap file for large models
- **`install-ollama-ui.sh`** - Quick Open WebUI installation
- **`install-ptop.sh`** - Install ptop system monitor

### Monitoring Scripts
- **`ollama-token-monitor.sh`** - Simple bash token metrics
- **`ollama-live-monitor.py`** - Real-time streaming token monitor
- **`monitor-combined.sh`** - GPU + token monitoring
- **`ollama-gradio-ui.py`** - Alternative Gradio web interface

## Files
- **`Dockerfile.jetson-ollama`** - Ollama Docker build for Jetson
- **`JETSON_OLLAMA_GUIDE.md`** - Comprehensive setup guide
- **`OPEN_WEBUI_TOKEN_DISPLAY.md`** - Token display configuration
- **`SSH_KEY_SETUP.md`** - Passwordless SSH setup

## Model Recommendations

### Fast (Mostly RAM - 8GB or less)
- `llama3.2:3b` (2.0GB) - Best balance
- `phi3.5:3.8b` (2.2GB) - High quality
- `deepseek-coder:6.7b` (3.8GB) - Code specialist
- `mistral:7b-q4` (4GB) - Excellent all-around

### Medium (Some Swap - 8-30GB)
- `llama3.1:70b-q2` (26GB) - Massive model
- `mixtral:8x7b-q4` (26GB) - Mixture of experts
- `qwen2.5:32b` (20GB) - Strong reasoning
- `codellama:34b-q4` (20GB) - Best code model

### Large (Heavy Swap - 30-120GB)
- `llama3.1:70b-q4` (40GB) - High quality 70B
- `qwen2.5:72b-q3` (30GB) - Powerful reasoning
- `mixtral:8x22b-q2` (90GB) - Huge mixture model

## Common Commands

```bash
# SSH to Jetson
ssh jetson

# Pull a model
docker exec ollama-orin ollama pull llama3.2:3b

# List models
docker exec ollama-orin ollama list

# Test a model
docker exec ollama-orin ollama run llama3.2:3b "Hello!"

# Check memory
free -h

# Monitor GPU
sudo tegrastats

# Check swap usage
swapon --show
```

## Performance Tips

1. **Models up to 8GB** run mostly in RAM (fast: 15-30 tok/s)
2. **Models 8-30GB** use some swap (medium: 5-15 tok/s)
3. **Models 30GB+** use heavy swap (slow: 1-5 tok/s)
4. Monitor with: `watch -n 1 free -h`
5. Use quantized models (q4) for best quality/speed balance

## Network
- **Ollama API**: http://localhost:11434
- **Open WebUI**: http://YOUR_IP:3000
- **Container**: ollama-orin

## Requirements
- Jetson Orin Nano (8GB recommended)
- NVMe SSD (128GB+ recommended)
- JetPack 36.4+
- Docker with NVIDIA runtime

## License
MIT

## Contributing
Pull requests welcome! This is a community project for optimizing AI workloads on Jetson hardware.
