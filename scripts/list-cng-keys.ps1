try {
    Write-Host "Listing all CNG keys for Microsoft Platform Crypto Provider..."
    
    $provider = [System.Security.Cryptography.CngProvider]::MicrosoftPlatformCryptoProvider
    
    # Try to use .NET API to list keys (may not work in all PowerShell versions)
    try {
        $keys = [System.Security.Cryptography.CngKey]::Exists("*", $provider)
        Write-Host "Direct API enumeration not available, trying alternative method..."
    } catch {
        Write-Host "Direct enumeration failed, using PowerShell commands..."
    }
    
    # Use PowerShell command to enumerate keys
    try {
        $keyOutput = & certlm -cng -v 2>$null
        Write-Host "CertLM output:"
        Write-Host $keyOutput
    } catch {
        Write-Host "CertLM failed, trying PowerShell Get-ChildItem..."
    }
    
    # Try registry approach
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\PCPKSP"
        if (Test-Path $regPath) {
            Write-Host "Registry keys in PCPKSP:"
            Get-ChildItem $regPath -Recurse | ForEach-Object {
                Write-Host "  $($_.Name)"
            }
        } else {
            Write-Host "PCPKSP registry path not found"
        }
    } catch {
        Write-Host "Registry enumeration failed: $($_.Exception.Message)"
    }
    
    # Try current user certificate store
    try {
        $userRegPath = "HKCU:\SOFTWARE\Microsoft\Cryptography\PCPKSP"
        if (Test-Path $userRegPath) {
            Write-Host "User registry keys in PCPKSP:"
            Get-ChildItem $userRegPath -Recurse | ForEach-Object {
                Write-Host "  $($_.Name)"
            }
        } else {
            Write-Host "User PCPKSP registry path not found"
        }
    } catch {
        Write-Host "User registry enumeration failed: $($_.Exception.Message)"
    }
    
    # Try alternative CNG enumeration using WMI
    try {
        Write-Host "Attempting WMI enumeration..."
        $wmiKeys = Get-WmiObject -Namespace "root\cimv2\security\microsofttpm" -Class Win32_Tpm -ErrorAction SilentlyContinue
        if ($wmiKeys) {
            Write-Host "Found TPM WMI objects: $($wmiKeys.Count)"
        } else {
            Write-Host "No TPM WMI objects found"
        }
    } catch {
        Write-Host "WMI enumeration failed: $($_.Exception.Message)"
    }
    
    # Try using certutil to list keys
    try {
        Write-Host "Using certutil to list CNG keys..."
        $certutilOutput = & certutil -key -cng 2>$null
        Write-Host $certutilOutput
    } catch {
        Write-Host "Certutil failed: $($_.Exception.Message)"
    }
    
} catch {
    Write-Host "General error: $($_.Exception.Message)"
}