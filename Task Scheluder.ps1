# Xóa task cũ
Unregister-ScheduledTask -TaskName "IdleDisplay" -Confirm:$false -ErrorAction SilentlyContinue

# Tạo thư mục và script
New-Item -Path "C:\Scripts" -ItemType Directory -Force

@'
Start-Process "msedge" "--kiosk https://cps-ad-display.pages.dev --edge-kiosk-type=fullscreen"
'@ | Out-File "C:\Scripts\open-display.ps1"

# Tạo task bằng XML
$xml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <GroupId>BUILTIN\Users</GroupId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <IdleSettings>
      <Duration>PT1M</Duration>
      <WaitTimeout>PT0S</WaitTimeout>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <RunOnlyIfIdle>true</RunOnlyIfIdle>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <WakeToRun>true</WakeToRun>
  </Settings>
  <Actions>
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Scripts\open-display.ps1</Arguments>
    </Exec>
  </Actions>
</Task>
'@

$xml | Out-File "C:\Scripts\task.xml" -Encoding Unicode
schtasks /create /tn "IdleDisplay" /xml "C:\Scripts\task.xml" /f