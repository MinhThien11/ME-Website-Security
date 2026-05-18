#Requires -RunAsAdministrator
Set-Location $PSScriptRoot

# ══════════════════════════════════════════
# BƯỚC 1: Xóa KMS
# ══════════════════════════════════════════
Write-Host "Dang xoa KMS activation..." -ForegroundColor Cyan

try {
    cscript //nologo "$env:windir\system32\slmgr.vbs" /upk
    Start-Sleep -Seconds 2
    cscript //nologo "$env:windir\system32\slmgr.vbs" /cpky
    Start-Sleep -Seconds 2
    cscript //nologo "$env:windir\system32\slmgr.vbs" /ckms
    Write-Host "OK: Da xoa KMS thanh cong." -ForegroundColor Green
} catch {
    Write-Host "LOI khi xoa KMS: $_" -ForegroundColor Red
    exit 1
}

# ══════════════════════════════════════════
# BƯỚC 2: Sửa registry Pro -> Home
# ══════════════════════════════════════════
Write-Host "Dang sua registry..." -ForegroundColor Cyan

$regPath    = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion"
$currentReg = Get-ItemProperty -Path $regPath

$currentEditionID   = $currentReg.EditionID
$currentProductName = $currentReg.ProductName

$osInfo  = Get-CimInstance Win32_OperatingSystem
$osBuild = $osInfo.BuildNumber

$targetProduct = if ([int]$osBuild -ge 22000) { "Windows 11 Home" } else { "Windows 10 Home" }

$isPro = ($currentEditionID -like "*Professional*") -or
         ($currentEditionID -eq "Professional")     -or
         ($currentProductName -like "*Pro*")

if (-not $isPro) {
    Write-Host "SKIP: Khong phai Pro, bo qua buoc 2." -ForegroundColor Yellow
} else {
    try {
        Set-ItemProperty -Path $regPath -Name "EditionID"            -Value "Core"
        Set-ItemProperty -Path $regPath -Name "ProductName"          -Value $targetProduct
        Set-ItemProperty -Path $regPath -Name "CompositionEditionID" -Value "Core"
        Write-Host "OK: Da chuyen registry sang $targetProduct" -ForegroundColor Green
    } catch {
        Write-Host "LOI registry: $_" -ForegroundColor Red
        # Revert
        Set-ItemProperty -Path $regPath -Name "EditionID"            -Value $currentEditionID
        Set-ItemProperty -Path $regPath -Name "ProductName"          -Value $currentProductName
        Set-ItemProperty -Path $regPath -Name "CompositionEditionID" -Value $currentEditionID
        exit 1
    }
}

# ══════════════════════════════════════════
# BƯỚC 3: Chạy Windows Setup
# ══════════════════════════════════════════
Write-Host "Dang chay Windows Setup..." -ForegroundColor Cyan

$setupPath = "C:\Win10\setup.exe"

if (-not (Test-Path $setupPath)) {
    Write-Host "LOI: Khong tim thay $setupPath" -ForegroundColor Red
    # Revert registry
    if ($isPro) {
        Set-ItemProperty -Path $regPath -Name "EditionID"            -Value $currentEditionID
        Set-ItemProperty -Path $regPath -Name "ProductName"          -Value $currentProductName
        Set-ItemProperty -Path $regPath -Name "CompositionEditionID" -Value $currentEditionID
        Write-Host "Da khoi phuc registry." -ForegroundColor Yellow
    }
    exit 1
}

$setup = Start-Process -FilePath $setupPath `
    -ArgumentList "/auto upgrade /Quiet /NoReboot /DynamicUpdate disable /showoobe None /Telemetry Disable /EULA Accept /Compat IgnoreWarning" `
    -Verb RunAs `
    -PassThru

Wait-Process -Id $setup.Id

Write-Host "DONE: Hoan tat. Vui long reboot thu cong sau." -ForegroundColor Green
exit 0