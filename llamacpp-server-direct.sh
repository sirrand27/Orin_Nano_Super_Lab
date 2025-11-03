#!/bin/bash
# Run llama.cpp server directly with Ollama models
# Bypasses Ollama's memory restrictions completely

set -e

echo "=========================================="
echo "llama.cpp Direct Server for Large Models"
echo "Jetson Orin Nano + 128GB Swap"
echo "=========================================="

# Configuration
SERVER_PORT=8080
GPU_LAYERS=25  # Adjust based on model size
CONTEXT_SIZE=4096
THREADS=6

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to extract model from Ollama
extract_model() {
    local model_name=$1
    echo -e "${YELLOW}Extracting $model_name from Ollama cache...${NC}"
    
    # Get model info
    ssh jetson "docker exec ollama-orin ollama show $model_name" || {
        echo "Model not found. Pull it first with: ollama pull $model_name"
        exit 1
    }
    
    # Find the model blob
    echo "Finding model file..."
    MODEL_BLOB=$(ssh jetson "docker exec ollama-orin ollama show $model_name --modelfile" | grep "FROM" | awk '{print $2}')
    echo "Model blob: $MODEL_BLOB"
}

# Function to start llama.cpp server
start_server() {
    local model_name=$1
    local gpu_layers=${2:-25}
    
    echo -e "${YELLOW}Starting llama.cpp server for $model_name${NC}"
    echo "Configuration:"
    echo "  - Port: $SERVER_PORT"
    echo "  - GPU Layers: $gpu_layers"
    echo "  - CPU Threads: $THREADS"
    echo "  - Context Size: $CONTEXT_SIZE"
    
    # Find model in Ollama cache
    case "$model_name" in
        deepseek-coder:33b)
            MODEL_HASH="sha256-065b9a7416ba28634cd4efc2cd3024d4755731c1275dc0286b81b01793185fbb"
            ;;
        llama3.3:70b)
            MODEL_HASH="sha256-4824460d29f26e0fab0b69705ed8346b2340372e98b8f7890fdcfb1b82fe9e98"
            ;;
        qwen2.5:32b)
            MODEL_HASH="sha256-9f13ba1299af89c1154ac3c0d0efdb2fb6c82e0cebb7d5b8c1b7b3b0b8c0c0c0"
            ;;
        *)
            echo "Unknown model. Finding automatically..."
            MODEL_HASH=$(ssh jetson "docker exec ollama-orin find /root/.ollama/models/blobs -name 'sha256-*' -size +10G | head -1 | xargs basename")
            ;;
    esac
    
    MODEL_PATH="/root/.ollama/models/blobs/$MODEL_HASH"
    
    echo "Model path: $MODEL_PATH"
    
    # Check if llama-server exists in container
    echo "Checking for llama.cpp binaries..."
    ssh jetson "docker exec ollama-orin find /build -name 'llama-server' -o -name 'llama-cli' 2>/dev/null" || {
        echo "llama.cpp binaries not found in expected location"
        echo "Searching entire container..."
        ssh jetson "docker exec ollama-orin find / -name 'llama-server' 2>/dev/null | head -5"
    }
    
    # Try to run server
    LLAMA_BIN=$(ssh jetson "docker exec ollama-orin find /build -name 'llama-server' 2>/dev/null | head -1")
    
    if [ -z "$LLAMA_BIN" ]; then
        echo "llama-server not found, trying llama-cli..."
        LLAMA_BIN=$(ssh jetson "docker exec ollama-orin find /build -name 'llama-cli' 2>/dev/null | head -1")
    fi
    
    if [ -z "$LLAMA_BIN" ]; then
        echo "ERROR: No llama.cpp binary found"
        echo "The Ollama build may not have exposed the llama.cpp binaries"
        exit 1
    fi
    
    echo "Using: $LLAMA_BIN"
    
    # Start server in background
    ssh jetson "docker exec -d ollama-orin $LLAMA_BIN \
        --model $MODEL_PATH \
        --host 0.0.0.0 \
        --port $SERVER_PORT \
        --ctx-size $CONTEXT_SIZE \
        --threads $THREADS \
        --n-gpu-layers $gpu_layers \
        --parallel 1 \
        --cont-batching"
    
    echo -e "${GREEN}Server starting!${NC}"
    echo "Test with: curl http://192.168.100.191:$SERVER_PORT/v1/chat/completions -H 'Content-Type: application/json' -d '{\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'"
}

# Main
case "$1" in
    start)
        if [ -z "$2" ]; then
            echo "Usage: $0 start <model_name> [gpu_layers]"
            echo "Example: $0 start deepseek-coder:33b 25"
            exit 1
        fi
        start_server "$2" "${3:-25}"
        ;;
    stop)
        echo "Stopping llama.cpp server..."
        ssh jetson "docker exec ollama-orin pkill -f llama-server || true"
        echo "Stopped"
        ;;
    list)
        echo "Available large models:"
        ssh jetson "docker exec ollama-orin ollama list"
        ;;
    *)
        echo "Usage: $0 {start|stop|list}"
        echo ""
        echo "Commands:"
        echo "  start <model> [gpu_layers]  - Start llama.cpp server"
        echo "  stop                         - Stop llama.cpp server"
        echo "  list                         - List available models"
        exit 1
        ;;
esac
