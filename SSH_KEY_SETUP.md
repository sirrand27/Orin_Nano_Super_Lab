# Setup SSH Key Authentication for Jetson
# This eliminates the need to type passwords for SSH/SCP

## Quick Setup (Run on Windows)

### Step 1: Generate SSH Key (if you don't have one)
```powershell
# Check if you already have a key
Test-Path ~\.ssh\id_rsa.pub

# If False, generate a new key
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
# Press Enter for all prompts (default location, no passphrase)
```

### Step 2: Copy Public Key to Jetson
```powershell
# Method 1: Using ssh-copy-id (if available)
ssh-copy-id rawi@192.168.100.191

# Method 2: Manual copy (if ssh-copy-id not available)
type $env:USERPROFILE\.ssh\id_rsa.pub | ssh rawi@192.168.100.191 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### Step 3: Test Passwordless SSH
```powershell
ssh rawi@192.168.100.191 "hostname"
# Should NOT ask for password!
```

## Alternative: Windows OpenSSH Setup

If the above doesn't work, use this PowerShell script:

```powershell
# Read your SSH public key
$pubKey = Get-Content ~\.ssh\id_rsa.pub -Raw

# Copy to Jetson (will ask for password ONE last time)
$setupScript = @"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo '$pubKey' >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
"@

ssh rawi@192.168.100.191 $setupScript
```

## Troubleshooting

### If still asking for password:

1. **Check key permissions on Jetson:**
   ```bash
   ssh rawi@192.168.100.191
   chmod 700 ~/.ssh
   chmod 600 ~/.ssh/authorized_keys
   ls -la ~/.ssh
   ```

2. **Verify key was added:**
   ```bash
   ssh rawi@192.168.100.191 "cat ~/.ssh/authorized_keys"
   # Should show your public key
   ```

3. **Check SSH daemon config on Jetson:**
   ```bash
   ssh rawi@192.168.100.191
   sudo grep "PubkeyAuthentication" /etc/ssh/sshd_config
   # Should be "yes"
   
   # If not:
   sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

## Benefits
- ✅ No more password prompts for SSH/SCP
- ✅ More secure than passwords
- ✅ Works with all SSH-based tools
- ✅ Can be used from multiple machines

## After Setup
All these commands will work without passwords:
```powershell
ssh rawi@192.168.100.191 "df -h"
scp file.txt rawi@192.168.100.191:~/
ssh rawi@192.168.100.191 "sudo docker ps"  # sudo may still ask for password
```

## For sudo Commands
If you want passwordless sudo on the Jetson:
```bash
ssh rawi@192.168.100.191
sudo visudo
# Add this line:
# rawi ALL=(ALL) NOPASSWD: ALL
```
⚠️ Only do this if it's your personal device!
