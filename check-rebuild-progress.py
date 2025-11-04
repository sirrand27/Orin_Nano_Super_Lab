#!/usr/bin/env python3
"""
Monitor the Ollama rebuild progress on Jetson
"""

import subprocess
import time
import sys

def check_build_status():
    """Check if Docker build is running"""
    result = subprocess.run(
        ["ssh", "jetson", "ps aux | grep docker"],
        capture_output=True,
        text=True
    )
    
    if "docker build" in result.stdout or "dockerd" in result.stdout:
        return "BUILDING"
    return "IDLE"

def check_container_status():
    """Check Ollama container status"""
    result = subprocess.run(
        ["ssh", "jetson", "docker ps -a | grep ollama-orin"],
        capture_output=True,
        text=True
    )
    return result.stdout.strip()

def test_model():
    """Test if large model works"""
    print("\n🧪 Testing deepseek-coder:33b...")
    result = subprocess.run(
        ["ssh", "jetson", "timeout 60 docker exec ollama-orin ollama run deepseek-coder:33b 'print(1+1)'"],
        capture_output=True,
        text=True,
        timeout=65
    )
    
    if result.returncode == 0 and "Error" not in result.stdout:
        print("✅ SUCCESS! Large model is working!")
        print(f"Response: {result.stdout[:200]}")
        return True
    else:
        print("❌ Still not working")
        print(f"Error: {result.stdout[:200]}")
        return False

def main():
    print("="*60)
    print("Ollama Rebuild Progress Monitor")
    print("="*60)
    
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        test_model()
        return
    
    print("\n⏳ Checking build status...")
    status = check_build_status()
    print(f"Build Status: {status}")
    
    print("\n📦 Container Status:")
    container = check_container_status()
    if container:
        print(container)
    else:
        print("No container found (may be building)")
    
    if status == "BUILDING":
        print("\n⏰ Build in progress (30-60 minutes total)")
        print("   Run this script again to check progress")
        print("   Or check logs: ssh jetson 'docker logs -f <container_id>'")
    else:
        print("\n✅ Build appears complete!")
        print("   Testing model now...")
        test_model()

if __name__ == "__main__":
    main()
