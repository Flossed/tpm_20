try {
    Add-Type -AssemblyName System.Security
    Write-Host "Listing all available CNG providers..."
    
    # Get all standard providers
    $providers = @(
        [System.Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,
        [System.Security.Cryptography.CngProvider]::MicrosoftSmartCardKeyStorageProvider
    )
    
    # Try to get Microsoft Platform Crypto Provider
    try {
        $platformProvider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
        $providers += $platformProvider
    } catch {
        Write-Host "Microsoft Platform Crypto Provider not available: $($_.Exception.Message)"
    }
    
    foreach ($provider in $providers) {
        Write-Host "Provider: '$($provider.Provider)'"
    }
    
    # Test software provider with our key
    Write-Host "`nTesting with Microsoft Software Key Storage Provider..."
    $softwareProvider = [System.Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
    
    $testNames = @("TPM_ES256_test010", "test010")
    foreach ($name in $testNames) {
        try {
            Write-Host "Attempting to open key: $name"
            $key = [System.Security.Cryptography.CngKey]::Open($name, $softwareProvider)
            Write-Host "SUCCESS: Opened software key $name"
            Write-Host "  UniqueName: $($key.UniqueName)"
            Write-Host "  Algorithm: $($key.Algorithm.Algorithm)"
            break
        } catch {
            Write-Host "FAILED: Could not open software key $name - $($_.Exception.Message)"
        }
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
}