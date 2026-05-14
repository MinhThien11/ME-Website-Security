@echo off
chcp 65001 >nul
title Ha Windows Pro xuong Home OEM - 1 Buoc
color 0A

:: -------------------------------------------------------
:: Kiem tra quyen Admin
:: -------------------------------------------------------
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo [LOI] Vui long chay lai bang quyen Administrator!
    echo Click chuot phai vao file -^> Run as administrator
    pause
    exit /b
)

cls
echo ============================================
echo    Ha Windows Pro xuong Home OEM - 1 Buoc
echo    Check hang ^| Go KMS ^| Doi Edition ^| OA
echo ============================================
echo.

:: -------------------------------------------------------
:: BUOC 1: Thu thap thong tin may
:: -------------------------------------------------------
echo [1/6] Dang thu thap thong tin may...
echo.

for /f "skip=1 tokens=*" %%a in ('wmic computersystem get Manufacturer') do (
    if not defined MAKER set "MAKER=%%a"
)
for /f "skip=1 tokens=*" %%a in ('wmic computersystem get Model') do (
    if not defined MODEL set "MODEL=%%a"
)
for /f "skip=1 tokens=*" %%a in ('wmic bios get SerialNumber') do (
    if not defined SERIAL set "SERIAL=%%a"
)
for /f "skip=1 tokens=*" %%a in ('wmic bios get SMBIOSBIOSVersion') do (
    if not defined BIOSVER set "BIOSVER=%%a"
)
for /f "skip=1 tokens=*" %%a in ('wmic os get Caption') do (
    if not defined OSNAME set "OSNAME=%%a"
)
for /f "tokens=3*" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v EditionID') do (
    set "EDITION=%%a %%b"
)
for /f "skip=1 tokens=*" %%a in ('wmic path SoftwareLicensingService get OA3xOriginalProductKey') do (
    if not defined BIOSKEY set "BIOSKEY=%%a"
)

:: Xoa khoang trang thua
set "MAKER=%MAKER: =%"
set "MODEL=%MODEL: =%"
set "SERIAL=%SERIAL: =%"

echo  +------------------------------------------+
echo  ^| THONG TIN MAY                            ^|
echo  +------------------------------------------+
echo  ^| Hang         : %MAKER%
echo  ^| Model        : %MODEL%
echo  ^| Serial       : %SERIAL%
echo  ^| Windows      : %OSNAME%
echo  ^| Edition      : %EDITION%
if defined BIOSKEY (
    echo  ^| BIOS OEM Key : %BIOSKEY%
) else (
    echo  ^| BIOS OEM Key : Khong tim thay
)
echo  +------------------------------------------+
echo.

:: -------------------------------------------------------
:: BUOC 2: Go bo KMS
:: -------------------------------------------------------
echo [2/6] Dang go bo KMS activation...

cscript //nologo %windir%\system32\slmgr.vbs /cpky >nul 2>&1
cscript //nologo %windir%\system32\slmgr.vbs /upk  >nul 2>&1
cscript //nologo %windir%\system32\slmgr.vbs /ckms >nul 2>&1

net stop sppsvc /y >nul 2>&1
timeout /t 3 /nobreak >nul
net start sppsvc >nul 2>&1
timeout /t 3 /nobreak >nul

echo       [OK] Da go bo KMS!
echo.

:: -------------------------------------------------------
:: BUOC 3: Doc lai key BIOS sau khi go KMS
:: -------------------------------------------------------
echo [3/6] Doc lai key BIOS sau khi go KMS...

set "BIOSKEY="
for /f "skip=1 tokens=*" %%a in ('wmic path SoftwareLicensingService get OA3xOriginalProductKey') do (
    if not defined BIOSKEY set "BIOSKEY=%%a"
)
set "BIOSKEY=%BIOSKEY: =%"

if defined BIOSKEY (
    echo       [OK] Tim thay key BIOS: %BIOSKEY%
) else (
    echo       [!] Van khong tim thay key BIOS.
    echo.
    echo       May co the khong co key nhung BIOS.
    echo       Kiem tra COA sticker duoi may hoac pin.
    echo.
    set /p BIOSKEY="       Nhap key OEM thu cong (hoac Enter de thoat): "
    if not defined BIOSKEY (
        echo [THOAT] Khong co key de xu ly.
        pause
        exit /b
    )
)
echo.

:: -------------------------------------------------------
:: BUOC 4: Xac dinh edition theo hang may
:: -------------------------------------------------------
echo [4/6] Xac dinh edition phu hop voi may %MAKER% %MODEL%...

set "GENERIC_KEY=YTMG3-N6DKC-DKB77-7M9GH-8HVX7"
set "TARGET_EDITION=Windows Home"

:: Hang thuong dung Single Language tai Viet Nam
echo %MAKER% | findstr /i "Asus Acer Lenovo" >nul
if %errorLevel% EQU 0 (
    set "GENERIC_KEY=7HNRX-D7KGG-3K4RQ-4WPJ4-YTDFH"
    set "TARGET_EDITION=Windows Home Single Language"
    echo       [Auto] May %MAKER% thuong dung Single Language tai VN
) else (
    echo       [Auto] Mac dinh chon Windows Home
)

echo       =^> Chuyen sang: %TARGET_EDITION%
echo.

:: -------------------------------------------------------
:: BUOC 5: Doi edition va apply key BIOS
:: -------------------------------------------------------
echo [5/6] Dang chuyen edition va apply key OEM...

echo       Dang ap dung generic key de doi edition...
changepk.exe /ProductKey %GENERIC_KEY% >nul 2>&1
if %errorLevel% NEQ 0 (
    cscript //nologo %windir%\system32\slmgr.vbs /ipk %GENERIC_KEY% >nul 2>&1
)
timeout /t 3 /nobreak >nul

echo       Dang apply key OEM BIOS chinh thuc...
changepk.exe /ProductKey %BIOSKEY% >nul 2>&1
if %errorLevel% NEQ 0 (
    cscript //nologo %windir%\system32\slmgr.vbs /ipk %BIOSKEY% >nul 2>&1
)

echo       [OK] Da apply key OEM BIOS!
echo.

:: -------------------------------------------------------
:: BUOC 6: Activate
:: -------------------------------------------------------
echo [6/6] Dang kich hoat Windows...
timeout /t 2 /nobreak >nul
cscript //nologo %windir%\system32\slmgr.vbs /ato
echo.

echo ============================================
echo   HOAN TAT!
echo.
echo   May     : %MAKER% %MODEL%
echo   Edition : %TARGET_EDITION%
echo   Key     : %BIOSKEY%
echo.
echo   Sau khi RESTART + ket noi internet:
echo   Windows se tu Activate bang key BIOS.
echo   Neu chua: chay 'slmgr /ato' trong CMD Admin
echo ============================================
echo.

set /p RESTART="Khoi dong lai ngay bay gio? (Y/N): "
if /i "%RESTART%"=="Y" (
    echo Khoi dong lai sau 10 giay...
    shutdown /r /t 10 /c "Ap dung thay doi edition Windows"
) else (
    echo Nho khoi dong lai may truoc khi dung tiep.
)

pause