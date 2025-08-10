# ZANDD HSM - Hardware TPM Performance Test
# Tests REAL TPM hardware performance for key operations

param(
    [int]$Iterations = 100,
    [switch]$ShowDetails,
    [string]$KeyAlgorithm = "ECDSA_P256"  # ECDSA_P256 or RSA
)

$ErrorActionPreference = "Stop"

Write-Host "=== Hardware TPM Performance Test ===" -ForegroundColor Cyan
Write-Host "THIS TEST REQUIRES ADMINISTRATOR PRIVILEGES" -ForegroundColor Yellow
Write-Host ""

# Check Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script MUST be run as Administrator to access TPM hardware!" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host "✓ Administrator privileges confirmed" -ForegroundColor Green

# Check TPM availability
Write-Host "`nChecking TPM hardware..." -ForegroundColor Cyan
try {
    $tpm = Get-Tpm
    if (-not $tpm.TpmPresent) {
        throw "No TPM hardware detected on this system"
    }
    if (-not $tpm.TpmReady) {
        throw "TPM is present but not ready. Status: $($tpm | Out-String)"
    }
    
    Write-Host "✓ TPM Hardware Present: $($tpm.TpmPresent)" -ForegroundColor Green
    Write-Host "✓ TPM Ready: $($tpm.TpmReady)" -ForegroundColor Green
    Write-Host "✓ TPM Enabled: $($tpm.TpmEnabled)" -ForegroundColor Green
    Write-Host "✓ TPM Activated: $($tpm.TpmActivated)" -ForegroundColor Green
    Write-Host "✓ TPM Owned: $($tpm.TpmOwned)" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Initialize statistics
$stats = @{
    keyCreationTimes = @()
    signatureTimes = @()
    verifyTimes = @()
    deletionTimes = @()
    failures = 0
    startTime = Get-Date
}

Write-Host "`nStarting TPM hardware performance test with $Iterations iterations..." -ForegroundColor Cyan
Write-Host "Key Algorithm: $KeyAlgorithm" -ForegroundColor Yellow
Write-Host ""

# Add .NET types for CNG operations
Add-Type -AssemblyName System.Security

# Test data
$testData = "This is test data for TPM hardware performance testing. Document ID: {0}, Timestamp: {1}"

Write-Host "Progress:" -ForegroundColor Cyan

for ($i = 1; $i -le $Iterations; $i++) {
    
    $iterationStart = Get-Date
    $keyName = "TPMPerfTest-$i-$(Get-Random -Maximum 99999)"
    
    try {
        # 1. CREATE KEY IN TPM HARDWARE
        $createStart = Get-Date
        
        $key = $null
        $ecdsa = $null
        
        try {
            # Create CNG parameters for TPM
            $cngKeyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
            $cngKeyParams.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
            $cngKeyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
            
            # Make key ephemeral (not persisted) for performance testing
            $cngKeyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::None
            
            if ($KeyAlgorithm -eq "RSA") {
                # Create RSA key in TPM
                $key = [System.Security.Cryptography.CngKey]::Create(
                    [System.Security.Cryptography.CngAlgorithm]::Rsa,
                    $keyName,
                    $cngKeyParams
                )
                $rsa = [System.Security.Cryptography.RSACng]::new($key)
                $signer = $rsa
            } else {
                # Create ECDSA P-256 key in TPM (default)
                $key = [System.Security.Cryptography.CngKey]::Create(
                    [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
                    $keyName,
                    $cngKeyParams
                )
                $ecdsa = [System.Security.Cryptography.ECDsaCng]::new($key)
                $signer = $ecdsa
            }
            
            $createTime = ((Get-Date) - $createStart).TotalMilliseconds
            $stats.keyCreationTimes += $createTime
            
            if ($ShowDetails) {
                Write-Host "  [$i] Key created in TPM: $([Math]::Round($createTime, 2)) ms" -ForegroundColor Gray
            }
            
            # 2. SIGN DATA USING TPM HARDWARE
            $signStart = Get-Date
            
            $dataToSign = $testData -f $i, (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
            $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($dataToSign)
            $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($dataBytes)
            
            # Sign with TPM key
            $signature = $signer.SignHash($hash)
            
            $signTime = ((Get-Date) - $signStart).TotalMilliseconds
            $stats.signatureTimes += $signTime
            
            if ($ShowDetails) {
                Write-Host "  [$i] Data signed by TPM: $([Math]::Round($signTime, 2)) ms" -ForegroundColor Gray
            }
            
            # 3. VERIFY SIGNATURE USING TPM HARDWARE
            $verifyStart = Get-Date
            
            # Verify with TPM key
            $isValid = $signer.VerifyHash($hash, $signature)
            
            $verifyTime = ((Get-Date) - $verifyStart).TotalMilliseconds
            $stats.verifyTimes += $verifyTime
            
            if (-not $isValid) {
                throw "Signature verification failed!"
            }
            
            if ($ShowDetails) {
                Write-Host "  [$i] Signature verified: $([Math]::Round($verifyTime, 2)) ms" -ForegroundColor Gray
            }
            
            # 4. DELETE KEY FROM TPM
            $deleteStart = Get-Date
            
            if ($signer) {
                $signer.Dispose()
            }
            if ($key) {
                try {
                    $key.Delete()
                } catch {
                    # Key might already be deleted
                }
                $key.Dispose()
            }
            
            $deleteTime = ((Get-Date) - $deleteStart).TotalMilliseconds
            $stats.deletionTimes += $deleteTime
            
            if ($ShowDetails) {
                Write-Host "  [$i] Key deleted from TPM: $([Math]::Round($deleteTime, 2)) ms" -ForegroundColor Gray
                Write-Host ""
            } elseif ($i % 10 -eq 0) {
                Write-Host -NoNewline "."
            }
            
        }
        catch {
            throw $_.Exception.Message
        }
        finally {
            # Cleanup
            if ($signer) { try { $signer.Dispose() } catch {} }
            if ($key) { try { $key.Dispose() } catch {} }
        }
        
    }
    catch {
        $stats.failures++
        if ($ShowDetails) {
            Write-Host "  [$i] ERROR: $($_.Exception.Message)" -ForegroundColor Red
        } else {
            Write-Host -NoNewline "x"
        }
    }
    
    # Show progress
    if (-not $ShowDetails -and $i % 100 -eq 0) {
        $percent = [Math]::Round(($i / $Iterations) * 100)
        Write-Host " [$percent%]"
    }
}

if (-not $ShowDetails) {
    Write-Host " [100%]"
}

# Calculate statistics
$endTime = Get-Date
$totalTime = ($endTime - $stats.startTime).TotalSeconds

$avgKeyCreation = ($stats.keyCreationTimes | Measure-Object -Average).Average
$avgSigning = ($stats.signatureTimes | Measure-Object -Average).Average
$avgVerification = ($stats.verifyTimes | Measure-Object -Average).Average
$avgDeletion = ($stats.deletionTimes | Measure-Object -Average).Average

$minKeyCreation = ($stats.keyCreationTimes | Measure-Object -Minimum).Minimum
$maxKeyCreation = ($stats.keyCreationTimes | Measure-Object -Maximum).Maximum

$minSigning = ($stats.signatureTimes | Measure-Object -Minimum).Minimum
$maxSigning = ($stats.signatureTimes | Measure-Object -Maximum).Maximum

# Display results
Write-Host "`n=== Hardware TPM Performance Results ===" -ForegroundColor Green
Write-Host ""

Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "  TPM Provider: Microsoft Platform Crypto Provider" -ForegroundColor White
Write-Host "  Key Algorithm: $KeyAlgorithm" -ForegroundColor White
Write-Host "  Iterations: $Iterations" -ForegroundColor White
Write-Host "  Total Time: $([Math]::Round($totalTime, 2)) seconds" -ForegroundColor White
Write-Host "  Successful Operations: $($Iterations - $stats.failures)" -ForegroundColor White
Write-Host "  Failures: $($stats.failures)" -ForegroundColor $(if ($stats.failures -gt 0) { "Yellow" } else { "White" })
Write-Host ""

Write-Host "TPM Hardware Performance (Average):" -ForegroundColor Cyan
Write-Host "  Key Creation: $([Math]::Round($avgKeyCreation, 2)) ms" -ForegroundColor White
Write-Host "  Signing: $([Math]::Round($avgSigning, 2)) ms" -ForegroundColor White
Write-Host "  Verification: $([Math]::Round($avgVerification, 2)) ms" -ForegroundColor White
Write-Host "  Key Deletion: $([Math]::Round($avgDeletion, 2)) ms" -ForegroundColor White
Write-Host "  Total per Operation: $([Math]::Round($avgKeyCreation + $avgSigning + $avgVerification + $avgDeletion, 2)) ms" -ForegroundColor Yellow
Write-Host ""

Write-Host "TPM Hardware Performance (Range):" -ForegroundColor Cyan
Write-Host "  Key Creation: $([Math]::Round($minKeyCreation, 2)) - $([Math]::Round($maxKeyCreation, 2)) ms" -ForegroundColor White
Write-Host "  Signing: $([Math]::Round($minSigning, 2)) - $([Math]::Round($maxSigning, 2)) ms" -ForegroundColor White
Write-Host ""

Write-Host "Throughput (Operations/Second):" -ForegroundColor Cyan
$totalOperationTime = $avgKeyCreation + $avgSigning + $avgVerification + $avgDeletion
$opsPerSecond = 1000 / $totalOperationTime
$signaturesPerSecond = 1000 / $avgSigning

Write-Host "  Complete Operations: $([Math]::Round($opsPerSecond, 1)) ops/sec" -ForegroundColor White
Write-Host "  Signatures Only: $([Math]::Round($signaturesPerSecond, 1)) sigs/sec" -ForegroundColor White
Write-Host ""

Write-Host "Projected Daily Capacity:" -ForegroundColor Cyan
Write-Host "  Complete Operations: $([Math]::Round($opsPerSecond * 86400))" -ForegroundColor White
Write-Host "  Signatures (if keys pre-created): $([Math]::Round($signaturesPerSecond * 86400))" -ForegroundColor White
Write-Host ""

Write-Host "HSM Architecture Insights:" -ForegroundColor Cyan
Write-Host "  • TPM key creation is the slowest operation (~$([Math]::Round($avgKeyCreation, 0)) ms)" -ForegroundColor White
Write-Host "  • Signing is fast once key exists (~$([Math]::Round($avgSigning, 0)) ms)" -ForegroundColor White
Write-Host "  • Pre-creating and caching keys would improve throughput significantly" -ForegroundColor White
Write-Host "  • TPM hardware provides ~$([Math]::Round($signaturesPerSecond, 0)) signatures/second" -ForegroundColor White

# Success rate
$successRate = (($Iterations - $stats.failures) / $Iterations) * 100
Write-Host ""
Write-Host "Reliability:" -ForegroundColor Cyan
Write-Host "  Success Rate: $([Math]::Round($successRate, 2))%" -ForegroundColor $(if ($successRate -ge 99) { "Green" } elseif ($successRate -ge 95) { "Yellow" } else { "Red" })

# JSON output
Write-Host "`nJSON_OUTPUT_START" -ForegroundColor Magenta
@{
    success = $true
    tmpHardware = $true
    keyAlgorithm = $KeyAlgorithm
    iterations = $Iterations
    totalTimeSeconds = [Math]::Round($totalTime, 2)
    failures = $stats.failures
    avgKeyCreationMs = [Math]::Round($avgKeyCreation, 2)
    avgSigningMs = [Math]::Round($avgSigning, 2)
    avgVerificationMs = [Math]::Round($avgVerification, 2)
    avgDeletionMs = [Math]::Round($avgDeletion, 2)
    totalPerOperationMs = [Math]::Round($totalOperationTime, 2)
    operationsPerSecond = [Math]::Round($opsPerSecond, 1)
    signaturesPerSecond = [Math]::Round($signaturesPerSecond, 1)
    successRatePercent = [Math]::Round($successRate, 2)
} | ConvertTo-Json
Write-Host "JSON_OUTPUT_END" -ForegroundColor Magenta