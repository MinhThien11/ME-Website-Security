# ====================================================================
# FIX LỖI TREO: Tự động tắt QuickEdit Mode khi click chuột vào PowerShell
# ====================================================================
$Win32Console = Add-Type -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@ -Name "Win32Console" -Namespace "Win32" -PassThru

$hStdout = $Win32Console::GetStdHandle(-10) # STD_INPUT_HANDLE
$oldMode = 0
$Win32Console::GetConsoleMode($hStdout, [ref]$oldMode) | Out-Null
$newMode = $oldMode -band -not 0x0040 # Xóa cờ ENABLE_QUICK_EDIT_MODE
$Win32Console::SetConsoleMode($hStdout, $newMode) | Out-Null
# ====================================================================

# 1. Cau hinh duong dan file và thu muc giai nen
$url = "http://release.cps.onl/win10.zip"
$zipFile = "C:\win10.zip"
$extractPath = "C:\win10_extracted"

# 2. Tao thu muc neu chua ton tai
if (!(Test-Path -Path $extractPath)) {
    New-Item -ItemType Directory -Path $extractPath -Force | Out-Null
    Write-Host "Đã tạo thư mục: $extractPath" -ForegroundColor Cyan
}

# 3. Tai file bang curl.exe đe đat toc do cao nhat
Write-Host "Đang tải file bằng curl.exe (Đã chặn lỗi treo khi click chuột)..." -ForegroundColor Yellow
curl.exe -L $url -o $zipFile

# 4. Kiểm tra xem file đã tải về thành công chưa rồi mới giải nén
if (Test-Path -Path $zipFile) {
    Write-Host "Tải thành công! Đang tiến hành giải nén..." -ForegroundColor Yellow
    
    # Giải nén đè lên nếu thư mục đã có dữ liệu cũ
    Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force
    
    Write-Host "Giải nén hoàn tất vào thư mục: $extractPath" -ForegroundColor Green
    
    # 5. Tùy chọn: Xóa file .zip sau khi giải nén xong để dọn dẹp ổ C
    Remove-Item -Path $zipFile -Force
    Write-Host "Đã xóa file zip gốc để tiết kiệm bộ nhớ ổ C." -ForegroundColor Gray
} else {
    Write-Host "Lỗi: Không thể tải file. Vui lòng kiểm tra lại đường truyền internet." -ForegroundColor Red
}

# Khôi phục lại chế độ QuickEdit ban đầu sau khi script chạy xong
$Win32Console::SetConsoleMode($hStdout, $oldMode) | Out-Null