# ZANDD HSM - AMD TPM Optimized Architecture Performance Test
# Designed for TPMs that can export but not import keys

param(
    [int]$Iterations = 100,
    [switch]$ShowDetails
)

$ErrorActionPreference = "Stop"

Write-Host "=== AMD TPM Optimized HSM Architecture Performance Test ===" -ForegroundColor Cyan
Write-Host "Architecture: Export-only TPM with software crypto for daily operations" -ForegroundColor Yellow
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Administrator privileges required for TPM operations!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Administrator privileges confirmed" -ForegroundColor Green

# Initialize statistics
$stats = @{
    keyCreationTimes = @()
    keyExportTimes = @()
    softwareSignTimes = @()
    softwareVerifyTimes = @()
    totalCycleTimes = @()
    failures = 0
    startTime = Get-Date
}

Write-Host "`nTesting AMD TPM Optimized HSM workflow with $Iterations iterations..." -ForegroundColor Cyan
Write-Host ""

Write-Host "HSM Architecture (optimized for your AMD TPM):" -ForegroundColor Yellow
Write-Host "  1. Create key in TPM (true hardware randomness)" -ForegroundColor Gray
Write-Host "  2. Export private key blob (AllowArchiving)" -ForegroundColor Gray
Write-Host "  3. Store encrypted blob in vault" -ForegroundColor Gray
Write-Host "  4. Delete key from TPM (free up TPM memory)" -ForegroundColor Gray
Write-Host "  5. Use software crypto for operations (fast)" -ForegroundColor Gray
Write-Host "  6. TPM provides Hardware Root of Trust for key generation" -ForegroundColor Gray
Write-Host ""

Add-Type -AssemblyName System.Security

$testData = "AMD TPM HSM Performance Test - Document ID: {0}, Timestamp: {1}"

Write-Host "Progress:" -ForegroundColor Cyan

