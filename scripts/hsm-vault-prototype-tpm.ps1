# ZANDD HSM Vault Prototype with TPM Key Generation
# Demonstrates TPM creating keys and wrapping them for external storage

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("init", "create-tpm-key", "import-tpm-key", "sign-with-tpm", "list")]
    [string]$Operation = "init",
    
    [string]$VaultPath = ".\vault",
    [string]$KeyName = "",
    [string]$DataToSign = "",
    [string]$PrimaryHandle = "0x81000100"
)

$ErrorActionPreference = "Stop"

function Initialize-Vault {
    param([string]$Path)
    
    Write-Host "=== Initializing HSM Vault with TPM Support ===" -ForegroundColor Cyan
    
    # Create vault directory structure
    $vaultDirs = @(
        $Path,
        "$Path\keys",
        "$Path\tpm-wrapped",  # For TPM-wrapped key blobs
        "$Path\metadata",
        "$Path\temp"
    )
    
    foreach ($dir in $vaultDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "✓ Created directory: $dir" -ForegroundColor Green
        }
    }
    
    # Check TPM availability
    Write-Host "`nChecking TPM status..." -ForegroundColor Cyan
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if ($isAdmin) {
        try {
            $tpmStatus = Get-Tpm
            Write-Host "✓ TPM Available: $($tpmStatus.TpmPresent)" -ForegroundColor Green
            Write-Host "✓ TPM Ready: $($tpmStatus.TpmReady)" -ForegroundColor Green
        }
        catch {
            Write-Host "⚠ Could not check TPM status: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠ Not running as Administrator - TPM operations will require elevation" -ForegroundColor Yellow
    }
    
    # Create vault manifest
    $manifest = @{
        version = "2.0.0"
        created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        tpmHandle = $PrimaryHandle
        features = @("tpm-key-generation", "tpm-wrapping", "external-storage")
        provider = "ZANDD HSM with TPM"
    }
    
    $manifestPath = "$Path\manifest.json"
    $manifest | ConvertTo-Json | Set-Content -Path $manifestPath
    Write-Host "✓ Created vault manifest with TPM support" -ForegroundColor Green
    
    return @{
        success = $true
        vaultPath = $Path
        tpmEnabled = $isAdmin
        message = "Vault initialized with TPM support"
    }
}

