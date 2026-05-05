# 1. Xóa task cũ
Unregister-ScheduledTask -TaskName "IdleDisplay" -Confirm:$false -ErrorAction SilentlyContinue

# 2. Tạo thư mục
$scriptDir = "C:\Scripts"
if (!(Test-Path $scriptDir)) { New-Item -Path $scriptDir -ItemType Directory -Force }

# 3. Tạo script giám sát Idle "thông minh"
$monitorScript = @'
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class UserInput {
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }
    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    public static uint GetIdleTime() {
        LASTINPUTINFO lastInputInfo = new LASTINPUTINFO();
        lastInputInfo.cbSize = (uint)Marshal.SizeOf(lastInputInfo);
        GetLastInputInfo(ref lastInputInfo);
        return ((uint)Environment.TickCount - lastInputInfo.dwTime);
    }
}
'@

$idleThreshold = 60000 # 60 giây (1 phút)
$url = "https://cps-ad-display.pages.dev"

while($true) {
    $idleTime = [UserInput]::GetIdleTime()

    # Kiểm tra nếu Edge đã mở chưa để tránh mở trùng nhiều cửa sổ
    $edgeRunning = Get-Process msedge -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" }

    if ($idleTime -gt $idleThreshold) {
        if (!$edgeRunning) {
            Start-Process "msedge" "--kiosk $url --edge-kiosk-type=fullscreen"
        }
    }
    Start-Sleep -Seconds 10 # Kiểm tra lại sau mỗi 10 giây
}
'@
$monitorScript | Out-File "$scriptDir\monitor-idle.ps1" -Encoding utf8 -Force

# 4. Tạo Task để chạy script này ngay khi Logon (Không dùng điều kiện Idle của Windows nữa)
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Scripts\monitor-idle.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType InteractiveToken -RunLevel HighestAvailable
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0

Register-ScheduledTask -TaskName "IdleDisplay" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force

# 5. Chạy ngay lập tức để test
Start-ScheduledTask -TaskName "IdleDisplay"

Write-Host "---" -ForegroundColor Green
Write-Host "Đã chuyển sang chế độ giám sát trực tiếp (Active Monitoring)." -ForegroundColor Green
Write-Host "Vui lòng không chạm vào máy trong 60 giây để thử nghiệm." -ForegroundColor Cyan