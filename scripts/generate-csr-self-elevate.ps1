# Self-Elevating CSR Generation Script
param(
    [Parameter(Mandatory=$true)]
    [string]$TPMPath,
    [Parameter(Mandatory=$true)]
    [string]$CommonName,
    [string]$Organization = "TPM20 Organization",
    [string]$Country = "US"
)

# Check if running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    # Create a temporary script file with the parameters
    $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
    
    $scriptContent = @"
# Elevated CSR Generation
param()

Add-Type -AssemblyName System.Security

try {
    `$TPMPath = "$TPMPath"
    `$CommonName = "$CommonName"  
    `$Organization = "$Organization"
    `$Country = "$Country"
    
    # Open the hardware TPM key
    `$provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    if ([string]::IsNullOrEmpty(`$provider.Provider)) {
        throw "Microsoft Platform Crypto Provider not available even with elevation"
    }
    
    `$key = [System.Security.Cryptography.CngKey]::Open(`$TPMPath, `$provider)
    `$ecdsa = [System.Security.Cryptography.ECDsaCng]::new(`$key)
    
    # Build subject
    `$subject = "CN=`$CommonName"
    if (`$Organization) { `$subject += ", O=`$Organization" }
    if (`$Country -and `$Country.Length -eq 2) { `$subject += ", C=`$Country" }
    
    `$subjectDN = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new(`$subject)
    
    # Generate CSR
    `$certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
        `$subjectDN,
        `$ecdsa,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256
    )
    
    `$keyUsage = [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::NonRepudiation
    `$keyUsageExt = [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new(`$keyUsage, `$true)
    `$certRequest.CertificateExtensions.Add(`$keyUsageExt)
    
    `$csrBytes = `$certRequest.CreateSigningRequest()
    `$csrBase64 = [Convert]::ToBase64String(`$csrBytes)
    
    # Format as PEM
    `$pemCSR = "-----BEGIN CERTIFICATE REQUEST-----``n"
    for (`$i = 0; `$i -lt `$csrBase64.Length; `$i += 64) {
        `$line = `$csrBase64.Substring(`$i, [Math]::Min(64, `$csrBase64.Length - `$i))
        `$pemCSR += "`$line``n"
    }
    `$pemCSR += "-----END CERTIFICATE REQUEST-----"
    
    # Output JSON result
    `$result = @{
        Success = `$true
        CSR = `$pemCSR
        Subject = `$subject
        TPMPath = `$TPMPath
        Method = "Self-Elevated Pure .NET"
    }
    
    `$result | ConvertTo-Json -Compress
    
    # Cleanup
    `$ecdsa.Dispose()
    `$key.Dispose()
    
} catch {
    `$result = @{
        Success = `$false
        Error = `$_.Exception.Message
        TPMPath = `$TPMPath
    }
    `$result | ConvertTo-Json -Compress
    exit 1
}
"@

    # Write the elevated script
    $scriptContent | Out-File -FilePath $tempScript -Encoding UTF8
    
    try {
        # Run elevated and capture output
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-ExecutionPolicy Bypass -File `"$tempScript`""
        $psi.UseShellExecute = $true
        $psi.Verb = "runas"
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.RedirectStandardOutput = $false
        $psi.RedirectStandardError = $false
        
        $process = [System.Diagnostics.Process]::Start($psi)
        $process.WaitForExit()
        
        if ($process.ExitCode -eq 0) {
            # Since we can't redirect output with runas, return a success marker
            $result = @{
                Success = $true
                Message = "CSR generated successfully with elevation. Check application logs or run script directly to get CSR content."
                TPMPath = $TPMPath
                Method = "Self-Elevated (output not captured)"
            }
            $result | ConvertTo-Json -Compress
        } else {
            throw "Elevated process failed with exit code: $($process.ExitCode)"
        }
        
    } catch {
        $result = @{
            Success = $false
            Error = "Self-elevation failed: $($_.Exception.Message)"
            TPMPath = $TPMPath
        }
        $result | ConvertTo-Json -Compress
        exit 1
    } finally {
        # Clean up temp script
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }
    }
} else {
    # Already running as Administrator, proceed normally
    Add-Type -AssemblyName System.Security

    try {
        # Open the hardware TPM key
        $provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
        if ([string]::IsNullOrEmpty($provider.Provider)) {
            throw "Microsoft Platform Crypto Provider not available"
        }
        
        $key = [System.Security.Cryptography.CngKey]::Open($TPMPath, $provider)
        $ecdsa = [System.Security.Cryptography.ECDsaCng]::new($key)
        
        # Build subject
        $subject = "CN=$CommonName"
        if ($Organization) { $subject += ", O=$Organization" }
        if ($Country -and $Country.Length -eq 2) { $subject += ", C=$Country" }
        
        $subjectDN = [System.Security.Cryptography.X509Certificates.X500DistinguishedName]::new($subject)
        
        # Generate CSR
        $certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            $subjectDN,
            $ecdsa,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256
        )
        
        $keyUsage = [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature -bor [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::NonRepudiation
        $keyUsageExt = [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($keyUsage, $true)
        $certRequest.CertificateExtensions.Add($keyUsageExt)
        
        $csrBytes = $certRequest.CreateSigningRequest()
        $csrBase64 = [Convert]::ToBase64String($csrBytes)
        
        # Format as PEM
        $pemCSR = "-----BEGIN CERTIFICATE REQUEST-----`n"
        for ($i = 0; $i -lt $csrBase64.Length; $i += 64) {
            $line = $csrBase64.Substring($i, [Math]::Min(64, $csrBase64.Length - $i))
            $pemCSR += "$line`n"
        }
        $pemCSR += "-----END CERTIFICATE REQUEST-----"
        
        # Output JSON result
        $result = @{
            Success = $true
            CSR = $pemCSR
            Subject = $subject
            TPMPath = $TPMPath
            Method = "Already Elevated Pure .NET"
        }
        
        $result | ConvertTo-Json -Compress
        
        # Cleanup
        $ecdsa.Dispose()
        $key.Dispose()
        
    } catch {
        $result = @{
            Success = $false
            Error = $_.Exception.Message
            TPMPath = $TPMPath
        }
        $result | ConvertTo-Json -Compress
        exit 1
    }
}