# Deep TPM Diagnosis
Write-Host "COMPREHENSIVE TPM DIAGNOSIS" -ForegroundColor Cyan
Write-Host "=" * 50

# 1. Check admin status
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
Write-Host "Administrator: $isAdmin" -ForegroundColor $(if($isAdmin){"Green"}else{"Red"})

# 2. Check TPM status
Write-Host "`nTPM STATUS:" -ForegroundColor Yellow
try {
    $tpm = Get-Tpm
    Write-Host "  TpmPresent: $($tpm.TmpPresent)"
    Write-Host "  TmpReady: $($tpm.TmpReady)" 
    Write-Host "  TmpEnabled: $($tpm.TmpEnabled)"
    Write-Host "  TmpActivated: $($tpm.TmpActivated)"
    Write-Host "  Manufacturer: $($tpm.ManufacturerId)"
    Write-Host "  Spec Version: $($tpm.SpecVersion)"
}
catch {
    Write-Host "  Cannot get TPM info: $_" -ForegroundColor Red
}

# 3. Check TPM services
Write-Host "`nTPM SERVICES:" -ForegroundColor Yellow
$services = @("TBS", "TPM")
foreach ($service in $services) {
    try {
        $svc = Get-Service -Name $service -ErrorAction SilentlyContinue
        if ($svc) {
            $color = if($svc.Status -eq "Running"){"Green"}else{"Red"}
            Write-Host "  $service`: $($svc.Status)" -ForegroundColor $color
        } else {
            Write-Host "  $service`: Not Found" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  $service`: Error checking" -ForegroundColor Red
    }
}

# 4. Check crypto providers
Write-Host "`nCRYPTO PROVIDERS:" -ForegroundColor Yellow
try {
    $platformProvider = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider\Microsoft Platform Crypto Provider" -ErrorAction SilentlyContinue
    if ($platformProvider) {
        Write-Host "  Microsoft Platform Crypto Provider: FOUND" -ForegroundColor Green
        Write-Host "    Image Path: $($platformProvider.'Image Path')"
        Write-Host "    Type: $($platformProvider.Type)"
    } else {
        Write-Host "  Microsoft Platform Crypto Provider: NOT FOUND" -ForegroundColor Red
    }
}
catch {
    Write-Host "  Error checking providers: $_" -ForegroundColor Red
}

# 5. Test certlm.exe approach (machine store)
Write-Host "`nTEST: Machine Certificate Store" -ForegroundColor Yellow
try {
    $cert = New-SelfSignedCertificate `
        -Subject "CN=TPM_MACHINE_TEST" `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\LocalMachine\My" `
        -KeyExportPolicy NonExportable
    
    Write-Host "  SUCCESS: Machine store TPM key created!" -ForegroundColor Green
    Write-Host "  Thumbprint: $($cert.Thumbprint)"
    # Clean up
    Remove-Item "Cert:\LocalMachine\My\$($cert.Thumbprint)" -Force
}
catch {
    Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. Test different key algorithms
Write-Host "`nTEST: Different Algorithms with Software Provider" -ForegroundColor Yellow
$algorithms = @("RSA", "ECDSA_nistP256")
foreach ($alg in $algorithms) {
    try {
        $certParams = @{
            Subject = "CN=TEST_$alg"
            Provider = "Microsoft Software Key Storage Provider"
            CertStoreLocation = "Cert:\CurrentUser\My"
        }
        
        if ($alg -eq "RSA") {
            $certParams.KeyAlgorithm = "RSA"
            $certParams.KeyLength = 2048
        } else {
            $certParams.KeyAlgorithm = $alg
        }
        
        $cert = New-SelfSignedCertificate @certParams
        Write-Host "  $alg with Software Provider: SUCCESS" -ForegroundColor Green
        Remove-Item "Cert:\CurrentUser\My\$($cert.Thumbprint)" -Force
    }
    catch {
        Write-Host "  $alg with Software Provider: FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }
}

# 7. Check group policies that might block TPM
Write-Host "`nGROUP POLICY CHECK:" -ForegroundColor Yellow
$policies = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\TPM",
    "HKLM:\SOFTWARE\Policies\Microsoft\Cryptography"
)
foreach ($policy in $policies) {
    if (Test-Path $policy) {
        Write-Host "  Policy exists: $policy" -ForegroundColor Yellow
        Get-ItemProperty $policy | Format-List
    }
}

Write-Host "`nDIAGNOSIS COMPLETE" -ForegroundColor Cyan