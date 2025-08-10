param(
    [string]$KeyName,
    [string]$CommonName,
    [string]$Organization = "TPM20 Organization",
    [string]$Country = "US"
)

try {
    Write-Host "Generating CSR for CNG key: $KeyName"
    
    # Load required assemblies
    Add-Type -AssemblyName System.Security
    
    # Open the existing CNG key
    $provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    
    # Try to open the key with different name formats
    $key = $null
    $keyOpened = $false
    
    # Try with the key name directly first (might be the full handle)
    try {
        $key = [System.Security.Cryptography.CngKey]::Open($KeyName, $provider)
        Write-Host "Opened CNG key successfully with name: $KeyName"
        $keyOpened = $true
    } catch {
        Write-Host "Could not open key with direct name, trying with prefix..."
    }
    
    # Try with TPM_ES256_ prefix if direct didn't work
    if (-not $keyOpened) {
        try {
            $keyNameFull = "TPM_ES256_$KeyName"
            $key = [System.Security.Cryptography.CngKey]::Open($keyNameFull, $provider)
            Write-Host "Opened CNG key successfully with name: $keyNameFull"
            $keyOpened = $true
        } catch {
            Write-Host "Could not open key with TPM_ES256_ prefix..."
        }
    }
    
    # Try using PowerShell to enumerate keys via registry/CNG API
    if (-not $keyOpened) {
        Write-Host "Enumerating keys using alternative method..."
        try {
            # Use CNG.exe or PowerShell commands to list keys
            $keyList = & powershell -Command "Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Cryptography\Calais\Current\' -Recurse | Where-Object { `$_.PSChildName -like '*$KeyName*' }"
            
            if ($keyList) {
                # Try each potential key name
                foreach ($keyEntry in $keyList) {
                    try {
                        $potentialName = $keyEntry.PSChildName
                        $key = [System.Security.Cryptography.CngKey]::Open($potentialName, $provider)
                        Write-Host "Found and opened key: $potentialName"
                        $keyOpened = $true
                        break
                    } catch {
                        continue
                    }
                }
            }
        } catch {
            Write-Host "Registry enumeration failed, trying direct approaches"
        }
    }
    
    # Try a few more common variations if still not found
    if (-not $keyOpened) {
        $variations = @(
            $KeyName.ToUpper(),
            $KeyName.ToLower(),
            "ES256_$KeyName",
            "CNG_$KeyName"
        )
        
        foreach ($variation in $variations) {
            try {
                $key = [System.Security.Cryptography.CngKey]::Open($variation, $provider)
                Write-Host "Opened key with variation: $variation"
                $keyOpened = $true
                break
            } catch {
                continue
            }
        }
    }
    
    if (-not $keyOpened) {
        throw "Could not find or open CNG key: $KeyName. Please verify the key exists and is accessible."
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
    Write-Host "Using key container: $($key.UniqueName)"
    
    # Create the certificate request using CertEnroll COM objects
    $pkcs10 = New-Object -ComObject X509Enrollment.CX509CertificateRequestPkcs10
    $privateKey = New-Object -ComObject X509Enrollment.CX509PrivateKey
    
    # Configure the private key to use existing key
    $privateKey.ExistingKey = $true
    $privateKey.ProviderName = "Microsoft Platform Crypto Provider"
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
        KeyName = $KeyName
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