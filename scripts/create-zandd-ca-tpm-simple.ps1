# ZANDD Certificate Authority - Simple TPM-Backed CA
# Creates a CA with keys stored directly in TPM hardware

param(
    [string]$CAName = "ZANDD Root CA",
    [string]$CAPath = ".\zandd-ca",
    [int]$ValidityYears = 10
)

$ErrorActionPreference = "Stop"

Write-Host "=== ZANDD TPM-Backed Certificate Authority ===" -ForegroundColor Cyan
Write-Host "Creating CA with TPM hardware-backed root key" -ForegroundColor Yellow
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Administrator privileges required for TPM operations!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Administrator privileges confirmed" -ForegroundColor Green

# Create CA directory structure
Write-Host "`nCreating CA directory structure..." -ForegroundColor Cyan
$directories = @(
    $CAPath,
    "$CAPath\certs",
    "$CAPath\crl", 
    "$CAPath\newcerts",
    "$CAPath\private",
    "$CAPath\csr"
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

try {
    Write-Host "`nCreating TPM-backed root key..." -ForegroundColor Cyan
    
    # Step 1: Create hardware TPM key
    $keyName = "ZANDD-CA-Root-$(Get-Random -Minimum 1000 -Maximum 9999)"
    Write-Host "  Creating TPM key: $keyName" -ForegroundColor Yellow
    
    $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $keyParams.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
    $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowArchiving
    
    $tpmKey = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $keyName,
        $keyParams
    )
    
    Write-Host "  ✓ TPM key created successfully" -ForegroundColor Green
    Write-Host "    Key Name: $($tpmKey.KeyName)" -ForegroundColor Gray
    Write-Host "    Key Path: $($tpmKey.UniqueName)" -ForegroundColor Gray
    
    # Export for backup (optional)
    try {
        $exportedKey = $tpmKey.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
        $keyPath = "$CAPath\private\ca-root-tpm-backup.key"
        [Convert]::ToBase64String($exportedKey) | Set-Content -Path $keyPath
        Write-Host "  ✓ TPM key backup saved" -ForegroundColor Green
    } catch {
        Write-Host "  ⚠ Could not create backup: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Save key information
    $keyInfo = @{
        KeyName = $tpmKey.KeyName
        KeyPath = $tpmKey.UniqueName
        Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Provider = "Microsoft Platform Crypto Provider"
        Algorithm = "ECDSA P-256"
    }
    
    $keyInfoPath = "$CAPath\private\tpm-key-info.json"
    $keyInfo | ConvertTo-Json | Set-Content -Path $keyInfoPath
    Write-Host "  ✓ TPM key information saved" -ForegroundColor Green
    
    Write-Host "`nCreating CA certificate using TPM key..." -ForegroundColor Cyan
    
    # Step 2: Try different approaches for certificate creation
    $certificateCreated = $false
    $rootCert = $null
    
    # Approach 1: Direct CertificateRequest (most likely to work)
    Write-Host "  Attempting direct certificate creation with TPM key..." -ForegroundColor Yellow
    
    try {
        # Create ECDSA from TPM key
        $tpmEcdsa = [System.Security.Cryptography.ECDsaCng]::new($tpmKey)
        
        # Create certificate request
        $distinguishedName = "CN=$CAName, O=ZANDD, OU=Security Division, C=US, S=State, L=City"
        $dn = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new($distinguishedName)
        
        $certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            $dn,
            $tmpEcdsa,
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
        $certificateCreated = $true
        
        Write-Host "  ✓ Direct TPM certificate creation successful!" -ForegroundColor Green
        
        # Clean up ECDSA wrapper but keep TPM key
        $tpmEcdsa.Dispose()
        
    } catch {
        Write-Host "  ✗ Direct approach failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  → Trying alternative approach..." -ForegroundColor Yellow
    }
    
    # Approach 2: Use certreq if direct approach failed
    if (-not $certificateCreated) {
        Write-Host "  Attempting certificate creation with certreq..." -ForegroundColor Yellow
        
        try {
            # Create certificate request file
            $certReqContent = @"
[Version]
Signature = "`$Windows NT`$"

[NewRequest]
Subject = "CN=$CAName, O=ZANDD, OU=Security Division, C=US, S=State, L=City"
KeyAlgorithm = ECDSA_P256
KeyContainer = "$($tpmKey.KeyName)"
ProviderName = "Microsoft Platform Crypto Provider"
MachineKeySet = true
SMIME = false
RequestType = Cert

[Extensions]
2.5.29.19 = "{critical}{text}ca=true&pathlength=2"
2.5.29.15 = "{critical}{hex}06"
2.5.29.37 = "{text}1.3.6.1.5.5.7.3.1,1.3.6.1.5.5.7.3.2,1.3.6.1.5.5.7.3.3,1.3.6.1.5.5.7.3.4"
"@

            $tempReqFile = [System.IO.Path]::GetTempFileName() + ".inf"
            $tempCertFile = [System.IO.Path]::GetTempFileName() + ".cer"
            
            $certReqContent | Set-Content -Path $tempReqFile -Encoding ASCII
            
            # Create certificate using certreq
            $certReqProcess = Start-Process -FilePath "certreq" -ArgumentList @("-new", "-f", $tempReqFile, $tempCertFile) -Wait -PassThru -NoNewWindow
            
            if ($certReqProcess.ExitCode -eq 0 -and (Test-Path $tempCertFile)) {
                $certBytes = [System.IO.File]::ReadAllBytes($tempCertFile)
                $rootCert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certBytes)
                $certificateCreated = $true
                
                Write-Host "  ✓ CertReq approach successful!" -ForegroundColor Green
            } else {
                Write-Host "  ✗ CertReq failed with exit code: $($certReqProcess.ExitCode)" -ForegroundColor Red
            }
            
            # Cleanup temp files
            Remove-Item $tempReqFile -ErrorAction SilentlyContinue
            Remove-Item $tempCertFile -ErrorAction SilentlyContinue
            
        } catch {
            Write-Host "  ✗ CertReq approach failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    if (-not $certificateCreated -or -not $rootCert) {
        throw "Failed to create certificate with TPM key using any available method"
    }
    
    Write-Host "`n  ✓ TPM-backed CA certificate created successfully!" -ForegroundColor Green
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
    Write-Host "    Certificate saved: $rootCertPath" -ForegroundColor Gray
    
    # Install in Windows trust store
    try {
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
        )
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $store.Add($rootCert)
        $store.Close()
        Write-Host "    Certificate installed in trust store" -ForegroundColor Gray
    }
    catch {
        Write-Host "    ⚠ Could not install in trust store: $($_.Exception.Message)" -ForegroundColor Yellow
    }
    
    # Create CA configuration
    Write-Host "`nCreating TPM CA configuration..." -ForegroundColor Cyan
    
    $caConfig = @{
        CAName = $CAName
        Created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        RootCertThumbprint = $rootCert.Thumbprint
        KeyAlgorithm = "ECDSA P-256"
        HashAlgorithm = "SHA256"
        ValidityYears = $ValidityYears
        IssuedCertificates = 0
        KeyBackend = "TPM Hardware"
        TPMKeyName = $tpmKey.KeyName
        TPMKeyPath = $tpmKey.UniqueName
        CAPath = $CAPath
    }
    
    $caConfig | ConvertTo-Json | Set-Content -Path "$CAPath\ca-config.json"
    Write-Host "  ✓ TPM CA configuration saved" -ForegroundColor Green
    
    # Create OpenSSL-compatible config
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

private_key       = `$dir\private\tpm-key-info.json
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
"@
    
    $opensslConfig | Set-Content -Path "$CAPath\openssl.cnf"
    Write-Host "  ✓ OpenSSL configuration created" -ForegroundColor Green
    
    Write-Host "`n=== TPM-Backed ZANDD Certificate Authority Created Successfully ====" -ForegroundColor Green
    Write-Host ""
    Write-Host "CA Information:" -ForegroundColor Cyan
    Write-Host "  Name: $CAName" -ForegroundColor White
    Write-Host "  Location: $CAPath" -ForegroundColor White
    Write-Host "  Root Certificate: $rootCertPath" -ForegroundColor White
    Write-Host "  Validity: $ValidityYears years" -ForegroundColor White
    Write-Host ""
    Write-Host "TPM Security Features:" -ForegroundColor Cyan
    Write-Host "  ✓ Private key stored in TPM hardware" -ForegroundColor Green
    Write-Host "  ✓ Hardware-backed certificate signing" -ForegroundColor Green
    Write-Host "  ✓ Microsoft Platform Crypto Provider" -ForegroundColor Green
    Write-Host "  ✓ TPM Key Name: $($tpmKey.KeyName)" -ForegroundColor Green
    Write-Host "  ✓ Hardware Root of Trust established" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Issue certificates: .\issue-zandd-certificate.ps1" -ForegroundColor White
    Write-Host "  2. Validate certificates: .\validate-zandd-certificate.ps1" -ForegroundColor White
    Write-Host "  3. View TPM keys: tpm.msc or Get-TpmKeyData PowerShell" -ForegroundColor White
    
    # Keep TPM key active - do not dispose
    Write-Host "`n⚠ TPM key remains active for certificate operations" -ForegroundColor Yellow
    
}
catch {
    Write-Host "`nError creating TPM-backed CA: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.InnerException) {
        Write-Host "Inner Exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
    }
    
    # Clean up on error
    if ($tpmKey) {
        try {
            $tpmKey.Delete()
            $tpmKey.Dispose()
        } catch {
            Write-Host "Could not clean up TPM key: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    exit 1
}