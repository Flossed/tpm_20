# Force Hardware TPM Key Creation (requires Admin)
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Security

try {
    Write-Host "=== FORCE HARDWARE TPM KEY CREATION ===" -ForegroundColor Cyan
    Write-Host "Creating hardware TPM key: $KeyName" -ForegroundColor White
    
    # Build consistent key name
    $fullKeyName = "TPM_ES256_$KeyName"
    Write-Host "Full key name: $fullKeyName" -ForegroundColor Yellow
    
    # Create CNG key parameters - FORCE hardware TPM provider
    $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::None
    $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $keyParams.Provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    
    Write-Host "Using FORCED hardware TPM provider: $($keyParams.Provider.Provider)" -ForegroundColor Green
    
    # Create the key
    Write-Host "Creating hardware TPM key..." -ForegroundColor Cyan
    $key = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $fullKeyName,
        $keyParams
    )
    
    if (-not $key) {
        throw "Key creation returned null"
    }
    
    # Get key details immediately after creation
    $actualProvider = $key.Provider.Provider
    $keyHandle = $key.UniqueName
    $isHardwareTPM = ($actualProvider -like "*Platform*")
    
    Write-Host "SUCCESS: Hardware TPM key created!" -ForegroundColor Green
    Write-Host "  Requested name: $KeyName" -ForegroundColor White
    Write-Host "  Full key name: $fullKeyName" -ForegroundColor White
    Write-Host "  Actual provider: $actualProvider" -ForegroundColor White
    Write-Host "  Hardware TPM: $isHardwareTPM" -ForegroundColor Green
    Write-Host "  Unique name: $keyHandle" -ForegroundColor Gray
    
    # Export public key
    $publicBlob = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
    $publicBase64 = [Convert]::ToBase64String($publicBlob)
    
    # CRITICAL: Test that we can reopen the key immediately
    $key.Dispose()
    Write-Host "Testing hardware key persistence..." -ForegroundColor Cyan
    
    $verifyKey = $null
    try {
        $verifyKey = [System.Security.Cryptography.CngKey]::Open($fullKeyName, $keyParams.Provider)
        Write-Host "SUCCESS: Hardware key can be reopened" -ForegroundColor Green
        Write-Host "  Verify provider: $($verifyKey.Provider.Provider)" -ForegroundColor White
        Write-Host "  Verify unique name: $($verifyKey.UniqueName)" -ForegroundColor White
        $verifyKey.Dispose()
        $canReopen = $true
    } catch {
        Write-Host "FAILED: Cannot reopen hardware key - $($_.Exception.Message)" -ForegroundColor Red
        $canReopen = $false
    }
    
    if (-not $canReopen) {
        throw "Hardware key was created but cannot be reopened - this will cause CSR generation to fail"
    }
    
    # Return result for Node.js service
    $result = @{
        Success = $true
        KeyName = $KeyName
        FullKeyName = $fullKeyName
        Handle = $fullKeyName  # Use full name for all future operations
        Algorithm = "ES256"
        Provider = $actualProvider
        PublicKey = $publicBase64
        InTPM = $isHardwareTPM
        CanReopen = $canReopen
        Created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    Write-Host ""
    Write-Host "=== HARDWARE TPM KEY CREATION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "TRUE HARDWARE TPM KEY CREATED SUCCESSFULLY!" -ForegroundColor Green -BackgroundColor Black
    Write-Host "Database should store:" -ForegroundColor Yellow
    Write-Host "  name: '$KeyName'" -ForegroundColor White
    Write-Host "  tpmHandle: '$fullKeyName'" -ForegroundColor White
    Write-Host "  inTPM: $isHardwareTPM" -ForegroundColor White
    Write-Host "  provider: '$actualProvider'" -ForegroundColor White
    Write-Host ""
    Write-Host "CSR generation should use key name: '$fullKeyName'" -ForegroundColor Yellow
    Write-Host ""
    
    $result | ConvertTo-Json -Compress
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    
    $result = @{
        Success = $false
        Error = $_.Exception.Message
        KeyName = $KeyName
        FullKeyName = "TPM_ES256_$KeyName"
    }
    
    $result | ConvertTo-Json -Compress
    exit 1
}