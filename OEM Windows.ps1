# Ha Windows Pro xuong Home OEM - TU DONG 1 BUOC
# Tu check hang, model, BIOS key -> Go KMS -> Doi edition -> Activate
# Chay bang PowerShell Admin

# Kiem tra quyen Admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "[LOI] Vui long chay lai bang quyen Administrator!" -ForegroundColor Red
    Write-Host "Click chuot phai vao file -> Run with PowerShell (as Admin)" -ForegroundColor Yellow
    pause
    exit
}

Clear-Host
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "   Ha Windows Pro xuong Home OEM - 1 Buoc  " -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# -------------------------------------------------------
# BUOC 1: Tu dong check hang, model, BIOS
# -------------------------------------------------------
Write-Host "[1/6] Dang thu thap thong tin may..." -ForegroundColor Yellow

$cs      = Get-WmiObject Win32_ComputerSystem
$bios    = Get-WmiObject Win32_BIOS
$os      = Get-WmiObject Win32_OperatingSystem
$svc     = Get-WmiObject -query 'select * from SoftwareLicensingService'

$maker   = $cs.Manufacturer.Trim()
$model   = $cs.Model.Trim()
$biosVer = $bios.SMBIOSBIOSVersion.Trim()
$serial  = $bios.SerialNumber.Trim()
$osName  = $os.Caption.Trim()
$edition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").EditionID
$biosKey = $svc.OA3xOriginalProductKey

Write-Host ""
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host "  | THONG TIN MAY                            |" -ForegroundColor Cyan
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ("  | Hang          : {0,-25}|" -f $maker) -ForegroundColor White
Write-Host ("  | Model         : {0,-25}|" -f $model) -ForegroundColor White
Write-Host ("  | Serial        : {0,-25}|" -f $serial) -ForegroundColor White
Write-Host ("  | BIOS Version  : {0,-25}|" -f $biosVer) -ForegroundColor White
Write-Host ("  | Windows       : {0,-25}|" -f $osName) -ForegroundColor White
Write-Host ("  | Edition       : {0,-25}|" -f $edition) -ForegroundColor White

if ($biosKey) {
    Write-Host ("  | BIOS OEM Key  : {0,-25}|" -f $biosKey) -ForegroundColor Green
} else {
    Write-Host "  | BIOS OEM Key  : Khong tim thay          |" -ForegroundColor Red
}
Write-Host "  +------------------------------------------+" -ForegroundColor Cyan
Write-Host ""

# Canh bao neu hang la thuong hieu lon -> thuong co key BIOS
$knownBrands = @("Dell","HP","Hewlett","Lenovo","Asus","Acer","Samsung","Toshiba","Sony","MSI","LG","Huawei","Microsoft")
$isBranded = $false
foreach ($brand in $knownBrands) {
    if ($maker -like "*$brand*") { $isBranded = $true; break }
}

if ($isBranded -and -not $biosKey) {
    Write-Host "  [!] May hang $maker thuong co key BIOS nhung khong doc duoc." -ForegroundColor Yellow
    Write-Host "  [!] Co the do KMS da ghi de. Script se co gang go KMS truoc." -ForegroundColor Yellow
    Write-Host ""
}

# -------------------------------------------------------
# BUOC 2: Go bo KMS hoan toan
# -------------------------------------------------------
Write-Host "[2/6] Dang go bo KMS activation..." -ForegroundColor Yellow

cscript //nologo $env:windir\system32\slmgr.vbs /cpky 2>&1 | Out-Null
cscript //nologo $env:windir\system32\slmgr.vbs /upk  2>&1 | Out-Null
cscript //nologo $env:windir\system32\slmgr.vbs /ckms 2>&1 | Out-Null

Stop-Service -Name sppsvc -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
Start-Service -Name sppsvc -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

Write-Host "      [OK] Da go bo KMS!" -ForegroundColor Green
Write-Host ""

# -------------------------------------------------------
# BUOC 3: Doc lai key BIOS sau khi go KMS
# -------------------------------------------------------
Write-Host "[3/6] Doc lai key BIOS sau khi go KMS..." -ForegroundColor Yellow

