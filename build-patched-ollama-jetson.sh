#!/bin/bash
# Simple approach: Build patched Ollama in a Docker container

set -e

echo "=========================================="
echo "Building Patched Ollama for Large Models"
echo "=========================================="

# Create a new Dockerfile with the patch built-in
cat > /tmp/Dockerfile.ollama-patched <<'DOCKERFILEEND'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV OLLAMA_HOST=0.0.0.0:11434
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential cmake curl git wget ca-certificates libgomp1 \
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

# Patch the memory check
# Replace the memory validation with a stub that always succeeds
RUN sed -i '/model is too large for system memory/,+2d' server/sched.go || true
RUN sed -i 's/if estimate\.TotalSize > systemFreeMemory/if false \&\& estimate.TotalSize > systemFreeMemory/g' server/sched.go || true

# Show what we changed
RUN echo "=== Patched sched.go ===" && grep -A 5 "systemFreeMemory" server/sched.go || echo "Pattern not found, trying alternative..."

# Build
ENV CUDA_ARCHITECTURES="87"
ENV CGO_ENABLED=1
ENV GOARCH=arm64

RUN go generate ./...
RUN go build -tags cuda -o /usr/local/bin/ollama .

RUN mkdir -p /root/.ollama

EXPOSE 11434

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:11434/api/tags || exit 1

ENTRYPOINT ["/usr/local/bin/ollama"]
CMD ["serve"]
DOCKERFILEEND

echo "[1/3] Building patched Docker image..."
echo "This will take 30-60 minutes..."

docker build -t ollama-jetson:patched -f /tmp/Dockerfile.ollama-patched . || {
    echo "Build failed!"
    exit 1
}

echo "[2/3] Stopping current container..."
docker stop ollama-orin
docker rm ollama-orin

echo "[3/3] Starting patched Ollama..."
docker run -d \
    --runtime=nvidia \
    --network host \
    --restart always \
    --name ollama-orin \
    -v ollama-data:/root/.ollama \
    -e OLLAMA_HOST=0.0.0.0:11434 \
    -e OLLAMA_NUM_PARALLEL=1 \
    -e OLLAMA_MAX_LOADED_MODELS=1 \
    --memory-swap=-1 \
    --shm-size=8g \
    ollama-jetson:patched

echo ""
echo "✓ Patched Ollama running!"
echo "Wait 5 seconds then test with:"
echo "docker exec ollama-orin ollama run deepseek-coder:33b 'test'"
DOCKERFILEEND

chmod +x /tmp/build-patched-ollama.sh
/tmp/build-patched-ollama.sh
