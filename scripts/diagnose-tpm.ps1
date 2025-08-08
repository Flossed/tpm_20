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
    Write-Host "TPM Present: $($tpm.TpmPresent)" -ForegroundColor Green
    Write-Host "TPM Ready: $($tpm.TpmReady)" -ForegroundColor Green
    Write-Host "TPM Enabled: $($tpm.TpmEnabled)" -ForegroundColor Green
    Write-Host "TPM Activated: $($tpm.TpmActivated)" -ForegroundColor Green
    Write-Host "TPM Owned: $($tpm.TpmOwned)" -ForegroundColor Green
    Write-Host "Manufacturer ID: $($tpm.ManufacturerId)" -ForegroundColor Green
    Write-Host "Manufacturer Version: $($tpm.ManufacturerVersion)" -ForegroundColor Green
    Write-Host "Manufacturer Version Info: $($tpm.ManufacturerVersionInfo)" -ForegroundColor Green
    Write-Host "TPM Version: $($tpm.SpecVersion)" -ForegroundColor Green
    
    # Check if TPM 2.0
    if ($tpm.ManufacturerVersion -like "*2.0*" -or $tpm.SpecVersion -like "*2.0*") {
        Write-Host "TPM Type: TPM 2.0 Detected" -ForegroundColor Green
    } else {
        Write-Host "TPM Type: TPM 1.2 or Unknown" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "Error getting TPM info: $_" -ForegroundColor Red
}
Write-Host ""

