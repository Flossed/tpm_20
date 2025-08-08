# Simple TPM Test Script
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

Write-Host "Testing TPM Key Creation for: $KeyName"
Write-Host "=" * 50

# Test 1: Try Microsoft Platform Crypto Provider (TPM)
Write-Host "Test 1: Microsoft Platform Crypto Provider (Hardware TPM)"
try {
    $cert1 = New-SelfSignedCertificate `
        -Subject "CN=$KeyName-TPM" `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy NonExportable
    
    Write-Host "SUCCESS: Created TPM-backed RSA certificate" -ForegroundColor Green
    Write-Host "Thumbprint: $($cert1.Thumbprint)"
    
    $result = @{
        Success = $true
        Provider = "Microsoft Platform Crypto Provider"
        Algorithm = "RSA"
        Handle = $cert1.Thumbprint
        InTPM = $true
    }
    
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
}
catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
}

# Test 2: Try TPM with ECC
Write-Host ""
Write-Host "Test 2: Microsoft Platform Crypto Provider with ECC"
try {
    $cert2 = New-SelfSignedCertificate `
        -Subject "CN=$KeyName-TPM-ECC" `
        -KeyAlgorithm ECDSA_nistP256 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy NonExportable
    
    Write-Host "SUCCESS: Created TPM-backed ECC certificate" -ForegroundColor Green
    Write-Host "Thumbprint: $($cert2.Thumbprint)"
    
    $result = @{
        Success = $true
        Provider = "Microsoft Platform Crypto Provider"
        Algorithm = "ECDSA_nistP256"
        Handle = $cert2.Thumbprint
        InTPM = $true
    }
    
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
}
catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
}

# Test 3: Try with different ECC curve
Write-Host ""
Write-Host "Test 3: Microsoft Platform Crypto Provider with P384"
try {
    $cert3 = New-SelfSignedCertificate `
        -Subject "CN=$KeyName-TPM-P384" `
        -KeyAlgorithm ECDSA_nistP384 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy NonExportable
    
    Write-Host "SUCCESS: Created TPM-backed P384 certificate" -ForegroundColor Green
    Write-Host "Thumbprint: $($cert3.Thumbprint)"
    
    $result = @{
        Success = $true
        Provider = "Microsoft Platform Crypto Provider"
        Algorithm = "ECDSA_nistP384"
        Handle = $cert3.Thumbprint
        InTPM = $true
    }
    
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 0
}
catch {
    Write-Host "FAILED: $_" -ForegroundColor Red
}

# All TPM tests failed
Write-Host ""
Write-Host "All TPM tests failed. Hardware TPM may not support key creation or may need configuration." -ForegroundColor Yellow

$result = @{
    Success = $false
    Provider = "None"
    Algorithm = "None"
    Handle = $null
    InTPM = $false
    Error = "All TPM key creation methods failed"
}

Write-Output ($result | ConvertTo-Json -Compress)