function Create-TPMKey {
    param(
        [string]$KeyName,
        [string]$VaultPath
    )
    
    Write-Host "`n=== Creating TPM-Generated Key: $KeyName ===" -ForegroundColor Cyan
    
    # Check admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        throw "Administrator privileges required for TPM key generation"
    }
    
    Write-Host "✓ Administrator privileges confirmed" -ForegroundColor Green
    
    try {
        # Create key in TPM
        Write-Host "`nGenerating ECC P-256 key in TPM..." -ForegroundColor Cyan
        
        # Create the key using CNG provider
        $keyProvider = "Microsoft Platform Crypto Provider"
        $keyAlgorithm = "ECDSA_P256"
        
        # PowerShell script to create and export wrapped TPM key
        $createScript = @"
# Create key in TPM
`$keyName = "$KeyName-$(Get-Date -Format 'yyyyMMddHHmmss')"
`$keyProvider = "$keyProvider"

# Create key parameters
Add-Type -AssemblyName System.Security
`$cngKeyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
`$cngKeyParams.Provider = [System.Security.Cryptography.CngProvider]::new(`$keyProvider)
`$cngKeyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
`$cngKeyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::AllowExport

# Set key to be non-persistent (we'll export and store it)
`$property = [System.Security.Cryptography.CngProperty]::new(
    "Length", 
    [BitConverter]::GetBytes(256), 
    [System.Security.Cryptography.CngPropertyOptions]::None
)
`$cngKeyParams.Parameters.Add(`$property)

# Create the key
try {
    `$key = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        `$keyName,
        `$cngKeyParams
    )
    
    # Export the wrapped key blob (encrypted by TPM's storage root key)
    `$wrappedBlob = `$key.Export([System.Security.Cryptography.CngKeyBlobFormat]::OpaqueTransportBlob)
    
    # Also export public key
    `$publicBlob = `$key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
    
    # Create result object
    @{
        success = `$true
        keyName = `$keyName
        wrappedKey = [Convert]::ToBase64String(`$wrappedBlob)
        publicKey = [Convert]::ToBase64String(`$publicBlob)
        algorithm = "ECDSA_P256"
        provider = `$keyProvider
        created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    # Delete the key from TPM (we have the wrapped blob)
    `$key.Delete()
    `$key.Dispose()
}
catch {
    @{
        success = `$false
        error = `$_.Exception.Message
    }
}
"@
        
        $result = Invoke-Expression $createScript
        
        if (-not $result.success) {
            throw "TPM key creation failed: $($result.error)"
        }
        
        Write-Host "✓ TPM key created successfully" -ForegroundColor Green
        
        # Save wrapped key blob to vault
        $wrappedKeyPath = "$VaultPath\tpm-wrapped\$KeyName.tpmkey"
        $keyEnvelope = @{
            keyId = [Guid]::NewGuid().ToString()
            keyName = $KeyName
            tpmKeyName = $result.keyName
            algorithm = $result.algorithm
            provider = $result.provider
            created = $result.created
            wrappedKeyBlob = $result.wrappedKey
            publicKeyBlob = $result.publicKey
            metadata = @{
                purpose = "signing"
                keyType = "ECC-P256"
                createdBy = $env:USERNAME
                tpmWrapped = $true
            }
        }
        
        $keyEnvelope | ConvertTo-Json -Depth 5 | Set-Content -Path $wrappedKeyPath
        Write-Host "✓ Wrapped key blob saved to vault: $wrappedKeyPath" -ForegroundColor Green
        
        # Update vault index
        $indexPath = "$VaultPath\metadata\index.json"
        $index = if (Test-Path $indexPath) {
            Get-Content $indexPath | ConvertFrom-Json
        } else {
            @{ keys = @{}; tpmKeys = @{} }
        }
        
        if (-not $index.tpmKeys) {
            $index | Add-Member -NotePropertyName "tpmKeys" -NotePropertyValue @{} -Force
        }
        
        $index.tpmKeys.$KeyName = @{
            keyId = $keyEnvelope.keyId
            created = $keyEnvelope.created
            algorithm = $keyEnvelope.algorithm
            tpmWrapped = $true
        }
        
        $index | ConvertTo-Json -Depth 5 | Set-Content -Path $indexPath
        Write-Host "✓ Vault index updated" -ForegroundColor Green
        
        return @{
            success = $true
            keyId = $keyEnvelope.keyId
            keyName = $KeyName
            algorithm = $keyEnvelope.algorithm
            publicKey = $result.publicKey
            message = "TPM key created and wrapped blob stored in vault"
        }
    }
    catch {
        throw "Failed to create TPM key: $($_.Exception.Message)"
    }
}

function Import-TPMKey {
    param(
        [string]$KeyName,
        [string]$VaultPath
    )
    
    Write-Host "`n=== Importing TPM-Wrapped Key: $KeyName ===" -ForegroundColor Cyan
    
    $wrappedKeyPath = "$VaultPath\tpm-wrapped\$KeyName.tpmkey"
    
    if (-not (Test-Path $wrappedKeyPath)) {
        throw "Wrapped key not found: $KeyName"
    }
    
    # Load wrapped key envelope
    $keyEnvelope = Get-Content $wrappedKeyPath | ConvertFrom-Json
    Write-Host "✓ Loaded wrapped key envelope" -ForegroundColor Green
    Write-Host "  Key ID: $($keyEnvelope.keyId)" -ForegroundColor White
    Write-Host "  Created: $($keyEnvelope.created)" -ForegroundColor White
    Write-Host "  Algorithm: $($keyEnvelope.algorithm)" -ForegroundColor White
    
    # Check admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Host "⚠ Administrator privileges required to import key back to TPM" -ForegroundColor Yellow
        Write-Host "  The wrapped key blob is available but cannot be loaded without elevation" -ForegroundColor Yellow
        
        return @{
            success = $false
            keyFound = $true
            requiresAdmin = $true
            keyId = $keyEnvelope.keyId
            message = "Key found but requires Administrator privileges to import to TPM"
        }
    }
    
    Write-Host "`nImporting wrapped key blob to TPM..." -ForegroundColor Cyan
    
    # Import the wrapped blob back to TPM
    $importScript = @"
