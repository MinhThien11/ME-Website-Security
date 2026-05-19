#Requires -RunAsAdministrator
Set-Location $PSScriptRoot

# ══════════════════════════════════════════
# BƯỚC 1: Xóa KMS Activation cũ
# ══════════════════════════════════════════
Write-Host "--------------------------------------------------" -ForegroundColor Gray
Write-Host "BUOC 1: Dang xoa key va KMS..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Gray

try {
    cscript //nologo "$env:SystemRoot\system32\slmgr.vbs" /upk 2>$null
    Start-Sleep -Seconds 1
    cscript //nologo "$env:SystemRoot\system32\slmgr.vbs" /cpky 2>$null
    Start-Sleep -Seconds 1
    cscript //nologo "$env:SystemRoot\system32\slmgr.vbs" /ckms 2>$null
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
    $wimPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup"
    Set-ItemProperty -Path $wimPath -Name "Edition" -Value "Core" -ErrorAction SilentlyContinue
    Write-Host "[OK] Ghi de Registry thanh ban Home thanh cong." -ForegroundColor Green
} catch {
    Write-Host "[LOI] Khong the sua Registry: $_" -ForegroundColor Red
    exit 1
}

# ══════════════════════════════════════════
# BƯỚC 3: Kiểm tra bộ cài
# ══════════════════════════════════════════
Write-Host "`n--------------------------------------------------" -ForegroundColor Gray
Write-Host "BUOC 3: Kiem tra bo cai tai C:\win10..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Gray

$setupPath = "C:\win10\setup.exe"
$wimFile   = "C:\win10\sources\install.wim"
$esdFile   = "C:\win10\sources\install.esd"

if (-not (Test-Path $setupPath)) {
    Write-Host "[LOI] Khong tim thay bo cai tai $setupPath" -ForegroundColor Red
    Set-ItemProperty -Path $regPath -Name "EditionID"            -Value $oldEditionID
    Set-ItemProperty -Path $regPath -Name "ProductName"          -Value $oldProductName
    Set-ItemProperty -Path $regPath -Name "CompositionEditionID" -Value $oldCompID
    exit 1
}

$sourceFile = if (Test-Path $wimFile) { $wimFile } elseif (Test-Path $esdFile) { $esdFile } else { $null }
if ($sourceFile) {
    try {
        $dismOutput = & dism /Get-WimInfo /WimFile:"$sourceFile" 2>&1
        if (($dismOutput | Out-String) -match "Home|Core") {
            Write-Host "[OK] Bo cai co chua edition Home." -ForegroundColor Green
        } else {
            Write-Host "[CANH BAO] Khong tim thay edition Home trong bo cai!" -ForegroundColor Red
        }
    } catch { Write-Host "[INFO] Bo qua kiem tra DISM." -ForegroundColor Yellow }
}

# ══════════════════════════════════════════
# BƯỚC 4: Mở setup.exe rồi tự động click qua GUI
# Dùng UI Automation thay vi /Quiet vi Microsoft block silent downgrade
# ══════════════════════════════════════════
Write-Host "`n--------------------------------------------------" -ForegroundColor Gray
Write-Host "BUOC 4: Mo setup va tu dong click GUI..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Gray

# Load UI Automation assembly
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

# Helper: tim button theo ten trong cua so
function Find-Button {
    param($root, [string]$name, [int]$timeoutSec = 30)
    $condition = New-Object System.Windows.Automation.AndCondition(
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
            [System.Windows.Automation.ControlType]::Button)),
        (New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty, $name))
    )
    $elapsed = 0
    while ($elapsed -lt $timeoutSec) {
        try {
            # Tim tat ca button co ten nay
            $btn = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, $condition)
            if ($btn) {
                # Kiem tra IsEnabled - cho den khi enabled moi click
                $isEnabled = $btn.GetCurrentPropertyValue(
                    [System.Windows.Automation.AutomationElement]::IsEnabledProperty)
                if ($isEnabled -eq $true) { return $btn }
                Write-Host -NoNewline "~" -ForegroundColor DarkGray
            } else {
                Write-Host -NoNewline "." -ForegroundColor DarkGray
            }
        } catch {
            Write-Host -NoNewline "?" -ForegroundColor DarkGray
        }
        Start-Sleep -Seconds 2
        $elapsed += 2
    }
    return $null
}

