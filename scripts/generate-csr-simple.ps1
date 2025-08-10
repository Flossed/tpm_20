param(
    [string]$KeyName,
    [string]$CommonName,
    [string]$Organization = "TPM20 Organization",
    [string]$Country = "US"
)

try {
    Write-Host "Generating CSR for CNG key: $KeyName (simple approach)"
    
    # Load required assemblies
    Add-Type -AssemblyName System.Security
    
    # Try to open the key without specifying provider (let system choose)
    $key = $null
    $keyOpened = $false
    
    # Try different name variations
    $variations = @(
        $KeyName,
        "TPM_ES256_$KeyName",
        $KeyName.Replace("TPM_ES256_", "")
    )
    
    foreach ($variation in $variations) {
        try {
            Write-Host "Attempting to open key: $variation"
            $key = [System.Security.Cryptography.CngKey]::Open($variation)
            Write-Host "SUCCESS: Opened key $variation"
            Write-Host "Provider: $($key.Provider.Provider)"
            $keyOpened = $true
            $actualKeyName = $variation
            break
        } catch {
            Write-Host "Failed to open $variation - $($_.Exception.Message)"
            continue
        }
    }
    
    if (-not $keyOpened) {
        throw "Could not find or open CNG key with any variation of: $KeyName"
    }
    
    # Build the subject
    $subject = "CN=$CommonName"
    if ($Organization) { $subject += ", O=$Organization" }
    if ($Country -and $Country.Length -eq 2) { $subject += ", C=$Country" }
    
    Write-Host "Using subject: $subject"
    Write-Host "Using key: $actualKeyName"
    Write-Host "Key provider: $($key.Provider.Provider)"
    
    # Use certreq to generate CSR with the key
    $tempInfFile = "$env:TEMP\csr_request_$([System.Guid]::NewGuid().ToString()).inf"
    $tempReqFile = "$env:TEMP\csr_request_$([System.Guid]::NewGuid().ToString()).req"
    
    # Create INF file for certreq
    $infContent = @"
[Version]
Signature = "`$Windows NT`$"

[NewRequest]
Subject = "$subject"
KeyAlgorithm = ECDSA_P256
KeyContainer = "$($key.UniqueName)"
ProviderName = "$($key.Provider.Provider)"
ProviderType = 0
RequestType = PKCS10
KeyUsage = 0xA0
"@
    
    Write-Host "Creating INF file: $tempInfFile"
    $infContent | Out-File -FilePath $tempInfFile -Encoding ASCII
    
    # Generate CSR using certreq
    Write-Host "Running certreq to generate CSR..."
    $certreqOutput = & certreq -new "$tempInfFile" "$tempReqFile" 2>&1
    Write-Host "Certreq output: $certreqOutput"
    
    if (Test-Path $tempReqFile) {
        $csrContent = Get-Content $tempReqFile -Raw
        Write-Host "CSR file created successfully"
        
        # Clean up temp files
        Remove-Item $tempInfFile -Force -ErrorAction SilentlyContinue
        Remove-Item $tempReqFile -Force -ErrorAction SilentlyContinue
        
        $output = @{
            Success = $true
            CSR = $csrContent.Trim()
            Subject = $subject
            KeyName = $actualKeyName
            Provider = $key.Provider.Provider
            ContainerName = $key.UniqueName
        }
        
        Write-Host "CSR generated successfully"
        $output | ConvertTo-Json -Compress
    } else {
        # Clean up temp files
        Remove-Item $tempInfFile -Force -ErrorAction SilentlyContinue
        Remove-Item $tempReqFile -Force -ErrorAction SilentlyContinue
        
        throw "Certreq failed to create CSR file. Output: $certreqOutput"
    }
    
} catch {
    $output = @{
        Success = $false
        Error = $_.Exception.Message
        Details = $_.Exception.GetType().FullName
    }
    Write-Host "ERROR: $_"
    $output | ConvertTo-Json -Compress
    exit 1
} finally {
    # Ensure cleanup
    if ($key) {
        $key.Dispose()
    }
}