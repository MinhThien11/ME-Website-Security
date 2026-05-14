# 1. Xóa task cũ
Unregister-ScheduledTask -TaskName "IdleDisplay" -Confirm:$false -ErrorAction SilentlyContinue

# 2. Tạo thư mục
$scriptDir = "C:\Scripts"
if (!(Test-Path $scriptDir)) { New-Item -Path $scriptDir -ItemType Directory -Force }

# 3. Tạo script launcher — chạy monitor-idle dưới context của user đang login
$launcherScript = @'
# Lấy session ID của user đang login (không phải SYSTEM)
$session = (Get-Process -Name "explorer" -ErrorAction SilentlyContinue | Select-Object -First 1).SessionId
if ($null -eq $session) { exit }

# Lấy username từ session đó
$username = (Get-WmiObject Win32_ComputerSystem).UserName
if (!$username) { exit }

# Chạy monitor script dưới user đang login qua Task Scheduler tạm thời
$action   = New-ScheduledTaskAction -Execute "powershell.exe" `
              -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Scripts\monitor-idle.ps1"
$principal = New-ScheduledTaskPrincipal -UserId $username -LogonType Interactive -RunLevel Limited
$settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0

Register-ScheduledTask -TaskName "IdleDisplay_User" -Action $action -Principal $principal -Settings $settings -Force
Start-ScheduledTask -TaskName "IdleDisplay_User"
'@
$launcherScript | Out-File "$scriptDir\launcher.ps1" -Encoding utf8 -Force

# 4. Tạo monitor-idle script (giữ nguyên như cũ)
$monitorScript = @'
$typeDefinition = @"
using System;
using System.Runtime.InteropServices;
public class UserInput {
    [StructLayout(LayoutKind.Sequential)]
    public struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    [DllImport("user32.dll")]
    public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    public static uint GetIdleTime() {
        LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
        lastInputInfo.cbSize = (uint)System.Runtime.InteropServices.Marshal.SizeOf(lastInputInfo);
        GetLastInputInfo(ref lastInputInfo);
        return ((uint)Environment.TickCount - lastInputInfo.dwTime);
    }
}
"@
Add-Type -TypeDefinition $typeDefinition

$idleThreshold = 60000
$url = "https://cps-ad-display.pages.dev"
$edgeProcess = $null

while ($true) {
    $idleTime = [UserInput]::GetIdleTime()

    if ($idleTime -gt $idleThreshold) {
        $isEdgeAlive = ($edgeProcess -ne $null) -and (-not $edgeProcess.HasExited)
        if (-not $isEdgeAlive) {
            $edgeProcess = Start-Process "msedge" `
                -ArgumentList "--kiosk $url --edge-kiosk-type=fullscreen --noerrdialogs --disable-infobars" `
                -PassThru
        }
    } else {
        if ($edgeProcess -ne $null -and -not $edgeProcess.HasExited) {
            Stop-Process -Id $edgeProcess.Id -Force -ErrorAction SilentlyContinue
            $edgeProcess = $null
        }
    }

    Start-Sleep -Seconds 5
}
'@
$monitorScript | Out-File "$scriptDir\monitor-idle.ps1" -Encoding utf8 -Force

# 5. Tạo task chính chạy dưới SYSTEM — trigger khi BẤT KỲ user nào login
$action   = New-ScheduledTaskAction -Execute "powershell.exe" `
              -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Scripts\launcher.ps1"
$trigger  = New-ScheduledTaskTrigger -AtLogon
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0

Register-ScheduledTask -TaskName "IdleDisplay" `
    -Action $action `
    -Trigger $trigger `
    -RunLevel Highest `
    -User "SYSTEM" `
    -Settings $settings `
    -Force

Write-Host "---" -ForegroundColor Green
Write-Host "Hoàn tất! Task sẽ chạy với MỌI user khi login." -ForegroundColor Green
Write-Host "Logout rồi login lại để test." -ForegroundColor Cyan