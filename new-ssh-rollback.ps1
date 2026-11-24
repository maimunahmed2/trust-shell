$ErrorActionPreference = "Stop"

# --- Configuration ---
$Username = "ssh"
$RemoveSSHConfigFolder = $false # Set to $true if you also want to delete C:\ProgramData\ssh (host keys & sshd_config)

# 1. Stop and disable the sshd service
Write-Host "[1/5] Stopping sshd service..." -ForegroundColor Cyan
$sshdService = Get-Service -Name sshd -ErrorAction SilentlyContinue
if ($sshdService) {
    if ($sshdService.Status -ne 'Stopped') {
        Stop-Service -Name sshd -Force -ErrorAction SilentlyContinue
    }
    Set-Service -Name sshd -StartupType Disabled -ErrorAction SilentlyContinue
    Write-Host "sshd service stopped." -ForegroundColor Green
} else {
    Write-Host "sshd service not found." -ForegroundColor Yellow
}

# 2. Uninstall OpenSSH Server (.msi AND/OR Windows Capability)
Write-Host "[2/5] Uninstalling OpenSSH Server..." -ForegroundColor Cyan

# Check for .msi installation via registry uninstall keys
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$msiApp = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue | Where-Object {
    $_.DisplayName -like "*OpenSSH*"
}

if ($msiApp) {
    foreach ($app in $msiApp) {
        Write-Host "Removing MSI package: $($app.DisplayName)..." -ForegroundColor Yellow
        if ($app.PSChildName -match '^\{[0-9A-Fa-f-]+\}$') {
            Start-Process msiexec.exe -ArgumentList "/x $($app.PSChildName) /qn /norestart" -Wait
        }
    }
    Write-Host "OpenSSH MSI uninstalled." -ForegroundColor Green
}

# Check for built-in Windows Capability installation
$sshCap = Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object Name -like 'OpenSSH.Server*'
if ($sshCap -and $sshCap.State -eq 'Installed') {
    Write-Host "Removing Windows Capability ($($sshCap.Name))..." -ForegroundColor Yellow
    Remove-WindowsCapability -Online -Name $sshCap.Name | Out-Null
    Write-Host "OpenSSH Windows Capability removed." -ForegroundColor Green
}

# 3. Remove the Windows Firewall rule
Write-Host "[3/5] Removing Windows Firewall rule..." -ForegroundColor Cyan
if (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
    Write-Host "Firewall rule 'OpenSSH-Server-In-TCP' removed." -ForegroundColor Green
} else {
    Write-Host "Firewall rule not found." -ForegroundColor Yellow
}

# 4. Remove the local SSH user and login screen hide entry
Write-Host "[4/5] Removing local user '$Username'..." -ForegroundColor Cyan
if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name $Username
    Write-Host "Local user '$Username' deleted." -ForegroundColor Green
} else {
    Write-Host "Local user '$Username' not found." -ForegroundColor Yellow
}

$HideRegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList"
if (Get-ItemProperty -Path $HideRegPath -Name $Username -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $HideRegPath -Name $Username -Force
    Write-Host "Removed '$Username' from Winlogon UserList." -ForegroundColor Green
}

# 5. Clean up OpenSSH registry settings (and optional ProgramData folder)
Write-Host "[5/5] Cleaning up OpenSSH registry settings..." -ForegroundColor Cyan
if (Get-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\OpenSSH" -Name "DefaultShell" -Force
    Write-Host "Removed DefaultShell registry property." -ForegroundColor Green
}

if ($RemoveSSHConfigFolder -and (Test-Path "$env:ProgramData\ssh")) {
    Remove-Item -Path "$env:ProgramData\ssh" -Recurse -Force
    Write-Host "Removed $env:ProgramData\ssh directory." -ForegroundColor Green
}

Write-Host "`nRollback complete! All OpenSSH Server components and user accounts have been reverted." -ForegroundColor Green