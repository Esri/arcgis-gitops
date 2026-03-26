param(
    [string]$AliasFQDN
)
try {
    $computerName = $env:COMPUTERNAME
    $hosts = @($computerName, $AliasFQDN, "localhost", "127.0.0.1")

    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\MSV1_0"
    
    if (-not (Test-Path $registryPath)) { 
        New-Item $registryPath -Force 
    }
    
    New-ItemProperty -Path $registryPath -Name "BackConnectionHostNames" -Value $hosts -PropertyType MultiString -Force
    
    Write-Host "Loopback alias set successfully. Hostnames: $($hosts -join ', ')"
} catch {
    Write-Error $_.Exception | format-list -force
    Write-Error 'Error occurred while setting loopback alias.' -ErrorAction Stop
}
