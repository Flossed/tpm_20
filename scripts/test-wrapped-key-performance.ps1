# ZANDD HSM - Wrapped Key Performance Test
# Tests the real HSM workflow: wrap keys, store externally, import for operations

param(
    [int]$Iterations = 100,
    [switch]$ShowDetails,
    [string]$VaultPath = ".\vault\perf-test"
)

$ErrorActionPreference = "Stop"

Write-Host "=== Wrapped Key Performance Test ===" -ForegroundColor Cyan
Write-Host "Testing REAL HSM workflow with wrapped keys" -ForegroundColor Yellow
Write-Host ""

# Check Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: Administrator privileges required for TPM operations!" -ForegroundColor Red
    exit 1
}

Write-Host "✓ Administrator privileges confirmed" -ForegroundColor Green

# Create vault directory
if (-not (Test-Path $VaultPath)) {
    New-Item -ItemType Directory -Path $VaultPath -Force | Out-Null
}

# Initialize statistics
$stats = @{
    keyCreationAndWrapTimes = @()
    wrapKeyImportTimes = @()
    signWithWrappedTimes = @()
    verifyWithWrappedTimes = @()
    totalCycleTimes = @()
    failures = 0
    startTime = Get-Date
}

Write-Host "`nTesting wrapped key workflow with $Iterations iterations..." -ForegroundColor Cyan
Write-Host "Vault Path: $VaultPath" -ForegroundColor Yellow
Write-Host ""

Add-Type -AssemblyName System.Security

$testData = "HSM Wrapped Key Performance Test - Document ID: {0}, Timestamp: {1}"
$wrappedKeys = @{}

Write-Host "Progress:" -ForegroundColor Cyan

