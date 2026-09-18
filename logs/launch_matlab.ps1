$proc = Start-Process -FilePath "matlab" `
    -ArgumentList '-batch', "cd('D:\mayra\Descargas\UPF_COMAK\COMAK\matlab_scripts'); diary('D:\mayra\Descargas\UPF_COMAK\logs\bilateral_e2e_HOLOA040_20260621.log'); diary on; test_bilateral_comak; diary off" `
    -PassThru `
    -NoNewWindow
Write-Output "PID: $($proc.Id)"
Write-Output "Inicio: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Start-Sleep -Seconds 5
$alive = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
Write-Output "Vivo a 5s: $(if ($alive) { 'SI' } else { 'NO' })"
