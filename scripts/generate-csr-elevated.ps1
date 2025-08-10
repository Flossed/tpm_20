# Generate CSR with Automatic Elevation
param(
    [Parameter(Mandatory=$true)]
    [string]$TPMPath,
    [Parameter(Mandatory=$true)]
    [string]$CommonName,
    [string]$Organization = "TPM20 Organization",
    [string]$Country = "US"
)

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "Not running as Administrator, attempting to elevate..." -ForegroundColor Yellow
    
    # Self-elevate the script
    $arguments = "-ExecutionPolicy Bypass -File `"$PSCommandPath`" -TPMPath `"$TPMPath`" -CommonName `"$CommonName`" -Organization `"$Organization`" -Country `"$Country`""
    
    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $arguments -Wait -WindowStyle Hidden
        exit 0
    } catch {
        # If elevation fails, output error and exit
        $result = @{
            Success = $false
            Error = "Failed to elevate privileges: $($_.Exception.Message)"
        }
        $result | ConvertTo-Json -Compress
        exit 1
    }
}

# At this point, we should be running as Administrator
Add-Type -AssemblyName System.Security

try {
    Write-Host "=== GENERATE CSR WITH ELEVATION ===" -ForegroundColor Cyan
    Write-Host "Running as Administrator: $isAdmin" -ForegroundColor Green
    Write-Host "Generating CSR for TPM key path:" -ForegroundColor White
    Write-Host "$TPMPath" -ForegroundColor Yellow
    
    # Step 1: Open the existing hardware TPM key
    Write-Host "`nOpening hardware TPM key..." -ForegroundColor Cyan
    
    $provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    if ([string]::IsNullOrEmpty($provider.Provider)) {
        throw "Microsoft Platform Crypto Provider still not available even with elevation"
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
    
    Write-Host "SUCCESS: CSR generated with elevation!" -ForegroundColor Green
    
    # Clean up resources
    $ecdsa.Dispose()
    $key.Dispose()
    
    # Return result
    $result = @{
        Success = $true
        CSR = $pemCSR
        Subject = $subject
        TPMPath = $TPMPath
        Method = "Elevated Pure .NET CertificateRequest"
        RunAsAdmin = $isAdmin
    }
    
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
        RunAsAdmin = $isAdmin
    }
    
    $result | ConvertTo-Json -Compress
    exit 1
}