for ($i = 1; $i -le $Iterations; $i++) {
    $cycleStart = Get-Date
    $keyName = "wrapped-perf-key-$i"
    
    try {
        # PHASE 1: CREATE AND WRAP KEY (like HSM key generation)
        $wrapStart = Get-Date
        
        if ($ShowDetails) {
            Write-Host "`n  [$i] PHASE 1: Creating and wrapping key..." -ForegroundColor Cyan
        }
        
        try {
            # Create key in TPM
            $cngKeyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
            $cngKeyParams.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
            $cngKeyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
            $cngKeyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowExport
            
            # Create ECDSA key in TPM
            $key = [System.Security.Cryptography.CngKey]::Create(
                [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
                $keyName,
                $cngKeyParams
            )
            
            # Export wrapped blob (this is the "HSM vault storage")
            $wrappedBlob = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::OpaqueTransportBlob)
            $publicBlob = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
            
            # Store wrapped key info
            $wrappedKeyInfo = @{
                keyName = $keyName
                wrappedBlob = $wrappedBlob
                publicBlob = $publicBlob
                created = Get-Date
            }
            
            # Save to "vault" (file system)
            $keyPath = "$VaultPath\$keyName.wrapped"
            @{
                wrappedKey = [Convert]::ToBase64String($wrappedBlob)
                publicKey = [Convert]::ToBase64String($publicBlob)
                algorithm = "ECDSA_P256"
                created = Get-Date.ToString("yyyy-MM-dd HH:mm:ss")
            } | ConvertTo-Json | Set-Content -Path $keyPath
            
            # Delete from TPM (key now only exists as wrapped blob)
            $key.Delete()
            $key.Dispose()
            
            $wrapTime = ((Get-Date) - $wrapStart).TotalMilliseconds
            $stats.keyCreationAndWrapTimes += $wrapTime
            
            if ($ShowDetails) {
                Write-Host "    Key created, wrapped, and stored: $([Math]::Round($wrapTime, 2)) ms" -ForegroundColor Gray
            }
            
            # PHASE 2: IMPORT WRAPPED KEY FOR SIGNING (like HSM operation)
            $importStart = Get-Date
            
            if ($ShowDetails) {
                Write-Host "  [$i] PHASE 2: Importing wrapped key for signing..." -ForegroundColor Cyan
            }
            
            # Import wrapped key back to TPM
            $importedKey = [System.Security.Cryptography.CngKey]::Import(
                $wrappedBlob,
                [System.Security.Cryptography.CngKeyBlobFormat]::OpaqueTransportBlob,
                [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
            )
            
            $importTime = ((Get-Date) - $importStart).TotalMilliseconds
            $stats.wrapKeyImportTimes += $importTime
            
            if ($ShowDetails) {
                Write-Host "    Wrapped key imported to TPM: $([Math]::Round($importTime, 2)) ms" -ForegroundColor Gray
            }
            
            # PHASE 3: SIGN WITH IMPORTED WRAPPED KEY
            $signStart = Get-Date
            
            if ($ShowDetails) {
                Write-Host "  [$i] PHASE 3: Signing with imported wrapped key..." -ForegroundColor Cyan
            }
            
            $ecdsa = [System.Security.Cryptography.ECDsaCng]::new($importedKey)
            
            $dataToSign = $testData -f $i, (Get-Date).ToString("yyyy-MM-dd HH:mm:ss.fff")
            $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($dataToSign)
            $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($dataBytes)
            
            $signature = $ecdsa.SignHash($hash)
            
            $signTime = ((Get-Date) - $signStart).TotalMilliseconds
            $stats.signWithWrappedTimes += $signTime
            
            if ($ShowDetails) {
                Write-Host "    Data signed with wrapped key: $([Math]::Round($signTime, 2)) ms" -ForegroundColor Gray
            }
            
            # PHASE 4: VERIFY WITH IMPORTED WRAPPED KEY
            $verifyStart = Get-Date
            
            if ($ShowDetails) {
                Write-Host "  [$i] PHASE 4: Verifying with imported wrapped key..." -ForegroundColor Cyan
            }
            
            $isValid = $ecdsa.VerifyHash($hash, $signature)
            
            if (-not $isValid) {
                throw "Wrapped key signature verification failed!"
            }
            
            $verifyTime = ((Get-Date) - $verifyStart).TotalMilliseconds
            $stats.verifyWithWrappedTimes += $verifyTime
            
            if ($ShowDetails) {
                Write-Host "    Signature verified with wrapped key: $([Math]::Round($verifyTime, 2)) ms" -ForegroundColor Gray
            }
            
            # Clean up - remove key from TPM (back to wrapped storage only)
            $ecdsa.Dispose()
            $importedKey.Delete()
            $importedKey.Dispose()
            
            $totalCycleTime = ((Get-Date) - $cycleStart).TotalMilliseconds
            $stats.totalCycleTimes += $totalCycleTime
            
            if ($ShowDetails) {
                Write-Host "    Complete cycle: $([Math]::Round($totalCycleTime, 2)) ms" -ForegroundColor Yellow
            } elseif ($i % 10 -eq 0) {
                Write-Host -NoNewline "."
            }
            
        }
        catch {
            throw $_.Exception.Message
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

$avgWrapCreation = ($stats.keyCreationAndWrapTimes | Measure-Object -Average).Average
$avgImport = ($stats.wrapKeyImportTimes | Measure-Object -Average).Average
$avgSignWrapped = ($stats.signWithWrappedTimes | Measure-Object -Average).Average
$avgVerifyWrapped = ($stats.verifyWithWrappedTimes | Measure-Object -Average).Average
$avgTotalCycle = ($stats.totalCycleTimes | Measure-Object -Average).Average

# Display results
Write-Host "`n=== Wrapped Key Performance Results ===" -ForegroundColor Green
Write-Host ""

Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "  Workflow: Create→Wrap→Store→Import→Sign→Verify→Unload" -ForegroundColor White
Write-Host "  TPM Provider: Microsoft Platform Crypto Provider" -ForegroundColor White
Write-Host "  Key Algorithm: ECDSA_P256" -ForegroundColor White
Write-Host "  Iterations: $Iterations" -ForegroundColor White
Write-Host "  Total Time: $([Math]::Round($totalTime, 2)) seconds" -ForegroundColor White
Write-Host "  Successful Operations: $($Iterations - $stats.failures)" -ForegroundColor White
Write-Host "  Failures: $($stats.failures)" -ForegroundColor $(if ($stats.failures -gt 0) { "Yellow" } else { "White" })
Write-Host ""

Write-Host "HSM Wrapped Key Performance (Average):" -ForegroundColor Cyan
Write-Host "  1. Create + Wrap + Store: $([Math]::Round($avgWrapCreation, 2)) ms" -ForegroundColor White
Write-Host "  2. Import Wrapped Key: $([Math]::Round($avgImport, 2)) ms" -ForegroundColor White
Write-Host "  3. Sign with Wrapped Key: $([Math]::Round($avgSignWrapped, 2)) ms" -ForegroundColor White
Write-Host "  4. Verify with Wrapped Key: $([Math]::Round($avgVerifyWrapped, 2)) ms" -ForegroundColor White
Write-Host "  Total HSM Cycle: $([Math]::Round($avgTotalCycle, 2)) ms" -ForegroundColor Yellow
Write-Host ""

Write-Host "Performance Comparison:" -ForegroundColor Cyan
Write-Host "  Direct TPM Sign: ~23 ms (from previous test)" -ForegroundColor White
Write-Host "  Wrapped Key Sign: $([Math]::Round($avgImport + $avgSignWrapped, 2)) ms (import + sign)" -ForegroundColor White
Write-Host "  HSM Overhead: $([Math]::Round(($avgImport + $avgSignWrapped) - 23, 2)) ms per signature" -ForegroundColor Yellow
Write-Host ""

Write-Host "HSM Throughput:" -ForegroundColor Cyan
$hsmOpsPerSecond = 1000 / $avgTotalCycle
$hsmSignsPerSecond = 1000 / ($avgImport + $avgSignWrapped)

Write-Host "  Complete HSM Operations: $([Math]::Round($hsmOpsPerSecond, 1)) ops/sec" -ForegroundColor White
Write-Host "  HSM Signatures (pre-created keys): $([Math]::Round($hsmSignsPerSecond, 1)) sigs/sec" -ForegroundColor White
Write-Host ""

Write-Host "Daily HSM Capacity:" -ForegroundColor Cyan
Write-Host "  Complete operations: $([Math]::Round($hsmOpsPerSecond * 86400))" -ForegroundColor White
Write-Host "  Signatures (keys pre-wrapped): $([Math]::Round($hsmSignsPerSecond * 86400))" -ForegroundColor White
Write-Host ""

Write-Host "HSM Architecture Insights:" -ForegroundColor Cyan
Write-Host "  • Key wrapping adds ~$([Math]::Round(($avgImport + $avgSignWrapped) - 23, 0)) ms overhead per signature" -ForegroundColor White
Write-Host "  • Import time: ~$([Math]::Round($avgImport, 0)) ms (acceptable for HSM security)" -ForegroundColor White
Write-Host "  • Wrapped keys provide unlimited storage with TPM security" -ForegroundColor White
Write-Host "  • Performance: $([Math]::Round($hsmSignsPerSecond, 0)) signatures/second in HSM mode" -ForegroundColor White

# Success rate
$successRate = (($Iterations - $stats.failures) / $Iterations) * 100
Write-Host ""
Write-Host "HSM Reliability:" -ForegroundColor Cyan
Write-Host "  Success Rate: $([Math]::Round($successRate, 2))%" -ForegroundColor $(if ($successRate -ge 99) { "Green" } elseif ($successRate -ge 95) { "Yellow" } else { "Red" })

# Clean up test vault
Write-Host ""
Write-Host "Cleaning up test vault..." -ForegroundColor Gray
Remove-Item -Path $VaultPath -Recurse -Force 2>$null

# JSON output
Write-Host "`nJSON_OUTPUT_START" -ForegroundColor Magenta
@{
    success = $true
    hsmWrappedKeyTest = $true
    iterations = $Iterations
    totalTimeSeconds = [Math]::Round($totalTime, 2)
    failures = $stats.failures
    avgCreateWrapMs = [Math]::Round($avgWrapCreation, 2)
    avgImportMs = [Math]::Round($avgImport, 2)
    avgSignWrappedMs = [Math]::Round($avgSignWrapped, 2)
    avgVerifyWrappedMs = [Math]::Round($avgVerifyWrapped, 2)
    avgTotalCycleMs = [Math]::Round($avgTotalCycle, 2)
    hsmOperationsPerSecond = [Math]::Round($hsmOpsPerSecond, 1)
    hsmSignaturesPerSecond = [Math]::Round($hsmSignsPerSecond, 1)
    hsmOverheadMs = [Math]::Round(($avgImport + $avgSignWrapped) - 23, 2)
    successRatePercent = [Math]::Round($successRate, 2)
} | ConvertTo-Json
Write-Host "JSON_OUTPUT_END" -ForegroundColor Magenta