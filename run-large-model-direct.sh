#!/bin/bash
# Direct llama.cpp runner for large models on Jetson
# Bypasses Ollama's memory estimation to use full swap space

set -e

# Configuration
MODEL_PATH="/root/.ollama/models/blobs"
CONTEXT_SIZE=4096
THREADS=6
GPU_LAYERS=20  # Only 20 layers on GPU, rest on CPU using swap

echo "=========================================="
echo "Direct Large Model Runner for Jetson"
echo "Using 128GB swap + 8GB RAM"
echo "=========================================="

# Function to find model file
find_model() {
    local model_name=$1
    echo "Searching for $model_name in Ollama cache..."
    
    # Find the model blob
    docker exec ollama-orin find /root/.ollama/models/blobs -type f -name "sha256-*" -size +10G
}

# Function to run model with llama.cpp directly
run_model_direct() {
    local model_file=$1
    local prompt=$2
    local gpu_layers=${3:-20}
    
    echo "Running model with:"
    echo "  - GPU Layers: $gpu_layers"
    echo "  - CPU Threads: $THREADS"
    echo "  - Context: $CONTEXT_SIZE"
    echo "  - Prompt: $prompt"
    
    docker exec ollama-orin /build/ollama/llm/build/linux/arm64/cuda/bin/llama-cli \
        --model "$model_file" \
        --prompt "$prompt" \
        --ctx-size $CONTEXT_SIZE \
        --threads $THREADS \
        --n-gpu-layers $gpu_layers \
        --temp 0.7 \
        --repeat-penalty 1.1 \
        --color
}

# Main execution
case "$1" in
    list)
        echo "Available large models:"
        docker exec ollama-orin ollama list
        ;;
    find)
        find_model
        ;;
    run)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 run <model_blob_sha> <prompt> [gpu_layers]"
            echo "Example: $0 run sha256-065b9a7416ba... 'Write hello world' 20"
            exit 1
        fi
        model_blob="/root/.ollama/models/blobs/$2"
        prompt="$3"
        gpu_layers="${4:-20}"
        run_model_direct "$model_blob" "$prompt" "$gpu_layers"
        ;;
    *)
        echo "Usage: $0 {list|find|run}"
        echo ""
        echo "Commands:"
        echo "  list                                    - List available models"
        echo "  find                                    - Find large model files"
        echo "  run <model_sha> <prompt> [gpu_layers]  - Run model directly"
        exit 1
        ;;
esac
