# Delete CNG TPM Key
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Security

try {
    Write-Host "🗑️ Deleting TPM key: $KeyName" -ForegroundColor Cyan
    
    $keyNameFull = "TPM_ES256_$KeyName"
    
    # Try to open and delete the key
    $key = $null
    $providers = @(
        [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider,
        [System.Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,
        $null
    )
    
    foreach ($provider in $providers) {
        try {
            if ($provider) {
                $key = [System.Security.Cryptography.CngKey]::Open($keyNameFull, $provider)
            } else {
                $key = [System.Security.Cryptography.CngKey]::Open($keyNameFull)
            }
            if ($key) {
                Write-Host "✅ Key found with provider: $($key.Provider.Provider)" -ForegroundColor Green
                break
            }
        } catch {
            # Continue trying
        }
    }
    
    if ($key) {
        $provider = $key.Provider.Provider
        $key.Delete()
        $key.Dispose()
        
        $result = @{
            Success = $true
            Message = "Key '$KeyName' deleted successfully"
            Provider = $provider
        }
        
        Write-Host "✅ Key deleted successfully" -ForegroundColor Green
    } else {
        throw "Key not found: $KeyName"
    }
    
    Write-Output ($result | ConvertTo-Json -Compress)
    
} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    
    $result = @{
        Success = $false
        Error = $_.Exception.Message
    }
    
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 1
}