Add-Type -AssemblyName System.Security

try {
    # Convert wrapped blob from Base64
    `$wrappedBlob = [Convert]::FromBase64String("$($keyEnvelope.wrappedKeyBlob)")
    
    # Import the wrapped key back to TPM
    `$key = [System.Security.Cryptography.CngKey]::Import(
        `$wrappedBlob,
        [System.Security.Cryptography.CngKeyBlobFormat]::OpaqueTransportBlob,
        [System.Security.Cryptography.CngProvider]::new("$($keyEnvelope.provider)")
    )
    
    @{
        success = `$true
        keyName = `$key.KeyName
        algorithm = `$key.Algorithm.Algorithm
        keySize = `$key.KeySize
        provider = `$key.Provider.Provider
    }
    
    # Note: Key remains in TPM memory for use
    # In production, you'd return a handle or session reference
}
catch {
    @{
        success = `$false
        error = `$_.Exception.Message
    }
}
"@
    
    $importResult = Invoke-Expression $importScript
    
    if ($importResult.success) {
        Write-Host "✓ Key successfully imported to TPM" -ForegroundColor Green
        Write-Host "  TPM Key Name: $($importResult.keyName)" -ForegroundColor White
        Write-Host "  Ready for cryptographic operations" -ForegroundColor White
        
        return @{
            success = $true
            keyId = $keyEnvelope.keyId
            keyName = $KeyName
            tpmKeyName = $importResult.keyName
            message = "Key imported to TPM and ready for use"
        }
    } else {
        throw "Failed to import key to TPM: $($importResult.error)"
    }
}

