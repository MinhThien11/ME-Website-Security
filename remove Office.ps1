#Requires -RunAsAdministrator
# ==============================================================
# SCRIPT GO CAI DAT OFFICE 2021 - FIX LOI 30053-44
# Yeu cau: Chay PowerShell voi quyen Administrator
# ==============================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

# ── 1. Dung tien trinh va dich vu ──────────────────────────
Write-Host "`n[1/4] Dung cac tien trinh Office..." -ForegroundColor Cyan

$apps = @(
    "winword", "excel", "outlook", "powerpnt", "onenote",
    "OfficeClickToRun", "setup", "integratedoffice", "msaccess",
    "mspub", "lync", "teams", "groove", "msedge"
)

foreach ($app in $apps) {
    Stop-Process -Name $app -Force -ErrorAction SilentlyContinue
}

Stop-Service -Name "ClickToRunSvc" -Force -ErrorAction SilentlyContinue
Stop-Service -Name "OfficeSvc"     -Force -ErrorAction SilentlyContinue

# Xoa Scheduled Tasks de tranh Office tu khoi dong lai
Get-ScheduledTask -TaskPath "\Microsoft\Office\" -ErrorAction SilentlyContinue |
    Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "   -> Hoan tat." -ForegroundColor Green

# ── Ham: Xoa Registry co ep quyen ──────────────────────────
function Remove-RegistryKeyForced {
    param ([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Host "   [SKIP] Khong tim thay: $Path" -ForegroundColor DarkGray
        return
    }

    try {
        # Xac dinh hive va subkey
        $hiveMap = @{
            "HKLM:" = [Microsoft.Win32.Registry]::LocalMachine
            "HKCU:" = [Microsoft.Win32.Registry]::CurrentUser
        }

        $hive   = ($Path -split "\\")[0]           # e.g. "HKLM:"
        $subKey = ($Path -replace "^[^\\]+\\", "") # bo "HKLM:\"
        $root   = $hiveMap[$hive]

        if (-not $root) { throw "Hive khong hop le: $hive" }

        # Mo khoa voi quyen TakeOwnership + ChangePermissions
        $rights = [System.Security.AccessControl.RegistryRights]::TakeOwnership `
                -bor [System.Security.AccessControl.RegistryRights]::ChangePermissions `
                -bor [System.Security.AccessControl.RegistryRights]::FullControl

        $key = $root.OpenSubKey(
            $subKey,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            $rights
        )

        if ($key) {
            # Buoc 1: Chiem quyen so huu
            $acl   = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
            $admin = [System.Security.Principal.NTAccount]"BUILTIN\Administrators"
            $acl.SetOwner($admin)
            $key.SetAccessControl($acl)

            # Buoc 2: Cap FullControl de co the xoa
            $acl2 = $key.GetAccessControl()
            $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
                $admin,
                [System.Security.AccessControl.RegistryRights]::FullControl,
                [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit",
                [System.Security.AccessControl.PropagationFlags]::None,
                [System.Security.AccessControl.AccessControlType]::Allow
            )
            $acl2.AddAccessRule($rule)
            $key.SetAccessControl($acl2)
            $key.Close()
        }

        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        Write-Host "   [OK]   Xoa: $Path" -ForegroundColor Green

    } catch {
        Write-Host "   [WARN] That bai: $Path" -ForegroundColor Yellow
        Write-Host "          Ly do : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ── 2. Xoa Registry ────────────────────────────────────────
Write-Host "`n[2/4] Xoa Registry Office..." -ForegroundColor Cyan

$hklmKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
    "HKLM:\SOFTWARE\Microsoft\Office\16.0",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\ClickToRun",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office\16.0",
    "HKLM:\SOFTWARE\Microsoft\AppVISV",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\O365ProPlusRetail - en-us",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Office Professional Plus 2021 - en-us",
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ProPlus2021Retail - en-us"
)

$hkcuKeys = @(
    "HKCU:\SOFTWARE\Microsoft\Office\16.0",
    "HKCU:\SOFTWARE\Microsoft\Office"
)

foreach ($k in $hklmKeys) { Remove-RegistryKeyForced -Path $k }
foreach ($k in $hkcuKeys)  { Remove-RegistryKeyForced -Path $k }

Write-Host "   -> Hoan tat." -ForegroundColor Green

# ── 3. Xoa thu muc vat ly ──────────────────────────────────
Write-Host "`n[3/4] Xoa thu muc tren o cung..." -ForegroundColor Cyan

$folders = @(
    "$env:ProgramFiles\Microsoft Office",
    "$env:ProgramFiles(x86)\Microsoft Office",
    "$env:ProgramData\Microsoft\Office",
    "$env:ProgramData\Microsoft Help",
    "$env:LOCALAPPDATA\Microsoft\Office",
    "$env:APPDATA\Microsoft\Office",
    "$env:LOCALAPPDATA\Microsoft\Teams"
)

foreach ($f in $folders) {
    if (-not (Test-Path $f)) {
        Write-Host "   [SKIP] Khong tim thay: $f" -ForegroundColor DarkGray
        continue
    }

    # Thu xoa binh thuong truoc
    Remove-Item $f -Recurse -Force -ErrorAction SilentlyContinue

    # Neu van con, ep quyen bang takeown + icacls roi xoa lai
    if (Test-Path $f) {
        Write-Host "   [INFO] Dang ep quyen: $f" -ForegroundColor DarkYellow
        & takeown /F "$f" /R /D Y 2>$null | Out-Null
        & icacls  "$f" /grant "Administrators:F" /T /C /Q 2>$null | Out-Null
        Remove-Item $f -Recurse -Force -ErrorAction SilentlyContinue
    }

    if (-not (Test-Path $f)) {
        Write-Host "   [OK]   Xoa: $f" -ForegroundColor Green
    } else {
        Write-Host "   [WARN] Con sot (co the dang duoc su dung): $f" -ForegroundColor Yellow
    }
}

Write-Host "   -> Hoan tat." -ForegroundColor Green

# ── 4. Ket thuc ────────────────────────────────────────────
Write-Host "`n[4/4] QUA TRINH GO CAI DAT HOAN TAT!" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Vui long KHOI DONG LAI may tinh truoc khi cai Office moi." -ForegroundColor White
Write-Host ""
Write-Host "  Neu van gap loi 30053-44 sau khi khoi dong lai," -ForegroundColor White
Write-Host "  hay chay Microsoft SaRA Tool (cong cu chinh thuc cua Microsoft):" -ForegroundColor White
Write-Host "  https://aka.ms/SaRA-OfficeUninstall" -ForegroundColor Cyan
Write-Host ""
Write-Host "Nhan phim bat ky de thoat..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")