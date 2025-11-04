# Monitor Ollama Build Progress on Jetson
# Run this periodically to check build status

Write-Host "`n=== Ollama Build Monitor ===" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'HH:mm:ss')`n" -ForegroundColor Gray

# Check if build processes are running
Write-Host "Build Processes:" -ForegroundColor Yellow
ssh jetson "ps aux | grep 'go build' | grep -v grep | wc -l" | ForEach-Object {
    $count = $_.Trim()
    if ($count -gt 0) {
        Write-Host "  ✓ $count active build process(es)" -ForegroundColor Green
        ssh jetson "ps aux | grep 'go build' | grep -v grep | awk '{print \`"  PID: \`" \$2 \`" | Runtime: \`" \$10 \`" | CPU: \`" \$3\`"%\`"}'"
    } else {
        Write-Host "  ✗ No build processes running" -ForegroundColor Red
    }
}

# Check for output binary
Write-Host "`nBinary Status:" -ForegroundColor Yellow
$binaryCheck = ssh jetson "test -f /tmp/ollama-patched-final && echo 'EXISTS' || echo 'NOT_FOUND'" 2>&1
if ($binaryCheck -match "EXISTS") {
    Write-Host "  ✓ Binary created!" -ForegroundColor Green
    ssh jetson "ls -lh /tmp/ollama-patched-final"
} else {
    Write-Host "  ⏳ Still compiling..." -ForegroundColor Yellow
}

# Memory usage
Write-Host "`nSystem Resources:" -ForegroundColor Yellow
ssh jetson "free -h | grep -E 'Mem|Swap' | awk '{print \`"  \`" \$1 \`" Used: \`" \$3 \`"/\`" \$2}'"

Write-Host "`n=== Estimated Time Remaining: 12-17 minutes ===" -ForegroundColor Cyan
Write-Host "Run this script again in 5 minutes to check progress.`n"
