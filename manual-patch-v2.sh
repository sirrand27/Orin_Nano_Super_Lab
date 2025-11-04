#!/bin/bash
# Direct manual patch for Ollama on Jetson

set -e

echo "=========================================="
echo "Manual Ollama Patch - Take 2"
echo "=========================================="

cd /tmp/ollama

echo "[1] Creating precise patch..."

# Create a proper patch file
cat > /tmp/ollama-jetson.patch << 'PATCHEND'
--- a/server/sched.go
+++ b/server/sched.go
@@ -435,12 +435,12 @@ func (s *Scheduler) run(ctx context.Context) {
                if errors.Is(err, llm.ErrLoadRequiredFull) {
                        if !requireFull {
                                // No other models loaded, yet we still don't fit, so report an error
-                               slog.Info("model is too large for system memory", "requireFull", requireFull)
-                               s.activeLoading.Close()
-                               s.activeLoading = nil
-                               req.errCh <- err
+                               // PATCHED: Allow loading to swap on Jetson
+                               slog.Info("JETSON PATCH: allowing large model load", "requireFull", requireFull, "swap", "128GB")
+                               // Continue instead of erroring
+                               requireFull = false
                        }
-                       return true
+                       // Don't return, let it try to load
                }
PATCHEND

echo "[2] Applying patch..."
patch -p1 < /tmp/ollama-jetson.patch || {
    echo "Patch failed, trying sed approach..."
    
    # Fallback: comment out the error block
    sed -i '438,441s/^/\/\/ PATCHED: /' server/sched.go
    sed -i '442s/return true/\/\/ return true  \/\/ PATCHED: allow loading/' server/sched.go
}

echo "[3] Verifying patch..."
echo "=== Modified code ==="
sed -n '435,445p' server/sched.go

echo ""
echo "[4] Building patched Ollama..."
export CUDA_ARCHITECTURES="87"
export CGO_ENABLED=1
export GOARCH=arm64

go generate ./...
go build -tags cuda -o /tmp/ollama-patched .

echo ""
echo "[5] Installing to container..."
docker cp /tmp/ollama-patched ollama-orin:/usr/local/bin/ollama

echo ""
echo "[6] Restarting container..."
docker restart ollama-orin

echo ""
echo "✓ Patch complete! Waiting 10 seconds..."
sleep 10

echo ""
echo "[7] Testing..."
docker exec ollama-orin ollama run deepseek-coder:33b "print('hello')"

echo ""
echo "✓✓✓ SUCCESS!"
