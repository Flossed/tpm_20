try {
    Add-Type -AssemblyName System.Security
    Write-Host "Enumerating all CNG keys from all providers..."
    
    # Test different providers
    $providers = @(
        @{Name="Microsoft Software Key Storage Provider"; Provider=[System.Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider},
        @{Name="Microsoft Smart Card Key Storage Provider"; Provider=[System.Security.Cryptography.CngProvider]::MicrosoftSmartCardKeyStorageProvider}
    )
    
    # Try to add Platform provider if available
    try {
        $platformProvider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
        if (-not [string]::IsNullOrEmpty($platformProvider.Provider)) {
            $providers += @{Name="Microsoft Platform Crypto Provider"; Provider=$platformProvider}
        }
    } catch {
        Write-Host "Platform provider not available"
    }
    
    foreach ($providerInfo in $providers) {
        Write-Host "`nTesting provider: $($providerInfo.Name)"
        Write-Host "Provider value: '$($providerInfo.Provider.Provider)'"
        
        if ([string]::IsNullOrEmpty($providerInfo.Provider.Provider)) {
            Write-Host "Skipping empty provider"
            continue
        }
        
        # Try to enumerate keys by attempting to open common key names
        $testNames = @(
            "test011", 
            "TPM_ES256_test011",
            "testdebug",
            "TPM_ES256_testdebug"
        )
        
        $foundAny = $false
        foreach ($testName in $testNames) {
            try {
                $key = [System.Security.Cryptography.CngKey]::Open($testName, $providerInfo.Provider)
                Write-Host "  FOUND: $testName"
                Write-Host "    UniqueName: $($key.UniqueName)"
                Write-Host "    Algorithm: $($key.Algorithm.Algorithm)"
                $key.Dispose()
                $foundAny = $true
            } catch {
                # Key doesn't exist, continue silently
            }
        }
        
        if (-not $foundAny) {
            Write-Host "  No keys found with test names"
        }
    }
    
    # Also try using certutil to list keys from different providers
    Write-Host "`nTrying certutil approach..."
    try {
        $certutilOutput = & certutil -key 2>&1
        if ($certutilOutput) {
            Write-Host "Certutil output:"
            Write-Host $certutilOutput
        }
    } catch {
        Write-Host "Certutil failed: $($_.Exception.Message)"
    }
    
} catch {
    Write-Host "General error: $($_.Exception.Message)"
}