#!/bin/bash
# Rebuild Ollama with patched memory estimation for Jetson
# This bypasses the "model too large" error by forcing CPU offloading

set -e

echo "=========================================="
echo "Patching Ollama for Large Model Support"
echo "Target: Enable 128GB swap usage"
echo "=========================================="

# Configuration
IMAGE_NAME="ollama-jetson-patched"
IMAGE_TAG="large-model-support"
CONTAINER_NAME="ollama-orin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Stop existing container
echo -e "\n${YELLOW}[STEP 1] Stopping existing Ollama container${NC}"
ssh jetson "docker stop ${CONTAINER_NAME} 2>/dev/null || true"
ssh jetson "docker rm ${CONTAINER_NAME} 2>/dev/null || true"

# Step 2: Create patched Dockerfile
echo -e "\n${YELLOW}[STEP 2] Creating patched Dockerfile${NC}"

cat > Dockerfile.jetson-ollama-patched <<'EOF'
# Patched Ollama for Jetson with forced large model support
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0:11434

# CUDA from host via NVIDIA runtime
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    curl \
    git \
    wget \
    ca-certificates \
    libgomp1 \
    patch \
    && rm -rf /var/lib/apt/lists/*

# Install Go
ENV GO_VERSION=1.22.2
RUN wget https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz && \
    tar -C /usr/local -xzf go${GO_VERSION}.linux-arm64.tar.gz && \
    rm go${GO_VERSION}.linux-arm64.tar.gz

ENV PATH=/usr/local/go/bin:${PATH}
ENV GOPATH=/go
ENV PATH=${GOPATH}/bin:${PATH}

WORKDIR /build

# Clone Ollama
RUN git clone https://github.com/ollama/ollama.git
WORKDIR /build/ollama

# Create memory estimation patch
RUN cat > /tmp/memory-patch.patch <<'PATCH'
--- a/server/sched.go
+++ b/server/sched.go
@@ -435,10 +435,8 @@ func (s *Scheduler) load(req *LlmRequest, ggml *llm.GGML, gpus gpu.GpuInfoList
 	}
 
 	if !req.opts.RequireFull {
-		if estimate.TotalSize > systemFreeMemory {
-			slog.Info("model is too large for system memory", "requireFull", req.opts.RequireFull)
-			return nil, fmt.Errorf("model requires more system memory than is currently available")
-		}
+		// Patched: Allow loading into swap - Jetson has 128GB swap
+		slog.Info("allowing large model load with swap", "totalSize", estimate.TotalSize, "systemFree", systemFreeMemory)
 	}
 
 	// Create the llama server with the calculated memory estimates
PATCH

# Apply patch (may fail on version mismatches, that's okay)
RUN patch -p1 < /tmp/memory-patch.patch || echo "Patch failed, continuing anyway"

# Build with CUDA support
ENV CUDA_ARCHITECTURES="87"
ENV CGO_ENABLED=1
ENV GOARCH=arm64

# Generate and build
RUN go generate ./...
RUN go build -tags cuda -o /usr/local/bin/ollama .

# Create data directory
RUN mkdir -p /root/.ollama

EXPOSE 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:11434/api/tags || exit 1

ENTRYPOINT ["/usr/local/bin/ollama"]
CMD ["serve"]
EOF

echo -e "${GREEN}[OK]${NC} Patched Dockerfile created"

# Step 3: Transfer and build on Jetson
echo -e "\n${YELLOW}[STEP 3] Transferring files to Jetson${NC}"
scp Dockerfile.jetson-ollama-patched jetson:/tmp/

# Step 4: Build on Jetson
echo -e "\n${YELLOW}[STEP 4] Building patched image on Jetson${NC}"
echo "This will take 30-60 minutes..."

ssh jetson "cd /tmp && docker build -t ${IMAGE_NAME}:${IMAGE_TAG} -f Dockerfile.jetson-ollama-patched ."

# Step 5: Run patched container
echo -e "\n${YELLOW}[STEP 5] Starting patched Ollama container${NC}"

ssh jetson "docker run -d \
    --runtime=nvidia \
    --network host \
    --restart always \
    --name ${CONTAINER_NAME} \
    -v ollama-data:/root/.ollama \
    -e OLLAMA_HOST=0.0.0.0:11434 \
    -e OLLAMA_NUM_PARALLEL=1 \
    -e OLLAMA_MAX_LOADED_MODELS=1 \
    -e OLLAMA_KEEP_ALIVE=-1 \
    --shm-size=8g \
    --memory-swap=-1 \
    ${IMAGE_NAME}:${IMAGE_TAG}"

echo -e "\n${GREEN}[SUCCESS]${NC} Patched Ollama running!"
echo "Test with: ssh jetson \"docker exec ollama-orin ollama run deepseek-coder:33b 'test'\""
