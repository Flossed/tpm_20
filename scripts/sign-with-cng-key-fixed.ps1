# Sign with CNG TPM Key (Fixed for both key name and file path formats)
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
    
    $key = $null
    
    # Check if KeyName is a file path (old format) or key name (new format)
    if ($KeyName -like "*\*" -or $KeyName -like "*/*") {
        Write-Host "📁 File path format detected, searching for matching key..." -ForegroundColor Yellow
        
        # It's a file path, we need to find the key by enumerating
        # Try to find keys that match this file path
        $providers = @(
            [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider,
            [System.Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
        )
        
        foreach ($provider in $providers) {
            try {
                # Get all keys from this provider
                $keyNames = [System.Security.Cryptography.CngKey]::GetKeys($provider, [System.Security.Cryptography.CngKeyOpenOptions]::UserKey)
                
                foreach ($knownKeyName in $keyNames) {
                    try {
                        $testKey = [System.Security.Cryptography.CngKey]::Open($knownKeyName, $provider, [System.Security.Cryptography.CngKeyOpenOptions]::UserKey)
                        
                        # Check if this key's UniqueName matches our file path
                        if ($testKey.UniqueName -eq $KeyName) {
                            Write-Host "✅ Found matching key: $knownKeyName" -ForegroundColor Green
                            $key = $testKey
                            break
                        } else {
                            $testKey.Dispose()
                        }
                    } catch {
                        # Continue searching
                    }
                }
                
                if ($key) { break }
            } catch {
                # Continue with next provider
            }
        }
        
        if (-not $key) {
            throw "Could not find key matching file path: $KeyName"
        }
    } else {
        # It's a key name, use the standard approach
        $keyNameFull = if ($KeyName -like "TPM_ES256_*") { $KeyName } else { "TPM_ES256_$KeyName" }
        
        Write-Host "🔑 Attempting to open key: $keyNameFull" -ForegroundColor Cyan
        
        # Try to open the key with different providers
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