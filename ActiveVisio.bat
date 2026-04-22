@echo off
title Kich hoat Microsoft Visio
cls

echo Dang kiem tra thu muc cai dat Office...

:check_path
if exist "C:\Program Files\Microsoft Office\Office16\ospp.vbs" (
    cd /d "C:\Program Files\Microsoft Office\Office16"
) else if exist "C:\Program Files (x86)\Microsoft Office\Office16\ospp.vbs" (
    cd /d "C:\Program Files (x86)\Microsoft Office\Office16"
) else (
    echo Khong tim thay file ospp.vbs. Vui long kiem tra lai phien ban Visio.
    pause
    exit
)

echo Dang nap Key cua ban...
:: Thay "YOUR-KEY-HERE" bang key thuc te cua ban
cscript ospp.vbs /inpkey:QTJ3N-27K67-9V2VW-F6CC9-YD2D2

echo Dang tien hanh kich hoat...
cscript ospp.vbs /act

echo --- Hoan tat ---
pause