# Simple Hardware TPM Key Creation
param(
    [Parameter(Mandatory=$true)]
    [string]$KeyName
)

# Import required modules and ensure certificate provider is available
Import-Module PKI -Force -ErrorAction SilentlyContinue

Write-Host "Creating TPM hardware key: $KeyName"

# Method 1: Try with explicit certificate store creation
try {
    Write-Host "Method 1: Direct certificate creation with TPM"
    
    # Use certreq.exe approach for TPM key creation
    $tempReqFile = "$env:TEMP\tpm_$KeyName.req"
    $tempCertFile = "$env:TEMP\tpm_$KeyName.cer"
    
    # Create certificate request file for TPM
    $reqContent = @"
[NewRequest]
Subject = "CN=$KeyName"
KeyLength = 2048
KeyAlgorithm = RSA
ProviderName = "Microsoft Platform Crypto Provider"
KeyUsage = CERT_DIGITAL_SIGNATURE_KEY_USAGE
MachineKeySet = FALSE
Exportable = FALSE
"@
    
    $reqContent | Out-File -FilePath $tempReqFile -Encoding ASCII
    
    # Create the certificate using certreq
    $certreqResult = & certreq.exe -new $tempReqFile $tempCertFile 2>&1
    
    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempCertFile)) {
        Write-Host "SUCCESS: TPM certificate created with certreq!" -ForegroundColor Green
        
        # Import the certificate
        $importResult = & certreq.exe -accept $tempCertFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Certificate imported successfully" -ForegroundColor Green
            
            # Find the certificate
            $certs = Get-ChildItem -Path "Cert:\CurrentUser\My" | Where-Object {$_.Subject -like "*$KeyName*"}
            if ($certs) {
                $cert = $certs[0]
                
                $result = @{
                    Success = $true
                    Algorithm = "RSA"
                    KeyLength = 2048
                    Provider = "Microsoft Platform Crypto Provider"
                    Handle = $cert.Thumbprint
                    Subject = $cert.Subject
                    InTPM = $true
                    Method = "certreq.exe"
                }
                
                Write-Host "Thumbprint: $($cert.Thumbprint)"
                Write-Output ($result | ConvertTo-Json -Compress)
                
                # Cleanup temp files
                Remove-Item $tempReqFile -Force -ErrorAction SilentlyContinue
                Remove-Item $tempCertFile -Force -ErrorAction SilentlyContinue
                exit 0
            }
        }
    }
    
    Write-Host "certreq method failed: $certreqResult" -ForegroundColor Yellow
}
catch {
    Write-Host "Method 1 failed: $_" -ForegroundColor Yellow
}

# Method 2: PowerShell with different store location
try {
    Write-Host "Method 2: PowerShell New-SelfSignedCertificate with LocalMachine"
    
    $cert = New-SelfSignedCertificate `
        -Subject "CN=$KeyName" `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -Provider "Microsoft Platform Crypto Provider" `
        -CertStoreLocation "Cert:\LocalMachine\My" `
        -KeyExportPolicy NonExportable
    
    if ($cert) {
        Write-Host "SUCCESS: PowerShell LocalMachine certificate created!" -ForegroundColor Green
        
        $result = @{
            Success = $true
            Algorithm = "RSA"
            KeyLength = 2048
            Provider = "Microsoft Platform Crypto Provider"
            Handle = $cert.Thumbprint
            Subject = $cert.Subject
            InTPM = $true
            Method = "PowerShell-LocalMachine"
        }
        
        Write-Host "Thumbprint: $($cert.Thumbprint)"
        Write-Output ($result | ConvertTo-Json -Compress)
        exit 0
    }
}
catch {
    Write-Host "Method 2 failed: $_" -ForegroundColor Yellow
}

# All methods failed
Write-Host "All TPM hardware key creation methods failed" -ForegroundColor Red

$result = @{
    Success = $false
    Error = "All hardware TPM methods failed"
    InTPM = $false
}

Write-Output ($result | ConvertTo-Json -Compress)
exit 1