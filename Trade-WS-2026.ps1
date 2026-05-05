# 1. Xóa task cũ
Unregister-ScheduledTask -TaskName "IdleDisplay" -Confirm:$false -ErrorAction SilentlyContinue

# 2. Tạo thư mục
$scriptDir = "C:\Scripts"
if (!(Test-Path $scriptDir)) { New-Item -Path $scriptDir -ItemType Directory -Force }

# 3. Tạo script giám sát Idle
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

# 4. Đăng ký Scheduled Task
# SỬA: RunLevel dùng "Highest" (không phải "HighestAvailable")
# SỬA: Bỏ hẳn -Principal, để task tự chạy dưới user hiện tại
$action   = New-ScheduledTaskAction -Execute "powershell.exe" `
              -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Scripts\monitor-idle.ps1"
$trigger  = New-ScheduledTaskTrigger -AtLogon -User "$env:USERNAME"
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0

Register-ScheduledTask -TaskName "IdleDisplay" `
    -Action $action `
    -Trigger $trigger `
    -RunLevel Highest `
    -Settings $settings `
    -Force

# 5. Chạy ngay để test
Start-ScheduledTask -TaskName "IdleDisplay"

Write-Host "---" -ForegroundColor Green
Write-Host "Đã đăng ký và khởi chạy IdleDisplay thành công." -ForegroundColor Green
Write-Host "Không chạm chuột/bàn phím trong 60 giây để thấy Edge mở." -ForegroundColor Cyan
Write-Host "Khi dùng máy lại, Edge sẽ tự đóng." -ForegroundColor Cyan