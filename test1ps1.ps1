#Requires -RunAsAdministrator
Set-Location $PSScriptRoot

# ══════════════════════════════════════════
# BƯỚC 1: Xóa KMS Activation cũ
# ══════════════════════════════════════════
Write-Host "--------------------------------------------------" -ForegroundColor Gray
Write-Host "BUOC 1: Dang xoa key va KMS..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Gray

try {
    cscript //nologo "$env:SystemRoot\system32\slmgr.vbs" /upk
    Start-Sleep -Seconds 1
    cscript //nologo "$env:SystemRoot\system32\slmgr.vbs" /cpky
    Start-Sleep -Seconds 1
    cscript //nologo "$env:SystemRoot\system32\slmgr.vbs" /ckms
    Write-Host "[OK] Da go bo key cu." -ForegroundColor Green
} catch {
    Write-Host "[INFO] Bo qua xoa key." -ForegroundColor Yellow
}

# ══════════════════════════════════════════
# BƯỚC 2: Ép Registry về Home (Core)
# ══════════════════════════════════════════
Write-Host "`n--------------------------------------------------" -ForegroundColor Gray
Write-Host "BUOC 2: Dang ep Registry ve ban Home..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Gray

$regPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion"

# Lưu dự phòng ban đầu
$oldEditionID   = (Get-ItemProperty -Path $regPath -Name "EditionID").EditionID
$oldProductName = (Get-ItemProperty -Path $regPath -Name "ProductName").ProductName
$oldCompID      = (Get-ItemProperty -Path $regPath -Name "CompositionEditionID").CompositionEditionID

$osInfo  = Get-CimInstance Win32_OperatingSystem
$osBuild = [int]$osInfo.BuildNumber
$targetProduct = if ($osBuild -ge 22000) { "Windows 11 Home" } else { "Windows 10 Home" }

try {
    Set-ItemProperty -Path $regPath -Name "EditionID"            -Value "Core"
    Set-ItemProperty -Path $regPath -Name "ProductName"          -Value $targetProduct
    Set-ItemProperty -Path $regPath -Name "CompositionEditionID" -Value "Core"
    
    # Ép thêm nhánh Setup phụ để qua mặt bộ cài Retail cứng đầu
    $wimPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup"
    Set-ItemProperty -Path $wimPath -Name "Edition" -Value "Core" -ErrorAction SilentlyContinue
    
    Write-Host "[OK] Ghi de Registry lua may thanh ban Home thanh cong." -ForegroundColor Green
} catch {
    Write-Host "[LOI] Khong the sua Registry: $_" -ForegroundColor Red
    exit 1
}

# ══════════════════════════════════════════
# BƯỚC 3: Tạo File Cấu Hình Ép Hạ Cấp Tự Động
# ══════════════════════════════════════════
Write-Host "`n--------------------------------------------------" -ForegroundColor Gray
Write-Host "BUOC 3: Dang tao file cau hinh ep Downgrade..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Gray

$configFile = "$env:TEMP\config.ini"
$configContent = @"
[Setup]
Edition=Core
Format=WIM
ConfigFile=
"@
Out-File -FilePath $configFile -InputObject $configContent -Encoding ASCII -Force

# ══════════════════════════════════════════
# BƯỚC 4: Thực thi cài đặt Silent (KHÔNG TỰ REBOOT)
# ══════════════════════════════════════════
Write-Host "`n--------------------------------------------------" -ForegroundColor Gray
Write-Host "BUOC 4: Dang thuc thi cai dat am tham (Giu lai data)..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Gray

$setupPath = "C:\win10\win10\setup.exe"

if (-not (Test-Path $setupPath)) {
    Write-Host "[LOI] Khong tim thay bo cai tai $setupPath" -ForegroundColor Red
    Set-ItemProperty -Path $regPath -Name "EditionID" -Value $oldEditionID
    Set-ItemProperty -Path $regPath -Name "ProductName" -Value $oldProductName
    Set-ItemProperty -Path $regPath -Name "CompositionEditionID" -Value $oldCompID
    exit 1
}

# Sử dụng tham số /NoReboot để bắt Windows Setup KHÔNG tự khởi động lại máy
$setupArgs = "/ConfigFile `"$configFile`" /Quiet /NoReboot /DynamicUpdate Disable /EULA Accept /MigrateChoice DataOnly /Compat IgnoreWarning"

try {
    Write-Host "[WARNING] Tien trinh dang chay ngam hoan toan (mat tu 15-30 phut)." -ForegroundColor Yellow
    Write-Host "KHONG DUOC TAT NGUON. Vui long doi cho den khi script bao DONE..." -ForegroundColor Red
    
    $setup = Start-Process -FilePath $setupPath -ArgumentList $setupArgs -Verb RunAs -PassThru
    Wait-Process -Id $setup.Id
    
    # Xóa file cấu hình tạm sau khi nạp xong
    Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
    
    Write-Host "`n[DONE] Tien trinh cai dat ngam da HOAN TAT!" -ForegroundColor Green
    Write-Host "May cua ban SE KHONG TU DONG RESTART." -ForegroundColor Yellow
    Write-Host "Vui long chu dong Khoi dong lai (Reboot) bang tay bat cu khi nao ban muon de hoan thanh ha cap." -ForegroundColor Cyan
} catch {
    Write-Host "[LOI] That bai khi thuc thi Setup: $_" -ForegroundColor Red
    # Khôi phục nếu lỗi nửa chừng
    Set-ItemProperty -Path $regPath -Name "EditionID" -Value $oldEditionID
    Set-ItemProperty -Path $regPath -Name "ProductName" -Value $oldProductName
    Set-ItemProperty -Path $regPath -Name "CompositionEditionID" -Value $oldCompID
}