# Create Hardware TPM Key and Generate CSR in One Operation
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName,
    [Parameter(Mandatory=$true)]
    [string]$CommonName,
    [string]$Organization = "TPM Test Org",
    [string]$Country = "US"
)

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Security

try {
    Write-Host "=== CREATE HARDWARE TPM KEY AND GENERATE CSR ===" -ForegroundColor Cyan
    Write-Host "Creating hardware TPM key and CSR for: $KeyName" -ForegroundColor White
    
    # Step 1: Create Hardware TPM Key
    Write-Host "`nStep 1: Creating hardware TPM key..." -ForegroundColor Yellow
    
    $requestedKeyName = "TPM_ES256_$KeyName"
    
    # Create CNG key parameters for hardware TPM
    $keyParams = [System.Security.Cryptography.CngKeyCreationParameters]::new()
    $keyParams.ExportPolicy = [System.Security.Cryptography.CngExportPolicies]::None
    $keyParams.KeyUsage = [System.Security.Cryptography.CngKeyUsages]::Signing
    $keyParams.Provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    
    # Create the key
    $key = [System.Security.Cryptography.CngKey]::Create(
        [System.Security.Cryptography.CngAlgorithm]::ECDsaP256,
        $requestedKeyName,
        $keyParams
    )
    
    if (-not $key) {
        throw "Key creation failed"
    }
    
    $actualTPMName = $key.UniqueName
    $actualProvider = $key.Provider.Provider
    
    Write-Host "SUCCESS: Hardware TPM key created!" -ForegroundColor Green
    Write-Host "  User name: $KeyName" -ForegroundColor White
    Write-Host "  Requested: $requestedKeyName" -ForegroundColor Yellow  
    Write-Host "  Actual TPM path: $actualTPMName" -ForegroundColor Cyan
    Write-Host "  Provider: $actualProvider" -ForegroundColor White
    
    # Export public key
    $publicBlob = $key.Export([System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
    $publicBase64 = [Convert]::ToBase64String($publicBlob)
    
    # Step 2: Generate CSR immediately using the same key object
    Write-Host "`nStep 2: Generating CSR with the same key..." -ForegroundColor Yellow
    
    # Build subject
    $subject = "CN=$CommonName"
    if ($Organization) { $subject += ", O=$Organization" }
    if ($Country -and $Country.Length -eq 2) { $subject += ", C=$Country" }
    
    Write-Host "CSR subject: $subject" -ForegroundColor Cyan
    
    # Use certreq approach with the key's container name
    $tempInfFile = "$env:TEMP\hardware_csr_$([System.Guid]::NewGuid().ToString()).inf"
    $tempReqFile = "$env:TEMP\hardware_csr_$([System.Guid]::NewGuid().ToString()).req"
    
    # Create INF file for certreq using the actual TPM container
    $infContent = @"
[Version]
Signature = "`$Windows NT`$"

[NewRequest]
Subject = "$subject"
KeyAlgorithm = ECDSA_P256
KeyContainer = "$actualTPMName"
ProviderName = "$actualProvider"
ProviderType = 0
RequestType = PKCS10
KeyUsage = 0xA0
"@
    
    Write-Host "Creating INF file with TPM container: $actualTPMName" -ForegroundColor Cyan
    $infContent | Out-File -FilePath $tempInfFile -Encoding ASCII
    
    # Generate CSR using certreq
    Write-Host "Running certreq with hardware TPM key..." -ForegroundColor Cyan
    $certreqOutput = & certreq -new "$tempInfFile" "$tempReqFile" 2>&1
    
    $csrGenerated = $false
    $csrContent = ""
    
    if (Test-Path $tempReqFile) {
        $csrContent = Get-Content $tempReqFile -Raw
        $csrGenerated = $true
        Write-Host "SUCCESS: CSR generated for hardware TPM key!" -ForegroundColor Green
    } else {
        Write-Host "CSR generation failed. Certreq output:" -ForegroundColor Red
        Write-Host $certreqOutput -ForegroundColor Red
    }
    
    # Clean up temp files
    Remove-Item $tempInfFile -Force -ErrorAction SilentlyContinue
    Remove-Item $tempReqFile -Force -ErrorAction SilentlyContinue
    
    # Dispose key
    $key.Dispose()
    
    if ($csrGenerated) {
        # Success result
        $result = @{
            Success = $true
            KeyName = $KeyName
            Handle = $actualTPMName  # The actual TPM path that works
            Algorithm = "ES256"
            Provider = $actualProvider
            PublicKey = $publicBase64
            InTPM = $true
            CSR = $csrContent.Trim()
            Subject = $subject
            Created = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        
        Write-Host ""
        Write-Host "=== COMPLETE SUCCESS ===" -ForegroundColor Green -BackgroundColor Black
        Write-Host "Hardware TPM key created AND CSR generated!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Database should store:" -ForegroundColor Yellow
        Write-Host "  name: '$KeyName'" -ForegroundColor White
        Write-Host "  tmpHandle: '$actualTPMName'" -ForegroundColor Green
        Write-Host "  inTPM: true" -ForegroundColor White
        Write-Host "  provider: '$actualProvider'" -ForegroundColor White
        Write-Host "  certificateRequest: [CSR CONTENT]" -ForegroundColor White
        Write-Host ""
        
        $result | ConvertTo-Json -Compress
    } else {
        throw "CSR generation failed for hardware TPM key"
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    
    $result = @{
        Success = $false
        Error = $_.Exception.Message
        KeyName = $KeyName
    }
    
    $result | ConvertTo-Json -Compress
    exit 1
}