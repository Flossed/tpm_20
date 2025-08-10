# Verify CNG TPM Signature
param(
    [Parameter(Mandatory=$true)]
    [string]$DocumentHash,
    
    [Parameter(Mandatory=$true)]
    [string]$Signature,
    
    [Parameter(Mandatory=$true)]
    [string]$PublicKey
)

Add-Type -AssemblyName System.Security

try {
    Write-Host "🔍 Verifying CNG signature..." -ForegroundColor Cyan
    Write-Host "  Document Hash: $DocumentHash" -ForegroundColor Gray
    Write-Host "  Signature: $($Signature.Substring(0, 32))..." -ForegroundColor Gray
    Write-Host "  Public Key: $($PublicKey.Substring(0, 32))..." -ForegroundColor Gray
    
    # Convert Base64 signature to bytes
    $signatureBytes = [Convert]::FromBase64String($Signature)
    
    # Convert Base64 public key to CNG key
    $publicKeyBytes = [Convert]::FromBase64String($PublicKey)
    
    # Import the CNG public key
    $cngKey = [System.Security.Cryptography.CngKey]::Import($publicKeyBytes, [System.Security.Cryptography.CngKeyBlobFormat]::EccPublicBlob)
    
    # Create ECDSA object
    $ecdsa = [System.Security.Cryptography.ECDsaCng]::new($cngKey)
    
    # The DocumentHash parameter is the hex string that was originally signed
    # The signing process treats this hex string as UTF-8 text and hashes it with SHA256
    # So we need to verify against the data that was actually signed (the hex string as UTF-8)
    
    $dataBytes = [System.Text.Encoding]::UTF8.GetBytes($DocumentHash)
    
    # Verify the signature using VerifyData (which will hash the data with SHA256 internally)
    $isValid = $ecdsa.VerifyData($dataBytes, $signatureBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256)
    
    $result = @{
        Valid = $isValid
        Algorithm = "ES256"
        Verified = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }
    
    if ($isValid) {
        Write-Host "✅ Signature is VALID" -ForegroundColor Green
    } else {
        Write-Host "❌ Signature is INVALID" -ForegroundColor Red
    }
    
    # Clean up
    $ecdsa.Dispose()
    $cngKey.Dispose()
    
    Write-Output ($result | ConvertTo-Json -Compress)
    
} catch {
    $errorMessage = $_.Exception.Message
    $errorDetails = $_.Exception.ToString()
    
    Write-Host "❌ ERROR: $errorMessage" -ForegroundColor Red
    Write-Host "Error Details: $errorDetails" -ForegroundColor Gray
    
    $result = @{
        Valid = $false
        Error = $errorMessage
        ErrorDetails = $errorDetails
        DocumentHashLength = $DocumentHash.Length
        SignatureLength = $Signature.Length
        PublicKeyLength = $PublicKey.Length
    }
    
    Write-Output ($result | ConvertTo-Json -Compress)
    exit 1
}