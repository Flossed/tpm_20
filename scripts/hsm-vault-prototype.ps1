# ZANDD HSM Vault Prototype - Hybrid Approach
# Demonstrates TPM primary key protecting individual vault entries

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("init", "derive", "wrap", "unwrap", "list")]
    [string]$Operation = "init",
    
    [string]$VaultPath = ".\vault",
    [string]$KeyName = "",
    [string]$KeyData = "",
    [string]$PrimaryHandle = "0x81000100"
)

$ErrorActionPreference = "Stop"

function Initialize-Vault {
    param([string]$Path)
    
    Write-Host "=== Initializing HSM Vault ===" -ForegroundColor Cyan
    
    # Create vault directory structure
    $vaultDirs = @(
        $Path,
        "$Path\keys",
        "$Path\metadata",
        "$Path\temp"
    )
    
    foreach ($dir in $vaultDirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "✓ Created directory: $dir" -ForegroundColor Green
        }
    }
    
    # Create vault manifest
    $manifest = @{
        version = "1.0.0"
        created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        tpmHandle = $PrimaryHandle
        keyDerivationMethod = "TPM2_KDF"
        encryptionAlgorithm = "AES-256-GCM"
        provider = "ZANDD HSM"
    }
    
    $manifestPath = "$Path\manifest.json"
    $manifest | ConvertTo-Json | Set-Content -Path $manifestPath
    Write-Host "✓ Created vault manifest" -ForegroundColor Green
    
    return @{
        success = $true
        vaultPath = $Path
        message = "Vault initialized successfully"
    }
}

