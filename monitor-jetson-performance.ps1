# Jetson LLM Performance Monitor
# Shows real-time performance metrics for Ollama on Jetson
# Run: .\monitor-jetson-performance.ps1

Write-Host "`n=========================================="
Write-Host "Jetson Orin Nano LLM Performance Monitor"
Write-Host "=========================================="
Write-Host "Press Ctrl+C to stop`n"

while ($true) {
    Clear-Host
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Host "🕐 $timestamp`n" -ForegroundColor Cyan
    
    # GPU Status
    Write-Host "🎮 GPU STATUS:" -ForegroundColor Yellow
    ssh jetson "nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu,clocks.current.graphics --format=csv,noheader,nounits" | ForEach-Object {
        $stats = $_ -split ','
        Write-Host "   Utilization: $($stats[0].Trim())%" -ForegroundColor Green
        Write-Host "   Memory: $($stats[1].Trim()) / $($stats[2].Trim()) MB" -ForegroundColor Green
        Write-Host "   Temperature: $($stats[3].Trim())°C" -ForegroundColor Green
        Write-Host "   Clock: $($stats[4].Trim()) MHz" -ForegroundColor Green
    }
    
    # Memory Status
    Write-Host "`n💾 MEMORY STATUS:" -ForegroundColor Yellow
    ssh jetson "free -h | grep -E 'Mem|Swap'" | ForEach-Object {
        $line = $_ -replace '\s+', ' '
        if ($line -match '^Mem:') {
            $parts = $line -split ' '
            Write-Host "   RAM: $($parts[2]) used / $($parts[1]) total" -ForegroundColor Green
        }
        if ($line -match '^Swap:') {
            $parts = $line -split ' '
            $swapUsed = $parts[2]
            $swapColor = if ($swapUsed -match '^0') { "Gray" } else { "Cyan" }
            Write-Host "   Swap: $swapUsed used / $($parts[1]) total" -ForegroundColor $swapColor
        }
    }
    
    # CPU Status
    Write-Host "`n🔧 CPU STATUS:" -ForegroundColor Yellow
    ssh jetson "top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print 100 - \$1}'" | ForEach-Object {
        $cpuUsage = [math]::Round($_, 1)
        $cpuColor = if ($cpuUsage -gt 80) { "Red" } elseif ($cpuUsage -gt 50) { "Yellow" } else { "Green" }
        Write-Host "   Usage: $cpuUsage%" -ForegroundColor $cpuColor
    }
    
    # Ollama Process Status
    Write-Host "`n🤖 OLLAMA STATUS:" -ForegroundColor Yellow
    $ollamaProc = ssh jetson "docker exec ollama-orin ps aux | grep 'ollama' | grep -v grep" 2>$null
    if ($ollamaProc) {
        Write-Host "   Status: Running" -ForegroundColor Green
        
        # Check for active model
        $activeModel = ssh jetson "docker exec ollama-orin ps aux | grep 'ollama run' | grep -v grep" 2>$null
        if ($activeModel) {
            if ($activeModel -match '(qwen|deepseek|llama)[^\s]*') {
                Write-Host "   Active Model: $($matches[0])" -ForegroundColor Cyan
            }
        } else {
            Write-Host "   Active Model: None (idle)" -ForegroundColor Gray
        }
    } else {
        Write-Host "   Status: Not Running" -ForegroundColor Red
    }
    
    # Container Stats
    Write-Host "`n📦 CONTAINER STATS:" -ForegroundColor Yellow
    ssh jetson "docker stats --no-stream ollama-orin --format 'table {{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}'" 2>$null | Select-Object -Skip 1 | ForEach-Object {
        $stats = $_ -split '\s+'
        Write-Host "   CPU: $($stats[0])" -ForegroundColor Green
        Write-Host "   Memory: $($stats[1])" -ForegroundColor Green
        Write-Host "   Network: $($stats[2])" -ForegroundColor Green
    }
    
    # Disk I/O
    Write-Host "`n💿 DISK I/O:" -ForegroundColor Yellow
    ssh jetson "iostat -x 1 2 | tail -n +4 | grep nvme | tail -1" 2>$null | ForEach-Object {
        if ($_ -match '^\s*\S+\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)') {
            Write-Host "   Read: $($matches[1]) KB/s" -ForegroundColor Green
            Write-Host "   Write: $($matches[2]) KB/s" -ForegroundColor Green
        }
    }
    
    # Quick Performance Tips
    Write-Host "`n💡 QUICK TIPS:" -ForegroundColor Yellow
    $swapCheck = ssh jetson "free -h | grep Swap | awk '{print \$3}'" 2>$null
    if ($swapCheck -and $swapCheck -notmatch '^0') {
        Write-Host "   ⚠️  Swap in use - Large model loading or active" -ForegroundColor Cyan
        Write-Host "   💡 Consider using qwen2.5-coder:7b for faster responses" -ForegroundColor Gray
    }
    
    $gpuTemp = ssh jetson "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader" 2>$null
    if ($gpuTemp -and [int]$gpuTemp -gt 75) {
        Write-Host "   🌡️  GPU temperature elevated ($gpuTemp°C)" -ForegroundColor Yellow
    }
    
    Write-Host "`n=========================================="
    Write-Host "Refreshing in 2 seconds..." -ForegroundColor Gray
    Start-Sleep -Seconds 2
}