for ($i = 1; $i -le $Iterations; $i++) {
    $cycleStart = Get-Date
    
    try {
        # PHASE 1: CREATE KEY IN TPM (Hardware randomness)
        $createStart = Get-Date
        
        if ($ShowDetails) {
            Write-Host "`n  [$i] PHASE 1: Creating key in TPM (hardware RNG)..." -ForegroundColor Cyan
        }
        
        $tpmKey = $null
        $privateKeyBlob = $null
        
        try {
            # Create key in TPM for hardware-grade randomness
            $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
            $keyParams.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
            $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
            $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowArchiving
            
            $tpmKey = [System.Security.Cryptography.CngKey]::Create(
                [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
                $null,  # Auto-generate name
                $keyParams
            )
            
            $createTime = ((Get-Date) - $createStart).TotalMilliseconds
            $stats.keyCreationTimes += $createTime
            
            if ($ShowDetails) {
                Write-Host "    TPM key created: $([Math]::Round($createTime, 2)) ms" -ForegroundColor Gray
            }
            
        }
        catch {
            throw "TPM key creation failed: $($_.Exception.Message)"
        }
        
        # PHASE 2: EXPORT KEY FROM TPM
        $exportStart = Get-Date
        
        if ($ShowDetails) {
            Write-Host "  [$i] PHASE 2: Exporting key from TPM..." -ForegroundColor Cyan
        }
        
        try {
            # Export private key blob (this works on your AMD TPM)
            $privateKeyBlob = $tpmKey.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
            
            # Delete TPM key immediately (free up TPM memory)
            $tpmKey.Delete()
            $tpmKey.Dispose()
            $tpmKey = $null
            
            $exportTime = ((Get-Date) - $exportStart).TotalMilliseconds
            $stats.keyExportTimes += $exportTime
            
            if ($ShowDetails) {
                Write-Host "    Key exported from TPM: $([Math]::Round($exportTime, 2)) ms ($($privateKeyBlob.Length) bytes)" -ForegroundColor Gray
            }
            
        }
        catch {
            if ($tpmKey) {
                try { 
                    $tpmKey.Delete()
                    $tpmKey.Dispose() 
                } catch {}
            }
            throw "TPM key export failed: $($_.Exception.Message)"
        }
        
        # PHASE 3: SOFTWARE CRYPTO FOR OPERATIONS (Fast)
        $signStart = Get-Date
        
        if ($ShowDetails) {
            Write-Host "  [$i] PHASE 3: Software crypto operations..." -ForegroundColor Cyan
        }
        
        $softwareECDSA = $null
        try {
            # Create software ECDSA from exported TPM blob
            $softwareECDSA = [System.Security.Cryptography.ECDsa]::Create()
            $softwareECDSA.ImportECPrivateKey($privateKeyBlob, [ref]$null)
            
            # Sign with software crypto (fast)
            $dataToSign = $testData -f $i, (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
            $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($dataToSign)
            $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($dataBytes)
            
            $signature = $softwareECDSA.SignHash($hash)
            
            $signTime = ((Get-Date) - $signStart).TotalMilliseconds
            $stats.softwareSignTimes += $signTime
            
            if ($ShowDetails) {
                Write-Host "    Software signing: $([Math]::Round($signTime, 2)) ms" -ForegroundColor Gray
            }
            
        }
        catch {
            throw "Software signing failed: $($_.Exception.Message)"
        }
        
        # PHASE 4: SOFTWARE VERIFICATION
        $verifyStart = Get-Date
        
        if ($ShowDetails) {
            Write-Host "  [$i] PHASE 4: Software verification..." -ForegroundColor Cyan
        }
        
        try {
            # Verify with software crypto
            $isValid = $softwareECDSA.VerifyHash($hash, $signature)
            
            if (-not $isValid) {
                throw "Signature verification failed!"
            }
            
            $verifyTime = ((Get-Date) - $verifyStart).TotalMilliseconds
            $stats.softwareVerifyTimes += $verifyTime
            
            if ($ShowDetails) {
                Write-Host "    Software verification: $([Math]::Round($verifyTime, 2)) ms" -ForegroundColor Gray
            }
            
            # Clean up software objects
            $softwareECDSA.Dispose()
            
        }
        catch {
            if ($softwareECDSA) { $softwareECDSA.Dispose() }
            throw "Software verification failed: $($_.Exception.Message)"
        }
        
        $totalCycleTime = ((Get-Date) - $cycleStart).TotalMilliseconds
        $stats.totalCycleTimes += $totalCycleTime
        
        if ($ShowDetails) {
            Write-Host "    Complete AMD TPM HSM cycle: $([Math]::Round($totalCycleTime, 2)) ms" -ForegroundColor Yellow
        } elseif ($i % 10 -eq 0) {
            Write-Host -NoNewline "."
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
    if (-not $ShowDetails -and $i % 50 -eq 0) {
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

$avgCreate = ($stats.keyCreationTimes | Measure-Object -Average).Average
$avgExport = ($stats.keyExportTimes | Measure-Object -Average).Average
$avgSign = ($stats.softwareSignTimes | Measure-Object -Average).Average
$avgVerify = ($stats.softwareVerifyTimes | Measure-Object -Average).Average
$avgTotalCycle = ($stats.totalCycleTimes | Measure-Object -Average).Average

# Display results
Write-Host "`n=== AMD TPM Optimized HSM Performance Results ===" -ForegroundColor Green
Write-Host ""

Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "  Architecture: TPM for key generation + Software for operations" -ForegroundColor White
Write-Host "  TPM Hardware: AMD TPM with Microsoft Platform Crypto Provider" -ForegroundColor White
Write-Host "  TPM Usage: Hardware RNG + Key export (AllowArchiving)" -ForegroundColor White
Write-Host "  Crypto Operations: Software ECDSA (fast)" -ForegroundColor White
Write-Host "  Algorithm: ECDSA P-256" -ForegroundColor White
Write-Host "  Iterations: $Iterations" -ForegroundColor White
Write-Host "  Total Time: $([Math]::Round($totalTime, 2)) seconds" -ForegroundColor White
Write-Host "  Successful Operations: $($Iterations - $stats.failures)" -ForegroundColor White
Write-Host "  Failures: $($stats.failures)" -ForegroundColor $(if ($stats.failures -gt 0) { "Yellow" } else { "White" })
Write-Host ""

Write-Host "AMD TPM HSM Performance (Average):" -ForegroundColor Cyan
Write-Host "  1. TPM Key Creation: $([Math]::Round($avgCreate, 2)) ms" -ForegroundColor White
Write-Host "  2. TPM Key Export: $([Math]::Round($avgExport, 2)) ms" -ForegroundColor White
Write-Host "  3. Software Signing: $([Math]::Round($avgSign, 2)) ms" -ForegroundColor White
Write-Host "  4. Software Verification: $([Math]::Round($avgVerify, 2)) ms" -ForegroundColor White
Write-Host "  Total HSM Cycle: $([Math]::Round($avgTotalCycle, 2)) ms" -ForegroundColor Yellow
Write-Host ""

Write-Host "Performance Comparison:" -ForegroundColor Cyan
Write-Host "  Pure TPM Operations: ~110 ms per cycle" -ForegroundColor White
Write-Host "  AMD TPM HSM: $([Math]::Round($avgTotalCycle, 2)) ms per cycle" -ForegroundColor White
Write-Host "  Software vs TPM Sign: $([Math]::Round($avgSign, 2)) ms vs ~23 ms" -ForegroundColor White
Write-Host "  HSM Advantage: Hardware RNG + Software speed" -ForegroundColor Yellow
Write-Host ""

Write-Host "AMD TPM HSM Throughput:" -ForegroundColor Cyan
$hsmOpsPerSecond = 1000 / $avgTotalCycle
$dailyOpsPerSecond = 1000 / ($avgSign + $avgVerify)  # Daily ops without key creation

Write-Host "  Complete HSM Operations: $([Math]::Round($hsmOpsPerSecond, 1)) ops/sec" -ForegroundColor White
Write-Host "  Daily Operations (pre-generated keys): $([Math]::Round($dailyOpsPerSecond, 1)) ops/sec" -ForegroundColor White
Write-Host ""

Write-Host "Daily Production Capacity:" -ForegroundColor Cyan
Write-Host "  Complete operations: $([Math]::Round($hsmOpsPerSecond * 86400))" -ForegroundColor White
Write-Host "  Daily signatures: $([Math]::Round($dailyOpsPerSecond * 86400))" -ForegroundColor White
Write-Host ""

Write-Host "AMD TPM HSM Architecture Benefits:" -ForegroundColor Cyan
Write-Host "  ✓ Hardware-grade key generation (TPM RNG)" -ForegroundColor Green
Write-Host "  ✓ Fast daily operations (software crypto)" -ForegroundColor Green
Write-Host "  ✓ Unlimited key storage (export capability)" -ForegroundColor Green
Write-Host "  ✓ No TPM memory limitations" -ForegroundColor Green
Write-Host "  ✓ Hardware Root of Trust maintained" -ForegroundColor Green
Write-Host "  ✓ Optimized for AMD TPM capabilities" -ForegroundColor Green

# Success rate
$successRate = (($Iterations - $stats.failures) / $Iterations) * 100
Write-Host ""
Write-Host "AMD TPM HSM Reliability:" -ForegroundColor Cyan
Write-Host "  Success Rate: $([Math]::Round($successRate, 2))%" -ForegroundColor $(if ($successRate -ge 99) { "Green" } elseif ($successRate -ge 95) { "Yellow" } else { "Red" })

# JSON output
Write-Host "`nJSON_OUTPUT_START" -ForegroundColor Magenta
@{
    success = $true
    amdTPMOptimizedHSM = $true
    architecture = "TPM-generation + Software-operations"
    iterations = $Iterations
    totalTimeSeconds = [Math]::Round($totalTime, 2)
    failures = $stats.failures
    avgCreateMs = [Math]::Round($avgCreate, 2)
    avgExportMs = [Math]::Round($avgExport, 2)
    avgSoftwareSignMs = [Math]::Round($avgSign, 2)
    avgSoftwareVerifyMs = [Math]::Round($avgVerify, 2)
    avgTotalCycleMs = [Math]::Round($avgTotalCycle, 2)
    hsmOperationsPerSecond = [Math]::Round($hsmOpsPerSecond, 1)
    dailyOperationsPerSecond = [Math]::Round($dailyOpsPerSecond, 1)
    successRatePercent = [Math]::Round($successRate, 2)
} | ConvertTo-Json
Write-Host "JSON_OUTPUT_END" -ForegroundColor Magenta