# Helper: click button
function Click-Button {
    param($btn, [string]$label)
    if ($btn) {
        $invokePattern = $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $invokePattern.Invoke()
        Write-Host "[CLICK] $label" -ForegroundColor Green
        return $true
    }
    Write-Host "[WARN] Khong tim thay nut: $label" -ForegroundColor Yellow
    return $false
}

# Helper: tim cua so setup theo title
function Wait-SetupWindow {
    param([int]$timeoutSec = 120)
    $elapsed = 0
    while ($elapsed -lt $timeoutSec) {
        $root = [System.Windows.Automation.AutomationElement]::RootElement
        $condition = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty, "Windows 10 Setup"
        )
        $win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition)
        if ($win) { return $win }
        # Thu voi ten Windows 11
        $condition2 = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty, "Windows 11 Setup"
        )
        $win2 = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $condition2)
        if ($win2) { return $win2 }
        Start-Sleep -Seconds 2
        $elapsed += 2
        Write-Host -NoNewline "." -ForegroundColor DarkGray
    }
    return $null
}

# Khoi dong setup (khong /Quiet de hien GUI, script se tu click)
Write-Host "[INFO] Dang khoi dong setup.exe..." -ForegroundColor Yellow
$setup = Start-Process -FilePath $setupPath -ArgumentList "/DynamicUpdate Disable /Compat IgnoreWarning" -Verb RunAs -PassThru

# Cho cua so setup xuat hien
Write-Host "[INFO] Cho cua so Setup xuat hien (toi da 2 phut)..." -ForegroundColor Yellow
$win = Wait-SetupWindow -timeoutSec 120
Write-Host ""

