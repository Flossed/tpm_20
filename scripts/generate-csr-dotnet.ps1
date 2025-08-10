# Generate CSR using Pure .NET Methods
param(
    [Parameter(Mandatory=$true)]
    [string]$TPMPath,  # The actual TPM path from database
    [Parameter(Mandatory=$true)]
    [string]$CommonName,
    [string]$Organization = "TPM20 Organization",
    [string]$Country = "US"
)

Add-Type -AssemblyName System.Security

try {
    Write-Host "=== GENERATE CSR WITH PURE .NET ===" -ForegroundColor Cyan
    Write-Host "Generating CSR for TPM key path:" -ForegroundColor White
    Write-Host "$TPMPath" -ForegroundColor Yellow
    
    # Step 1: Open the existing hardware TPM key using the exact path
    Write-Host "`nOpening hardware TPM key..." -ForegroundColor Cyan
    
    # Check if Microsoft Platform Crypto Provider is available
    $provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    if ([string]::IsNullOrEmpty($provider.Provider)) {
        throw "Microsoft Platform Crypto Provider not available - requires Administrator privileges"
    }
    Write-Host "Provider available: $($provider.Provider)" -ForegroundColor Green
    
    $key = [System.Security.Cryptography.CngKey]::Open($TPMPath, $provider)
    
    Write-Host "SUCCESS: TPM key opened" -ForegroundColor Green
    Write-Host "  Key path: $TPMPath" -ForegroundColor White
    Write-Host "  Provider: $($key.Provider.Provider)" -ForegroundColor White
    Write-Host "  Algorithm: $($key.Algorithm.Algorithm)" -ForegroundColor White
    
    # Step 2: Create ECDsa object from the CNG key
    Write-Host "`nCreating ECDsaCng object..." -ForegroundColor Cyan
    $ecdsa = [System.Security.Cryptography.ECDsaCng]::new($key)
    
    # Step 3: Build subject distinguished name
    $subject = "CN=$CommonName"
    if ($Organization) { $subject += ", O=$Organization" }
    if ($Country -and $Country.Length -eq 2) { $subject += ", C=$Country" }
    
    Write-Host "CSR subject: $subject" -ForegroundColor Cyan
    
    # Create X500DistinguishedName
    $subjectDN = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new($subject)
    
    # Step 4: Generate CSR using CertificateRequest
    Write-Host "`nGenerating CSR with CertificateRequest..." -ForegroundColor Cyan
    
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
    
    Write-Host "SUCCESS: CSR generated using pure .NET!" -ForegroundColor Green
    
    # Clean up resources
    $ecdsa.Dispose()
    $key.Dispose()
    
    # Return result
    $result = @{
        Success = $true
        CSR = $pemCSR
        Subject = $subject
        TPMPath = $TPMPath
        Method = "Pure .NET CertificateRequest"
    }
    
    Write-Host ""
    Write-Host "CSR generated successfully for hardware TPM key!" -ForegroundColor Green
    Write-Host "Subject: $subject" -ForegroundColor White
    Write-Host ""
    
    $result | ConvertTo-Json -Compress
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    
    # Try to clean up if possible
    try {
        if ($ecdsa) { $ecdsa.Dispose() }
        if ($key) { $key.Dispose() }
    } catch { }
    
    $result = @{
        Success = $false
        Error = $_.Exception.Message
        TPMPath = $TPMPath
    }
    
    $result | ConvertTo-Json -Compress
    exit 1
}