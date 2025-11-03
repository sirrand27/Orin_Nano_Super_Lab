#!/bin/bash
# Real-time Ollama Token Monitoring
# Shows generation speed and token metrics

echo "Ollama Token Monitor"
echo "===================="
echo ""

MODEL=${1:-"llama3.2:1b"}
PROMPT=${2:-"Write a short poem about AI"}

echo "Model: $MODEL"
echo "Prompt: $PROMPT"
echo ""
echo "Generating..."
echo ""

RESPONSE=$(curl -s http://localhost:11434/api/generate -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"$PROMPT\",
  \"stream\": false
}")

# Extract metrics
PROMPT_TOKENS=$(echo $RESPONSE | jq -r '.prompt_eval_count // 0')
OUTPUT_TOKENS=$(echo $RESPONSE | jq -r '.eval_count // 0')
TOTAL_DURATION=$(echo $RESPONSE | jq -r '.total_duration // 0')
EVAL_DURATION=$(echo $RESPONSE | jq -r '.eval_duration // 0')
LOAD_DURATION=$(echo $RESPONSE | jq -r '.load_duration // 0')

# Calculate tokens per second
if [ "$EVAL_DURATION" -gt 0 ]; then
    TOKENS_PER_SEC=$(echo "scale=2; $OUTPUT_TOKENS / ($EVAL_DURATION / 1000000000)" | bc)
else
    TOKENS_PER_SEC=0
fi

# Calculate total time
TOTAL_SEC=$(echo "scale=2; $TOTAL_DURATION / 1000000000" | bc)

# Display metrics
echo "====================================="
echo "TOKEN METRICS"
echo "====================================="
echo "Input tokens:        $PROMPT_TOKENS"
echo "Output tokens:       $OUTPUT_TOKENS"
echo "Total tokens:        $((PROMPT_TOKENS + OUTPUT_TOKENS))"
echo ""
echo "PERFORMANCE"
echo "====================================="
echo "Generation speed:    $TOKENS_PER_SEC tokens/sec"
echo "Total time:          $TOTAL_SEC seconds"
echo "Model load time:     $(echo "scale=2; $LOAD_DURATION / 1000000000" | bc)s"
echo ""
echo "RESPONSE"
echo "====================================="
echo $RESPONSE | jq -r '.response'
echo ""
