# TPM Diagnostics Script
# This script gathers comprehensive information about the TPM hardware

Write-Host "=" * 80
Write-Host "TPM DIAGNOSTICS REPORT" -ForegroundColor Cyan
Write-Host "=" * 80
Write-Host ""

# 1. Basic TPM Information
Write-Host "1. BASIC TPM INFORMATION" -ForegroundColor Yellow
Write-Host "-" * 40
try {
    $tpm = Get-Tpm
    Write-Host "TPM Present: $($tpm.TmpPresent)" -ForegroundColor Green
    Write-Host "TPM Ready: $($tpm.TmpReady)" -ForegroundColor Green
    Write-Host "TPM Enabled: $($tpm.TmpEnabled)" -ForegroundColor Green
    Write-Host "TPM Activated: $($tpm.TmpActivated)" -ForegroundColor Green
    Write-Host "TPM Owned: $($tpm.TmpOwned)" -ForegroundColor Green
    Write-Host "Manufacturer ID: $($tpm.ManufacturerId)" -ForegroundColor Green
    Write-Host "Manufacturer Version: $($tpm.ManufacturerVersion)" -ForegroundColor Green
    Write-Host "TPM Version: $($tmp.SpecVersion)" -ForegroundColor Green
}
catch {
    Write-Host "Error getting TPM info: $_" -ForegroundColor Red
}
Write-Host ""

# 2. Test Key Creation Capabilities
Write-Host "2. KEY CREATION TEST" -ForegroundColor Yellow
Write-Host "-" * 40

# Test RSA with Platform Provider
Write-Host "Testing RSA key with Platform Provider..." -ForegroundColor Cyan
$supportsRSA = $false
try {
    $testCert = New-SelfSignedCertificate -Subject "CN=TPM_RSA_TEST" -KeyAlgorithm RSA -KeyLength 2048 -Provider "Microsoft Platform Crypto Provider" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy NonExportable
    
    if ($testCert) {
        Write-Host "  SUCCESS: RSA key created with TPM" -ForegroundColor Green
        Write-Host "  Thumbprint: $($testCert.Thumbprint)" -ForegroundColor Gray
        $supportsRSA = $true
        # Clean up test certificate
        Remove-Item "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -Force
    }
}
catch {
    Write-Host "  FAILED: RSA with TPM - $_" -ForegroundColor Red
}

# Test ECDSA with Platform Provider
Write-Host "Testing ECDSA P256 key with Platform Provider..." -ForegroundColor Cyan
$supportsECC = $false
try {
    $testCert = New-SelfSignedCertificate -Subject "CN=TPM_ECC_TEST" -KeyAlgorithm ECDSA_nistP256 -Provider "Microsoft Platform Crypto Provider" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy NonExportable
    
    if ($testCert) {
        Write-Host "  SUCCESS: ECDSA P256 key created with TPM" -ForegroundColor Green
        Write-Host "  Thumbprint: $($testCert.Thumbprint)" -ForegroundColor Gray
        $supportsECC = $true
        # Clean up test certificate
        Remove-Item "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -Force
    }
}
catch {
    Write-Host "  FAILED: ECDSA P256 with TPM - $_" -ForegroundColor Red
}

Write-Host ""

# 3. Summary and JSON Output
Write-Host "3. SUMMARY" -ForegroundColor Yellow
Write-Host "-" * 40

if ($supportsRSA) {
    Write-Host "✓ TPM supports RSA keys" -ForegroundColor Green
}

if ($supportsECC) {
    Write-Host "✓ TPM supports ECC keys" -ForegroundColor Green
}

if (-not $supportsRSA -and -not $supportsECC) {
    Write-Host "✗ No TPM key types working" -ForegroundColor Red
}

# JSON output for application
$result = @{
    SupportsRSA = $supportsRSA
    SupportsECC = $supportsECC
    Success = $supportsRSA -or $supportsECC
}

Write-Host ""
Write-Host "JSON Result:"
$result | ConvertTo-Json -Compress