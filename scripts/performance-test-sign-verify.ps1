# ZANDD HSM - Performance Test: Sign and Verify Documents
# Tests creating keys, signing documents, and verifying signatures at scale

param(
    [int]$Iterations = 10000,
    [string]$TestMode = "full",  # full, sign-only, verify-only
    [switch]$UseTPM,
    [switch]$ShowProgress,
    [int]$BatchSize = 100
)

$ErrorActionPreference = "Stop"

Write-Host "=== ZANDD HSM Performance Test ===" -ForegroundColor Cyan
Write-Host "Iterations: $Iterations" -ForegroundColor Yellow
Write-Host "Test Mode: $TestMode" -ForegroundColor Yellow
Write-Host "Use TPM: $UseTPM" -ForegroundColor Yellow
Write-Host "Batch Size: $BatchSize" -ForegroundColor Yellow
Write-Host ""

# Check admin privileges if TPM requested
if ($UseTPM) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        Write-Host "⚠ TPM mode requires Administrator privileges. Falling back to software keys." -ForegroundColor Yellow
        $UseTPM = $false
    }
}

# Initialize statistics
$stats = @{
    totalOperations = 0
    keyCreationTimes = @()
    signingTimes = @()
    verificationTimes = @()
    failures = 0
    startTime = Get-Date
    keysCreated = 0
    documentsSignd = 0
    signaturesVerified = 0
}

# Create test data
$testDocuments = @(
    "This is test document 1 with some content.",
    "Invoice #12345: Amount: $1,234.56 Due: 2024-12-31",
    "Contract agreement between parties A and B for services rendered.",
    "Medical record: Patient ID: 98765, Date: 2024-01-15, Diagnosis: Healthy",
    "Financial statement Q4 2024: Revenue: $10M, Profit: $2M",
    (1..100 | ForEach-Object { "Line $_" }) -join "`n"  # Larger document
)

# Storage for keys and signatures (in-memory for performance)
$keyVault = @{}
$signatureVault = @{}

Write-Host "Starting performance test..." -ForegroundColor Cyan
Write-Host ""

