# Force Loading Large Models on Jetson Orin Nano Super

## Problem
Ollama has a memory estimation bug on Jetson that prevents loading models larger than GPU VRAM (8GB), even though we have 128GB swap available.

Error: `model requires more system memory than is currently available unable to load full model on GPU`

## Root Cause
Ollama's `server/sched.go` incorrectly calculates memory requirements and refuses to load models that don't fit entirely in GPU memory, ignoring the unified memory architecture and swap space available on Jetson.

---

## Solution 1: Docker Memory Configuration (TRY THIS FIRST)

Restart Ollama with memory limits disabled and swap explicitly enabled.

### Steps:

```bash
# 1. Stop current container
ssh jetson "docker stop ollama-orin && docker rm ollama-orin"

# 2. Restart with unlimited swap
ssh jetson "docker run -d \
    --runtime=nvidia \
    --network host \
    --restart always \
    --name ollama-orin \
    -v ollama-data:/root/.ollama \
    -e OLLAMA_HOST=0.0.0.0:11434 \
    -e OLLAMA_NUM_PARALLEL=1 \
    -e OLLAMA_MAX_LOADED_MODELS=1 \
    -e OLLAMA_KEEP_ALIVE=5m \
    --memory-swap=-1 \
    --oom-kill-disable \
    --shm-size=8g \
    ollama-jetson:orin-nano-jp36.4"

# 3. Test (will be slow on first load)
ssh jetson "docker exec ollama-orin ollama run deepseek-coder:33b 'test'"
```

**Key Docker flags:**
- `--memory-swap=-1`: Unlimited swap usage
- `--oom-kill-disable`: Don't kill container if out of memory
- `--shm-size=8g`: Shared memory for CUDA

---

## Solution 2: System Memory Overcommit (REQUIRES SUDO)

Enable Linux memory overcommit to allow allocations beyond physical RAM.

```bash
# On Jetson (requires sudo)
sudo sysctl -w vm.overcommit_memory=1
sudo sysctl -w vm.swappiness=100
sudo sysctl -w vm.vfs_cache_pressure=50

# Make permanent
echo "vm.overcommit_memory=1" | sudo tee -a /etc/sysctl.conf
echo "vm.swappiness=100" | sudo tee -a /etc/sysctl.conf
echo "vm.vfs_cache_pressure=50" | sudo tee -a /etc/sysctl.conf
```

Then restart Ollama container (Solution 1).

---

## Solution 3: Patch Ollama Source Code

Rebuild Ollama with the memory check removed.

### Quick Patch:
Edit `/build/ollama/server/sched.go` in the Docker build:

```go
// REMOVE OR COMMENT OUT THESE LINES (around line 438):
// if estimate.TotalSize > systemFreeMemory {
//     slog.Info("model is too large for system memory")
//     return nil, fmt.Errorf("model requires more system memory...")
// }

// REPLACE WITH:
slog.Info("allowing large model load with swap", 
    "totalSize", estimate.TotalSize, 
    "systemFree", systemFreeMemory,
    "swapFree", "128GB")
// Continue loading regardless of memory check
```

Use the `patch-ollama-large-models.sh` script to automate this.

---

## Solution 4: Use llama.cpp Directly

Bypass Ollama entirely and use llama.cpp with explicit GPU layer control.

### Extract model from Ollama:
```bash
# Find model blob
MODEL_HASH="sha256-065b9a7416ba..."  # From ollama show
MODEL_PATH="/root/.ollama/models/blobs/$MODEL_HASH"

# Run with llama.cpp (if binaries available)
/path/to/llama-server \
    --model $MODEL_PATH \
    --host 0.0.0.0 \
    --port 8080 \
    --n-gpu-layers 25 \
    --ctx-size 4096 \
    --threads 6
```

Use `force-load-large-models.py` to automate this.

---

## Solution 5: Use Smaller Quantized Models

Pull models that fit in GPU memory (working now):

### Excellent coding models that work:
```bash
docker exec ollama-orin ollama pull qwen2.5-coder:7b  # ✓ WORKS - 4.7GB
docker exec ollama-orin ollama pull codellama:13b     # Should work - ~7GB
docker exec ollama-orin ollama pull deepseek-coder:6.7b  # Should work
```

### General purpose models that work:
```bash
docker exec ollama-orin ollama pull llama3.1:8b       # Should work - ~4.7GB
docker exec ollama-orin ollama pull mistral:7b        # Should work
docker exec ollama-orin ollama pull phi3:14b          # Should work
```

---

## Current Status

### ✓ Working Models:
- `qwen2.5-coder:7b` (4.7GB) - Excellent coding, fits in GPU
- `llama3.2:1b` (1.3GB) - Small general purpose

### ✗ Not Working (Memory Bug):
- `deepseek-coder:33b` (18GB) - Memory estimation fails
- `llama3.3:70b` (42GB) - Memory estimation fails
- `qwen2.5:32b` (19GB) - Memory estimation fails

---

## Recommended Action Plan

### Immediate (No sudo required):
1. **Try Solution 1** - Restart container with `--memory-swap=-1`
2. If that fails, use **Solution 5** - Stick with 7B-13B models

### With System Access (sudo):
1. Apply **Solution 2** - Enable memory overcommit
2. Retry large models
3. If still fails, apply **Solution 3** - Patch Ollama source

### Advanced:
1. **Solution 4** - Use llama.cpp directly for maximum control

---

## Performance Expectations

### Models fitting in 8GB GPU RAM:
- **Fast**: All processing on GPU
- Response time: < 1 second per token

### Models using swap (33B-70B):
- **First load**: 5-15 minutes to load from disk
- **After loaded**: Slow but usable
- Response time: 2-10 seconds per token
- Subsequent queries faster (if model stays in RAM)

### Optimization Tips:
- Set `OLLAMA_KEEP_ALIVE=-1` to keep model loaded
- Use `OLLAMA_NUM_PARALLEL=1` to avoid memory thrashing
- Monitor with: `watch -n 1 free -h`

---

## Scripts Provided

1. `enable-memory-overcommit.sh` - Automate Solution 1 + 2
2. `patch-ollama-large-models.sh` - Automate Solution 3
3. `force-load-large-models.py` - Automate Solution 4
4. `run-large-model-direct.sh` - Manual llama.cpp execution
5. `llamacpp-server-direct.sh` - Run llama.cpp server

---

## Next Steps

Let me know if you have sudo access on the Jetson, and I'll help you enable memory overcommit. Otherwise, we'll restart the Docker container with the correct flags.
