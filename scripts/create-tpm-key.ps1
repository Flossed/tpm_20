param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Starting key creation for: $KeyName"
    
    # List available providers
    $providers = @(
        "Microsoft Platform Crypto Provider",
        "Microsoft Software Key Storage Provider",
        "Microsoft Smart Card Key Storage Provider"
    )
    
    $cert = $null
    $usedProvider = ""
    
    # Try each provider
    foreach ($provider in $providers) {
        try {
            Write-Host "Trying provider: $provider"
            
            $certParams = @{
                Subject = "CN=$KeyName"
                KeyAlgorithm = "ECDSA_nistP256"
                KeyUsage = "DigitalSignature"
                CertStoreLocation = "Cert:\CurrentUser\My"
                Provider = $provider
                KeyExportPolicy = "NonExportable"
            }
            
            $cert = New-SelfSignedCertificate @certParams
            
            if ($cert) {
                $usedProvider = $provider
                Write-Host "Successfully created certificate with provider: $provider"
                break
            }
        }
        catch {
            Write-Host "Failed with provider $provider : $_"
            continue
        }
    }
    
    if ($cert) {
        # Output JSON result
        $result = @{
            Success = $true
            Handle = $cert.Thumbprint
            Subject = $cert.Subject
            Provider = $usedProvider
            HasPrivateKey = $cert.HasPrivateKey
            KeyAlgorithm = $cert.PublicKey.Oid.FriendlyName
        }
        
        $jsonResult = $result | ConvertTo-Json -Compress
        Write-Output $jsonResult
    }
    else {
        $result = @{
            Success = $false
            Error = "Failed to create certificate with any provider"
        }
        Write-Output ($result | ConvertTo-Json -Compress)
    }
}
catch {
    $result = @{
        Success = $false
        Error = $_.Exception.Message
        Details = $_.Exception.ToString()
    }
    Write-Output ($result | ConvertTo-Json -Compress)
}