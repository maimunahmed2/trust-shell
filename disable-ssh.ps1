
$ErrorActionPreference = "Continue"

$Username = "ssh"

Write-Host "`n[1/5] Removing SSH user..." -ForegroundColor Cyan

if (Get-LocalUser -Name $Username -ErrorAction SilentlyContinue) {
    Remove-LocalUser -Name $Username
    Write-Host "SSH user removed."
} else {
    Write-Host "SSH user does not exist."
}

Write-Host "`n[2/5] Stopping and disabling SSH service..." -ForegroundColor Cyan

if (Get-Service sshd -ErrorAction SilentlyContinue) {
    Stop-Service sshd -Force -ErrorAction SilentlyContinue
    Set-Service sshd -StartupType Disabled
    Write-Host "SSH service stopped and disabled."
}

Write-Host "`n[3/5] Removing SSH firewall rule..." -ForegroundColor Cyan

$Rule = Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue

if ($Rule) {
    Remove-NetFirewallRule -Name "OpenSSH-Server-In-TCP"
    Write-Host "SSH firewall rule removed."
}

Write-Host "`n[4/5] Removing custom SSH shell configuration..." -ForegroundColor Cyan

$RegistryPath = "HKLM:\SOFTWARE\OpenSSH"

if (Test-Path $RegistryPath) {
    $Shell = Get-ItemProperty -Path $RegistryPath -Name DefaultShell -ErrorAction SilentlyContinue

    if ($Shell.DefaultShell -eq "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe") {
        Remove-ItemProperty -Path $RegistryPath -Name DefaultShell
        Write-Host "Custom default shell removed."
    }
}

Write-Host "`n[5/5] Rollback completed. Uninstalling OpenSSH Server." -ForegroundColor Green
# Write-Host "OpenSSH Server remains installed but disabled."

Remove-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Write-Host "Uninstall complete." -ForegroundColor Green