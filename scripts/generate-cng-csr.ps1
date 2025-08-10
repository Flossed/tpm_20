
param(
    [string]$KeyName,
    [string]$CommonName,
    [string]$Organization = "TPM20 Organization",
    [string]$Country = "US"
)

try {
    Write-Host "🔑 Generating CSR for CNG key: $KeyName"
    
    # Open the existing CNG key
    $provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    
    # Try to open the key
    try {
        $key = [System.Security.Cryptography.CngKey]::Open("TPM_ES256_$KeyName", $provider)
        Write-Host "✓ Opened CNG key successfully"
    } catch {
        # Try without TPM_ES256_ prefix
        $key = [System.Security.Cryptography.CngKey]::Open($KeyName, $provider)
        Write-Host "✓ Opened CNG key successfully (without prefix)"
    }
    
    # Create CSR using CertReq
    $subject = "CN=$CommonName, O=$Organization, C=$Country"
    $infFile = [System.IO.Path]::GetTempFileName() + ".inf"
    $csrFile = [System.IO.Path]::GetTempFileName() + ".csr"
    
    # Create INF file for CertReq
    $infContent = @"
[NewRequest]
Subject = "$subject"
KeySpec = 1
KeyUsage = 0xA0
MachineKeySet = FALSE
ProviderName = "Microsoft Platform Crypto Provider"
ProviderType = 0
UseExistingKeySet = TRUE
KeyContainer = "$($key.UniqueName)"
RequestType = PKCS10
"@
    
    [System.IO.File]::WriteAllText($infFile, $infContent)
    
    # Generate CSR using certreq
    $result = & certreq -new $infFile $csrFile 2>&1
    
    if (Test-Path $csrFile) {
        $csrContent = Get-Content $csrFile -Raw
        
        # Clean up temp files
        Remove-Item $infFile -Force -ErrorAction SilentlyContinue
        Remove-Item $csrFile -Force -ErrorAction SilentlyContinue
        
        # Output as JSON
        $output = @{
            Success = $true
            CSR = $csrContent
            Subject = $subject
            KeyName = $KeyName
        }
        
        Write-Host "✓ CSR generated successfully"
        $output | ConvertTo-Json -Compress
    } else {
        throw "Failed to generate CSR: $result"
    }
    
} catch {
    $output = @{
        Success = $false
        Error = $_.Exception.Message
    }
    Write-Host "✗ ERROR: $_"
    $output | ConvertTo-Json -Compress
    exit 1
}
