try {
    Add-Type -AssemblyName System.Security
    Write-Host "Testing Microsoft Platform Crypto Provider availability..."
    
    $provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    Write-Host "Provider object created successfully"
    Write-Host "Provider name: '$($provider.Provider)'"
    
    if ($provider -eq $null) {
        Write-Host "ERROR: Provider is null"
        exit 1
    }
    
    if ([string]::IsNullOrEmpty($provider.Provider)) {
        Write-Host "ERROR: Provider name is empty"
        exit 1
    }
    
    Write-Host "Provider is valid and available"
    
    # Test key opening with this provider
    Write-Host "Testing key opening with names from database..."
    
    $testNames = @("TPM_ES256_test010", "test010")
    foreach ($name in $testNames) {
        try {
            Write-Host "Attempting to open key: $name"
            $key = [System.Security.Cryptography.CngKey]::Open($name, $provider)
            Write-Host "SUCCESS: Opened key $name"
            Write-Host "  UniqueName: $($key.UniqueName)"
            Write-Host "  Algorithm: $($key.Algorithm.Algorithm)"
            break
        } catch {
            Write-Host "FAILED: Could not open key $name - $($_.Exception.Message)"
        }
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.Exception.StackTrace)"
}