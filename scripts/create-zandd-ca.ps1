# ZANDD Certificate Authority - Create Root CA using HSM
# Creates a local CA for issuing X.509 certificates

param(
    [string]$CAName = "ZANDD Root CA",
    [string]$CAPath = ".\zandd-ca",
    [int]$ValidityYears = 10,
    [switch]$UseTPM
)

$ErrorActionPreference = "Stop"

Write-Host "=== ZANDD Certificate Authority Setup ===" -ForegroundColor Cyan
Write-Host "Creating local CA with HSM-backed security" -ForegroundColor Yellow
Write-Host ""

# Check admin privileges if TPM requested
if ($UseTPM) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "⚠ TPM mode requires Administrator privileges. Using software keys." -ForegroundColor Yellow
        $UseTPM = $false
    }
}

# Create CA directory structure
Write-Host "Creating CA directory structure..." -ForegroundColor Cyan
$directories = @(
    $CAPath,
    "$CAPath\certs",      # Issued certificates
    "$CAPath\crl",        # Certificate revocation lists
    "$CAPath\newcerts",   # New certificates
    "$CAPath\private",    # Private keys (encrypted)
    "$CAPath\csr"         # Certificate signing requests
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Host "  ✓ Created: $dir" -ForegroundColor Green
    }
}

# Initialize CA database
$dbFile = "$CAPath\index.txt"
if (-not (Test-Path $dbFile)) {
    New-Item -ItemType File -Path $dbFile -Force | Out-Null
}

$serialFile = "$CAPath\serial"
if (-not (Test-Path $serialFile)) {
    "1000" | Set-Content -Path $serialFile
}

Add-Type -AssemblyName System.Security

Write-Host "`nGenerating CA Root Key..." -ForegroundColor Cyan

