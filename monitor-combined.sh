#!/bin/bash
# Combined GPU and Token Monitoring
# Shows real-time GPU usage alongside token generation

echo "Starting combined monitoring..."
echo "Press Ctrl+C to stop"
echo ""

# Start tegrastats in background
sudo tegrastats --interval 1000 > /tmp/tegrastats.log 2>&1 &
TEGRA_PID=$!

# Run token monitoring
docker exec ollama-orin ollama run llama3.2:1b "Write a detailed explanation of neural networks" &
OLLAMA_PID=$!

# Monitor both
while kill -0 $OLLAMA_PID 2>/dev/null; do
    clear
    echo "====================================="
    echo "GPU & Memory Status"
    echo "====================================="
    tail -n 1 /tmp/tegrastats.log
    echo ""
    echo "====================================="
    echo "Ollama Processing..."
    echo "====================================="
    sleep 1
done

# Cleanup
kill $TEGRA_PID 2>/dev/null
rm /tmp/tegrastats.log

echo ""
echo "Generation complete!"
