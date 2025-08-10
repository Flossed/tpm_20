# Test TPM Hardware Wrapping Capabilities
# Discovers what your AMD TPM actually supports for key wrapping

$ErrorActionPreference = "Stop"

Write-Host "=== Testing TPM Hardware Wrapping Capabilities ===" -ForegroundColor Cyan
Write-Host "AMD TPM Hardware Capability Assessment" -ForegroundColor Yellow
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Administrator privileges required!" -ForegroundColor Red
    exit 1
}

Add-Type -AssemblyName System.Security

Write-Host "1. Testing TPM Export Policy Support..." -ForegroundColor Cyan

$exportPolicies = @(
    @{Name="None"; Policy=[System.Security.Cryptography.CngExportPolicies]::None},
    @{Name="AllowExport"; Policy=[System.Security.Cryptography.CngExportPolicies]::AllowExport},
    @{Name="AllowPlaintextExport"; Policy=[System.Security.Cryptography.CngExportPolicies]::AllowPlaintextExport},
    @{Name="AllowArchiving"; Policy=[System.Security.Cryptography.CngExportPolicies]::AllowArchiving},
    @{Name="AllowPlaintextArchiving"; Policy=[System.Security.Cryptography.CngExportPolicies]::AllowPlaintextArchiving}
)

$supportedPolicies = @()
$keyFormats = @(
    @{Name="OpaqueTransportBlob"; Format=[System.Security.Cryptography.CngKeyBlobFormat]::OpaqueTransportBlob},
    @{Name="GenericPrivateBlob"; Format=[System.Security.Cryptography.CngKeyBlobFormat]::GenericPrivateBlob},
    @{Name="EccPrivateBlob"; Format=[System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob},
    @{Name="Pkcs8PrivateBlob"; Format=[System.Security.Cryptography.CngKeyBlobFormat]::Pkcs8PrivateBlob}
)

foreach ($exportPolicy in $exportPolicies) {
    Write-Host "  Testing Export Policy: $($exportPolicy.Name)..." -ForegroundColor White
    
    try {
        $keyName = "test-export-$($exportPolicy.Name)-$(Get-Random)"
        
        # Create key with this export policy
        $cngKeyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
        $cngKeyParams.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
        $cngKeyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
        $cngKeyParams.ExportPolicy = $exportPolicy.Policy
        
        $key = [System.Security.Cryptography.CngKey]::Create(
            [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
            $keyName,
            $cngKeyParams
        )
        
        Write-Host "    ✓ Key creation: SUCCESS" -ForegroundColor Green
        
        # Test export formats
        $supportedFormats = @()
        foreach ($format in $keyFormats) {
            try {
                $blob = $key.Export($format.Format)
                $supportedFormats += $format.Name
                Write-Host "    ✓ Export $($format.Name): SUCCESS ($($blob.Length) bytes)" -ForegroundColor Green
            }
            catch {
                Write-Host "    ✗ Export $($format.Name): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        $supportedPolicies += @{
            Policy = $exportPolicy.Name
            Supported = $true
            SupportedFormats = $supportedFormats
        }
        
        # Clean up
        $key.Delete()
        $key.Dispose()
        
    }
    catch {
        Write-Host "    ✗ Key creation: $($_.Exception.Message)" -ForegroundColor Red
        $supportedPolicies += @{
            Policy = $exportPolicy.Name
            Supported = $false
            Error = $_.Exception.Message
        }
    }
    Write-Host ""
}

Write-Host "2. Testing TPM Import Capabilities..." -ForegroundColor Cyan

# Test if we can create a key with software provider and import to TPM
try {
    Write-Host "  Creating software key for import test..." -ForegroundColor White
    
    # Create with software provider
    $softKey = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        "test-software-key",
        [System.Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
    )
    
    Write-Host "    ✓ Software key created" -ForegroundColor Green
    
    # Try to export from software key
    $privateBlob = $softKey.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
    Write-Host "    ✓ Software key exported: $($privateBlob.Length) bytes" -ForegroundColor Green
    
    # Try to import to TPM
    try {
        $importedKey = [System.Security.Cryptography.CngKey]::Import(
            $privateBlob,
            [System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob,
            [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
        )
        
        Write-Host "    ✓ Import to TPM: SUCCESS" -ForegroundColor Green
        
        # Test signing with imported key
        $ecdsa = [System.Security.Cryptography.ECDsaCng]::new($importedKey)
        $testData = [System.Text.Encoding]::UTF8.GetBytes("test data")
        $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($testData)
        $signature = $ecdsa.SignHash($hash)
        
        Write-Host "    ✓ Signing with imported TPM key: SUCCESS" -ForegroundColor Green
        
        $ecdsa.Dispose()
        $importedKey.Delete()
        $importedKey.Dispose()
        
    }
    catch {
        Write-Host "    ✗ Import to TPM failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $softKey.Delete()
    $softKey.Dispose()
}
catch {
    Write-Host "  ✗ Software key creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. Testing TPM 2.0 Tools Availability..." -ForegroundColor Cyan

$tpm2Tools = @("tpm2_create", "tpm2_load", "tpm2_sign", "tpm2_createprimary")
foreach ($tool in $tpm2Tools) {
    try {
        $result = & $tool --help 2>$null
        if ($LASTEXITCODE -eq 0 -or $result) {
            Write-Host "  ✓ ${tool}: Available" -ForegroundColor Green
        } else {
            Write-Host "  ✗ ${tool}: Not found" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ✗ ${tool}: Not found" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "=== TPM Capability Summary ===" -ForegroundColor Green

Write-Host "`nSupported Export Policies:" -ForegroundColor Cyan
foreach ($policy in $supportedPolicies) {
    if ($policy.Supported) {
        Write-Host "  ✓ $($policy.Policy)" -ForegroundColor Green
        if ($policy.SupportedFormats) {
            Write-Host "    Formats: $($policy.SupportedFormats -join ', ')" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✗ $($policy.Policy): $($policy.Error)" -ForegroundColor Red
    }
}

Write-Host "`nRecommendations for HSM Implementation:" -ForegroundColor Yellow

$workingPolicies = $supportedPolicies | Where-Object { $_.Supported -and $_.SupportedFormats.Count -gt 0 }

if ($workingPolicies.Count -gt 0) {
    Write-Host "✓ Your TPM supports key export! Use these policies:" -ForegroundColor Green
    foreach ($policy in $workingPolicies) {
        Write-Host "  • $($policy.Policy) with formats: $($policy.SupportedFormats -join ', ')" -ForegroundColor White
    }
} else {
    Write-Host "✗ Your TPM does not support key export through CNG" -ForegroundColor Red
    Write-Host "  Consider using TPM 2.0 tools directly or alternative approaches" -ForegroundColor Yellow
}

Write-Host ""