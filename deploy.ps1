#Requires -RunAsAdministrator

Set-Location $PSScriptRoot

# ══════════════════════════════════════════
# BƯỚC 1: Downgrade registry Pro -> Home
# ══════════════════════════════════════════
$regPath    = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion"
$currentReg = Get-ItemProperty -Path $regPath

$currentEditionID   = $currentReg.EditionID
$currentProductName = $currentReg.ProductName

$osInfo  = Get-CimInstance Win32_OperatingSystem
$osBuild = $osInfo.BuildNumber

if ([int]$osBuild -ge 22000) {
    $targetProduct = "Windows 11 Home"
} else {
    $targetProduct = "Windows 10 Home"
}

$isPro = ($currentEditionID -like "*Professional*") -or
         ($currentEditionID -eq "Professional")     -or
         ($currentProductName -like "*Pro*")

if (-not $isPro) {
    Write-Host "SKIP: Khong phai Pro, bo qua buoc 1." -ForegroundColor Yellow
} else {
    try {
        Set-ItemProperty -Path $regPath -Name "EditionID"            -Type String -Value "Core"
        Set-ItemProperty -Path $regPath -Name "ProductName"          -Type String -Value $targetProduct
        Set-ItemProperty -Path $regPath -Name "CompositionEditionID" -Type String -Value "Core"
        Write-Host "OK: Da chuyen registry sang $targetProduct" -ForegroundColor Green
    } catch {
        Write-Host "LOI registry: $_" -ForegroundColor Red
        exit 1
    }
}

# ══════════════════════════════════════════
# BƯỚC 2: Chạy Media Creation Tool
# ══════════════════════════════════════════
Write-Host "Dang chay Media Creation Tool..." -ForegroundColor Cyan

$mctPath = Join-Path $PSScriptRoot "MediaCreationTool_22H2.exe"

if (-not (Test-Path $mctPath)) {
    Write-Host "LOI: Khong tim thay file $mctPath" -ForegroundColor Red
    exit 1
}

# Khởi động MCT
$mct = Start-Process $mctPath `
    -ArgumentList "/Sku Home /NoReboot /DynamicUpdate Disable" `
    -Verb RunAs `
    -PassThru

$wshell = New-Object -ComObject WScript.Shell

# Bước 1: Chờ màn hình License rồi click Accept (Alt+A)
Start-Sleep -Seconds 8
$wshell.AppActivate("Windows 10 Setup")
Start-Sleep -Seconds 1
$wshell.SendKeys("%A")

# Bước 2: Chờ màn hình "What do you want to do" rồi click Next
Start-Sleep -Seconds 5
$wshell.AppActivate("Windows 10 Setup")
Start-Sleep -Seconds 1
$wshell.SendKeys("{TAB}")
Start-Sleep -Seconds 1
$wshell.SendKeys("{ENTER}")

Write-Host "Da tu dong qua 2 buoc setup!" -ForegroundColor Green

Wait-Process -Id $mct.Id

Write-Host "DONE: Hoan tat. Vui long reboot thu cong sau." -ForegroundColor Green
exit 0