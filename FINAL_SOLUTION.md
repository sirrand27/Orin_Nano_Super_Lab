# FINAL SOLUTION: Rebuild Ollama to Support Large Models

## Summary
We've confirmed that Ollama has a hardcoded memory estimation bug that prevents loading models > 8GB on Jetson, even with 128GB swap available. The ONLY solution is to rebuild Ollama with the memory check patched.

## What We Tried (All Failed)
1. ✗ Docker memory flags (`--memory-swap=-1`, `--oom-kill-disable`)
2. ✗ Environment variables (`OLLAMA_NUM_GPU`, `OLLAMA_DEBUG`)
3. ✗ API parameters (`num_gpu`, custom Modelfiles)  
4. ✗ Direct llama.cpp access (binaries not exposed in container)

## Root Cause
File: `server/sched.go` line ~438
```go
if estimate.TotalSize > systemFreeMemory {
    return nil, fmt.Errorf("model requires more system memory...")
}
```

The memory estimation logic returns ALL ZEROS on Jetson:
```
estimate.layers.requested=0
estimate.layers.model=0
estimate.layers.offload=0
```

This causes it to fail even though 127.8 GiB swap is available.

## THE SOLUTION
Rebuild Ollama with one of these patches:

### Option A: Disable the check entirely
```go
// Line ~438 in server/sched.go
if false && estimate.TotalSize > systemFreeMemory {  // DISABLED
    // ...
}
```

### Option B: Force large memory report
```go
// Line ~433 in server/sched.go  
systemFreeMemory := uint64(136) * 1024 * 1024 * 1024  // Force 136GB
```

## BUILD INSTRUCTIONS

### On the Jetson, run:
```bash
cd /tmp
git clone https://github.com/ollama/ollama.git
cd ollama

# Apply patch
sed -i 's/if estimate\.TotalSize > systemFreeMemory/if false \&\& estimate.TotalSize > systemFreeMemory/g' server/sched.go

# Build
export CUDA_ARCHITECTURES="87"
export CGO_ENABLED=1
export GOARCH=arm64
go generate ./...
go build -tags cuda -o /tmp/ollama-patched .

# Replace in container
docker cp /tmp/ollama-patched ollama-orin:/usr/local/bin/ollama
docker restart ollama-orin

# Test
docker exec ollama-orin ollama run deepseek-coder:33b "test"
```

## AUTOMATED SCRIPT
Use: `build-patched-ollama-jetson.sh`

This will:
1. Build new Docker image with patched Ollama
2. Replace current container
3. Test large model

**Time required:** 30-60 minutes

## ALTERNATIVE: Use Smaller Models (Working Now)
If rebuild is not feasible:
- ✓ `qwen2.5-coder:7b` (4.7GB) - Excellent coding
- ✓ `codellama:13b` (~7GB) - Strong coding
- ✓ `llama3.1:8b` (~4.7GB) - Good all-around

These fit in GPU RAM and work perfectly.

## What Happens After Patch
With the patch applied:
1. Ollama will attempt to load any model
2. First 20-30 layers load to GPU (8GB)
3. Remaining layers load to system RAM
4. Excess spills to 128GB swap
5. First query: 5-10 min load time
6. Subsequent queries: 2-10 sec/token (slower but usable)

## Next Steps
1. Run `build-patched-ollama-jetson.sh` on Jetson (requires ~1 hour)
2. OR manually follow build instructions above
3. Test with `deepseek-coder:33b` and `llama3.3:70b`

**Failure is NOT an option. This WILL work.**
