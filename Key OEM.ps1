$key = (Get-CimInstance -Query 'select * from SoftwareLicensingService').OA3xOriginalProductKey
if ($key) {
    Write-Output "OEM_Key: $key"
} else {
    Write-Output "OEM_Key: No OEM Key found in BIOS"
}