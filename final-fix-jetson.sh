#!/bin/bash
# FINAL FIX: Patch the actual memory check in llm/server.go

set -e

echo "=========================================="
echo "FINAL JETSON LARGE MODEL FIX"
echo "Patching llm/server.go line 473"
echo "=========================================="

cd /tmp/ollama

echo "[1] Backing up original file..."
cp llm/server.go llm/server.go.backup

echo "[2] Patching line 473 - force verifyCPUFit to always pass..."
# Change the if condition to always be false (skip the memory check)
sed -i '473s/if !verifyCPUFit/if false \&\& !verifyCPUFit/' llm/server.go

echo "[3] Verifying patch..."
echo "=== PATCHED CODE (line 470-478) ==="
sed -n '470,478p' llm/server.go

echo ""
echo "[4] Building with Go 1.24..."
export CUDA_ARCHITECTURES=87
export CGO_ENABLED=1  
export GOARCH=arm64
export PATH=/usr/local/go/bin:$PATH

go generate ./...
go build -buildvcs=false -tags cuda -o /tmp/ollama-patched-final .

echo ""
echo "[5] Verifying binary..."
ls -lh /tmp/ollama-patched-final

echo ""
echo "[6] Installing to container..."
docker cp /tmp/ollama-patched-final ollama-orin:/usr/local/bin/ollama

echo ""
echo "[7] Restarting Ollama..."
docker restart ollama-orin

echo ""
echo "✓✓✓ PATCH COMPLETE ✓✓✓"
echo "Waiting 10 seconds for Ollama to start..."
sleep 10

echo ""
echo "[8] TESTING LARGE MODEL..."
docker exec ollama-orin ollama run deepseek-coder:33b "print('Success!')"

echo ""
echo "✓✓✓ SUCCESS! LARGE MODELS NOW WORKING! ✓✓✓"
