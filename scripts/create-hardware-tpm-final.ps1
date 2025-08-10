# Final Hardware TPM Key Creation Script
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Security

try {
    Write-Host "=== FINAL HARDWARE TPM KEY CREATION ===" -ForegroundColor Cyan
    Write-Host "Creating hardware TPM key: $KeyName" -ForegroundColor White
    
    $requestedKeyName = "TPM_ES256_$KeyName"
    
    # Create CNG key parameters for hardware TPM
    $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::None
    $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $keyParams.Provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    
    Write-Host "Using Microsoft Platform Crypto Provider (Hardware TPM)" -ForegroundColor Green
    
    # Create the key
    $key = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $requestedKeyName,
        $keyParams
    )
    
    if (-not $key) {
        throw "Key creation failed"
    }
    
    # Get the actual TPM path - THIS IS CRITICAL
    $actualTPMPath = $key.UniqueName
    $actualProvider = $key.Provider.Provider
    
    Write-Host "SUCCESS: Hardware TPM key created!" -ForegroundColor Green
    Write-Host "  User name: $KeyName" -ForegroundColor White
    Write-Host "  Requested: $requestedKeyName" -ForegroundColor Yellow  
    Write-Host "  ACTUAL TPM PATH: $actualTPMPath" -ForegroundColor Green -BackgroundColor Black
    Write-Host "  Provider: $actualProvider" -ForegroundColor White
    
    # Export public key
    $publicBlob = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
    $publicBase64 = [Convert]::ToBase64String($publicBlob)
    
    # Test that key can be reopened (validation)
    $key.Dispose()
    
    try {
        $testKey = [System.Security.Cryptography.CngKey]::Open($actualTPMPath, $keyParams.Provider)
        Write-Host "✓ Key persistence verified" -ForegroundColor Green
        $testKey.Dispose()
        $canReopen = $true
    } catch {
        Write-Host "✗ Key persistence check failed: $($_.Exception.Message)" -ForegroundColor Red
        $canReopen = $false
    }
    
    # Return result for Node.js service
    $result = @{
        Success = $true
        KeyName = $KeyName
        Handle = $actualTPMPath  # CRITICAL: Store this exact path in database
        Algorithm = "ES256"
        Provider = $actualProvider
        PublicKey = $publicBase64
        InTPM = $true
        CanReopen = $canReopen
        Created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    Write-Host ""
    Write-Host "=== DATABASE STORAGE ===" -ForegroundColor Cyan
    Write-Host "Store in MongoDB tpmHandle field:" -ForegroundColor Yellow
    Write-Host "$actualTPMPath" -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    
    $result | ConvertTo-Json -Compress
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    
    $result = @{
        Success = $false
        Error = $_.Exception.Message
        KeyName = $KeyName
    }
    
    $result | ConvertTo-Json -Compress
    exit 1
}