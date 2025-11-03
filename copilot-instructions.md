# Copilot Instructions - Jetson Orin Nano AI Setup

This repository contains setup scripts and documentation for running Ollama with CUDA support on NVIDIA Jetson Orin Nano Super (8GB RAM, 1TB NVMe SSD, JetPack 36.4.7).

## Key Context
- **Hardware**: Jetson Orin Nano Super, CUDA 12.6, Ampere architecture (compute 8.7)
- **OS**: Ubuntu 22.04 ARM64 on NVMe SSD (booting from /dev/nvme0n1p1)
- **Swap**: 128GB on SSD for large model support (136GB total memory)
- **Ollama**: Running in Docker with NVIDIA runtime, host network mode
- **Web UI**: Open WebUI on port 3000
- **SSH**: Passwordless via key (jetson.key)

## Scripts
- `migrate-to-ssd.sh`: Migrate from SD card to NVMe
- `optimize-swap.sh`: Create large swap file
- `fix-ssd-boot.sh`: Fix boot configuration
- Monitoring: `ollama-token-monitor.sh`, `ollama-live-monitor.py`, `monitor-combined.sh`

## Commands
- SSH: `ssh jetson` or `ssh rawi@192.168.100.191`
- Docker: `docker exec ollama-orin ollama <command>`
- Pull models: `docker exec ollama-orin ollama pull <model>`
