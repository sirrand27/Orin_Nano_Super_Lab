#!/bin/bash
# Ollama Build Script for Jetson Orin Nano
# JetPack 36.4.7 / L4T R36.4.0

set -e

echo "=========================================="
echo "Ollama Build Plan for Jetson Orin Nano"
echo "JetPack 36.4.7 (L4T R36.4.0)"
echo "=========================================="

# Configuration
IMAGE_NAME="ollama-jetson"
IMAGE_TAG="orin-nano-jp36.4"
CONTAINER_NAME="ollama-orin"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Verify Prerequisites
echo -e "\n${YELLOW}[STEP 1] Verifying Prerequisites${NC}"

# Check if running on Jetson
if [ ! -f /etc/nv_tegra_release ]; then
    echo -e "${RED}Error: Not running on a Jetson device${NC}"
    echo "This script must be run on the Jetson Orin Nano"
    exit 1
fi

echo -e "${GREEN}[OK]${NC} Running on Jetson device"

# Check JetPack version
if grep -q "36.4" /etc/nv_tegra_release; then
    echo -e "${GREEN}[OK]${NC} JetPack 36.4.x detected"
else
    echo -e "${YELLOW}[WARNING]${NC} JetPack version may not match 36.4.x"
    cat /etc/nv_tegra_release
fi

# Check Docker installation
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker not found${NC}"
    echo "Install Docker with: sudo apt-get install docker.io"
    exit 1
fi
echo -e "${GREEN}[OK]${NC} Docker installed"

# Check NVIDIA Container Runtime
if ! docker info | grep -q nvidia; then
    echo -e "${YELLOW}[WARNING]${NC} NVIDIA Container Runtime may not be configured"
    echo "Install with: sudo apt-get install nvidia-container-runtime"
fi

# Check available disk space (need at least 10GB)
AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$AVAILABLE_SPACE" -lt 10 ]; then
    echo -e "${YELLOW}[WARNING]${NC} Low disk space: ${AVAILABLE_SPACE}GB available (recommend 10GB+)"
else
    echo -e "${GREEN}[OK]${NC} Sufficient disk space: ${AVAILABLE_SPACE}GB"
fi

# Step 2: Build Docker Image
echo -e "\n${YELLOW}[STEP 2] Building Ollama Docker Image${NC}"
echo "This will take 30-60 minutes depending on network and CPU..."

docker build \
    --network=host \
    --tag ${IMAGE_NAME}:${IMAGE_TAG} \
    --file Dockerfile.jetson-ollama \
    .

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[OK]${NC} Docker image built successfully"
else
    echo -e "${RED}[ERROR]${NC} Docker build failed"
    exit 1
fi

# Step 3: Verify Image
echo -e "\n${YELLOW}[STEP 3] Verifying Image${NC}"

IMAGE_SIZE=$(docker images ${IMAGE_NAME}:${IMAGE_TAG} --format "{{.Size}}")
echo "Image size: ${IMAGE_SIZE}"

# Step 4: Test Run
echo -e "\n${YELLOW}[STEP 4] Testing Ollama Container${NC}"

echo "Starting Ollama container..."
docker run -d \
    --name ${CONTAINER_NAME} \
    --runtime nvidia \
    --gpus all \
    --network host \
    --restart unless-stopped \
    -v ollama-data:/root/.ollama \
    ${IMAGE_NAME}:${IMAGE_TAG}

# Wait for container to start
echo "Waiting for Ollama to initialize..."
sleep 10

# Check if container is running
if docker ps | grep -q ${CONTAINER_NAME}; then
    echo -e "${GREEN}[OK]${NC} Container is running"
else
    echo -e "${RED}[ERROR]${NC} Container failed to start"
    docker logs ${CONTAINER_NAME}
    exit 1
fi

# Test API endpoint
echo "Testing Ollama API..."
sleep 5
if curl -f http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}[OK]${NC} Ollama API is responding"
else
    echo -e "${YELLOW}[WARNING]${NC} API not responding yet, may need more time to initialize"
fi

# Step 5: Display Usage Instructions
echo -e "\n${GREEN}=========================================="
echo "Build Complete!"
echo "==========================================${NC}"

echo -e "\n${YELLOW}Container Management:${NC}"
echo "  View logs:    docker logs -f ${CONTAINER_NAME}"
echo "  Stop:         docker stop ${CONTAINER_NAME}"
echo "  Start:        docker start ${CONTAINER_NAME}"
echo "  Remove:       docker rm -f ${CONTAINER_NAME}"

echo -e "\n${YELLOW}Pull a Model:${NC}"
echo "  docker exec ${CONTAINER_NAME} ollama pull llama3.2:1b"
echo "  docker exec ${CONTAINER_NAME} ollama pull phi3:mini"
echo "  docker exec ${CONTAINER_NAME} ollama pull gemma2:2b"

echo -e "\n${YELLOW}Run a Model:${NC}"
echo "  docker exec -it ${CONTAINER_NAME} ollama run llama3.2:1b"

echo -e "\n${YELLOW}API Usage:${NC}"
echo "  curl http://localhost:11434/api/generate -d '{\"model\":\"llama3.2:1b\",\"prompt\":\"Hello!\"}'"

echo -e "\n${YELLOW}Recommended Models for Orin Nano (8GB RAM):${NC}"
echo "  - llama3.2:1b          (1.3GB)  - Fast, good quality"
echo "  - phi3:mini            (2.3GB)  - Microsoft, very efficient"
echo "  - gemma2:2b            (1.6GB)  - Google, good performance"
echo "  - tinyllama:1.1b       (637MB)  - Smallest, fastest"
echo "  - qwen2.5:1.5b         (934MB)  - Alibaba, multilingual"

echo -e "\n${YELLOW}System Monitoring:${NC}"
echo "  GPU usage:    sudo tegrastats"
echo "  Container:    docker stats ${CONTAINER_NAME}"

echo -e "\n${GREEN}Done! Ollama is ready to use.${NC}"