# 2. TPM WMI Information
Write-Host "2. TPM WMI INFORMATION" -ForegroundColor Yellow
Write-Host "-" * 40
try {
    $tpmWmi = Get-WmiObject -Namespace "root\cimv2\security\microsofttpm" -Class Win32_Tpm
    if ($tpmWmi) {
        Write-Host "TPM Specification Version: $($tpmWmi.SpecVersion)" -ForegroundColor Green
        Write-Host "Physical Presence Version: $($tpmWmi.PhysicalPresenceVersionInfo)" -ForegroundColor Green
        Write-Host "Is Enabled: $($tpmWmi.IsEnabled_InitialValue)" -ForegroundColor Green
        Write-Host "Is Activated: $($tpmWmi.IsActivated_InitialValue)" -ForegroundColor Green
        Write-Host "Is Owned: $($tpmWmi.IsOwned_InitialValue)" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error getting WMI TPM info: $_" -ForegroundColor Red
}
Write-Host ""

# 3. Cryptographic Providers
Write-Host "3. CRYPTOGRAPHIC PROVIDERS" -ForegroundColor Yellow
Write-Host "-" * 40
try {
    $providers = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider"
    $tpmProviders = @()
    
    foreach ($provider in $providers) {
        $name = $provider.PSChildName
        if ($name -like "*TPM*" -or $name -like "*Platform*") {
            $tpmProviders += $name
            Write-Host "Found TPM Provider: $name" -ForegroundColor Green
        }
    }
    
    if ($tpmProviders.Count -eq 0) {
        Write-Host "No TPM-specific providers found" -ForegroundColor Yellow
    }
    
    # Check for Microsoft Platform Crypto Provider
    $platformProvider = "Microsoft Platform Crypto Provider"
    $providerPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider\$platformProvider"
    if (Test-Path $providerPath) {
        Write-Host ""
        Write-Host "Microsoft Platform Crypto Provider: INSTALLED" -ForegroundColor Green
        $providerInfo = Get-ItemProperty -Path $providerPath -ErrorAction SilentlyContinue
        if ($providerInfo) {
            Write-Host "  Image Path: $($providerInfo.'Image Path')" -ForegroundColor Gray
            Write-Host "  Type: $($providerInfo.Type)" -ForegroundColor Gray
        }
    } else {
        Write-Host "Microsoft Platform Crypto Provider: NOT FOUND" -ForegroundColor Red
    }
}
catch {
    Write-Host "Error checking providers: $_" -ForegroundColor Red
}
Write-Host ""

# 4. Test Key Creation Capabilities
Write-Host "4. KEY CREATION TEST" -ForegroundColor Yellow
Write-Host "-" * 40

# Test RSA with Platform Provider
Write-Host "Testing RSA key with Platform Provider..." -ForegroundColor Cyan
try {
    $testCert = New-SelfSignedCertificate `
        -Subject "CN=TPM_RSA_TEST_$(Get-Random)" `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy NonExportable
    
    if ($testCert) {
        Write-Host "  SUCCESS: RSA key created with TPM" -ForegroundColor Green
        Write-Host "  Thumbprint: $($testCert.Thumbprint)" -ForegroundColor Gray
        # Clean up test certificate
        Remove-Item "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -Force
    }
}
catch {
    Write-Host "  FAILED: RSA with TPM - $_" -ForegroundColor Red
}

# Test ECDSA with Platform Provider
Write-Host "Testing ECDSA P256 key with Platform Provider..." -ForegroundColor Cyan
try {
    $testCert = New-SelfSignedCertificate `
        -Subject "CN=TPM_ECC_TEST_$(Get-Random)" `
        -KeyAlgorithm ECDSA_nistP256 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy NonExportable
    
    if ($testCert) {
        Write-Host "  SUCCESS: ECDSA P256 key created with TPM" -ForegroundColor Green
        Write-Host "  Thumbprint: $($testCert.Thumbprint)" -ForegroundColor Gray
        # Clean up test certificate
        Remove-Item "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -Force
    }
}
catch {
    Write-Host "  FAILED: ECDSA P256 with TPM - $_" -ForegroundColor Red
}

# Test ECDSA P384 with Platform Provider
Write-Host "Testing ECDSA P384 key with Platform Provider..." -ForegroundColor Cyan
try {
    $testCert = New-SelfSignedCertificate `
        -Subject "CN=TPM_ECC384_TEST_$(Get-Random)" `
        -KeyAlgorithm ECDSA_nistP384 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -KeyExportPolicy NonExportable
    
    if ($testCert) {
        Write-Host "  SUCCESS: ECDSA P384 key created with TPM" -ForegroundColor Green
        Write-Host "  Thumbprint: $($testCert.Thumbprint)" -ForegroundColor Gray
        # Clean up test certificate
        Remove-Item "Cert:\CurrentUser\My\$($testCert.Thumbprint)" -Force
    }
}
catch {
    Write-Host "  FAILED: ECDSA P384 with TPM - $_" -ForegroundColor Red
}

Write-Host ""

# 5. TPM PCR Banks (for TPM 2.0)
Write-Host "5. TPM PCR BANKS (TPM 2.0)" -ForegroundColor Yellow
Write-Host "-" * 40
try {
    $pcrBanks = Get-TpmEndorsementKeyInfo -ErrorAction SilentlyContinue
    if ($pcrBanks) {
        Write-Host "Endorsement Key Info available" -ForegroundColor Green
    }
}
catch {
    Write-Host "Cannot retrieve PCR banks (may not be TPM 2.0): $_" -ForegroundColor Yellow
}
Write-Host ""

# 6. Summary and Recommendations
Write-Host "6. SUMMARY AND RECOMMENDATIONS" -ForegroundColor Yellow
Write-Host "-" * 40

$recommendations = @()

if ($tpm.TpmPresent -and $tpm.TpmReady) {
    Write-Host "✓ TPM is present and ready" -ForegroundColor Green
    
    # Check which algorithms work
    $supportsRSA = $false
    $supportsECC = $false
    
    try {
        $testRSA = New-SelfSignedCertificate `
            -Subject "CN=FINAL_TEST_RSA" `
            -KeyAlgorithm RSA `
            -KeyLength 2048 `
            -Provider "Microsoft Platform Crypto Provider" `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -KeyExportPolicy NonExportable `
            -ErrorAction SilentlyContinue
        
        if ($testRSA) {
            $supportsRSA = $true
            Remove-Item "Cert:\CurrentUser\My\$($testRSA.Thumbprint)" -Force
        }
    } catch {}
    
    try {
        $testECC = New-SelfSignedCertificate `
            -Subject "CN=FINAL_TEST_ECC" `
            -KeyAlgorithm ECDSA_nistP256 `
            -Provider "Microsoft Platform Crypto Provider" `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -KeyExportPolicy NonExportable `
            -ErrorAction SilentlyContinue
        
        if ($testECC) {
            $supportsECC = $true
            Remove-Item "Cert:\CurrentUser\My\$($testECC.Thumbprint)" -Force
        }
    } catch {}
    
    if ($supportsRSA) {
        Write-Host "✓ TPM supports RSA keys" -ForegroundColor Green
        $recommendations += "Use RSA 2048 for TPM keys"
    }
    
    if ($supportsECC) {
        Write-Host "✓ TPM supports ECC keys" -ForegroundColor Green
        $recommendations += "Use ECDSA_nistP256 for TPM keys"
    }
    
    if (-not $supportsRSA -and -not $supportsECC) {
        Write-Host "✗ TPM key creation failed with Platform Provider" -ForegroundColor Red
        $recommendations += "TPM may require additional configuration or may not support direct key creation"
        $recommendations += "Consider using Windows Hello for Business APIs"
    }
} else {
    Write-Host "✗ TPM is not ready or not present" -ForegroundColor Red
    $recommendations += "Check TPM status in BIOS/UEFI"
    $recommendations += "Run Windows TPM troubleshooter"
}

Write-Host ""
Write-Host "Recommendations:" -ForegroundColor Cyan
foreach ($rec in $recommendations) {
    Write-Host "  • $rec" -ForegroundColor White
}

Write-Host ""
Write-Host "=" * 80
Write-Host "END OF TPM DIAGNOSTICS REPORT" -ForegroundColor Cyan
Write-Host "=" * 80

# Output JSON summary for application use
$summary = @{
    TpmPresent = $tpm.TpmPresent
    TpmReady = $tpm.TpmReady
    TpmVersion = $tpm.SpecVersion
    SupportsRSA = $supportsRSA
    SupportsECC = $supportsECC
    PlatformProviderAvailable = (Test-Path "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider\Microsoft Platform Crypto Provider")
    Recommendations = $recommendations
}

Write-Host ""
Write-Host "JSON Summary:" -ForegroundColor Yellow
$summary | ConvertTo-Json -Compress