function Derive-VaultKey {
    param([string]$Context)
    
    Write-Host "`nDeriving vault key from TPM primary..." -ForegroundColor Cyan
    
    # In production, this would use TPM2_KDF to derive a key
    # For prototype, we'll simulate with a deterministic derivation
    
    $keyMaterial = @{
        context = $Context
        timestamp = Get-Date -Format "yyyyMMddHHmmss"
        tpmHandle = $PrimaryHandle
    }
    
    # Simulate TPM key derivation (in production, use actual TPM KDF)
    $derivedKey = [System.Convert]::ToBase64String(
        [System.Text.Encoding]::UTF8.GetBytes(
            ($keyMaterial | ConvertTo-Json -Compress)
        )
    )
    
    Write-Host "✓ Derived vault key for context: $Context" -ForegroundColor Green
    
    return @{
        success = $true
        keyContext = $Context
        derivedKey = $derivedKey.Substring(0, 32)  # Truncate for demo
        expiresAt = (Get-Date).AddHours(1).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

function Wrap-Key {
    param(
        [string]$KeyName,
        [string]$KeyData,
        [string]$VaultPath
    )
    
    Write-Host "`n=== Wrapping Key: $KeyName ===" -ForegroundColor Cyan
    
    # Derive wrapping key specific to this key
    $wrapKey = Derive-VaultKey -Context "wrap:$KeyName"
    
    if (-not $wrapKey.success) {
        throw "Failed to derive wrapping key"
    }
    
    # Create key envelope
    $envelope = @{
        keyId = [Guid]::NewGuid().ToString()
        keyName = $KeyName
        algorithm = "AES-256-GCM"
        created = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        wrapped = $true
        
        # In production: Encrypt KeyData with derived key
        # For prototype: Base64 encode with marker
        encryptedData = "WRAPPED:$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($KeyData)))"
        
        # Metadata (stored in clear)
        metadata = @{
            purpose = "signing"
            keyType = "RSA-2048"
            createdBy = $env:USERNAME
        }
    }
    
    # Save wrapped key
    $keyPath = "$VaultPath\keys\$KeyName.vault"
    $envelope | ConvertTo-Json | Set-Content -Path $keyPath
    
    Write-Host "✓ Key wrapped and stored: $keyPath" -ForegroundColor Green
    Write-Host "  Key ID: $($envelope.keyId)" -ForegroundColor White
    
    # Update index (encrypted in production)
    $indexPath = "$VaultPath\metadata\index.json"
    $index = if (Test-Path $indexPath) {
        Get-Content $indexPath | ConvertFrom-Json
    } else {
        @{ keys = @{} }
    }
    
    $index.keys[$KeyName] = @{
        keyId = $envelope.keyId
        created = $envelope.created
        algorithm = $envelope.algorithm
    }
    
    $index | ConvertTo-Json | Set-Content -Path $indexPath
    Write-Host "✓ Vault index updated" -ForegroundColor Green
    
    return @{
        success = $true
        keyId = $envelope.keyId
        keyName = $KeyName
        storagePath = $keyPath
    }
}

function Unwrap-Key {
    param(
        [string]$KeyName,
        [string]$VaultPath
    )
    
    Write-Host "`n=== Unwrapping Key: $KeyName ===" -ForegroundColor Cyan
    
    $keyPath = "$VaultPath\keys\$KeyName.vault"
    
    if (-not (Test-Path $keyPath)) {
        throw "Key not found: $KeyName"
    }
    
    # Load wrapped key
    $envelope = Get-Content $keyPath | ConvertFrom-Json
    Write-Host "✓ Loaded key envelope" -ForegroundColor Green
    
    # Derive unwrapping key
    $unwrapKey = Derive-VaultKey -Context "wrap:$KeyName"
    
    if (-not $unwrapKey.success) {
        throw "Failed to derive unwrapping key"
    }
    
    # Unwrap the key (in production: actual decryption)
    $wrappedData = $envelope.encryptedData
    if ($wrappedData -match "^WRAPPED:(.+)$") {
        $keyData = [Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($Matches[1])
        )
        
        Write-Host "✓ Key unwrapped successfully" -ForegroundColor Green
        Write-Host "  Key ID: $($envelope.keyId)" -ForegroundColor White
        Write-Host "  Created: $($envelope.created)" -ForegroundColor White
        
        return @{
            success = $true
            keyId = $envelope.keyId
            keyName = $envelope.keyName
            keyData = $keyData
            metadata = $envelope.metadata
        }
    } else {
        throw "Invalid wrapped key format"
    }
}

function List-Keys {
    param([string]$VaultPath)
    
    Write-Host "`n=== Vault Keys ===" -ForegroundColor Cyan
    
    $indexPath = "$VaultPath\metadata\index.json"
    
    if (-not (Test-Path $indexPath)) {
        Write-Host "No keys in vault" -ForegroundColor Yellow
        return @{ success = $true; keys = @() }
    }
    
    $index = Get-Content $indexPath | ConvertFrom-Json
    $keyList = @()
    
    foreach ($keyName in $index.keys.PSObject.Properties.Name) {
        $keyInfo = $index.keys.$keyName
        $keyList += @{
            name = $keyName
            keyId = $keyInfo.keyId
            created = $keyInfo.created
            algorithm = $keyInfo.algorithm
        }
        
        Write-Host "  • $keyName" -ForegroundColor White
        Write-Host "    ID: $($keyInfo.keyId)" -ForegroundColor Gray
        Write-Host "    Created: $($keyInfo.created)" -ForegroundColor Gray
    }
    
    Write-Host "`nTotal keys: $($keyList.Count)" -ForegroundColor Green
    
    return @{
        success = $true
        keys = $keyList
    }
}

# Main execution
try {
    $result = switch ($Operation) {
        "init" {
            Initialize-Vault -Path $VaultPath
        }
        "derive" {
            Derive-VaultKey -Context "vault:master"
        }
        "wrap" {
            if (-not $KeyName -or -not $KeyData) {
                throw "KeyName and KeyData are required for wrap operation"
            }
            Wrap-Key -KeyName $KeyName -KeyData $KeyData -VaultPath $VaultPath
        }
        "unwrap" {
            if (-not $KeyName) {
                throw "KeyName is required for unwrap operation"
            }
            Unwrap-Key -KeyName $KeyName -VaultPath $VaultPath
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