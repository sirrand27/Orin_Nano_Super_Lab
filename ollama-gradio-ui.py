#!/usr/bin/env python3
"""
Simple Gradio Web Interface for Ollama on Jetson
NVIDIA-style chat interface
"""

import gradio as gr
import requests
import json

OLLAMA_API = "http://localhost:11434/api/generate"

def chat_with_ollama(message, history, model="llama3.2:1b"):
    """Send message to Ollama and get response"""
    
    # Build conversation context
    context = ""
    for human, assistant in history:
        context += f"User: {human}\nAssistant: {assistant}\n"
    context += f"User: {message}\nAssistant: "
    
    try:
        response = requests.post(
            OLLAMA_API,
            json={
                "model": model,
                "prompt": context,
                "stream": False,
                "options": {
                    "temperature": 0.7,
                    "top_p": 0.9
                }
            },
            timeout=120
        )
        
        if response.status_code == 200:
            result = response.json()
            return result.get("response", "No response received")
        else:
            return f"Error: {response.status_code} - {response.text}"
            
    except Exception as e:
        return f"Error connecting to Ollama: {str(e)}"

def get_models():
    """Get list of available models"""
    try:
        response = requests.get("http://localhost:11434/api/tags")
        if response.status_code == 200:
            models = response.json().get("models", [])
            return [model["name"] for model in models]
    except:
        pass
    return ["llama3.2:1b"]

# Create Gradio interface
with gr.Blocks(title="Ollama Chat - Jetson Orin Nano", theme=gr.themes.Soft()) as demo:
    gr.Markdown(
        """
        # 🤖 Ollama Chat Interface
        ### Running on NVIDIA Jetson Orin Nano with CUDA Acceleration
        """
    )
    
    with gr.Row():
        with gr.Column(scale=3):
            chatbot = gr.Chatbot(
                label="Conversation",
                height=500,
                show_label=True
            )
            
            with gr.Row():
                msg = gr.Textbox(
                    label="Your message",
                    placeholder="Type your message here...",
                    scale=4,
                    show_label=False
                )
                submit = gr.Button("Send", variant="primary", scale=1)
            
            clear = gr.Button("Clear Conversation")
        
        with gr.Column(scale=1):
            model_dropdown = gr.Dropdown(
                choices=get_models(),
                value="llama3.2:1b",
                label="Select Model",
                interactive=True
            )
            
            gr.Markdown("### System Info")
            gr.Markdown(
                """
                - **Device**: Jetson Orin Nano
                - **CUDA**: Enabled
                - **Backend**: Ollama
                """
            )
            
            refresh_models = gr.Button("Refresh Models")
    
    # Event handlers
    def respond(message, chat_history, model):
        if not message.strip():
            return "", chat_history
        
        bot_message = chat_with_ollama(message, chat_history, model)
        chat_history.append((message, bot_message))
        return "", chat_history
    
    def clear_chat():
        return []
    
    def update_models():
        return gr.Dropdown(choices=get_models())
    
    msg.submit(respond, [msg, chatbot, model_dropdown], [msg, chatbot])
    submit.click(respond, [msg, chatbot, model_dropdown], [msg, chatbot])
    clear.click(clear_chat, None, chatbot)
    refresh_models.click(update_models, None, model_dropdown)

if __name__ == "__main__":
    demo.launch(
        server_name="0.0.0.0",
        server_port=7860,
        share=False
    )
