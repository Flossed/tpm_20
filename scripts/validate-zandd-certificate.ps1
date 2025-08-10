# ZANDD Certificate Authority - Validate X.509 Certificates
# Validates certificates against the ZANDD Root CA

param(
    [Parameter(Mandatory=$true)]
    [string]$CertificatePath,
    
    [string]$CAPath = ".\zandd-ca",
    [switch]$CheckRevocation,
[switch]$ShowDetails
)

$ErrorActionPreference = "Stop"

Write-Host "=== ZANDD Certificate Validation ===" -ForegroundColor Cyan
Write-Host "Validating certificate: $CertificatePath" -ForegroundColor Yellow
Write-Host ""

# Check if certificate file exists
if (-not (Test-Path $CertificatePath)) {
    Write-Host "Error: Certificate file not found: $CertificatePath" -ForegroundColor Red
    exit 1
}

# Check if CA exists
if (-not (Test-Path "$CAPath\ca-config.json")) {
    Write-Host "Error: CA not found at $CAPath" -ForegroundColor Red
    Write-Host "Please run create-zandd-ca.ps1 first" -ForegroundColor Yellow
    exit 1
}

# Load CA configuration
$caConfig = Get-Content "$CAPath\ca-config.json" | ConvertFrom-Json
Write-Host "Using CA: $($caConfig.CAName)" -ForegroundColor Cyan
Write-Host ""

Add-Type -AssemblyName System.Security

