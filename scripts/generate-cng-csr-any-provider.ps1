param(
    [string]$KeyName,
    [string]$CommonName,
    [string]$Organization = "TPM20 Organization",
    [string]$Country = "US"
)

try {
    Write-Host "Generating CSR for CNG key: $KeyName (any provider)"
    
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
    
    # Create a certificate request using .NET
    Write-Host "Creating certificate request..."
    
    # Build the X.500 Distinguished Name
    $distinguishedName = "CN=$CommonName"
    if ($Organization) {
        $distinguishedName += ", O=$Organization"
    }
    if ($Country -and $Country.Length -eq 2) {
        $distinguishedName += ", C=$Country"
    }
    
    Write-Host "Using subject: $distinguishedName"
    Write-Host "Using key: $actualKeyName"
    Write-Host "Key provider: $($key.Provider.Provider)"
    
    # Create the certificate request using CertEnroll COM objects
    $pkcs10 = New-Object -ComObject X509Enrollment.CX509CertificateRequestPkcs10
    $privateKey = New-Object -ComObject X509Enrollment.CX509PrivateKey
    
    # Configure the private key to use existing key
    $privateKey.ExistingKey = $true
    $privateKey.ProviderName = $key.Provider.Provider
    $privateKey.ContainerName = $key.UniqueName
    $privateKey.KeySpec = 1  # XCN_AT_KEYEXCHANGE
    
    # Initialize the private key
    $privateKey.Open()
    
    # Initialize the PKCS10 request
    $pkcs10.InitializeFromPrivateKey(
        0x2, # Context = User
        $privateKey,
        ""  # Template name (empty for no template)
    )
    
    # Set the subject
    $subjectDN = New-Object -ComObject X509Enrollment.CX500DistinguishedName
    $subjectDN.Encode($distinguishedName, 0)
    $pkcs10.Subject = $subjectDN
    
    # Set key usage for digital signature
    try {
        $keyUsageExt = New-Object -ComObject X509Enrollment.CX509ExtensionKeyUsage
        $keyUsageExt.InitializeEncode(0xA0) # DigitalSignature | NonRepudiation
        $keyUsageExt.Critical = $true
        $pkcs10.X509Extensions.Add($keyUsageExt)
        Write-Host "Added key usage extension"
    } catch {
        Write-Host "Warning: Could not add key usage extension: $($_.Exception.Message)"
    }
    
    # Create the enrollment object
    $enrollment = New-Object -ComObject X509Enrollment.CX509Enrollment
    $enrollment.InitializeFromRequest($pkcs10)
    
    # Generate the CSR
    Write-Host "Generating CSR..."
    $csrContent = $enrollment.CreateRequest(0x1) # Base64
    
    # Format as PEM
    $pemCSR = "-----BEGIN CERTIFICATE REQUEST-----`n"
    $pemCSR += $csrContent
    $pemCSR += "`n-----END CERTIFICATE REQUEST-----"
    
    # Output as JSON
    $output = @{
        Success = $true
        CSR = $pemCSR
        Subject = $distinguishedName
        KeyName = $actualKeyName
        Provider = $key.Provider.Provider
        ContainerName = $key.UniqueName
    }
    
    Write-Host "CSR generated successfully"
    $output | ConvertTo-Json -Compress
    
} catch {
    $output = @{
        Success = $false
        Error = $_.Exception.Message
        Details = $_.Exception.GetType().FullName
    }
    Write-Host "ERROR: $_"
    $output | ConvertTo-Json -Compress
    exit 1
}