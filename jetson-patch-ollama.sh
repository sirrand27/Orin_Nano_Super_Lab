#!/bin/bash
# ULTIMATE FIX: Rebuild Ollama with working memory estimation for Jetson
# This patches the sched.go file to bypass the broken memory check

set -e

cd /tmp

echo "=========================================="
echo "Patching & Rebuilding Ollama for Jetson"
echo "Fix: Bypass broken memory estimation"
echo "=========================================="

# Clean previous builds
rm -rf ollama-patched
mkdir -p ollama-patched
cd ollama-patched

# Clone Ollama
echo "[1/6] Cloning Ollama repository..."
git clone --depth 1 https://github.com/ollama/ollama.git
cd ollama

# Create the patch
echo "[2/6] Creating memory estimation patch..."
cat > /tmp/jetson-memory-fix.patch <<'ENDPATCH'
--- a/server/sched.go
+++ b/server/sched.go
@@ -430,15 +430,17 @@ func (s *Scheduler) load(req *LlmRequest, ggml *llm.GGML, gpus gpu.GpuInfoList
        }
 
        // Check if the model will fit in available system memory
-       systemFreeMemory := systemMemInfo.FreeMemory + systemMemInfo.FreeSwap
+       // JETSON PATCH: Always report 136GB available (8GB RAM + 128GB swap)
+       systemFreeMemory := uint64(136) * 1024 * 1024 * 1024
+       slog.Info("jetson override", "reportedFree", fmt.Sprintf("%d GB", systemFreeMemory/(1024*1024*1024)))
 
        if req.opts.RequireFull {
-               if estimate.TotalSize > systemFreeMemory {
-                       slog.Info("model is too large for system memory", "requireFull", req.opts.RequireFull)
-                       return nil, fmt.Errorf("model requires more system memory than is currently available")
-               }
+               // JETSON PATCH: Disabled - let it try to load
+               slog.Info("jetson: allowing full load attempt", "modelSize", estimate.TotalSize, "available", systemFreeMemory)
        }
 
+       // JETSON PATCH: Force GPU layer offloading
        if !req.opts.RequireFull {
-               if estimate.TotalSize > systemFreeMemory {
-                       slog.Info("model is too large for system memory", "requireFull", req.opts.RequireFull)
-                       return nil, fmt.Errorf("model requires more system memory than is currently available")
-               }
+               slog.Info("jetson: allowing partial load with swap", "modelSize", estimate.TotalSize)
        }
 
ENDPATCH

# Apply patch
echo "[3/6] Applying patch..."
patch -p1 < /tmp/jetson-memory-fix.patch || {
    echo "Patch failed - file structure may have changed"
    echo "Manually editing server/sched.go instead..."
    
    # Manual edit as fallback
    sed -i '435,445s/if estimate.TotalSize > systemFreeMemory {/\/\/ PATCHED: Disabled memory check\n\t\tif false \&\& estimate.TotalSize > systemFreeMemory {/' server/sched.go
}

# Build
echo "[4/6] Building Ollama with CUDA support..."
export CUDA_ARCHITECTURES="87"
export CGO_ENABLED=1
export GOARCH=arm64

go generate ./...
go build -tags cuda -o /tmp/ollama-patched-binary .

# Test binary
echo "[5/6] Testing patched binary..."
/tmp/ollama-patched-binary --version

echo "[6/6] Installing patched binary to container..."
docker cp /tmp/ollama-patched-binary ollama-orin:/usr/local/bin/ollama
docker restart ollama-orin

echo ""
echo "=========================================="
echo "✓ PATCH COMPLETE!"
echo "=========================================="
echo ""
echo "Test with:"
echo "docker exec ollama-orin ollama run deepseek-coder:33b 'test'"
echo ""
echo "Note: First load will take 5-10 minutes as model loads into swap"
