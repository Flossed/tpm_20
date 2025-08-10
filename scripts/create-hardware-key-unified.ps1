# Hardware TPM Key Creation with Actual Name Storage
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Security

try {
    Write-Host "=== HARDWARE TPM KEY CREATION WITH ACTUAL NAME ===" -ForegroundColor Cyan
    Write-Host "Creating hardware TPM key: $KeyName" -ForegroundColor White
    
    # Build initial key name (what we request)
    $requestedKeyName = "TPM_ES256_$KeyName"
    Write-Host "Requested key name: $requestedKeyName" -ForegroundColor Yellow
    
    # Create CNG key parameters for hardware TPM
    $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::None
    $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $keyParams.Provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    
    Write-Host "Using Microsoft Platform Crypto Provider (Hardware TPM)" -ForegroundColor Green
    
    # Create the key
    Write-Host "Creating hardware TPM key..." -ForegroundColor Cyan
    $key = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $requestedKeyName,
        $keyParams
    )
    
    if (-not $key) {
        throw "Key creation returned null"
    }
    
    # CRITICAL: Get the ACTUAL name assigned by the TPM
    # The TPM might store it differently than requested
    $actualTPMName = $key.UniqueName
    $actualProvider = $key.Provider.Provider
    
    Write-Host "SUCCESS: Hardware TPM key created!" -ForegroundColor Green
    Write-Host "  User-friendly name: $KeyName" -ForegroundColor White
    Write-Host "  Requested CNG name: $requestedKeyName" -ForegroundColor Yellow
    Write-Host "  ACTUAL TPM UNIQUE NAME: $actualTPMName" -ForegroundColor Green -BackgroundColor Black
    Write-Host "  Provider: $actualProvider" -ForegroundColor White
    
    # Export public key
    $publicBlob = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
    $publicBase64 = [Convert]::ToBase64String($publicBlob)
    
    # Dispose the original key
    $key.Dispose()
    
    # Test which name actually works for reopening
    Write-Host "`nTesting key persistence..." -ForegroundColor Cyan
    
    $workingName = ""
    
    # Test 1: Try the actual TPM unique name
    try {
        Write-Host "Testing with actual TPM name: $actualTPMName" -ForegroundColor Yellow
        $testKey = [System.Security.Cryptography.CngKey]::Open($actualTPMName, $keyParams.Provider)
        Write-Host "SUCCESS: TPM unique name works!" -ForegroundColor Green
        $testKey.Dispose()
        $workingName = $actualTPMName
    } catch {
        Write-Host "Cannot open with TPM unique name" -ForegroundColor Red
        
        # Test 2: Try the requested name
        try {
            Write-Host "Testing with requested name: $requestedKeyName" -ForegroundColor Yellow
            $testKey = [System.Security.Cryptography.CngKey]::Open($requestedKeyName, $keyParams.Provider)
            Write-Host "SUCCESS: Requested name works!" -ForegroundColor Green
            $testKey.Dispose()
            $workingName = $requestedKeyName
        } catch {
            # Test 3: Try just the base name
            try {
                Write-Host "Testing with base name: $KeyName" -ForegroundColor Yellow
                $testKey = [System.Security.Cryptography.CngKey]::Open($KeyName, $keyParams.Provider)
                Write-Host "SUCCESS: Base name works!" -ForegroundColor Green
                $testKey.Dispose()
                $workingName = $KeyName
            } catch {
                throw "Cannot reopen key with any name variant"
            }
        }
    }
    
    Write-Host "`n*** IMPORTANT: The working name for CSR is: $workingName ***" -ForegroundColor Green -BackgroundColor Black
    
    # Return result with the WORKING name for database storage
    $result = @{
        Success = $true
        KeyName = $KeyName  # User-friendly name
        Handle = $workingName  # THE ACTUAL WORKING NAME - STORE THIS IN DATABASE!
        Algorithm = "ES256"
        Provider = $actualProvider
        PublicKey = $publicBase64
        InTPM = $true
        Created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    Write-Host ""
    Write-Host "=== CRITICAL DATABASE STORAGE ===" -ForegroundColor Cyan -BackgroundColor Black
    Write-Host "MongoDB must store:" -ForegroundColor Yellow
    Write-Host "  name: '$KeyName' (user-friendly)" -ForegroundColor White
    Write-Host "  tpmHandle: '$workingName' (ACTUAL WORKING NAME)" -ForegroundColor Green -BackgroundColor Black
    Write-Host "  inTPM: true" -ForegroundColor White
    Write-Host "  provider: '$actualProvider'" -ForegroundColor White
    Write-Host ""
    Write-Host "CSR generation MUST use tpmHandle: '$workingName'" -ForegroundColor Green -BackgroundColor Black
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