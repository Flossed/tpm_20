param([string]$KeyName)

try {
    Add-Type -AssemblyName System.Security
    $provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    
    Write-Host "Testing key name: $KeyName"
    $key = [System.Security.Cryptography.CngKey]::Open($KeyName, $provider)
    Write-Host "SUCCESS: Found key $KeyName"
    Write-Host "UniqueName: $($key.UniqueName)"
    Write-Host "Provider: $($key.Provider.Provider)"
    
} catch {
    Write-Host "FAILED: Could not open key $KeyName"
    Write-Host "Error: $($_.Exception.Message)"
}