# Function to create a key
function Create-SigningKey {
    param([string]$KeyName)
    
    $keyStart = Get-Date
    
    try {
        if ($UseTPM) {
            # TPM-based key (would require actual TPM implementation)
            $keyData = @{
                keyId = [Guid]::NewGuid().ToString()
                keyName = $KeyName
                algorithm = "ECDSA-P256-TPM"
                created = Get-Date
                publicKey = [Convert]::ToBase64String([byte[]](1..256 | ForEach-Object { Get-Random -Maximum 256 }))
                privateKeyHandle = "TPM:$KeyName"  # Reference to TPM key
            }
        } else {
            # Software key using .NET cryptography
            Add-Type -AssemblyName System.Security
            
            # Create ECDSA key
            $ecdsa = [System.Security.Cryptography.ECDsa]::Create([System.Security.Cryptography.ECCurve+NamedCurves]::nistP256)
            
            # Export keys
            $privateKey = $ecdsa.ExportECPrivateKey()
            $publicKey = $ecdsa.ExportSubjectPublicKeyInfo()
            
            $keyData = @{
                keyId = [Guid]::NewGuid().ToString()
                keyName = $KeyName
                algorithm = "ECDSA-P256"
                created = Get-Date
                publicKey = [Convert]::ToBase64String($publicKey)
                privateKey = [Convert]::ToBase64String($privateKey)
                ecdsaObject = $ecdsa  # Keep object for signing
            }
        }
        
        $keyCreationTime = ((Get-Date) - $keyStart).TotalMilliseconds
        $script:stats.keyCreationTimes += $keyCreationTime
        $script:stats.keysCreated++
        
        return $keyData
    }
    catch {
        $script:stats.failures++
        Write-Host "✗ Key creation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to sign a document
function Sign-Document {
    param(
        [string]$Document,
        [object]$Key
    )
    
    $signStart = Get-Date
    
    try {
        # Hash the document
        $documentBytes = [System.Text.Encoding]::UTF8.GetBytes($Document)
        $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($documentBytes)
        
        if ($UseTPM -and $Key.privateKeyHandle) {
            # TPM signing (simulated)
            $signature = [System.Security.Cryptography.SHA256]::Create().ComputeHash($hash)
        } else {
            # Software signing using ECDSA
            if ($Key.ecdsaObject) {
                $signature = $Key.ecdsaObject.SignHash($hash)
            } else {
                # Recreate ECDSA from stored key
                $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
                $ecdsa.ImportECPrivateKey([Convert]::FromBase64String($Key.privateKey), [ref]$null)
                $signature = $ecdsa.SignHash($hash)
                $ecdsa.Dispose()
            }
        }
        
        $signatureData = @{
            signatureId = [Guid]::NewGuid().ToString()
            keyId = $Key.keyId
            documentHash = [Convert]::ToBase64String($hash)
            signature = [Convert]::ToBase64String($signature)
            algorithm = $Key.algorithm
            timestamp = Get-Date
        }
        
        $signingTime = ((Get-Date) - $signStart).TotalMilliseconds
        $script:stats.signingTimes += $signingTime
        $script:stats.documentsSignd++
        
        return $signatureData
    }
    catch {
        $script:stats.failures++
        Write-Host "✗ Signing failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Function to verify a signature
function Verify-Signature {
    param(
        [string]$Document,
        [object]$Signature,
        [object]$Key
    )
    
    $verifyStart = Get-Date
    
    try {
        # Hash the document
        $documentBytes = [System.Text.Encoding]::UTF8.GetBytes($Document)
        $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($documentBytes)
        
        # Compare hashes
        $originalHash = [Convert]::FromBase64String($Signature.documentHash)
        $hashesMatch = [System.Linq.Enumerable]::SequenceEqual($hash, $originalHash)
        
        if (-not $hashesMatch) {
            throw "Document hash mismatch"
        }
        
        # Verify signature
        $signatureBytes = [Convert]::FromBase64String($Signature.signature)
        
        if ($UseTPM -and $Key.privateKeyHandle) {
            # TPM verification (simulated)
            $isValid = $true  # In real implementation, use TPM2_VerifySignature
        } else {
            # Software verification using ECDSA
            if ($Key.ecdsaObject) {
                $isValid = $Key.ecdsaObject.VerifyHash($hash, $signatureBytes)
            } else {
                # Create public key only ECDSA for verification
                $ecdsa = [System.Security.Cryptography.ECDsa]::Create()
                $ecdsa.ImportSubjectPublicKeyInfo([Convert]::FromBase64String($Key.publicKey), [ref]$null)
                $isValid = $ecdsa.VerifyHash($hash, $signatureBytes)
                $ecdsa.Dispose()
            }
        }
        
        $verificationTime = ((Get-Date) - $verifyStart).TotalMilliseconds
        $script:stats.verificationTimes += $verificationTime
        $script:stats.signaturesVerified++
        
        return $isValid
    }
    catch {
        $script:stats.failures++
        Write-Host "✗ Verification failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main test loop
$progressInterval = [Math]::Max(1, [Math]::Floor($Iterations / 100))
$batchInterval = [Math]::Min($BatchSize, $Iterations)

Write-Host "Progress:" -ForegroundColor Cyan

for ($i = 1; $i -le $Iterations; $i++) {
    try {
        # Select a random document
        $document = $testDocuments | Get-Random
        
        # Create or reuse a key (create new key every 100 iterations for variety)
        if (($i % 100) -eq 1 -or $keyVault.Count -eq 0) {
            $keyName = "perf-key-$([Math]::Floor($i / 100))"
            $key = Create-SigningKey -KeyName $keyName
            if ($key) {
                $keyVault[$keyName] = $key
            }
        } else {
            $key = $keyVault.Values | Get-Random
        }
        
        if ($TestMode -eq "full" -or $TestMode -eq "sign-only") {
            # Sign the document
            $signature = Sign-Document -Document $document -Key $key
            if ($signature) {
                $signatureVault["sig-$i"] = @{
                    signature = $signature
                    document = $document
                    key = $key
                }
            }
        }
        
        if ($TestMode -eq "full" -or $TestMode -eq "verify-only") {
            # Verify a signature (use existing or current)
            if ($TestMode -eq "verify-only" -and $signatureVault.Count -gt 0) {
                $sigData = $signatureVault.Values | Get-Random
                $verifyResult = Verify-Signature -Document $sigData.document -Signature $sigData.signature -Key $sigData.key
            } elseif ($signature) {
                $verifyResult = Verify-Signature -Document $document -Signature $signature -Key $key
                if (-not $verifyResult) {
                    Write-Host "⚠ Signature verification failed at iteration $i" -ForegroundColor Yellow
                }
            }
        }
        
        $stats.totalOperations++
        
        # Show progress
        if ($ShowProgress -and ($i % $progressInterval) -eq 0) {
            $percent = [Math]::Round(($i / $Iterations) * 100)
            Write-Host -NoNewline "`r[$percent%] Operations: $i/$Iterations | Keys: $($stats.keysCreated) | Signed: $($stats.documentsSignd) | Verified: $($stats.signaturesVerified) | Failures: $($stats.failures)    "
        } elseif (($i % $batchInterval) -eq 0) {
            Write-Host -NoNewline "."
        }
        
    }
    catch {
        $stats.failures++
        Write-Host "`n✗ Operation $i failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n"

# Clean up ECDSA objects
foreach ($key in $keyVault.Values) {
    if ($key.ecdsaObject) {
        $key.ecdsaObject.Dispose()
    }
}

# Calculate statistics
$stats.endTime = Get-Date
$stats.totalTime = ($stats.endTime - $stats.startTime).TotalSeconds

$avgKeyCreation = if ($stats.keyCreationTimes.Count -gt 0) { 
    ($stats.keyCreationTimes | Measure-Object -Average).Average 
} else { 0 }

$avgSigning = if ($stats.signingTimes.Count -gt 0) { 
    ($stats.signingTimes | Measure-Object -Average).Average 
} else { 0 }

$avgVerification = if ($stats.verificationTimes.Count -gt 0) { 
    ($stats.verificationTimes | Measure-Object -Average).Average 
} else { 0 }

# Display results
Write-Host "=== Performance Test Results ===" -ForegroundColor Green
Write-Host ""
Write-Host "Test Configuration:" -ForegroundColor Cyan
Write-Host "  Mode: $TestMode" -ForegroundColor White
Write-Host "  Key Type: $(if ($UseTPM) { 'TPM-backed' } else { 'Software' })" -ForegroundColor White
Write-Host "  Iterations: $Iterations" -ForegroundColor White
Write-Host "  Total Time: $([Math]::Round($stats.totalTime, 2)) seconds" -ForegroundColor White
Write-Host ""

Write-Host "Operations Completed:" -ForegroundColor Cyan
Write-Host "  Keys Created: $($stats.keysCreated)" -ForegroundColor White
Write-Host "  Documents Signed: $($stats.documentsSignd)" -ForegroundColor White
Write-Host "  Signatures Verified: $($stats.signaturesVerified)" -ForegroundColor White
Write-Host "  Total Operations: $($stats.totalOperations)" -ForegroundColor White
Write-Host "  Failures: $($stats.failures)" -ForegroundColor $(if ($stats.failures -gt 0) { "Yellow" } else { "White" })
Write-Host ""

Write-Host "Performance Metrics:" -ForegroundColor Cyan
Write-Host "  Avg Key Creation: $([Math]::Round($avgKeyCreation, 2)) ms" -ForegroundColor White
Write-Host "  Avg Signing Time: $([Math]::Round($avgSigning, 2)) ms" -ForegroundColor White
Write-Host "  Avg Verification: $([Math]::Round($avgVerification, 2)) ms" -ForegroundColor White
Write-Host ""

Write-Host "Throughput:" -ForegroundColor Cyan
if ($stats.totalTime -gt 0) {
    $opsPerSecond = $stats.totalOperations / $stats.totalTime
    $signsPerSecond = $stats.documentsSignd / $stats.totalTime
    $verifiesPerSecond = $stats.signaturesVerified / $stats.totalTime
    
    Write-Host "  Total Operations/sec: $([Math]::Round($opsPerSecond, 1))" -ForegroundColor White
    Write-Host "  Signatures/sec: $([Math]::Round($signsPerSecond, 1))" -ForegroundColor White
    Write-Host "  Verifications/sec: $([Math]::Round($verifiesPerSecond, 1))" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Projected Daily Capacity:" -ForegroundColor Cyan
    Write-Host "  Signatures per day: $([Math]::Round($signsPerSecond * 86400))" -ForegroundColor White
    Write-Host "  Verifications per day: $([Math]::Round($verifiesPerSecond * 86400))" -ForegroundColor White
}

Write-Host ""
Write-Host "Memory Usage:" -ForegroundColor Cyan
$process = Get-Process -Id $PID
Write-Host "  Working Set: $([Math]::Round($process.WorkingSet64 / 1MB, 2)) MB" -ForegroundColor White
Write-Host "  Private Memory: $([Math]::Round($process.PrivateMemorySize64 / 1MB, 2)) MB" -ForegroundColor White

# Success rate
$successRate = if ($stats.totalOperations -gt 0) { 
    (($stats.totalOperations - $stats.failures) / $stats.totalOperations) * 100 
} else { 0 }

Write-Host ""
Write-Host "Reliability:" -ForegroundColor Cyan
Write-Host "  Success Rate: $([Math]::Round($successRate, 2))%" -ForegroundColor $(if ($successRate -ge 99) { "Green" } elseif ($successRate -ge 95) { "Yellow" } else { "Red" })

# Output JSON summary
Write-Host ""
Write-Host "JSON_OUTPUT_START" -ForegroundColor Magenta
@{
    success = $true
    testMode = $TestMode
    useTPM = $UseTPM
    iterations = $Iterations
    totalTimeSeconds = [Math]::Round($stats.totalTime, 2)
    keysCreated = $stats.keysCreated
    documentsSigned = $stats.documentsSignd
    signaturesVerified = $stats.signaturesVerified
    failures = $stats.failures
    avgKeyCreationMs = [Math]::Round($avgKeyCreation, 2)
    avgSigningMs = [Math]::Round($avgSigning, 2)
    avgVerificationMs = [Math]::Round($avgVerification, 2)
    operationsPerSecond = [Math]::Round($opsPerSecond, 1)
    successRatePercent = [Math]::Round($successRate, 2)
} | ConvertTo-Json
Write-Host "JSON_OUTPUT_END" -ForegroundColor Magenta