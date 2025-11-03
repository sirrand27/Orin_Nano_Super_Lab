# Open WebUI Token Display Configuration

## Problem
Token information (tokens/second, token counts) not showing in Open WebUI chat interface.

## Solution

### Method 1: Enable in Chat Settings (Per-Conversation)
1. Open a chat in Open WebUI
2. Click the **settings icon** (gear) in the top-right of the chat window
3. Scroll down to **"Advanced Parameters"** section
4. Look for **"Show token count"** or similar toggle
5. Enable the toggle
6. Token information should now appear at the bottom of responses

### Method 2: Enable in User Settings (Global)
1. Click your **profile icon** (bottom-left corner)
2. Select **"Settings"**
3. Go to **"Interface"** or **"Chat"** tab
4. Find **"Show token statistics"** or **"Show performance metrics"**
5. Enable the toggle
6. Save settings

### Method 3: Enable in Admin Panel (All Users)
If you're the admin (first user created):
1. Click profile icon → **"Admin Panel"**
2. Go to **"Settings"** → **"Interface"**
3. Enable **"Show Token Count"** or **"Display Performance Metrics"**
4. This will enable token display for all users

## Expected Token Display

After enabling, you should see at the bottom of each response:
```
Generated in 5.2s (15 tokens, ~2.9 tokens/s)
```

Or similar format showing:
- Generation time
- Total tokens generated
- Tokens per second

## Troubleshooting

### If token info still not showing:

1. **Check Ollama is responding with token data**:
   ```bash
   curl http://localhost:11434/api/generate -d '{
     "model": "llama3.2:1b",
     "prompt": "Say hello",
     "stream": false
   }' | jq '.eval_count, .eval_duration'
   ```
   Should return token count and duration.

2. **Try a fresh conversation**:
   - Start a new chat
   - Send a message
   - Token info appears after response completes

3. **Check browser console** (F12):
   - Look for JavaScript errors
   - Refresh page (Ctrl+F5)

4. **Verify Open WebUI version**:
   ```bash
   docker exec open-webui cat /app/package.json | grep version
   ```
   Older versions may not have token display.

5. **Update Open WebUI** (if needed):
   ```bash
   docker pull ghcr.io/open-webui/open-webui:main
   docker stop open-webui
   docker rm open-webui
   docker run -d --network=host \
     --add-host=host.docker.internal:host-gateway \
     -v open-webui:/app/backend/data \
     -e OLLAMA_BASE_URL=http://host.docker.internal:11434 \
     --name open-webui \
     --restart always \
     ghcr.io/open-webui/open-webui:main
   ```

## Alternative: Use Custom Monitoring Scripts

If Open WebUI doesn't show token info, use our custom scripts:

### Quick Test:
```bash
# Simple metrics
./ollama-token-monitor.sh llama3.2:1b "Explain quantum computing"

# Live streaming
python3 ollama-live-monitor.py llama3.2:1b "Write a haiku"

# GPU + token monitoring
./monitor-combined.sh
```

## Common Settings Locations

Open WebUI settings can be in different places depending on version:

- **v0.3.x+**: Settings → Interface → Show Token Count
- **v0.2.x**: Profile → Preferences → Display → Performance Metrics
- **v0.1.x**: May not have built-in token display (use API scripts instead)

## Current Setup
- Open WebUI: http://192.168.100.191:3000
- Ollama API: http://localhost:11434 (via host.docker.internal)
- Container: open-webui (running, logs show successful API calls)

## Notes
- Token display only appears AFTER generation completes (not during streaming)
- Some models may not return token counts (depends on model implementation)
- Token count accuracy depends on tokenizer used by model
