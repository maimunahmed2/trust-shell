$ErrorActionPreference = "Stop"

# --- Configuration ---
$Username = "ssh"
$PasswordPlain = "~35Maimun~35"
$GrantAdmin = $true # Set to $false for a standard non-admin user

# 1. Install OpenSSH Server if not already present
Write-Host "[1/4] Checking OpenSSH Server..." -ForegroundColor Cyan
$sshCap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($sshCap.State -ne 'Installed') {
    Write-Host "Installing OpenSSH Server..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name $sshCap.Name | Out-Null
}

# 2. Set sshd to Automatic BEFORE starting it
Write-Host "[2/4] Enabling persistent sshd service..." -ForegroundColor Cyan
Set-Service -Name sshd -StartupType 'Automatic'
try {
    Start-Service sshd -ErrorAction Stop
} catch {
    Write-Host "sshd failed to start. Checking OpenSSH diagnostics..." -ForegroundColor Red
    & "$env:WINDIR\System32\OpenSSH\sshd.exe" -t
    Get-WinEvent -LogName "OpenSSH/Operational" -MaxEvents 5 -ErrorAction SilentlyContinue | Format-Table TimeCreated, Message -Wrap
    throw
}

# 3. Ensure Firewall allows inbound SSH on TCP port 22
Write-Host "[3/4] Configuring Windows Firewall..." -ForegroundColor Cyan
if (!(Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
    New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' `
        -DisplayName 'OpenSSH Server (sshd)' `
        -Enabled True `
        -Direction Inbound `
        -Protocol TCP `
        -Action Allow `
        -LocalPort 22 | Out-Null
} else {
    Enable-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
}

# 4. Create the SSH user
Write-Host "[4/4] Creating local user '$Username'..." -ForegroundColor Cyan
$SecurePassword = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force

if (!(Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $Username `
        -Password $SecurePassword `
        -FullName "SSH Remote User" `
        -Description "Dedicated SSH access account" `
        -PasswordNeverExpires | Out-Null
} else {
    Set-LocalUser -Name $Username -Password $SecurePassword
}

# Add to Users or Administrators group
$TargetGroup = if ($GrantAdmin) { "Administrators" } else { "Users" }
try {
    Add-LocalGroupMember -Group $TargetGroup -Member $Username -ErrorAction Stop
} catch {
    # Ignore if user is already a member of the group
}

# Optional: Set PowerShell as the default SSH shell instead of cmd.exe
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String -Force | Out-Null

# Print local IPv4 addresses for quick connection testing
$IPs = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254.*" }).IPAddress
Write-Host "`nDone! SSH is active and persistent." -ForegroundColor Green
Write-Host "Connect using: ssh $Username@$($IPs -join ' or ')" -ForegroundColor Green