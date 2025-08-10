# Debug TPM Export Issue
# Investigates why key export fails in the real workflow

$ErrorActionPreference = "Stop"

Write-Host "=== Debugging TPM Export Issue ===" -ForegroundColor Cyan
Write-Host ""

# Check admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "ERROR: Administrator privileges required!" -ForegroundColor Red
    exit 1
}

Add-Type -AssemblyName System.Security

Write-Host "Testing different key creation approaches..." -ForegroundColor Yellow
Write-Host ""

# Test 1: Minimal key creation (like capability test)
Write-Host "Test 1: Minimal key creation (like capability test)" -ForegroundColor Cyan
try {
    $keyName1 = "debug-minimal-$(Get-Random)"
    
    $cngKeyParams1 = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $cngKeyParams1.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
    $cngKeyParams1.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $cngKeyParams1.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowArchiving
    
    $key1 = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $keyName1,
        $cngKeyParams1
    )
    
    Write-Host "  ✓ Key created successfully" -ForegroundColor Green
    Write-Host "    Key Name: $($key1.KeyName)" -ForegroundColor Gray
    Write-Host "    Key Size: $($key1.KeySize)" -ForegroundColor Gray
    Write-Host "    Algorithm: $($key1.Algorithm.Algorithm)" -ForegroundColor Gray
    Write-Host "    Provider: $($key1.Provider.Provider)" -ForegroundColor Gray
    
    # Try to export
    try {
        $privateBlob1 = $key1.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
        Write-Host "  ✓ EccPrivateBlob export: SUCCESS ($($privateBlob1.Length) bytes)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ EccPrivateBlob export failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    try {
        $publicBlob1 = $key1.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
        Write-Host "  ✓ EccPublicBlob export: SUCCESS ($($publicBlob1.Length) bytes)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ EccPublicBlob export failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $key1.Delete()
    $key1.Dispose()
}
catch {
    Write-Host "  ✗ Test 1 failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 2: Try with persistent key
Write-Host "Test 2: Persistent key creation" -ForegroundColor Cyan
try {
    $keyName2 = "debug-persistent-$(Get-Random)"
    
    $cngKeyParams2 = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $cngKeyParams2.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
    $cngKeyParams2.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $cngKeyParams2.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowArchiving
    
    # Try making key persistent
    $property = [System.Security.Cryptography.CngProperty]::new(
        "CLR IsEphemeral", 
        [System.BitConverter]::GetBytes($false), 
        [System.Security.Cryptography.CngPropertyOptions]::None
    )
    $cngKeyParams2.Parameters.Add($property)
    
    $key2 = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $keyName2,
        $cngKeyParams2
    )
    
    Write-Host "  ✓ Persistent key created successfully" -ForegroundColor Green
    
    # Try to export
    try {
        $privateBlob2 = $key2.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
        Write-Host "  ✓ EccPrivateBlob export: SUCCESS ($($privateBlob2.Length) bytes)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ EccPrivateBlob export failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $key2.Delete()
    $key2.Dispose()
}
catch {
    Write-Host "  ✗ Test 2 failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 3: Try with null key name (let TPM generate)
Write-Host "Test 3: Auto-generated key name" -ForegroundColor Cyan
try {
    $cngKeyParams3 = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $cngKeyParams3.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
    $cngKeyParams3.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $cngKeyParams3.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowArchiving
    
    # Let TPM auto-generate key name
    $key3 = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $null,  # Let TPM choose name
        $cngKeyParams3
    )
    
    Write-Host "  ✓ Auto-named key created successfully" -ForegroundColor Green
    Write-Host "    Auto Key Name: $($key3.KeyName)" -ForegroundColor Gray
    
    # Try to export
    try {
        $privateBlob3 = $key3.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
        Write-Host "  ✓ EccPrivateBlob export: SUCCESS ($($privateBlob3.Length) bytes)" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ EccPrivateBlob export failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $key3.Delete()
    $key3.Dispose()
}
catch {
    Write-Host "  ✗ Test 3 failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""

# Test 4: Try different export policies
Write-Host "Test 4: Testing AllowPlaintextArchiving" -ForegroundColor Cyan
try {
    $keyName4 = "debug-plaintext-$(Get-Random)"
    
    $cngKeyParams4 = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $cngKeyParams4.Provider = [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
    $cngKeyParams4.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $cngKeyParams4.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowPlaintextArchiving
    
    $key4 = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $keyName4,
        $cngKeyParams4
    )
    
    Write-Host "  ✓ PlaintextArchiving key created successfully" -ForegroundColor Green
    
    # Try to export
    try {
        $privateBlob4 = $key4.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob)
        Write-Host "  ✓ EccPrivateBlob export: SUCCESS ($($privateBlob4.Length) bytes)" -ForegroundColor Green
        
        # If this works, test import
        try {
            $importedKey = [System.Security.Cryptography.CngKey]::Import(
                $privateBlob4,
                [System.Security.Cryptography.CngKeyBlobFormat]::EccPrivateBlob,
                [System.Security.Cryptography.CngProvider]::new("Microsoft Platform Crypto Provider")
            )
            
            Write-Host "  ✓ Import back to TPM: SUCCESS" -ForegroundColor Green
            
            # Test signing
            $ecdsa = [System.Security.Cryptography.ECDsaCng]::new($importedKey)
            $testData = [System.Text.Encoding]::UTF8.GetBytes("test signing")
            $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($testData)
            $signature = $ecdsa.SignHash($hash)
            
            Write-Host "  ✓ Sign with imported key: SUCCESS" -ForegroundColor Green
            
            $isValid = $ecdsa.VerifyHash($hash, $signature)
            Write-Host "  ✓ Verify signature: $(if($isValid) {'SUCCESS'} else {'FAILED'})" -ForegroundColor $(if($isValid) {'Green'} else {'Red'})
            
            $ecdsa.Dispose()
            $importedKey.Delete()
            $importedKey.Dispose()
            
        }
        catch {
            Write-Host "  ✗ Import/Sign test failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "  ✗ EccPrivateBlob export failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    $key4.Delete()
    $key4.Dispose()
}
catch {
    Write-Host "  ✗ Test 4 failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Diagnosis Complete ===" -ForegroundColor Green
Write-Host "Look for which test passes completely for the working configuration." -ForegroundColor Yellow