try {
    Write-Host "=== TPM Hardware Detection Test ===" -ForegroundColor Cyan
    
    # Test 1: Get-TPM command
    Write-Host "`nTest 1: Get-TPM command" -ForegroundColor Yellow
    try {
        $tpm = Get-TPM
        Write-Host "TPM Present: $($tpm.TpmPresent)" -ForegroundColor Green
        Write-Host "TPM Ready: $($tpm.TpmReady)" -ForegroundColor Green
        Write-Host "TPM Enabled: $($tpm.TpmEnabled)" -ForegroundColor Green
        Write-Host "TPM Activated: $($tpm.TpmActivated)" -ForegroundColor Green
        Write-Host "TPM Owned: $($tpm.TpmOwned)" -ForegroundColor Green
    } catch {
        Write-Host "Get-TPM failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 2: WMI query
    Write-Host "`nTest 2: WMI TPM query" -ForegroundColor Yellow
    try {
        $wmiTpm = Get-WmiObject -Namespace "root\cimv2\security\microsofttpm" -Class Win32_Tpm
        if ($wmiTpm) {
            Write-Host "WMI TPM found: $($wmiTpm.Count) device(s)" -ForegroundColor Green
        } else {
            Write-Host "No TPM found via WMI" -ForegroundColor Red
        }
    } catch {
        Write-Host "WMI query failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 3: Check if Microsoft Platform Crypto Provider is available
    Write-Host "`nTest 3: Microsoft Platform Crypto Provider" -ForegroundColor Yellow
    try {
        Add-Type -AssemblyName System.Security
        $provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
        Write-Host "Provider Name: '$($provider.Provider)'" -ForegroundColor Green
        
        if ([string]::IsNullOrEmpty($provider.Provider)) {
            Write-Host "ERROR: Provider name is empty - Platform Crypto Provider not available" -ForegroundColor Red
        } else {
            Write-Host "Platform Crypto Provider is available" -ForegroundColor Green
        }
    } catch {
        Write-Host "Platform provider test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Test 4: Try to create a test TPM key
    Write-Host "`nTest 4: Test TPM key creation" -ForegroundColor Yellow
    try {
        Add-Type -AssemblyName System.Security
        
        $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
        $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::None
        $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
        $keyParams.Provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
        
        $testKeyName = "TPM_TEST_$(Get-Date -Format 'yyyyMMddHHmmss')"
        Write-Host "Attempting to create test key: $testKeyName" -ForegroundColor Cyan
        
        $key = [System.Security.Cryptography.CngKey]::Create(
            [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
            $testKeyName,
            $keyParams
        )
        
        if ($key) {
            Write-Host "SUCCESS: Test TPM key created!" -ForegroundColor Green
            Write-Host "  Key Name: $testKeyName" -ForegroundColor White
            Write-Host "  Provider: $($key.Provider.Provider)" -ForegroundColor White
            Write-Host "  Algorithm: $($key.Algorithm.Algorithm)" -ForegroundColor White
            
            # Test reopening
            $key.Dispose()
            try {
                $reopenKey = [System.Security.Cryptography.CngKey]::Open($testKeyName, $keyParams.Provider)
                Write-Host "SUCCESS: Key can be reopened" -ForegroundColor Green
                $reopenKey.Dispose()
            } catch {
                Write-Host "WARNING: Key created but cannot be reopened: $($_.Exception.Message)" -ForegroundColor Yellow
            }
            
            # Clean up test key
            try {
                $deleteKey = [System.Security.Cryptography.CngKey]::Open($testKeyName, $keyParams.Provider)
                $deleteKey.Delete()
                $deleteKey.Dispose()
                Write-Host "Test key deleted successfully" -ForegroundColor Green
            } catch {
                Write-Host "Could not delete test key: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            Write-Host "ERROR: Key creation returned null" -ForegroundColor Red
        }
    } catch {
        Write-Host "TPM key creation test failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "This usually means:" -ForegroundColor Yellow
        Write-Host "  1. TPM is not available or not properly configured" -ForegroundColor Yellow
        Write-Host "  2. Not running as Administrator" -ForegroundColor Yellow
        Write-Host "  3. TPM is not activated/owned" -ForegroundColor Yellow
    }
    
    Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
    Write-Host "If all tests pass, hardware TPM keys should work." -ForegroundColor White
    Write-Host "If any test fails, that indicates the issue preventing hardware TPM use." -ForegroundColor White
    
} catch {
    Write-Host "General error: $($_.Exception.Message)" -ForegroundColor Red
}