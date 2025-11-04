# Monitor Large Model Execution on Jetson
Write-Host "`n=== Deepseek-Coder 33B Status ===" -ForegroundColor Cyan
Write-Host "Time: $(Get-Date -Format 'HH:mm:ss')`n"

# Check processes
Write-Host "Ollama Processes:" -ForegroundColor Yellow
ssh jetson "ps aux | grep 'ollama run' | grep -v grep | grep deepseek" | ForEach-Object {
    if ($_ -match 'ollama runner.*?(\d+)%.*?(\d+:\d+)') {
        Write-Host "  CPU: $($matches[1])% | Runtime: $($matches[2])" -ForegroundColor Green
    }
}

# Memory
Write-Host "`nMemory Status:" -ForegroundColor Yellow
ssh jetson "free -h | grep -E 'Mem|Swap'" | ForEach-Object {
    Write-Host "  $_"
}

# Docker stats
Write-Host "`nContainer Stats:" -ForegroundColor Yellow
ssh jetson "docker stats --no-stream ollama-orin --format 'table {{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}'" | Select-Object -Last 1 | ForEach-Object {
    Write-Host "  $_" -ForegroundColor Green
}

Write-Host ""
