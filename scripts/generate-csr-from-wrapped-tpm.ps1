# ZANDD HSM - Generate CSR from TPM-Wrapped Key
# Creates a Certificate Signing Request using a key that's wrapped by TPM

param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName,
    
    [string]$VaultPath = ".\vault",
    
    # Certificate subject fields
    [string]$CommonName = "ZANDD HSM Certificate",
    [string]$Organization = "ZANDD",
    [string]$OrganizationalUnit = "HSM Division",
    [string]$Country = "US",
    [string]$State = "State",
    [string]$Locality = "City",
    [string]$EmailAddress = "admin@zandd.com"
)

$ErrorActionPreference = "Stop"

function Generate-CSRFromTPMKey {
    param(
        [string]$KeyName,
        [string]$VaultPath,
        [hashtable]$SubjectInfo
    )
    
    Write-Host "=== Generating CSR from TPM-Wrapped Key ===" -ForegroundColor Cyan
    Write-Host "Key Name: $KeyName" -ForegroundColor Yellow
    
    # Check admin privileges
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        throw "Administrator privileges required for TPM CSR generation"
    }
    
    # Load wrapped key metadata
    $wrappedKeyPath = "$VaultPath\tpm-wrapped\$KeyName.tpmkey"
    
    if (-not (Test-Path $wrappedKeyPath)) {
        throw "Wrapped key not found: $KeyName"
    }
    
    $keyEnvelope = Get-Content $wrappedKeyPath | ConvertFrom-Json
    Write-Host "✓ Loaded wrapped key envelope" -ForegroundColor Green
    
    try {
        Write-Host "`nMethod 1: Using CNG and .NET CertificateRequest..." -ForegroundColor Cyan
        
        $csrScript = @"
Add-Type -AssemblyName System.Security

try {
    # Import the wrapped key back to TPM
    Write-Host "  Importing wrapped key to TPM..." -ForegroundColor White
    `$wrappedBlob = [Convert]::FromBase64String("$($keyEnvelope.wrappedKeyBlob)")
    
    # Import with persistence flag for CSR generation
    `$cngProvider = [System.Security.Cryptography.CngProvider]::new("$($keyEnvelope.provider)")
    `$keyName = "$KeyName-CSR-$(Get-Date -Format 'yyyyMMddHHmmss')"
    
    # Import the key
    `$key = [System.Security.Cryptography.CngKey]::Import(
        `$wrappedBlob,
        [System.Security.Cryptography.CngKeyBlobFormat]::OpaqueTransportBlob,
        `$cngProvider
    )
    
    Write-Host "  ✓ Key imported to TPM" -ForegroundColor Green
    
    # Create ECDSA object from the CNG key
    `$ecdsa = [System.Security.Cryptography.ECDsaCng]::new(`$key)
    
    # Build the subject DN
    `$subjectDN = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new(
        "CN=$($SubjectInfo.CommonName), O=$($SubjectInfo.Organization), OU=$($SubjectInfo.OrganizationalUnit), C=$($SubjectInfo.Country), S=$($SubjectInfo.State), L=$($SubjectInfo.Locality), E=$($SubjectInfo.EmailAddress)"
    )
    
    Write-Host "  Creating certificate request..." -ForegroundColor White
    
    # Create the certificate request
    `$certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        `$subjectDN,
        `$ecdsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )
    
    # Add key usage extension
    `$keyUsage = [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new(
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor
        [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::NonRepudiation,
        `$true
    )
    `$certRequest.CertificateExtensions.Add(`$keyUsage)
    
    # Add enhanced key usage
    `$ekuOids = [System.Security.Cryptography.OidCollection]::new()
    `$ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.2")) | Out-Null  # Client Authentication
    `$ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.4")) | Out-Null  # Email Protection
    `$eku = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new(`$ekuOids, `$false)
    `$certRequest.CertificateExtensions.Add(`$eku)
    
    # Add Subject Alternative Name if email is provided
    if ("$($SubjectInfo.EmailAddress)") {
        `$sanBuilder = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
        `$sanBuilder.AddEmailAddress("$($SubjectInfo.EmailAddress)")
        `$san = `$sanBuilder.Build()
        `$certRequest.CertificateExtensions.Add(`$san)
    }
    
    Write-Host "  Signing CSR with TPM key..." -ForegroundColor White
    
    # Create the CSR (signed by the TPM key)
    `$csr = `$certRequest.CreateSigningRequest()
    `$csrBase64 = [Convert]::ToBase64String(`$csr)
    
    # Format as PEM
    `$pemCSR = "-----BEGIN CERTIFICATE REQUEST-----`n"
    for (`$i = 0; `$i -lt `$csrBase64.Length; `$i += 64) {
        `$length = [Math]::Min(64, `$csrBase64.Length - `$i)
        `$pemCSR += `$csrBase64.Substring(`$i, `$length) + "`n"
    }
    `$pemCSR += "-----END CERTIFICATE REQUEST-----"
    
    Write-Host "  ✓ CSR generated successfully" -ForegroundColor Green
    
    # Clean up - delete temporary key from TPM
    `$key.Delete()
    `$key.Dispose()
    `$ecdsa.Dispose()
    
    @{
        success = `$true
        csr = `$pemCSR
        csrBase64 = `$csrBase64
        subject = `$subjectDN.Name
        keyAlgorithm = "ECDSA_P256"
        signatureAlgorithm = "SHA256withECDSA"
    }
}
catch {
    @{
        success = `$false
        error = `$_.Exception.Message
        details = `$_.Exception.ToString()
    }
}
"@
        
        $result = Invoke-Expression $csrScript
        
        if (-not $result.success) {
            Write-Host "Method 1 failed: $($result.error)" -ForegroundColor Red
            Write-Host "`nTrying Method 2: Using certreq with imported key..." -ForegroundColor Cyan
            
            # Method 2: Use certreq with INF file
            $result = Generate-CSRWithCertReq -KeyEnvelope $keyEnvelope -SubjectInfo $SubjectInfo -VaultPath $VaultPath
        }
        
        return $result
    }
    catch {
        throw "CSR generation failed: $($_.Exception.Message)"
    }
}

