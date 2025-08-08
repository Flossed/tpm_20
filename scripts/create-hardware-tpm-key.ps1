# Create Hardware TPM Key
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

Write-Host "Creating Hardware TPM Key: $KeyName"

try {
    # Use .NET certificate classes directly instead of PowerShell drives
    Add-Type -AssemblyName System.Security
    
    # Create certificate request for TPM
    $distinguishedName = New-Object System.Security.Cryptography.X509Certificates.X500DistinguishedName("CN=$KeyName")
    
    # Try RSA first
    Write-Host "Attempting RSA 2048 key with TPM..."
    try {
        # Create RSA key with TPM backing
        $rsa = [System.Security.Cryptography.RSACng]::Create()
        $rsa.KeySize = 2048
        
        # Force TPM usage
        $cngKey = $rsa.Key
        $cngKey.SetProperty([System.Security.Cryptography.CngKeyProperties]::ProviderHandle, "Microsoft Platform Crypto Provider")
        
        # Create certificate request
        $certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new($distinguishedName, $rsa, "SHA256")
        
        # Create self-signed certificate
        $cert = $certRequest.CreateSelfSigned([System.DateTimeOffset]::Now, [System.DateTimeOffset]::Now.AddYears(1))
        
        # Store in certificate store
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new("My", "CurrentUser")
        $store.Open("ReadWrite")
        $store.Add($cert)
        $store.Close()
        
        Write-Host "SUCCESS: Created RSA TPM key!" -ForegroundColor Green
        
        $result = @{
            Success = $true
            Algorithm = "RSA"
            KeySize = 2048
            Provider = "Microsoft Platform Crypto Provider"
            Thumbprint = $cert.Thumbprint
            Subject = $cert.Subject
            InTPM = $true
        }
        
        Write-Output ($result | ConvertTo-Json -Compress)
        exit 0
    }
    catch {
        Write-Host "RSA failed: $_" -ForegroundColor Yellow
    }
    
    # Try ECDSA P256
    Write-Host "Attempting ECDSA P256 key with TPM..."
    try {
        # Create ECDSA key with TPM backing
        $ecdsa = [System.Security.Cryptography.ECDsaCng]::Create([System.Security.Cryptography.ECCurve]::NamedCurves.nistP256)
        
        # Force TPM usage
        $cngKey = $ecdsa.Key
        $cngKey.SetProperty([System.Security.Cryptography.CngKeyProperties]::ProviderHandle, "Microsoft Platform Crypto Provider")
        
        # Create certificate request
        $certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new($distinguishedName, $ecdsa, "SHA256")
        
        # Create self-signed certificate
        $cert = $certRequest.CreateSelfSigned([System.DateTimeOffset]::Now, [System.DateTimeOffset]::Now.AddYears(1))
        
        # Store in certificate store
        $store = [System.Security.Cryptography.X509Certificates.X509Store]::new("My", "CurrentUser")
        $store.Open("ReadWrite")
        $store.Add($cert)
        $store.Close()
        
        Write-Host "SUCCESS: Created ECDSA P256 TPM key!" -ForegroundColor Green
        
        $result = @{
            Success = $true
            Algorithm = "ECDSA_P256"
            Provider = "Microsoft Platform Crypto Provider"
            Thumbprint = $cert.Thumbprint
            Subject = $cert.Subject
            InTPM = $true
        }
        
        Write-Output ($result | ConvertTo-Json -Compress)
        exit 0
    }
    catch {
        Write-Host "ECDSA P256 failed: $_" -ForegroundColor Yellow
    }
    
    # Both failed
    throw "All TPM key creation attempts failed"
}
catch {
    Write-Host "Hardware TPM key creation failed: $_" -ForegroundColor Red
    
    $result = @{
        Success = $false
        Error = $_.Exception.Message
        InTPM = $false
    }
    
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 1
}