try {
    $biosKey = (Get-WmiObject -query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
} catch {
    $biosKey = $null
}

if ($biosKey) {
    Write-Host "      [OK] Tim thay key BIOS: $biosKey" -ForegroundColor Green
} else {
    Write-Host "      [!] Van khong tim thay key BIOS." -ForegroundColor Red
    Write-Host ""

    if ($isBranded) {
        Write-Host "  May $maker $model co the:" -ForegroundColor Yellow
        Write-Host "  - Co key tren COA sticker (nhan dan duoi may/pin)" -ForegroundColor White
        Write-Host "  - Hoac can cai lai Windows bang USB recovery cua hang" -ForegroundColor White
        Write-Host ""
    }

    $biosKey = Read-Host "  Nhap key OEM thu cong (hoac Enter de thoat)"
    if (-not $biosKey) {
        Write-Host "[THOAT] Khong co key de xu ly." -ForegroundColor Red
        pause
        exit
    }
}
Write-Host ""

# -------------------------------------------------------
# BUOC 4: Xac dinh edition phu hop theo hang may
# -------------------------------------------------------
Write-Host "[4/6] Xac dinh edition phu hop voi may $maker $model..." -ForegroundColor Yellow

# Thu xac dinh tu LicenseFamily
try {
    $licenseFamily = (Get-WmiObject -query "SELECT * FROM SoftwareLicensingProduct WHERE PartialProductKey IS NOT NULL" |
        Where-Object { $_.Name -like "*Windows*" -and $_.LicenseFamily -ne $null } |
        Select-Object -First 1).LicenseFamily
} catch {
    $licenseFamily = $null
}

Write-Host "      LicenseFamily: $(if ($licenseFamily) { $licenseFamily } else { 'Khong xac dinh duoc' })" -ForegroundColor White

# Xac dinh generic key
if ($licenseFamily -like "*HomeSL*" -or $licenseFamily -like "*CoreSingleLanguage*") {
    $genericKey  = "7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH"
    $targetEdition = "Windows Home Single Language"
} elseif ($licenseFamily -like "*Home*" -or $licenseFamily -like "*Core*") {
    $genericKey  = "YTMG3-N6DKC-DKB77-7M9GH-8HVX7"
    $targetEdition = "Windows Home"
} else {
    # Fallback theo hang may
    # Cac hang thuong dung Single Language tai VN
    $slBrands = @("Asus","Acer","Lenovo")
    $isSL = $false
    foreach ($b in $slBrands) {
        if ($maker -like "*$b*") { $isSL = $true; break }
    }

    if ($isSL) {
        Write-Host "      [Auto] May $maker thuong dung Single Language tai VN" -ForegroundColor Cyan
        $genericKey    = "7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH"
        $targetEdition = "Windows Home Single Language"
    } else {
        Write-Host "      [Auto] Mac dinh chon Windows Home" -ForegroundColor Cyan
        $genericKey    = "YTMG3-N6DKC-DKB77-7M9GH-8HVX7"
        $targetEdition = "Windows Home"
    }
}

Write-Host "      => Chuyen sang: $targetEdition" -ForegroundColor Cyan
Write-Host ""

# -------------------------------------------------------
# BUOC 5: Doi edition va apply key BIOS
# -------------------------------------------------------
Write-Host "[5/6] Dang chuyen edition va apply key OEM..." -ForegroundColor Yellow

# Ap dung generic key de doi edition
$r1 = Start-Process -FilePath "changepk.exe" -ArgumentList "/ProductKey $genericKey" -Wait -PassThru -ErrorAction SilentlyContinue
if (-not $r1 -or $r1.ExitCode -ne 0) {
    cscript //nologo $env:windir\system32\slmgr.vbs /ipk $genericKey 2>&1 | Out-Null
}
Start-Sleep -Seconds 3

# Ap dung key BIOS chinh thuc
$r2 = Start-Process -FilePath "changepk.exe" -ArgumentList "/ProductKey $biosKey" -Wait -PassThru -ErrorAction SilentlyContinue
if (-not $r2 -or $r2.ExitCode -ne 0) {
    cscript //nologo $env:windir\system32\slmgr.vbs /ipk $biosKey 2>&1 | Out-Null
}

Write-Host "      [OK] Da apply key OEM BIOS!" -ForegroundColor Green
Write-Host ""

# -------------------------------------------------------
# BUOC 6: Activate
# -------------------------------------------------------
Write-Host "[6/6] Dang kich hoat Windows..." -ForegroundColor Yellow
Start-Sleep -Seconds 2
cscript //nologo $env:windir\system32\slmgr.vbs /ato
Write-Host ""

# -------------------------------------------------------
# Ket qua
# -------------------------------------------------------
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  HOAN TAT!" -ForegroundColor Green
Write-Host ""
Write-Host ("  May       : {0} {1}" -f $maker, $model) -ForegroundColor White
Write-Host "  Edition   : $targetEdition" -ForegroundColor White
Write-Host "  Key BIOS  : $biosKey" -ForegroundColor White
Write-Host ""
Write-Host "  Sau khi RESTART + ket noi internet:" -ForegroundColor White
Write-Host "  Windows se tu Activate bang key BIOS." -ForegroundColor White
Write-Host "  Neu chua Active: chay 'slmgr /ato' trong PS Admin" -ForegroundColor White
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$restart = Read-Host "Khoi dong lai ngay bay gio? (Y/N)"
if ($restart -eq "Y" -or $restart -eq "y") {
    Write-Host "Khoi dong lai sau 10 giay..." -ForegroundColor Yellow
    shutdown /r /t 10 /c "Ap dung thay doi edition Windows"
} else {
    Write-Host "Nho khoi dong lai may truoc khi dung tiep." -ForegroundColor Yellow
}

pause