# Sign with CNG TPM Key
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName,
    
    [Parameter(Mandatory=$true)]
    [string]$DataToSign
)

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Security

try {
    Write-Host "🔍 Signing data with TPM key: $KeyName" -ForegroundColor Cyan
    
    $keyNameFull = "TPM_ES256_$KeyName"
    
    # Try to open the key with different approaches
    $key = $null
    $providers = @(
        [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider,
        [System.Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,
        $null  # Let system choose
    )
    
    foreach ($provider in $providers) {
        try {
            if ($provider) {
                $key = [System.Security.Cryptography.CngKey]::Open($keyNameFull, $provider, [System.Security.Cryptography.CngKeyOpenOptions]::UserKey)
            } else {
                $key = [System.Security.Cryptography.CngKey]::Open($keyNameFull)
            }
            if ($key) {
                Write-Host "✅ Key opened with provider: $($key.Provider.Provider)" -ForegroundColor Green
                break
            }
        } catch {
            # Continue trying
        }
    }
    
    if (-not $key) {
        throw "Key not found: $KeyName"
    }
    
    # Create ECDSA object
    $ecdsa = [System.Security.Cryptography.ECDsaCng]::new($key)
    
    # Sign data
    $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($DataToSign)
    $signatureBytes = $ecdsa.SignData($dataBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    
    # Create hash for reference
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash($dataBytes)
    
    $result = @{
        Success = $true
        Signature = [Convert]::ToBase64String($signatureBytes)
        Algorithm = "ES256"
        Hash = [BitConverter]::ToString($hashBytes).Replace("-", "")
        KeyName = $KeyName
        Provider = $key.Provider.Provider
        Signed = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    Write-Host "✅ Data signed successfully" -ForegroundColor Green
    
    # Clean up
    $ecdsa.Dispose()
    $sha256.Dispose()
    
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