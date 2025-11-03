#!/bin/bash
# Install Gradio Web Interface for Ollama on Jetson

echo "Installing Gradio Web Interface for Ollama..."

# Install Python dependencies
pip3 install gradio requests

echo ""
echo "Installation complete!"
echo ""
echo "To start the web interface:"
echo "  python3 ollama-gradio-ui.py"
echo ""
echo "Then open in browser:"
echo "  http://192.168.100.191:7860"
echo ""