if (-not $win) {
    Write-Host "[LOI] Khong tim thay cua so Windows Setup!" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Da tim thay cua so Setup!" -ForegroundColor Green
Start-Sleep -Seconds 3

# Helper: lay lai window handle (setup co the re-render)
function Get-SetupWindow {
    $root = [System.Windows.Automation.AutomationElement]::RootElement
    foreach ($title in @("Windows 10 Setup", "Windows 11 Setup")) {
        $cond = New-Object System.Windows.Automation.PropertyCondition(
            [System.Windows.Automation.AutomationElement]::NameProperty, $title)
        $w = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
        if ($w) { return $w }
    }
    return $null
}

# ── Man hinh 1: "Install Windows 10" → click Next ──
Write-Host "`n[INFO] Man 1: Cho nut Next active (toi da 90 giay)..." -ForegroundColor Yellow
$win = Get-SetupWindow
$btn = Find-Button -root $win -name "Next" -timeoutSec 90
if (-not $btn) {
    # Refresh window ref va thu lai
    $win = Get-SetupWindow
    $btn = Find-Button -root $win -name "Next" -timeoutSec 30
}
Click-Button -btn $btn -label "Next (Man 1 - Install Windows)"
Start-Sleep -Seconds 5

# ── Man hinh 2: "License terms" → click Accept ──
Write-Host "[INFO] Man 2: Cho nut Accept (toi da 60 giay)..." -ForegroundColor Yellow
$win = Get-SetupWindow
$btn = Find-Button -root $win -name "Accept" -timeoutSec 60
Click-Button -btn $btn -label "Accept (Man 2 - EULA)"
Start-Sleep -Seconds 5

# ── Man hinh 3: "Choose what to keep" → co the hien hoac skip ──
Write-Host "[INFO] Man 3: Kiem tra neu hien (cho 20 giay)..." -ForegroundColor Yellow
Start-Sleep -Seconds 5
$win = Get-SetupWindow
$btnNext = Find-Button -root $win -name "Next" -timeoutSec 20
if ($btnNext) {
    Click-Button -btn $btnNext -label "Next (Man 3 - Keep files)"
    Write-Host "[INFO] Da click Next man 3." -ForegroundColor Yellow
    Start-Sleep -Seconds 8
}

# ── Man hinh 4: "Ready to install" → click Install ──
Write-Host "[INFO] Man 4: Cho nut Install (toi da 3 phut)..." -ForegroundColor Yellow
$win = Get-SetupWindow
$btn = Find-Button -root $win -name "Install" -timeoutSec 180
Click-Button -btn $btn -label "Install (Man 4 - Ready to install)"

Write-Host "`n[OK] Da click qua 4 man hinh! Setup dang cai dat..." -ForegroundColor Green
Write-Host "[INFO] Tien trinh se mat 15-40 phut. KHONG TAT NGUON!" -ForegroundColor Red
Write-Host "[INFO] May se tu dong REBOOT sau khi cai xong." -ForegroundColor Yellow

# Cho setup hoan tat
$startTime = Get-Date
$logPath   = "C:\`$WINDOWS.~BT\Sources\Panther\setupact.log"
$lastSize  = 0
$lastPhase = ""
$keywords  = "SPSetupPhase|Gathering|Downlevel|SafeOS|FirstBoot|Migrate|Install|Completed"

while (-not $setup.HasExited) {
    Start-Sleep -Seconds 10
    $elapsed = [int]((Get-Date) - $startTime).TotalMinutes

    if (Test-Path $logPath) {
        try {
            $logLines    = [System.IO.File]::ReadAllLines($logPath)
            $currentSize = $logLines.Count
            if ($currentSize -ne $lastSize) {
                $lastSize  = $currentSize
                $latest    = $logLines | Where-Object { $_ -match $keywords } | Select-Object -Last 1
                if ($latest -and $latest -ne $lastPhase) {
                    $lastPhase = $latest
                    $clean     = $latest -replace "^\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2},\s*\w+\s+\w+\s+", ""
                    $clean     = $clean.Substring(0, [Math]::Min($clean.Length, 100))
                    Write-Host "[$elapsed phut] $clean" -ForegroundColor Cyan
                } else { Write-Host -NoNewline "." -ForegroundColor DarkGray }
            } else { Write-Host -NoNewline "." -ForegroundColor DarkGray }
        } catch { Write-Host -NoNewline "." -ForegroundColor DarkGray }
    } else { Write-Host -NoNewline "." -ForegroundColor DarkGray }
}

Write-Host ""
$exitCode = $setup.ExitCode

switch ($exitCode) {
    0    {
        Write-Host "`n[DONE] Cai dat thanh cong!" -ForegroundColor Green
        Write-Host "Tu dong REBOOT trong 15 giay... (Ctrl+C de huy)" -ForegroundColor Yellow
        Start-Sleep -Seconds 15
        Restart-Computer -Force
    }
    3010 {
        Write-Host "`n[DONE] Cai dat thanh cong!" -ForegroundColor Green
        Write-Host "Tu dong REBOOT trong 15 giay... (Ctrl+C de huy)" -ForegroundColor Yellow
        Start-Sleep -Seconds 15
        Restart-Computer -Force
    }
    default {
        $hex = "0x$("{0:X8}" -f [uint32]$exitCode)"
        Write-Host "`n[LOI] Setup ket thuc voi ma: $hex" -ForegroundColor Red
        if (Test-Path $logPath) {
            Write-Host "--- 10 dong cuoi log ---" -ForegroundColor Gray
            [System.IO.File]::ReadAllLines($logPath) | Select-Object -Last 10 | ForEach-Object {
                Write-Host $_ -ForegroundColor DarkYellow
            }
        }
        Set-ItemProperty -Path $regPath -Name "EditionID"            -Value $oldEditionID
        Set-ItemProperty -Path $regPath -Name "ProductName"          -Value $oldProductName
        Set-ItemProperty -Path $regPath -Name "CompositionEditionID" -Value $oldCompID
    }
}