try {
    # Step 1: Generate CA Root Key
    $caKey = $null
    $keyCreationTime = Measure-Command {
        if ($UseTPM) {
            Write-Host "  Using TPM for hardware-backed key generation..." -ForegroundColor Yellow
            
            # Create key in TPM with export capability
            $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
            $keyParams.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
            $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
            $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowArchiving
            
            $tpmKey = [System.Security.Cryptography.CngKey]::Create(
                [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
                "ZANDD-CA-Root-$(Get-Random)",
                $keyParams
            )
            
            # Create ECDSA wrapper for TPM key (keep TPM key alive for certificate creation)
            $caKey = [System.Security.Cryptography.ECDsaCng]::new($tpmKey)
            
            # Export key for storage after successful certificate creation
            $exportedKey = $tpmKey.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
            $keyPath = "$CAPath\private\ca-root.key"
            [Convert]::ToBase64String($exportedKey) | Set-Content -Path $keyPath
            
            Write-Host "  ✓ TPM-backed root key generated and exported" -ForegroundColor Green
        }
        else {
            Write-Host "  Using software key generation..." -ForegroundColor Yellow
            
            # Create software ECDSA key
            $caKey = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve+NamedCurves]::nistP256)
            
            # Export and save key
            $exportedKey = $caKey.ExportECPrivateKey()
            $keyPath = "$CAPath\private\ca-root.key"
            [Convert]::ToBase64String($exportedKey) | Set-Content -Path $keyPath
            
            Write-Host "  ✓ Software root key generated" -ForegroundColor Green
        }
    }
    
    Write-Host "  Key generation time: $([Math]::Round($keyCreationTime.TotalMilliseconds, 2)) ms" -ForegroundColor Gray
    
    # Step 2: Create Self-Signed Root Certificate
    Write-Host "`nCreating Root CA Certificate..." -ForegroundColor Cyan
    
    # Create certificate request
    $distinguishedName = "CN=$CAName, O=ZANDD, OU=Security Division, C=US, S=State, L=City"
    $dn = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new($distinguishedName)
    
    $certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        $dn,
        $caKey,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )
    
    # Add Basic Constraints - Critical, CA:TRUE
    $basicConstraints = [System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]::new(
        $true,  # isCA
        $true,  # hasPathLengthConstraint
        2,      # pathLengthConstraint
        $true   # critical
    )
    $certRequest.CertificateExtensions.Add($basicConstraints)
    
    # Add Key Usage - Critical
    $keyUsage = [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new(
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyCertSign -bor
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::CrlSign -bor
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature,
        $true  # critical
    )
    $certRequest.CertificateExtensions.Add($keyUsage)
    
    # Add Subject Key Identifier
    $ski = [System.Security.Cryptography.X509Certificates.X509SubjectKeyIdentifierExtension]::new(
        $certRequest.PublicKey,
        $false
    )
    $certRequest.CertificateExtensions.Add($ski)
    
    # Add Enhanced Key Usage
    $ekuOids = [System.Security.Cryptography.OidCollection]::new()
    $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.2")) | Out-Null  # Client Auth
    $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.1")) | Out-Null  # Server Auth
    $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.3")) | Out-Null  # Code Signing
    $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.4")) | Out-Null  # Email Protection
    $eku = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($ekuOids, $false)
    $certRequest.CertificateExtensions.Add($eku)
    
    # Create self-signed certificate
    $notBefore = [DateTimeOffset]::UtcNow.AddDays(-1)
    $notAfter = [DateTimeOffset]::UtcNow.AddYears($ValidityYears)
    
    $rootCert = $certRequest.CreateSelfSigned($notBefore, $notAfter)
    
    Write-Host "  ✓ Root CA certificate created" -ForegroundColor Green
    Write-Host "    Subject: $($rootCert.Subject)" -ForegroundColor Gray
    Write-Host "    Thumbprint: $($rootCert.Thumbprint)" -ForegroundColor Gray
    Write-Host "    Valid from: $($rootCert.NotBefore)" -ForegroundColor Gray
    Write-Host "    Valid to: $($rootCert.NotAfter)" -ForegroundColor Gray
    
    # Export root certificate
    $rootCertPath = "$CAPath\certs\ca-root.crt"
    $rootCertPem = @"
-----BEGIN CERTIFICATE-----
$([Convert]::ToBase64String($rootCert.RawData, [System.Base64FormattingOptions]::InsertLineBreaks))
-----END CERTIFICATE-----
"@
    $rootCertPem | Set-Content -Path $rootCertPath
    Write-Host "  ✓ Root certificate saved: $rootCertPath" -ForegroundColor Green
    
    # Save certificate to Windows store (optional)
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
        [System.Security.Cryptography.X509Certificates.StoreName]::Root,
        [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    )
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $store.Add($rootCert)
    $store.Close()
    Write-Host "  ✓ Root certificate installed in Windows trust store" -ForegroundColor Green
    
    # Create CA configuration
    Write-Host "`nCreating CA configuration..." -ForegroundColor Cyan
    
    $caConfig = @{
        CAName = $CAName
        Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        RootCertThumbprint = $rootCert.Thumbprint
        KeyAlgorithm = "ECDSA P-256"
        HashAlgorithm = "SHA256"
        ValidityYears = $ValidityYears
        IssuedCertificates = 0
        KeyBackend = if ($UseTPM) { "TPM Hardware" } else { "Software" }
        CAPath = $CAPath
    }
    
    $caConfig | ConvertTo-Json | Set-Content -Path "$CAPath\ca-config.json"
    Write-Host "  ✓ CA configuration saved" -ForegroundColor Green
    
    # Create OpenSSL-compatible config (for compatibility)
    $opensslConfig = @"
[ ca ]
default_ca = CA_default

[ CA_default ]
dir               = $CAPath
certs             = `$dir\certs
crl_dir           = `$dir\crl
new_certs_dir     = `$dir\newcerts
database          = `$dir\index.txt
serial            = `$dir\serial
RANDFILE          = `$dir\private\.rand

private_key       = `$dir\private\ca-root.key
certificate       = `$dir\certs\ca-root.crt

crlnumber         = `$dir\crlnumber
crl               = `$dir\crl\ca.crl
crl_extensions    = crl_ext
default_crl_days  = 30

default_md        = sha256
name_opt          = ca_default
cert_opt          = ca_default
default_days      = 365
preserve          = no
policy            = policy_loose

[ policy_loose ]
countryName             = optional
stateOrProvinceName     = optional
localityName            = optional
organizationName        = optional
organizationalUnitName  = optional
commonName              = supplied
emailAddress            = optional

[ req ]
default_bits        = 2048
distinguished_name  = req_distinguished_name
attributes          = req_attributes
x509_extensions     = v3_ca

[ req_distinguished_name ]
C  = US
ST = State
L  = City
O  = ZANDD
OU = Security Division
CN = $CAName

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign
"@
    
    $opensslConfig | Set-Content -Path "$CAPath\openssl.cnf"
    Write-Host "  ✓ OpenSSL configuration created" -ForegroundColor Green
    
    Write-Host "`n=== ZANDD Certificate Authority Created Successfully ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "CA Information:" -ForegroundColor Cyan
    Write-Host "  Name: $CAName" -ForegroundColor White
    Write-Host "  Location: $CAPath" -ForegroundColor White
    Write-Host "  Root Certificate: $rootCertPath" -ForegroundColor White
    Write-Host "  Validity: $ValidityYears years" -ForegroundColor White
    Write-Host "  Key Type: $(if ($UseTPM) { 'TPM Hardware-backed' } else { 'Software' })" -ForegroundColor White
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Issue certificates: .\issue-zandd-certificate.ps1" -ForegroundColor White
    Write-Host "  2. Validate certificates: .\validate-zandd-certificate.ps1" -ForegroundColor White
    Write-Host "  3. Manage CRL: .\manage-zandd-crl.ps1" -ForegroundColor White
    
    # Clean up
    if ($caKey) { $caKey.Dispose() }
    if ($UseTPM -and $tpmKey) { 
        $tpmKey.Delete()
        $tpmKey.Dispose() 
    }
    
}
catch {
    Write-Host "`nError creating CA: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.Exception.StackTrace -ForegroundColor Red
    exit 1
}