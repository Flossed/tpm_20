# Working TPM Key Creation using CNG APIs
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Security

try {
    Write-Host "🔥 Creating TPM key using CNG APIs..." -ForegroundColor Cyan
    
    # Create CNG key parameters
    $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::None
    $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    
    # Try to set TPM provider first
    $providerSet = $false
    $providerName = ""
    
    try {
        $keyParams.Provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
        $providerSet = $true
        $providerName = "Microsoft Platform Crypto Provider"
        Write-Host "✅ Using Microsoft Platform Crypto Provider (HARDWARE TPM)" -ForegroundColor Green
    } catch {
        # Platform provider failed, try software provider
        try {
            $keyParams.Provider = [System.Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
            $providerSet = $true
            $providerName = "Microsoft Software Key Storage Provider"
            Write-Host "⚠️ Using Microsoft Software Key Storage Provider (software fallback)" -ForegroundColor Yellow
        } catch {
            # Let system choose provider
            $providerName = "System Default"
            Write-Host "⚠️ Using system default provider" -ForegroundColor Yellow
        }
    }
    
    # Create ES256 key using CNG
    $keyNameFull = "TPM_ES256_$KeyName"
    $key = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $keyNameFull,
        $keyParams
    )
    
    if ($key) {
        Write-Host "🎉 SUCCESS: ES256 key created!" -ForegroundColor Green
        
        # Export public key
        $publicBlob = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
        $publicBase64 = [Convert]::ToBase64String($publicBlob)
        
        # Get key details
        $keyHandle = $key.UniqueName
        $actualProvider = $key.Provider.Provider
        $isHardwareTPM = ($actualProvider -like "*Platform*")
        
        Write-Host "📋 Key Details:" -ForegroundColor Cyan
        Write-Host "  Key Name: $KeyName" -ForegroundColor White
        Write-Host "  Full Name: $keyNameFull" -ForegroundColor White
        Write-Host "  Algorithm: ES256 (ECDSA P-256)" -ForegroundColor White
        Write-Host "  Provider: $actualProvider" -ForegroundColor White
        Write-Host "  Hardware TPM: $isHardwareTPM" -ForegroundColor $(if($isHardwareTPM){"Green"}else{"Yellow"})
        Write-Host "  Key Handle: $keyHandle" -ForegroundColor Gray
        
        # Test that we can reopen the key
        $key.Dispose()
        try {
            $verifyKey = [System.Security.Cryptography.CngKey]::Open($keyNameFull)
            $verifyKey.Dispose()
            Write-Host "✅ Key persistence verified" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Warning: Key created but cannot be reopened" -ForegroundColor Yellow
        }
        
        $result = @{
            Success = $true
            KeyName = $KeyName
            Algorithm = "ES256"
            Provider = $actualProvider
            PublicKey = $publicBase64
            Handle = $keyHandle
            InTPM = $isHardwareTPM
            Created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        
        Write-Host ""
        if ($isHardwareTPM) {
            Write-Host "🔒 TRUE HARDWARE TPM KEY CREATED! 🔒" -ForegroundColor Green -BackgroundColor Black
        } else {
            Write-Host "🔑 Software-backed key created (still secure)" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "JSON Result:"
        Write-Output ($result | ConvertTo-Json -Compress)
        
    } else {
        throw "Key creation returned null"
    }
    
} catch {
    Write-Host "❌ ERROR: $($_.Exception.Message)" -ForegroundColor Red
    
    $result = @{
        Success = $false
        Error = $_.Exception.Message
        InTPM = $false
    }
    
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 1
}