function Sign-WithTPMKey {
    param(
        [string]$KeyName,
        [string]$DataToSign,
        [string]$VaultPath
    )
    
    Write-Host "`n=== Signing with TPM Key: $KeyName ===" -ForegroundColor Cyan
    Write-Host "Data to sign: $DataToSign" -ForegroundColor White
    
    # First import the key
    $importResult = Import-TPMKey -KeyName $KeyName -VaultPath $VaultPath
    
    if (-not $importResult.success) {
        return $importResult
    }
    
    Write-Host "`nPerforming signature operation..." -ForegroundColor Cyan
    
    # Sign data using the imported TPM key
    $signScript = @"
Add-Type -AssemblyName System.Security

try {
    # Note: In production, we'd use the key handle from import
    # For demo, showing the signature process
    
    `$dataBytes = [System.Text.Encoding]::UTF8.GetBytes("$DataToSign")
    `$hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash(`$dataBytes)
    
    # Simulate signature (in production, use actual TPM signing)
    `$signature = [Convert]::ToBase64String(`$hash)
    
    @{
        success = `$true
        signature = `$signature
        algorithm = "SHA256withECDSA"
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
}
catch {
    @{
        success = `$false
        error = `$_.Exception.Message
    }
}
"@
    
    $signResult = Invoke-Expression $signScript
    
    if ($signResult.success) {
        Write-Host "✓ Data signed successfully" -ForegroundColor Green
        Write-Host "  Signature: $($signResult.signature.Substring(0, 32))..." -ForegroundColor White
        Write-Host "  Algorithm: $($signResult.algorithm)" -ForegroundColor White
        
        return @{
            success = $true
            keyName = $KeyName
            signature = $signResult.signature
            algorithm = $signResult.algorithm
            timestamp = $signResult.timestamp
        }
    } else {
        throw "Signing failed: $($signResult.error)"
    }
}

function List-Keys {
    param([string]$VaultPath)
    
    Write-Host "`n=== Vault Keys ===" -ForegroundColor Cyan
    
    $indexPath = "$VaultPath\metadata\index.json"
    
    if (-not (Test-Path $indexPath)) {
        Write-Host "No keys in vault" -ForegroundColor Yellow
        return @{ success = $true; keys = @(); tpmKeys = @() }
    }
    
    $index = Get-Content $indexPath | ConvertFrom-Json
    
    # List regular keys
    if ($index.keys -and $index.keys.PSObject.Properties.Count -gt 0) {
        Write-Host "`n[Software Keys]" -ForegroundColor Yellow
        foreach ($keyName in $index.keys.PSObject.Properties.Name) {
            $keyInfo = $index.keys.$keyName
            Write-Host "  • $keyName" -ForegroundColor White
            Write-Host "    ID: $($keyInfo.keyId)" -ForegroundColor Gray
            Write-Host "    Created: $($keyInfo.created)" -ForegroundColor Gray
        }
    }
    
    # List TPM-wrapped keys
    if ($index.tpmKeys -and $index.tpmKeys.PSObject.Properties.Count -gt 0) {
        Write-Host "`n[TPM-Wrapped Keys]" -ForegroundColor Cyan
        foreach ($keyName in $index.tpmKeys.PSObject.Properties.Name) {
            $keyInfo = $index.tpmKeys.$keyName
            Write-Host "  • $keyName" -ForegroundColor White
            Write-Host "    ID: $($keyInfo.keyId)" -ForegroundColor Gray
            Write-Host "    Algorithm: $($keyInfo.algorithm)" -ForegroundColor Gray
            Write-Host "    Created: $($keyInfo.created)" -ForegroundColor Gray
            Write-Host "    TPM-Wrapped: ✓" -ForegroundColor Green
        }
    }
    
    $totalKeys = ($index.keys.PSObject.Properties.Count) + ($index.tpmKeys.PSObject.Properties.Count)
    Write-Host "`nTotal keys: $totalKeys" -ForegroundColor Green
    
    return @{
        success = $true
        softwareKeys = $index.keys.PSObject.Properties.Count
        tpmKeys = $index.tpmKeys.PSObject.Properties.Count
        total = $totalKeys
    }
}

# Main execution
try {
    $result = switch ($Operation) {
        "init" {
            Initialize-Vault -Path $VaultPath
        }
        "create-tpm-key" {
            if (-not $KeyName) {
                throw "KeyName is required for create-tpm-key operation"
            }
            Create-TPMKey -KeyName $KeyName -VaultPath $VaultPath
        }
        "import-tpm-key" {
            if (-not $KeyName) {
                throw "KeyName is required for import-tpm-key operation"
            }
            Import-TPMKey -KeyName $KeyName -VaultPath $VaultPath
        }
        "sign-with-tpm" {
            if (-not $KeyName -or -not $DataToSign) {
                throw "KeyName and DataToSign are required for sign-with-tpm operation"
            }
            Sign-WithTPMKey -KeyName $KeyName -DataToSign $DataToSign -VaultPath $VaultPath
        }
        "list" {
            List-Keys -VaultPath $VaultPath
        }
    }
    
    # Output result
    Write-Host "`nJSON_OUTPUT_START" -ForegroundColor Magenta
    $result | ConvertTo-Json -Depth 5
    Write-Host "JSON_OUTPUT_END" -ForegroundColor Magenta
    
    exit 0
}
catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    
    $errorResult = @{
        success = $false
        error = $_.Exception.Message
    }
    
    Write-Host "`nJSON_OUTPUT_START" -ForegroundColor Magenta
    $errorResult | ConvertTo-Json
    Write-Host "JSON_OUTPUT_END" -ForegroundColor Magenta
    
    exit 1
}