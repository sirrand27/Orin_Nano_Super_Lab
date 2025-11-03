#!/bin/bash
# Ultimate solution: Restart Ollama with memory overcommit enabled
# This forces the system to allow Ollama to allocate beyond physical memory

set -e

echo "=========================================="
echo "Enabling Memory Overcommit for Large Models"
echo "Jetson Orin Nano + 128GB Swap"
echo "=========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "\n${YELLOW}[STEP 1] Configuring system memory overcommit${NC}"

# Enable memory overcommit on Jetson
ssh jetson 'sudo sysctl -w vm.overcommit_memory=1'
ssh jetson 'sudo sysctl -w vm.swappiness=100'
ssh jetson 'sudo sysctl -w vm.vfs_cache_pressure=50'

echo -e "${GREEN}[OK]${NC} System configured for aggressive swap usage"

echo -e "\n${YELLOW}[STEP 2] Stopping current Ollama container${NC}"
ssh jetson 'docker stop ollama-orin'
ssh jetson 'docker rm ollama-orin'

echo -e "\n${YELLOW}[STEP 3] Starting Ollama with unlimited memory${NC}"

ssh jetson 'docker run -d \
    --runtime=nvidia \
    --network host \
    --restart always \
    --name ollama-orin \
    -v ollama-data:/root/.ollama \
    -e OLLAMA_HOST=0.0.0.0:11434 \
    -e OLLAMA_NUM_PARALLEL=1 \
    -e OLLAMA_MAX_LOADED_MODELS=1 \
    -e OLLAMA_KEEP_ALIVE=5m \
    -e OLLAMA_DEBUG=1 \
    --memory-swap=-1 \
    --memory-swappiness=100 \
    --oom-kill-disable=true \
    --shm-size=8g \
    --ulimit memlock=-1:-1 \
    ollama-jetson:orin-nano-jp36.4'

echo -e "\n${YELLOW}[STEP 4] Waiting for Ollama to start...${NC}"
sleep 5

echo -e "\n${YELLOW}[STEP 5] Testing with deepseek-coder:33b${NC}"
echo "This will take a few minutes to load into swap..."

ssh jetson 'timeout 300 docker exec ollama-orin ollama run deepseek-coder:33b "Write hello world in Python"' || {
    echo -e "\n${RED}Model loading timed out or failed${NC}"
    echo "Checking logs..."
    ssh jetson 'docker logs --tail 30 ollama-orin'
    exit 1
}

echo -e "\n${GREEN}[SUCCESS]${NC} Large model working with swap!"
