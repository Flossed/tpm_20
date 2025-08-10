# Create Hardware TPM Key and Generate CSR using Pure .NET
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName,
    [Parameter(Mandatory=$true)]
    [string]$CommonName,
    [string]$Organization = "TPM Test Org",
    [string]$Country = "US"
)

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Security

try {
    Write-Host "=== CREATE HARDWARE TPM KEY AND GENERATE CSR (Pure .NET) ===" -ForegroundColor Cyan
    Write-Host "Creating hardware TPM key and CSR for: $KeyName" -ForegroundColor White
    
    # Step 1: Create Hardware TPM Key
    Write-Host "`nStep 1: Creating hardware TPM key..." -ForegroundColor Yellow
    
    $requestedKeyName = "TPM_ES256_$KeyName"
    
    # Create CNG key parameters for hardware TPM
    $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::None
    $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $keyParams.Provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    
    # Create the key
    $key = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $requestedKeyName,
        $keyParams
    )
    
    if (-not $key) {
        throw "Key creation failed"
    }
    
    $actualTPMName = $key.UniqueName
    $actualProvider = $key.Provider.Provider
    
    Write-Host "SUCCESS: Hardware TPM key created!" -ForegroundColor Green
    Write-Host "  User name: $KeyName" -ForegroundColor White
    Write-Host "  Requested: $requestedKeyName" -ForegroundColor Yellow  
    Write-Host "  Actual TPM path: $actualTPMName" -ForegroundColor Cyan
    Write-Host "  Provider: $actualProvider" -ForegroundColor White
    
    # Export public key
    $publicBlob = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
    $publicBase64 = [Convert]::ToBase64String($publicBlob)
    
    # Step 2: Generate CSR using pure .NET ECDsa class
    Write-Host "`nStep 2: Generating CSR with pure .NET ECDsa..." -ForegroundColor Yellow
    
    # Create ECDsa object from the CNG key
    $ecdsa = [System.Security.Cryptography.ECDsaCng]::new($key)
    
    # Build subject distinguished name
    $subject = "CN=$CommonName"
    if ($Organization) { $subject += ", O=$Organization" }
    if ($Country -and $Country.Length -eq 2) { $subject += ", C=$Country" }
    
    Write-Host "CSR subject: $subject" -ForegroundColor Cyan
    
    # Create X500DistinguishedName
    $subjectDN = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new($subject)
    
    # Create certificate request using CertificateRequest class (available in .NET Framework 4.7.1+)
    try {
        Write-Host "Using CertificateRequest class..." -ForegroundColor Cyan
        
        $certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            $subjectDN,
            $ecdsa,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        
        # Add key usage extension
        $keyUsage = [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor 
                   [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::NonRepudiation
        
        $keyUsageExt = [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($keyUsage, $true)
        $certRequest.CertificateExtensions.Add($keyUsageExt)
        
        # Generate the CSR
        $csrBytes = $certRequest.CreateSigningRequest()
        
        # Convert to PEM format
        $csrBase64 = [Convert]::ToBase64String($csrBytes)
        
        # Format as PEM with proper line breaks
        $pemCSR = "-----BEGIN CERTIFICATE REQUEST-----`n"
        for ($i = 0; $i -lt $csrBase64.Length; $i += 64) {
            $line = $csrBase64.Substring($i, [Math]::Min(64, $csrBase64.Length - $i))
            $pemCSR += "$line`n"
        }
        $pemCSR += "-----END CERTIFICATE REQUEST-----"
        
        $csrGenerated = $true
        Write-Host "SUCCESS: CSR generated using pure .NET!" -ForegroundColor Green
        
    } catch {
        Write-Host "CertificateRequest class not available or failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "This requires .NET Framework 4.7.1+ or .NET Core 2.0+" -ForegroundColor Yellow
        $csrGenerated = $false
        $pemCSR = ""
    }
    
    # Dispose resources
    $ecdsa.Dispose()
    $key.Dispose()
    
    if ($csrGenerated) {
        # Success result
        $result = @{
            Success = $true
            KeyName = $KeyName
            Handle = $actualTPMName  # The actual TPM path that works
            Algorithm = "ES256"
            Provider = $actualProvider
            PublicKey = $publicBase64
            InTPM = $true
            CSR = $pemCSR
            Subject = $subject
            Created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        
        Write-Host ""
        Write-Host "=== COMPLETE SUCCESS WITH PURE .NET ===" -ForegroundColor Green -BackgroundColor Black
        Write-Host "Hardware TPM key created AND CSR generated!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Database should store:" -ForegroundColor Yellow
        Write-Host "  name: '$KeyName'" -ForegroundColor White
        Write-Host "  tmpHandle: '$actualTPMName'" -ForegroundColor Green
        Write-Host "  inTPM: true" -ForegroundColor White
        Write-Host "  provider: '$actualProvider'" -ForegroundColor White
        Write-Host "  certificateRequest: [CSR CONTENT]" -ForegroundColor White
        Write-Host ""
        
        Write-Host "CSR Preview:" -ForegroundColor Cyan
        Write-Host $pemCSR.Substring(0, [Math]::Min(200, $pemCSR.Length)) -ForegroundColor Gray
        if ($pemCSR.Length -gt 200) {
            Write-Host "... [truncated]" -ForegroundColor Gray
        }
        Write-Host ""
        
        $result | ConvertTo-Json -Compress
    } else {
        # Return key info even if CSR failed
        $result = @{
            Success = $true  # Key creation succeeded
            KeyName = $KeyName
            Handle = $actualTPMName
            Algorithm = "ES256"
            Provider = $actualProvider
            PublicKey = $publicBase64
            InTPM = $true
            CSR = $null
            CSRError = "CertificateRequest class not available - requires newer .NET version"
            Created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        
        Write-Host ""
        Write-Host "Key created successfully, but CSR generation requires .NET Framework 4.7.1+" -ForegroundColor Yellow
        Write-Host "The key can still be used - CSR generation can be implemented differently" -ForegroundColor Yellow
        
        $result | ConvertTo-Json -Compress
    }
    
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