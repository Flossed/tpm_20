# ZANDD Certificate Authority - Issue X.509 Certificates
# Issues certificates signed by the ZANDD Root CA

param(
    [Parameter(Mandatory=$true)]
    [string]$CommonName,
    
    [string]$Organization = "ZANDD",
    [string]$OrganizationalUnit = "IT Department",
    [string]$Country = "US",
    [string]$State = "State",
    [string]$Locality = "City",
    [string]$EmailAddress = "",
    
    [ValidateSet("Server", "Client", "CodeSigning", "Email", "All")]
    [string]$CertificateType = "Client",
    
    [int]$ValidityDays = 365,
    [string]$CAPath = ".\zandd-ca",
    [string]$OutputPath = ".\issued-certs",
    [switch]$ExportPFX,
    [string]$PFXPassword = "changeme"
)

$ErrorActionPreference = "Stop"

Write-Host "=== ZANDD Certificate Issuance ===" -ForegroundColor Cyan
Write-Host "Issuing certificate for: $CommonName" -ForegroundColor Yellow
Write-Host ""

# Verify CA exists
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
    # Step 1: Generate key for the certificate
    Write-Host "Generating certificate key..." -ForegroundColor Cyan
    
    $certKey = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve+NamedCurves]::nistP256)
    Write-Host "  ✓ ECDSA P-256 key generated" -ForegroundColor Green
    
    # Step 2: Create certificate request
    Write-Host "`nCreating certificate request..." -ForegroundColor Cyan
    
    $distinguishedName = "CN=$CommonName, O=$Organization, OU=$OrganizationalUnit, C=$Country, S=$State, L=$Locality"
    if ($EmailAddress) {
        $distinguishedName += ", E=$EmailAddress"
    }
    
    $dn = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new($distinguishedName)
    
    $certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        $dn,
        $certKey,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )
    
    # Add extensions based on certificate type
    Write-Host "  Adding extensions for $CertificateType certificate..." -ForegroundColor Gray
    
    # Basic Constraints - Not a CA
    $basicConstraints = [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new(
        $false,  # isCA
        $false,  # hasPathLengthConstraint
        0,       # pathLengthConstraint
        $true    # critical
    )
    $certRequest.CertificateExtensions.Add($basicConstraints)
    
    # Key Usage based on type
    $keyUsageFlags = [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor
                     [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::NonRepudiation
    
    if ($CertificateType -eq "Server" -or $CertificateType -eq "All") {
        $keyUsageFlags = $keyUsageFlags -bor [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment
    }
    
    $keyUsage = [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($keyUsageFlags, $true)
    $certRequest.CertificateExtensions.Add($keyUsage)
    
    # Enhanced Key Usage
    $ekuOids = [System.Security.Cryptography.OidCollection]::new()
    
    switch ($CertificateType) {
        "Server" {
            $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.1")) | Out-Null  # Server Auth
        }
        "Client" {
            $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.2")) | Out-Null  # Client Auth
        }
        "CodeSigning" {
            $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.3")) | Out-Null  # Code Signing
        }
        "Email" {
            $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.4")) | Out-Null  # Email Protection
        }
        "All" {
            $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.1")) | Out-Null  # Server Auth
            $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.2")) | Out-Null  # Client Auth
            $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.3")) | Out-Null  # Code Signing
            $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.4")) | Out-Null  # Email Protection
        }
    }
    
    $eku = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($ekuOids, $false)
    $certRequest.CertificateExtensions.Add($eku)
    
    # Subject Alternative Names
    $sanBuilder = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
    
    if ($CertificateType -eq "Server" -or $CertificateType -eq "All") {
        $sanBuilder.AddDnsName($CommonName)
        $sanBuilder.AddDnsName("localhost")
    }
    
    if ($EmailAddress) {
        $sanBuilder.AddEmailAddress($EmailAddress)
    }
    
    $san = $sanBuilder.Build()
    $certRequest.CertificateExtensions.Add($san)
    
    # Subject Key Identifier
    $ski = [System.Security.Cryptography.X509Certificates.X509SubjectKeyIdentifierExtension]::new(
        $certRequest.PublicKey,
        $false
    )
    $certRequest.CertificateExtensions.Add($ski)
    
    Write-Host "  ✓ Certificate request created" -ForegroundColor Green
    
    # Step 3: Load CA certificate and key
    Write-Host "`nLoading CA certificate and key..." -ForegroundColor Cyan
    
    # Load CA certificate
    $caCertPath = "$CAPath\certs\ca-root.crt"
    $caCertPem = Get-Content $caCertPath -Raw
    $caCertPem = $caCertPem -replace "-----BEGIN CERTIFICATE-----", ""
    $caCertPem = $caCertPem -replace "-----END CERTIFICATE-----", ""
    $caCertPem = $caCertPem -replace "`r`n", ""
    $caCertBytes = [Convert]::FromBase64String($caCertPem)
    $caCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($caCertBytes)
    
    Write-Host "  ✓ CA certificate loaded" -ForegroundColor Green
    
    # Load CA private key
    $caKeyPath = "$CAPath\private\ca-root.key"
    $caKeyBase64 = Get-Content $caKeyPath
    $caKeyBytes = [Convert]::FromBase64String($caKeyBase64)
    
    # Create ECDSA from saved key
    $caKey = [System.Security.Cryptography.ECDsa]::Create()
    $caKey.ImportECPrivateKey($caKeyBytes, [ref]$null)
    
    Write-Host "  ✓ CA private key loaded" -ForegroundColor Green
    
    # Step 4: Sign the certificate
    Write-Host "`nSigning certificate..." -ForegroundColor Cyan
    
    # Get next serial number
    $serialPath = "$CAPath\serial"
    $serialNumber = [int](Get-Content $serialPath)
    $serialBytes = [BitConverter]::GetBytes($serialNumber)
    if ([BitConverter]::IsLittleEndian) {
        [Array]::Reverse($serialBytes)
    }
    
    # Create signed certificate
    $notBefore = [DateTimeOffset]::UtcNow.AddMinutes(-5)
    $notAfter = [DateTimeOffset]::UtcNow.AddDays($ValidityDays)
    
    # Create the certificate using CA's key
    $signedCert = $certRequest.Create(
        $caCert.SubjectName,
        [System.Security.Cryptography.X509Certificates.X509SignatureGenerator]::CreateForECDsa($caKey),
        $notBefore,
        $notAfter,
        $serialBytes
    )
    
    # Create certificate with private key using compatible approach
    $certWithKey = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($signedCert.RawData)
    
    # Export certificate and key separately (more compatible)
    $certWithKeyExportable = $signedCert
    
    Write-Host "  ✓ Certificate signed by CA" -ForegroundColor Green
    Write-Host "    Serial: $serialNumber" -ForegroundColor Gray
    Write-Host "    Thumbprint: $($certWithKey.Thumbprint)" -ForegroundColor Gray
    Write-Host "    Valid from: $($certWithKey.NotBefore)" -ForegroundColor Gray
    Write-Host "    Valid to: $($certWithKey.NotAfter)" -ForegroundColor Gray
    
    # Update serial number
    ($serialNumber + 1).ToString() | Set-Content -Path $serialPath
    
    # Update CA database
    $indexEntry = "$($certWithKey.NotAfter.ToString('yyMMddHHmmss'))Z`t$serialNumber`t`t$($certWithKey.SubjectName.Name)"
    Add-Content -Path "$CAPath\index.txt" -Value $indexEntry
    
    # Update CA config
    $caConfig.IssuedCertificates++
    $caConfig | ConvertTo-Json | Set-Content -Path "$CAPath\ca-config.json"
    
    # Step 5: Export certificate
    Write-Host "`nExporting certificate..." -ForegroundColor Cyan
    
    # Create output directory
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    $fileBaseName = $CommonName -replace '[^a-zA-Z0-9-_]', '_'
    
    # Export certificate (PEM)
    $certPath = "$OutputPath\$fileBaseName.crt"
    $certPem = @"
-----BEGIN CERTIFICATE-----
$([Convert]::ToBase64String($certWithKey.RawData, [System.Base64FormattingOptions]::InsertLineBreaks))
-----END CERTIFICATE-----
"@
    $certPem | Set-Content -Path $certPath
    Write-Host "  ✓ Certificate exported: $certPath" -ForegroundColor Green
    
    # Export private key (PEM)
    $keyPath = "$OutputPath\$fileBaseName.key"
    $privateKeyBytes = $certKey.ExportECPrivateKey()
    $keyPem = @"
-----BEGIN EC PRIVATE KEY-----
$([Convert]::ToBase64String($privateKeyBytes, [System.Base64FormattingOptions]::InsertLineBreaks))
-----END EC PRIVATE KEY-----
"@
    $keyPem | Set-Content -Path $keyPath
    Write-Host "  ✓ Private key exported: $keyPath" -ForegroundColor Green
    
    # Export PFX if requested (skip for now - requires private key association)
    if ($ExportPFX) {
        Write-Host "  ⚠ PFX export not available with current approach" -ForegroundColor Yellow
        Write-Host "    Use separate certificate (.crt) and private key (.key) files instead" -ForegroundColor Gray
    }
    
    # Copy CA certificate for chain validation
    $caCertCopyPath = "$OutputPath\ca-root.crt"
    Copy-Item -Path $caCertPath -Destination $caCertCopyPath -Force
    Write-Host "  ✓ CA certificate copied: $caCertCopyPath" -ForegroundColor Green
    
    Write-Host "`n=== Certificate Issued Successfully ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Certificate Details:" -ForegroundColor Cyan
    Write-Host "  Subject: $($certWithKey.Subject)" -ForegroundColor White
    Write-Host "  Issuer: $($certWithKey.Issuer)" -ForegroundColor White
    Write-Host "  Type: $CertificateType" -ForegroundColor White
    Write-Host "  Serial: $serialNumber" -ForegroundColor White
    Write-Host "  Thumbprint: $($certWithKey.Thumbprint)" -ForegroundColor White
    Write-Host ""
    Write-Host "Files Generated:" -ForegroundColor Cyan
    Write-Host "  Certificate: $certPath" -ForegroundColor White
    Write-Host "  Private Key: $keyPath" -ForegroundColor White
    if ($ExportPFX) {
        Write-Host "  PFX Bundle: $pfxPath" -ForegroundColor White
    }
    Write-Host "  CA Certificate: $caCertCopyPath" -ForegroundColor White
    Write-Host ""
    Write-Host "To validate this certificate, run:" -ForegroundColor Yellow
    Write-Host "  .\validate-zandd-certificate.ps1 -CertificatePath `"$certPath`"" -ForegroundColor White
    
    # Clean up
    $certKey.Dispose()
    $caKey.Dispose()
    
}
catch {
    Write-Host "`nError issuing certificate: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}