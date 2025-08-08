# TPM Test with Proper Modules
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

Write-Host "TPM Hardware Test for: $KeyName"
Write-Host "=" * 50

# Import required modules
Write-Host "Loading PowerShell modules..."
try {
    Import-Module PKI -Force
    Write-Host "PKI module loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "Warning: Could not load PKI module - $_" -ForegroundColor Yellow
}

try {
    Import-Module TrustedPlatformModule -Force
    Write-Host "TrustedPlatformModule loaded successfully" -ForegroundColor Green
}
catch {
    Write-Host "Warning: Could not load TrustedPlatformModule - $_" -ForegroundColor Yellow
}

# Check if Cert drive is available
Write-Host ""
Write-Host "Checking Certificate Store access..."
if (Get-PSDrive -Name Cert -ErrorAction SilentlyContinue) {
    Write-Host "Certificate store is accessible" -ForegroundColor Green
} else {
    Write-Host "Certificate store not accessible, trying to create..." -ForegroundColor Yellow
    try {
        New-PSDrive -Name Cert -PSProvider Certificate -Root ""
        Write-Host "Certificate drive created" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create Cert drive: $_" -ForegroundColor Red
        $result = @{
            Success = $false
            Error = "Certificate store not accessible: $_"
            InTPM = $false
        }
        Write-Output ($result | ConvertTo-Json -Compress)
        exit 1
    }
}

# Get TPM information
Write-Host ""
Write-Host "Getting TPM information..."
try {
    $tpmInfo = Get-Tpm
    Write-Host "TPM Present: $($tpmInfo.TmpPresent)" -ForegroundColor Cyan
    Write-Host "TPM Ready: $($tpmInfo.TmpReady)" -ForegroundColor Cyan
    Write-Host "TPM Enabled: $($tpmInfo.TmpEnabled)" -ForegroundColor Cyan
}
catch {
    Write-Host "Could not get TPM info: $_" -ForegroundColor Yellow
}

# Test Hardware TPM Key Creation
Write-Host ""
Write-Host "Testing Hardware TPM Key Creation..."
Write-Host "-" * 40

# Test 1: RSA with TPM
Write-Host "Test 1: RSA 2048 with Microsoft Platform Crypto Provider"
try {
    $rsaCert = New-SelfSignedCertificate `
        -Subject "CN=$KeyName-TPM-RSA" `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy NonExportable `
        -ErrorAction Stop
    
    Write-Host "✓ SUCCESS: RSA key created in hardware TPM!" -ForegroundColor Green
    Write-Host "  Thumbprint: $($rsaCert.Thumbprint)"
    Write-Host "  Subject: $($rsaCert.Subject)"
    Write-Host "  Algorithm: $($rsaCert.PublicKey.Oid.FriendlyName)"
    
    $result = @{
        Success = $true
        Provider = "Microsoft Platform Crypto Provider"
        Algorithm = "RSA"
        KeyLength = 2048
        Handle = $rsaCert.Thumbprint
        InTPM = $true
        Subject = $rsaCert.Subject
    }
    
    Write-Host ""
    Write-Host "JSON Result:"
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
}
catch {
    Write-Host "✗ FAILED: $_" -ForegroundColor Red
}

# Test 2: ECDSA P256 with TPM
Write-Host ""
Write-Host "Test 2: ECDSA P256 with Microsoft Platform Crypto Provider"
try {
    $eccCert = New-SelfSignedCertificate `
        -Subject "CN=$KeyName-TPM-ECC" `
        -KeyAlgorithm ECDSA_nistP256 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy NonExportable `
        -ErrorAction Stop
    
    Write-Host "✓ SUCCESS: ECDSA P256 key created in hardware TPM!" -ForegroundColor Green
    Write-Host "  Thumbprint: $($eccCert.Thumbprint)"
    Write-Host "  Subject: $($eccCert.Subject)"
    Write-Host "  Algorithm: $($eccCert.PublicKey.Oid.FriendlyName)"
    
    $result = @{
        Success = $true
        Provider = "Microsoft Platform Crypto Provider"
        Algorithm = "ECDSA_nistP256"
        Handle = $eccCert.Thumbprint
        InTPM = $true
        Subject = $eccCert.Subject
    }
    
    Write-Host ""
    Write-Host "JSON Result:"
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
}
catch {
    Write-Host "✗ FAILED: $_" -ForegroundColor Red
}

# Test 3: Try different approaches
Write-Host ""
Write-Host "Test 3: Alternative TPM approaches..."

# Check available cryptographic providers
Write-Host "Available providers:"
try {
    $providers = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider" | ForEach-Object { $_.PSChildName }
    $tpmProviders = $providers | Where-Object { $_ -like "*Platform*" -or $_ -like "*TPM*" }
    foreach ($provider in $tpmProviders) {
        Write-Host "  - $provider" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "Could not enumerate providers: $_" -ForegroundColor Yellow
}

# All tests failed
Write-Host ""
Write-Host "All hardware TPM tests failed." -ForegroundColor Red
Write-Host ""
Write-Host "Possible causes:" -ForegroundColor Yellow
Write-Host "  1. TPM is not enabled in BIOS/UEFI"
Write-Host "  2. TPM needs to be initialized/owned"
Write-Host "  3. Windows TPM services not running"
Write-Host "  4. TPM does not support the requested algorithms"
Write-Host "  5. Group Policy restrictions"

$result = @{
    Success = $false
    Provider = "None"
    Algorithm = "None"
    Handle = $null
    InTPM = $false
    Error = "All hardware TPM key creation attempts failed"
}

Write-Host ""
Write-Host "JSON Result:"
Write-Output ($result | ConvertTo-Json -Compress)