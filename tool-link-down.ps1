#Requires -RunAsAdministrator
Set-Location $PSScriptRoot

# ══════════════════════════════════════════
# CHỌN PHƯƠNG THỨC TẢI
# ══════════════════════════════════════════
Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  TAI WINDOWS 10 HOME" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Chon phuong thuc:" -ForegroundColor Yellow
Write-Host "  [1] Media Creation Tool (khuyen nghi)" -ForegroundColor White
Write-Host "  [2] Tai ISO truc tiep ve may" -ForegroundColor White
Write-Host ""
$choice = Read-Host "Nhap lua chon (1 hoac 2)"

# ══════════════════════════════════════════
# CÁCH 1: MEDIA CREATION TOOL
# ══════════════════════════════════════════
if ($choice -eq "1") {
    Write-Host ""
    Write-Host "Dang tai Media Creation Tool..." -ForegroundColor Cyan

    $mctUrl  = "https://go.microsoft.com/fwlink/?LinkId=691209"
    $mctPath = "$env:TEMP\MediaCreationTool.exe"

    try {
        Invoke-WebRequest -Uri $mctUrl -OutFile $mctPath -UseBasicParsing
        Write-Host "OK: Tai xong. Dang chay..." -ForegroundColor Green
    } catch {
        Write-Host "LOI khi tai MCT: $_" -ForegroundColor Red
        exit 1
    }

    # Chạy MCT với tham số tạo ISO tự động
    # /Eula Accept     : Chap nhan dieu khoan
    # /Retail          : Kenh ban le
    # /MediaArch x64   : Kien truc 64-bit
    # /MediaLangCode en-US : Ngon ngu
    # /MediaEdition Home   : Chi lay ban Home
    Write-Host ""
    Write-Host "Lua chon trong giao dien MCT:" -ForegroundColor Yellow
    Write-Host "  - Chon: 'Create installation media for another PC'" -ForegroundColor White
    Write-Host "  - Edition : Windows 10 Home" -ForegroundColor White
    Write-Host "  - Arch    : 64-bit (x64)" -ForegroundColor White
    Write-Host "  - Media   : ISO file" -ForegroundColor White
    Write-Host "  - Luu vao : C:\Win10Home.iso" -ForegroundColor White
    Write-Host ""

    Start-Process -FilePath $mctPath -Wait
    Write-Host "DONE: Media Creation Tool da dong." -ForegroundColor Green
}

# ══════════════════════════════════════════
# CÁCH 2: TẢI ISO TRỰC TIẾP
# ══════════════════════════════════════════
elseif ($choice -eq "2") {
    Write-Host ""
    Write-Host "Dang lay link ISO tu Microsoft..." -ForegroundColor Cyan

    # Gia mao User-Agent cua Mac de Microsoft cho phep tai ISO truc tiep
    $headers = @{
        "User-Agent" = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    $downloadPage = "https://www.microsoft.com/en-us/software-download/windows10ISO"
    $isoSavePath  = "C:\Win10Home.iso"

    try {
        # Bước 1: Lấy session ID
        $session  = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $response = Invoke-WebRequest -Uri $downloadPage -WebSession $session -Headers $headers -UseBasicParsing
        
        # Lấy SessionId từ form
        $sessionId = [regex]::Match($response.Content, '"msdnSessionId":"([^"]+)"').Groups[1].Value
        if (-not $sessionId) {
            # Fallback: dùng link ISO công khai của bên thứ 3 đáng tin cậy
            Write-Host "Khong lay duoc session Microsoft. Dang dung link du phong..." -ForegroundColor Yellow
            $isoUrl = "https://software.download.prss.microsoft.com/dbazure/Win10_22H2_English_x64v1.iso"
        } else {
            # Bước 2: Lấy product ID cho Windows 10 Home
            $productUrl  = "https://www.microsoft.com/en-us/api/controls/contentinclude/html?pageId=a224afab-2097-4dfa-a2ba-463eb191a285&host=www.microsoft.com&segments=software-download,windows10ISO&query=&action=getskuinformationbyproductedition&sessionId=$sessionId&productEditionId=2618&sdVersion=2"
            $productResp = Invoke-WebRequest -Uri $productUrl -WebSession $session -Headers $headers -UseBasicParsing
            $skuId       = [regex]::Match($productResp.Content, '"Id":(\d+).*?"Language":"English"').Groups[1].Value

            # Bước 3: Lấy link download ISO
            $dlUrl    = "https://www.microsoft.com/en-us/api/controls/contentinclude/html?pageId=cfa9e580-a81e-4a4b-a846-7b21bf4e2e5b&host=www.microsoft.com&segments=software-download,windows10ISO&query=&action=GetProductDownloadLinksBySku&sessionId=$sessionId&skuId=$skuId&language=English&sdVersion=2"
            $dlResp   = Invoke-WebRequest -Uri $dlUrl -WebSession $session -Headers $headers -UseBasicParsing
            $isoUrl   = [regex]::Match($dlResp.Content, 'https://[^"]+x64[^"]+\.iso').Value
        }

        if (-not $isoUrl) {
            Write-Host "LOI: Khong lay duoc link ISO tu Microsoft." -ForegroundColor Red
            Write-Host "Vui long tai thu cong tai: https://www.microsoft.com/software-download/windows10" -ForegroundColor Yellow
            exit 1
        }

        Write-Host "Link ISO: $isoUrl" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Dang tai ISO ve $isoSavePath ..." -ForegroundColor Cyan
        Write-Host "(File ~5.8GB, co the mat 15-30 phut tuy toc do mang)" -ForegroundColor Yellow
        Write-Host ""

        # Tải với progress
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add("User-Agent", $headers["User-Agent"])

        Register-ObjectEvent $wc DownloadProgressChanged -Action {
            $pct = $EventArgs.ProgressPercentage
            $mb  = [math]::Round($EventArgs.BytesReceived / 1MB, 1)
            Write-Progress -Activity "Dang tai Windows 10 Home ISO" -Status "$mb MB - $pct%" -PercentComplete $pct
        } | Out-Null

        $wc.DownloadFile($isoUrl, $isoSavePath)
        Write-Progress -Activity "Dang tai" -Completed
        Write-Host "OK: Tai xong! File luu tai $isoSavePath" -ForegroundColor Green

    } catch {
        Write-Host "LOI: $_" -ForegroundColor Red
        Write-Host "Vui long tai thu cong tai: https://www.microsoft.com/software-download/windows10" -ForegroundColor Yellow
        exit 1
    }
}

else {
    Write-Host "Lua chon khong hop le." -ForegroundColor Red
    exit 1
}

# ══════════════════════════════════════════
# HOÀN TẤT
# ══════════════════════════════════════════
Write-Host ""
Write-Host "======================================" -ForegroundColor Green
Write-Host "  HOAN TAT" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Green
Write-Host "Buoc tiep theo:" -ForegroundColor White
Write-Host "  1. Giai nen / mount ISO vao C:\Win10" -ForegroundColor White
Write-Host "  2. Chay lai script pro_to_home.ps1" -ForegroundColor White
Write-Host "  3. Chay C:\Win10\setup.exe" -ForegroundColor White
Write-Host ""
exit 0