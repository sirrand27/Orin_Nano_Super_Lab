#!/bin/bash
# Create optimized Ollama model variants for Jetson
# Run on your local machine to execute on Jetson

set -e

echo "=========================================="
echo "Creating Optimized Model Variants"
echo "=========================================="
echo ""

# ===========================================
# QWEN 2.5 CODER VARIANTS
# ===========================================
echo "🔧 Creating qwen2.5-coder optimized variants..."

# Turbo: Maximum speed, reduced context
ssh jetson "cat > /tmp/Modelfile.qwen-turbo << 'EOF'
FROM qwen2.5-coder:7b
PARAMETER num_ctx 2048
PARAMETER num_batch 512
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER repeat_penalty 1.1
SYSTEM You are a fast, efficient coding assistant specializing in Azure infrastructure.
EOF
docker cp /tmp/Modelfile.qwen-turbo ollama-orin:/tmp/
docker exec ollama-orin ollama create qwen2.5-coder:turbo -f /tmp/Modelfile.qwen-turbo"

echo "   ✓ qwen2.5-coder:turbo created (2K context, max speed)"

# Balanced: Good context, good speed
ssh jetson "cat > /tmp/Modelfile.qwen-balanced << 'EOF'
FROM qwen2.5-coder:7b
PARAMETER num_ctx 4096
PARAMETER num_batch 512
PARAMETER temperature 0.8
PARAMETER top_p 0.95
PARAMETER repeat_penalty 1.1
SYSTEM You are an expert coding assistant specializing in Azure Bicep, Azure CLI, and cloud infrastructure.
EOF
docker cp /tmp/Modelfile.qwen-balanced ollama-orin:/tmp/
docker exec ollama-orin ollama create qwen2.5-coder:balanced -f /tmp/Modelfile.qwen-balanced"

echo "   ✓ qwen2.5-coder:balanced created (4K context, balanced)"

# Quality: Maximum context, best quality
ssh jetson "cat > /tmp/Modelfile.qwen-quality << 'EOF'
FROM qwen2.5-coder:7b
PARAMETER num_ctx 8192
PARAMETER num_batch 256
PARAMETER temperature 0.8
PARAMETER top_p 0.95
PARAMETER repeat_penalty 1.1
SYSTEM You are an expert coding assistant specializing in Azure Bicep, Azure CLI, and cloud infrastructure. Provide detailed, well-documented solutions.
EOF
docker cp /tmp/Modelfile.qwen-quality ollama-orin:/tmp/
docker exec ollama-orin ollama create qwen2.5-coder:quality -f /tmp/Modelfile.qwen-quality"

echo "   ✓ qwen2.5-coder:quality created (8K context, best quality)"
echo ""

# ===========================================
# DEEPSEEK CODER VARIANTS (if you keep it)
# ===========================================
echo "🔧 Creating deepseek-coder optimized variants..."

# Fast: Minimal context for speed
ssh jetson "cat > /tmp/Modelfile.deepseek-fast << 'EOF'
FROM deepseek-coder:33b
PARAMETER num_ctx 2048
PARAMETER num_batch 128
PARAMETER temperature 0.7
PARAMETER top_p 0.9
SYSTEM You are a concise coding assistant. Provide direct, efficient code solutions.
EOF
docker cp /tmp/Modelfile.deepseek-fast ollama-orin:/tmp/
docker exec ollama-orin ollama create deepseek-coder:fast -f /tmp/Modelfile.deepseek-fast"

echo "   ✓ deepseek-coder:fast created (2K context)"
echo "   ⚠️  Note: 33B model will be slow from swap, consider removing"
echo ""

# ===========================================
# LLAMA 3.2 VARIANTS
# ===========================================
echo "🔧 Creating llama3.2 optimized variants..."

# Quick: Ultra-fast for simple tasks
ssh jetson "cat > /tmp/Modelfile.llama-quick << 'EOF'
FROM llama3.2:1b
PARAMETER num_ctx 2048
PARAMETER num_batch 512
PARAMETER temperature 0.7
SYSTEM You are a helpful, concise assistant.
EOF
docker cp /tmp/Modelfile.llama-quick ollama-orin:/tmp/
docker exec ollama-orin ollama create llama3.2:quick -f /tmp/Modelfile.llama-quick"

echo "   ✓ llama3.2:quick created (ultra-fast, 2K context)"
echo ""

# ===========================================
# SUMMARY
# ===========================================
echo "=========================================="
echo "✅ MODEL VARIANTS CREATED"
echo "=========================================="
echo ""

echo "📋 Available Models:"
ssh jetson "docker exec ollama-orin ollama list"

echo ""
echo "=========================================="
echo "🎯 Usage Recommendations:"
echo "=========================================="
echo ""
echo "⚡ For maximum speed (Azure quick tasks):"
echo "   docker exec ollama-orin ollama run qwen2.5-coder:turbo"
echo ""
echo "⚖️  For balanced performance (most work):"
echo "   docker exec ollama-orin ollama run qwen2.5-coder:balanced"
echo ""
echo "🎨 For complex code with lots of context:"
echo "   docker exec ollama-orin ollama run qwen2.5-coder:quality"
echo ""
echo "🚀 For ultra-fast simple queries:"
echo "   docker exec ollama-orin ollama run llama3.2:quick"
echo ""
echo "❌ NOT recommended (too slow from swap):"
echo "   - deepseek-coder:33b/fast (15+ min per response)"
echo "   - llama3.3:70b (30+ min per response)"
echo ""
echo "💡 Tip: Set an alias in your PowerShell profile:"
echo "   function Ask-Azure { ssh jetson \"docker exec ollama-orin ollama run qwen2.5-coder:balanced '\$args'\" }"
echo ""

exit 0
