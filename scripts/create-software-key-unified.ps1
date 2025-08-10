# Software Key Creation with Unified Naming (No Admin Required)
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

Add-Type -AssemblyName System.Security

try {
    Write-Host "=== UNIFIED SOFTWARE KEY CREATION ===" -ForegroundColor Cyan
    Write-Host "Creating software key: $KeyName (no admin required)" -ForegroundColor White
    
    # Build consistent key name
    $fullKeyName = "TPM_ES256_$KeyName"
    Write-Host "Full key name will be: $fullKeyName" -ForegroundColor Yellow
    
    # Create CNG key parameters for software provider
    $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::None
    $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $keyParams.Provider = [System.Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
    
    $providerUsed = "Microsoft Software Key Storage Provider"
    Write-Host "Using software provider (no TPM): $providerUsed" -ForegroundColor Yellow
    
    # Create the key
    Write-Host "Creating key with software provider..." -ForegroundColor Cyan
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
    $isHardwareTPM = $false  # Software key
    
    Write-Host "SUCCESS: Software key created!" -ForegroundColor Green
    Write-Host "  Requested name: $KeyName" -ForegroundColor White
    Write-Host "  Full key name: $fullKeyName" -ForegroundColor White
    Write-Host "  Actual provider: $actualProvider" -ForegroundColor White
    Write-Host "  Hardware TPM: $isHardwareTPM" -ForegroundColor Yellow
    Write-Host "  Unique name: $keyHandle" -ForegroundColor Gray
    
    # Export public key
    $publicBlob = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
    $publicBase64 = [Convert]::ToBase64String($publicBlob)
    
    # CRITICAL: Test that we can reopen the key immediately
    $key.Dispose()
    Write-Host "Testing key persistence..." -ForegroundColor Cyan
    
    $verifyKey = $null
    $canReopen = $false
    
    # Try to reopen with the same provider
    try {
        $verifyKey = [System.Security.Cryptography.CngKey]::Open($fullKeyName, $keyParams.Provider)
        Write-Host "SUCCESS: Key can be reopened with software provider" -ForegroundColor Green
        $canReopen = $true
    } catch {
        Write-Host "FAILED: Cannot reopen with software provider - $($_.Exception.Message)" -ForegroundColor Red
        
        # Try without provider (system choice)
        try {
            $verifyKey = [System.Security.Cryptography.CngKey]::Open($fullKeyName)
            Write-Host "SUCCESS: Key can be reopened with system provider selection" -ForegroundColor Green
            $canReopen = $true
        } catch {
            Write-Host "FAILED: Cannot reopen with any provider - $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    if ($verifyKey) {
        Write-Host "Verification details:" -ForegroundColor Cyan
        Write-Host "  Verify provider: $($verifyKey.Provider.Provider)" -ForegroundColor White
        Write-Host "  Verify unique name: $($verifyKey.UniqueName)" -ForegroundColor White
        $verifyKey.Dispose()
    }
    
    if (-not $canReopen) {
        throw "Key was created but cannot be reopened - this will cause CSR generation to fail"
    }
    
    # Return consistent result
    $result = @{
        Success = $true
        KeyName = $KeyName
        FullKeyName = $fullKeyName
        Handle = $fullKeyName  # IMPORTANT: Use full name for all future operations
        Algorithm = "ES256"
        Provider = $actualProvider
        PublicKey = $publicBase64
        InTPM = $isHardwareTPM
        CanReopen = $canReopen
        Created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    Write-Host ""
    Write-Host "=== SOFTWARE KEY CREATION SUMMARY ===" -ForegroundColor Cyan
    Write-Host "Database should store:" -ForegroundColor Yellow
    Write-Host "  name: '$KeyName'" -ForegroundColor White
    Write-Host "  tmpHandle: '$fullKeyName'" -ForegroundColor White
    Write-Host "  inTPM: $isHardwareTPM" -ForegroundColor White
    Write-Host "  provider: '$actualProvider'" -ForegroundColor White
    Write-Host ""
    Write-Host "CSR generation should use key name: '$fullKeyName'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "NOTE: This is a software key. For hardware TPM keys, run as Administrator." -ForegroundColor Yellow
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