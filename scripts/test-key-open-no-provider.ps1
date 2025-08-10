param([string]$KeyName)

try {
    Add-Type -AssemblyName System.Security
    
    Write-Host "Testing key name: $KeyName (no provider specified)"
    $key = [System.Security.Cryptography.CngKey]::Open($KeyName)
    Write-Host "SUCCESS: Found key $KeyName"
    Write-Host "UniqueName: $($key.UniqueName)"
    Write-Host "Provider: $($key.Provider.Provider)"
    $key.Dispose()
    
} catch {
    Write-Host "FAILED: Could not open key $KeyName"
    Write-Host "Error: $($_.Exception.Message)"
}