function Generate-CSRWithCertReq {
    param(
        [object]$KeyEnvelope,
        [hashtable]$SubjectInfo,
        [string]$VaultPath
    )
    
    Write-Host "  Attempting certreq method..." -ForegroundColor White
    
    try {
        # First import the key to TPM and get its container name
        $importScript = @"
Add-Type -AssemblyName System.Security

# Import the wrapped key
`$wrappedBlob = [Convert]::FromBase64String("$($KeyEnvelope.wrappedKeyBlob)")
`$keyName = "$($KeyEnvelope.keyName)-certreq-$(Get-Date -Format 'yyyyMMddHHmmss')"

`$key = [System.Security.Cryptography.CngKey]::Import(
    `$wrappedBlob,
    [System.Security.Cryptography.CngKeyBlobFormat]::OpaqueTransportBlob,
    [System.Security.Cryptography.CngProvider]::new("$($KeyEnvelope.provider)")
)

# Save the key persistently for certreq
`$key.KeyName
"@
        
        $tpmKeyName = Invoke-Expression $importScript
        
        # Create INF file for certreq
        $infContent = @"
[Version]
Signature="`$Windows NT$"

[NewRequest]
Subject = "CN=$($SubjectInfo.CommonName), O=$($SubjectInfo.Organization), OU=$($SubjectInfo.OrganizationalUnit), C=$($SubjectInfo.Country), S=$($SubjectInfo.State), L=$($SubjectInfo.Locality), E=$($SubjectInfo.EmailAddress)"
KeySpec = 1
KeyLength = 256
Exportable = FALSE
MachineKeySet = FALSE
SMIME = TRUE
PrivateKeyArchive = FALSE
UserProtected = FALSE
UseExistingKeySet = TRUE
ProviderName = "$($KeyEnvelope.provider)"
ProviderType = 0
RequestType = PKCS10
KeyUsage = 0xf0
KeyContainer = "$tpmKeyName"

[EnhancedKeyUsageExtension]
OID=1.3.6.1.5.5.7.3.2
OID=1.3.6.1.5.5.7.3.4
"@
        
        $infPath = "$VaultPath\temp\csr_request.inf"
        $csrPath = "$VaultPath\temp\$($KeyEnvelope.keyName).csr"
        
        $infContent | Set-Content -Path $infPath
        
        # Generate CSR using certreq
        $certreqCmd = "certreq -new `"$infPath`" `"$csrPath`" 2>&1"
        $output = Invoke-Expression $certreqCmd
        
        if (Test-Path $csrPath) {
            $csrContent = Get-Content $csrPath -Raw
            
            @{
                success = $true
                csr = $csrContent
                subject = $SubjectInfo.CommonName
                method = "certreq"
            }
        } else {
            throw "Certreq failed to create CSR: $output"
        }
    }
    catch {
        @{
            success = $false
            error = $_.Exception.Message
        }
    }
}

# Main execution
try {
    # Build subject info
    $subjectInfo = @{
        CommonName = $CommonName
        Organization = $Organization
        OrganizationalUnit = $OrganizationalUnit
        Country = $Country
        State = $State
        Locality = $Locality
        EmailAddress = $EmailAddress
    }
    
    $result = Generate-CSRFromTPMKey -KeyName $KeyName -VaultPath $VaultPath -SubjectInfo $subjectInfo
    
    if ($result.success) {
        Write-Host "`n=== CSR Generated Successfully ===" -ForegroundColor Green
        Write-Host "Subject: $($result.subject)" -ForegroundColor White
        Write-Host "Key Algorithm: $($result.keyAlgorithm)" -ForegroundColor White
        
        # Save CSR to file
        $csrOutputPath = "$VaultPath\tpm-wrapped\$KeyName.csr"
        $result.csr | Set-Content -Path $csrOutputPath
        Write-Host "`nCSR saved to: $csrOutputPath" -ForegroundColor Green
        
        # Display CSR
        Write-Host "`nCSR Content:" -ForegroundColor Cyan
        Write-Host $result.csr -ForegroundColor Gray
        
        Write-Host "`nJSON_OUTPUT_START" -ForegroundColor Magenta
        @{
            success = $true
            keyName = $KeyName
            csrPath = $csrOutputPath
            subject = $result.subject
            message = "CSR generated successfully from TPM-wrapped key"
        } | ConvertTo-Json
        Write-Host "JSON_OUTPUT_END" -ForegroundColor Magenta
    } else {
        throw "CSR generation failed: $($result.error)"
    }
    
    exit 0
}
catch {
    Write-Host "`nError: $($_.Exception.Message)" -ForegroundColor Red
    
    Write-Host "`nJSON_OUTPUT_START" -ForegroundColor Magenta
    @{
        success = $false
        error = $_.Exception.Message
    } | ConvertTo-Json
    Write-Host "JSON_OUTPUT_END" -ForegroundColor Magenta
    
    exit 1
}