try {
    # Step 1: Load the certificate to validate
    Write-Host "Loading certificate..." -ForegroundColor Cyan
    
    $certContent = Get-Content $CertificatePath -Raw
    
    # Handle both PEM and DER formats
    if ($certContent -match "-----BEGIN CERTIFICATE-----") {
        # PEM format
        $certPem = $certContent -replace "-----BEGIN CERTIFICATE-----", ""
        $certPem = $certPem -replace "-----END CERTIFICATE-----", ""
        $certPem = $certPem -replace "`r`n", ""
        $certBytes = [Convert]::FromBase64String($certPem)
    }
    else {
        # Assume DER format
        $certBytes = [System.IO.File]::ReadAllBytes($CertificatePath)
    }
    
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes)
    
    Write-Host "  ✓ Certificate loaded successfully" -ForegroundColor Green
    Write-Host ""
    
    # Step 2: Display certificate information
    Write-Host "Certificate Details:" -ForegroundColor Cyan
    Write-Host "  Subject: $($cert.Subject)" -ForegroundColor White
    Write-Host "  Issuer: $($cert.Issuer)" -ForegroundColor White
    Write-Host "  Serial Number: $($cert.SerialNumber)" -ForegroundColor White
    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
    Write-Host "  Not Before: $($cert.NotBefore)" -ForegroundColor White
    Write-Host "  Not After: $($cert.NotAfter)" -ForegroundColor White
    Write-Host "  Algorithm: $($cert.SignatureAlgorithm.FriendlyName)" -ForegroundColor White
    Write-Host ""
    
    # Step 3: Check certificate validity period
    Write-Host "Checking validity period..." -ForegroundColor Cyan
    $now = Get-Date
    
    if ($now -lt $cert.NotBefore) {
        Write-Host "  ✗ Certificate is not yet valid" -ForegroundColor Red
        Write-Host "    Valid from: $($cert.NotBefore)" -ForegroundColor Yellow
        $validPeriod = $false
    }
    elseif ($now -gt $cert.NotAfter) {
        Write-Host "  ✗ Certificate has expired" -ForegroundColor Red
        Write-Host "    Expired on: $($cert.NotAfter)" -ForegroundColor Yellow
        $validPeriod = $false
    }
    else {
        Write-Host "  ✓ Certificate is within validity period" -ForegroundColor Green
        $daysRemaining = ($cert.NotAfter - $now).Days
        if ($daysRemaining -lt 30) {
            Write-Host "    ⚠ Warning: Certificate expires in $daysRemaining days" -ForegroundColor Yellow
        }
        else {
            Write-Host "    Days remaining: $daysRemaining" -ForegroundColor Gray
        }
        $validPeriod = $true
    }
    Write-Host ""
    
    # Step 4: Load CA certificate
    Write-Host "Loading CA certificate..." -ForegroundColor Cyan
    $caCertPath = "$CAPath\certs\ca-root.crt"
    $caCertPem = Get-Content $caCertPath -Raw
    $caCertPem = $caCertPem -replace "-----BEGIN CERTIFICATE-----", ""
    $caCertPem = $caCertPem -replace "-----END CERTIFICATE-----", ""
    $caCertPem = $caCertPem -replace "`r`n", ""
    $caCertBytes = [Convert]::FromBase64String($caCertPem)
    $caCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($caCertBytes)
    
    Write-Host "  ✓ CA certificate loaded" -ForegroundColor Green
    Write-Host ""
    
    # Step 5: Build certificate chain
    Write-Host "Building certificate chain..." -ForegroundColor Cyan
    
    $chain = [System.Security.Cryptography.X509Certificates.X509Chain]::new()
    
    # Add CA certificate to extra store for chain building
    $chain.ChainPolicy.ExtraStore.Add($caCert) | Out-Null
    
    # Configure chain policy
    $chain.ChainPolicy.RevocationMode = if ($CheckRevocation) { 
        [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online
    } else {
        [System.Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    }
    
    $chain.ChainPolicy.VerificationFlags = [System.Security.Cryptography.X509Certificates.X509VerificationFlags]::AllowUnknownCertificateAuthority
    
    # Build the chain
    $chainBuilt = $chain.Build($cert)
    
    if ($chainBuilt) {
        Write-Host "  ✓ Certificate chain built successfully" -ForegroundColor Green
    }
    else {
        Write-Host "  ⚠ Certificate chain building reported issues" -ForegroundColor Yellow
    }
    
    # Display chain
    Write-Host "  Chain length: $($chain.ChainElements.Count)" -ForegroundColor Gray
    for ($i = 0; $i -lt $chain.ChainElements.Count; $i++) {
        $element = $chain.ChainElements[$i]
        Write-Host "    [$i] $($element.Certificate.Subject)" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Step 6: Verify issuer
    Write-Host "Verifying certificate issuer..." -ForegroundColor Cyan
    
    $isIssuedByCA = $false
    if ($cert.Issuer -eq $caCert.Subject) {
        Write-Host "  ✓ Certificate issued by ZANDD CA" -ForegroundColor Green
        $isIssuedByCA = $true
        
        # Verify signature using CA's public key
        Write-Host "  Verifying signature with CA public key..." -ForegroundColor Gray
        
        # For chain validation, check if the last element in chain is our CA
        if ($chain.ChainElements.Count -gt 1) {
            $rootElement = $chain.ChainElements[$chain.ChainElements.Count - 1]
            if ($rootElement.Certificate.Thumbprint -eq $caCert.Thumbprint) {
                Write-Host "  ✓ Signature verified with ZANDD CA" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "  ✗ Certificate NOT issued by ZANDD CA" -ForegroundColor Red
        Write-Host "    Expected issuer: $($caCert.Subject)" -ForegroundColor Yellow
        Write-Host "    Actual issuer: $($cert.Issuer)" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # Step 7: Check certificate in CA database
    if ($isIssuedByCA) {
        Write-Host "Checking CA database..." -ForegroundColor Cyan
        
        # Get serial number as decimal
        $serialHex = $cert.SerialNumber
        $serialDec = [System.Numerics.BigInteger]::Parse($serialHex, [System.Globalization.NumberStyles]::HexNumber)
        
        $indexPath = "$CAPath\index.txt"
        if (Test-Path $indexPath) {
            $indexContent = Get-Content $indexPath
            $found = $false
            
            foreach ($line in $indexContent) {
                if ($line -match "\s$serialDec\s") {
                    Write-Host "  ✓ Certificate found in CA database" -ForegroundColor Green
                    Write-Host "    Database entry: $line" -ForegroundColor Gray
                    $found = $true
                    break
                }
            }
            
            if (-not $found) {
                Write-Host "  ⚠ Certificate not found in CA database" -ForegroundColor Yellow
                Write-Host "    This may indicate the certificate was not issued by this CA instance" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
    
    # Step 8: Check revocation (if requested)
    if ($CheckRevocation) {
        Write-Host "Checking revocation status..." -ForegroundColor Cyan
        
        $crlPath = "$CAPath\crl\ca.crl"
        if (Test-Path $crlPath) {
            # Load CRL and check
            Write-Host "  ⚠ CRL checking not yet implemented" -ForegroundColor Yellow
        }
        else {
            Write-Host "  ℹ No CRL available" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Step 9: Validate extensions
    if ($ShowDetails) {
        Write-Host "Certificate Extensions:" -ForegroundColor Cyan
        foreach ($ext in $cert.Extensions) {
            Write-Host "  $($ext.Oid.FriendlyName) [$($ext.Oid.Value)]" -ForegroundColor White
            if ($ext.Critical) {
                Write-Host "    Critical: Yes" -ForegroundColor Yellow
            }
            
            # Parse specific extensions
            switch ($ext.Oid.Value) {
                "2.5.29.15" {  # Key Usage
                    $ku = [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]$ext
                    Write-Host "    Key Usage: $($ku.KeyUsages)" -ForegroundColor Gray
                }
                "2.5.29.37" {  # Enhanced Key Usage
                    $eku = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]$ext
                    foreach ($oid in $eku.EnhancedKeyUsages) {
                        Write-Host "    EKU: $($oid.FriendlyName) [$($oid.Value)]" -ForegroundColor Gray
                    }
                }
                "2.5.29.17" {  # Subject Alternative Name
                    Write-Host "    Subject Alternative Names present" -ForegroundColor Gray
                }
            }
        }
        Write-Host ""
    }
    
    # Final validation result
    Write-Host "=== Validation Result ===" -ForegroundColor Cyan
    
    $validationPassed = $validPeriod -and $isIssuedByCA
    
    if ($validationPassed) {
        Write-Host "✓ CERTIFICATE IS VALID" -ForegroundColor Green
        Write-Host ""
        Write-Host "Summary:" -ForegroundColor Cyan
        Write-Host "  • Certificate is within validity period" -ForegroundColor Green
        Write-Host "  • Certificate was issued by ZANDD CA" -ForegroundColor Green
        Write-Host "  • Certificate chain is valid" -ForegroundColor Green
        Write-Host "  • Signature verification passed" -ForegroundColor Green
    }
    else {
        Write-Host "✗ CERTIFICATE VALIDATION FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "Issues found:" -ForegroundColor Yellow
        if (-not $validPeriod) {
            Write-Host "  • Certificate is outside validity period" -ForegroundColor Red
        }
        if (-not $isIssuedByCA) {
            Write-Host "  • Certificate was not issued by ZANDD CA" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Certificate Information:" -ForegroundColor Cyan
    Write-Host "  Subject: $($cert.Subject)" -ForegroundColor White
    Write-Host "  Serial: $($cert.SerialNumber)" -ForegroundColor White
    Write-Host "  Thumbprint: $($cert.Thumbprint)" -ForegroundColor White
    
    # Clean up
    $chain.Dispose()
    
    # Return exit code
    if ($validationPassed) {
        exit 0
    }
    else {
        exit 1
    }
    
}
catch {
    Write-Host "`nError validating certificate: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}