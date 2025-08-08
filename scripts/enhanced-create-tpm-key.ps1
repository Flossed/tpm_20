param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Enhanced TPM Key Creation for: $KeyName"
    
    # Check if running as administrator
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    Write-Host "Running as Administrator: $isAdmin"
    
    # Check TPM Platform Provider availability
    $platformProviderPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\Defaults\Provider\Microsoft Platform Crypto Provider"
    $tpmAvailable = Test-Path $platformProviderPath
    Write-Host "TPM Platform Provider Available: $tpmAvailable"
    
    if ($tpmAvailable) {
        Write-Host "Attempting hardware TPM key creation..."
        
        # Method 1: Try RSA 2048 with TPM (most compatible)
        try {
            Write-Host "Trying RSA 2048 with TPM..."
            
            # Use different certificate store approach
            $certParams = @{
                Subject = "CN=$KeyName"
                KeyAlgorithm = "RSA"
                KeyLength = 2048
                Provider = "Microsoft Platform Crypto Provider"
                KeyExportPolicy = "NonExportable"
                KeyUsage = "DigitalSignature"
                NotAfter = (Get-Date).AddYears(1)
            }
            
            # Try to create in memory first, then store
            $cert = New-SelfSignedCertificate @certParams
            
            if ($cert) {
                # Manually add to certificate store
                $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "CurrentUser")
                $store.Open("ReadWrite")
                $store.Add($cert)
                $store.Close()
                
                Write-Host "SUCCESS: RSA TPM certificate created!" -ForegroundColor Green
                
                $output = @{
                    Success = $true
                    Handle = $cert.Thumbprint
                    Subject = $cert.Subject
                    Provider = "Microsoft Platform Crypto Provider"
                    Algorithm = "RSA"
                    KeyLength = 2048
                    InTPM = $true
                }
                
                Write-Output ($output | ConvertTo-Json -Compress)
                exit 0
            }
        }
        catch {
            Write-Host "RSA TPM failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
        
        # Method 2: Try ECDSA with TPM
        try {
            Write-Host "Trying ECDSA P256 with TPM..."
            
            $certParams = @{
                Subject = "CN=$KeyName"
                KeyAlgorithm = "ECDSA_nistP256"
                Provider = "Microsoft Platform Crypto Provider"
                KeyExportPolicy = "NonExportable"
                KeyUsage = "DigitalSignature"
                NotAfter = (Get-Date).AddYears(1)
            }
            
            $cert = New-SelfSignedCertificate @certParams
            
            if ($cert) {
                $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "CurrentUser")
                $store.Open("ReadWrite")
                $store.Add($cert)
                $store.Close()
                
                Write-Host "SUCCESS: ECDSA TPM certificate created!" -ForegroundColor Green
                
                $output = @{
                    Success = $true
                    Handle = $cert.Thumbprint
                    Subject = $cert.Subject
                    Provider = "Microsoft Platform Crypto Provider"
                    Algorithm = "ECDSA_nistP256"
                    InTPM = $true
                }
                
                Write-Output ($output | ConvertTo-Json -Compress)
                exit 0
            }
        }
        catch {
            Write-Host "ECDSA TPM failed: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Fallback to software provider (working method)
    Write-Host "Falling back to Microsoft Software Key Storage Provider..."
    
    try {
        $certParams = @{
            Subject = "CN=$KeyName"
            KeyAlgorithm = "ECDSA_nistP256"
            Provider = "Microsoft Software Key Storage Provider"
            NotAfter = (Get-Date).AddYears(1)
        }
        
        $cert = New-SelfSignedCertificate @certParams
        
        if ($cert) {
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "CurrentUser")
            $store.Open("ReadWrite")
            $store.Add($cert)
            $store.Close()
            
            Write-Host "SUCCESS: Software certificate created as fallback" -ForegroundColor Green
            
            $output = @{
                Success = $true
                Handle = $cert.Thumbprint
                Subject = $cert.Subject
                Provider = "Microsoft Software Key Storage Provider"
                Algorithm = "ECDSA_nistP256"
                InTPM = $false
            }
            
            Write-Output ($output | ConvertTo-Json -Compress)
            exit 0
        }
    }
    catch {
        Write-Host "Software fallback also failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    # Complete failure
    throw "All certificate creation methods failed"
}
catch {
    $output = @{
        Success = $false
        Error = $_.Exception.Message
        InTPM = $false
    }
    
    Write-Output ($output | ConvertTo-Json -Compress)
    exit 1
}