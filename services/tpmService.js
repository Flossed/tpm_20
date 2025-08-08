const crypto = require('crypto');
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);
const { logger } = require('./generic');
const elliptic = require('elliptic');
const EC = elliptic.ec;
const ec = new EC('p256');

class TPMService {
  constructor() {
    this.isWindows = process.platform === 'win32';
    this.tpmAvailable = false;
    this.checkTPMAvailability();
  }

  async checkTPMAvailability() {
    try {
      if (this.isWindows) {
        // Try different PowerShell commands to check TPM availability
        try {
          const { stdout } = await execAsync('powershell -Command "Get-TPM"');
          // If Get-TPM returns any output without error, TPM is available
          this.tpmAvailable = stdout.trim().length > 0;
          logger.info('TPM detected using Get-TPM command');
        } catch (getTpmError) {
          // Fallback: Check if TPM device exists in Device Manager
          try {
            const { stdout } = await execAsync('powershell -Command "Get-WmiObject -Namespace root/cimv2/security/microsofttpm -Class Win32_Tpm"');
            this.tpmAvailable = stdout.trim().length > 0;
            logger.info('TPM detected using WMI query');
          } catch (wmiError) {
            // Final fallback: Check registry for TPM
            try {
              await execAsync('reg query "HKLM\\SYSTEM\\CurrentControlSet\\Services\\TPM" /f TPM');
              this.tpmAvailable = true;
              logger.info('TPM detected using registry check');
            } catch (regError) {
              this.tpmAvailable = false;
              logger.warn('No TPM detected on Windows system');
            }
          }
        }
      } else {
        const { stdout } = await execAsync('tpm2_getcap properties-fixed 2>/dev/null | grep TPM2_PT_MANUFACTURER');
        this.tpmAvailable = stdout.length > 0;
      }
      logger.info(`TPM availability: ${this.tpmAvailable}`);
    } catch (error) {
      logger.error('Error checking TPM availability:', error);
      this.tpmAvailable = false;
    }
  }

  async createES256KeyPair(keyName) {
    try {
      if (!this.tpmAvailable) {
        logger.info(`TPM not available, creating software key for: ${keyName}`);
        return this.createSoftwareES256KeyPair(keyName);
      }

      try {
        if (this.isWindows) {
          return await this.createWindowsTPMKey(keyName);
        } else {
          return await this.createLinuxTPMKey(keyName);
        }
      } catch (tpmError) {
        logger.warn(`Failed to create TPM key, falling back to software key: ${tpmError.message}`);
        return this.createSoftwareES256KeyPair(keyName);
      }
    } catch (error) {
      logger.error('Error creating ES256 key pair:', error);
      throw error;
    }
  }

  async createSoftwareES256KeyPair(keyName) {
    try {
      const keyPair = ec.genKeyPair();
      const publicKey = keyPair.getPublic('hex');
      const privateKey = keyPair.getPrivate('hex');
      
      const handle = crypto.randomBytes(16).toString('hex');
      
      return {
        name: keyName,
        handle: handle,
        publicKey: publicKey,
        privateKey: privateKey,
        inTPM: false
      };
    } catch (error) {
      logger.error('Error creating software ES256 key pair:', error);
      throw error;
    }
  }

  async createWindowsTPMKey(keyName) {
    try {
      const path = require('path');
      const scriptPath = path.join(__dirname, '..', 'scripts', 'working-tpm-cng.ps1');
      
      // Test if we can execute PowerShell 7 first, fallback to PowerShell 5.1
      let psCommand = 'pwsh'; // PowerShell 7
      try {
        const { stdout: versionOut } = await execAsync('pwsh -Command "$PSVersionTable.PSVersion"');
        logger.info(`PowerShell 7 version: ${versionOut.trim()}`);
        psCommand = 'pwsh';
      } catch (ps7Error) {
        try {
          const { stdout: versionOut } = await execAsync('powershell -Command "$PSVersionTable.PSVersion"');
          logger.info(`PowerShell 5.1 version: ${versionOut.trim()}`);
          psCommand = 'powershell';
        } catch (ps5Error) {
          logger.error('Cannot execute any PowerShell version:', ps5Error.message);
          throw new Error('PowerShell is not available');
        }
      }
      
      // Execute the PowerShell script file with the detected PowerShell version
      const command = `${psCommand} -ExecutionPolicy Bypass -File "${scriptPath}" -KeyName "${keyName}"`;
      logger.info(`Executing CNG TPM command with ${psCommand}: ${command}`);
      
      const { stdout, stderr } = await execAsync(command, {
        timeout: 20000,
        windowsHide: true
      });
      
      if (stderr && !stderr.includes('Write-Host')) {
        logger.warn(`PowerShell stderr: ${stderr}`);
      }
      
      logger.info(`PowerShell full output: ${stdout}`);
      
      // Extract JSON from output (may have Write-Host debug messages)
      const lines = stdout.split('\n');
      let jsonLine = '';
      
      // Look for JSON output
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.startsWith('{') && trimmed.includes('"Success"')) {
          jsonLine = trimmed;
          break;
        }
      }
      
      if (!jsonLine) {
        logger.error(`No JSON found in PowerShell output: ${stdout}`);
        throw new Error('No JSON output from PowerShell script - may need administrator privileges');
      }
      
      logger.info(`PowerShell JSON output: ${jsonLine}`);
      
      let result;
      try {
        result = JSON.parse(jsonLine);
      } catch (parseError) {
        logger.error(`Failed to parse PowerShell JSON: ${jsonLine}`);
        throw new Error(`Invalid JSON from PowerShell: ${parseError.message}`);
      }
      
      if (!result.Success) {
        throw new Error(result.Error || 'Failed to create CNG key');
      }
      
      logger.info(`Successfully created CNG key for: ${keyName}`);
      logger.info(`Key details: Handle=${result.Handle}, Provider=${result.Provider}`);
      
      // Determine if this is true hardware TPM based on the provider
      const isTPM = result.InTPM || (result.Provider && result.Provider.includes('Platform'));
      
      // Log TPM status for debugging
      if (isTPM) {
        logger.info(`🔒 TRUE HARDWARE TPM KEY CREATED! Provider: ${result.Provider}`);
      } else {
        logger.info(`🔑 Software-backed CNG key created with provider: ${result.Provider}`);
      }
      
      return {
        name: keyName,
        handle: result.Handle,
        publicKey: result.PublicKey,
        privateKey: null, // CNG keys don't expose private keys
        inTPM: isTPM,
        windowsCert: false,
        cngKey: true,
        provider: result.Provider,
        algorithm: result.Algorithm || 'ES256',
        created: result.Created
      };
    } catch (error) {
      logger.error(`Error creating CNG key for ${keyName}:`, error.message);
      throw error;
    }
  }

  async createLinuxTPMKey(keyName) {
    try {
      const handle = `0x8100${Math.floor(Math.random() * 0xFFFF).toString(16).padStart(4, '0')}`;
      
      await execAsync(`tpm2_createprimary -C o -g sha256 -G ecc256 -c primary.ctx`);
      await execAsync(`tpm2_create -C primary.ctx -g sha256 -G ecc256 -u ${keyName}.pub -r ${keyName}.priv`);
      await execAsync(`tpm2_load -C primary.ctx -u ${keyName}.pub -r ${keyName}.priv -c ${keyName}.ctx`);
      await execAsync(`tpm2_evictcontrol -C o -c ${keyName}.ctx ${handle}`);
      
      const { stdout } = await execAsync(`tpm2_readpublic -c ${handle} -f pem`);
      
      return {
        name: keyName,
        handle: handle,
        publicKey: stdout,
        inTPM: true
      };
    } catch (error) {
      logger.error('Error creating Linux TPM key:', error);
      throw error;
    }
  }

  async signDocument(documentHash, keyHandle, isTPMKey = true) {
    try {
      if (!isTPMKey) {
        return this.signWithSoftwareKey(documentHash, keyHandle);
      }

      if (this.isWindows) {
        return await this.signWithWindowsTPM(documentHash, keyHandle);
      } else {
        return await this.signWithLinuxTPM(documentHash, keyHandle);
      }
    } catch (error) {
      logger.error('Error signing document:', error);
      throw error;
    }
  }

  signWithSoftwareKey(documentHash, privateKey) {
    try {
      const key = ec.keyFromPrivate(privateKey, 'hex');
      const signature = key.sign(documentHash);
      return signature.toDER('hex');
    } catch (error) {
      logger.error('Error signing with software key:', error);
      throw error;
    }
  }

  async signWithWindowsTPM(documentHash, keyHandle) {
    try {
      const path = require('path');
      const scriptPath = path.join(__dirname, '..', 'scripts', 'sign-with-cng-key.ps1');
      
      // Extract key name from handle (remove TPM_ES256_ prefix if present)
      const keyName = keyHandle.replace('TPM_ES256_', '');
      
      logger.info(`Signing with CNG key: ${keyName}`);
      
      // Use PowerShell 7 if available, fallback to PowerShell 5.1
      let psCommand = 'pwsh';
      try {
        await execAsync('pwsh -Command "Get-Host"');
      } catch {
        psCommand = 'powershell';
      }
      
      // Execute the PowerShell signing script
      const command = `${psCommand} -ExecutionPolicy Bypass -File "${scriptPath}" -KeyName "${keyName}" -DataToSign "${documentHash}"`;
      
      const { stdout, stderr } = await execAsync(command, {
        timeout: 15000,
        windowsHide: true
      });
      
      if (stderr && !stderr.includes('Write-Host')) {
        logger.warn(`PowerShell signing stderr: ${stderr}`);
      }
      
      logger.info(`PowerShell signing output: ${stdout}`);
      
      // Extract JSON from output
      const lines = stdout.split('\n');
      let jsonLine = '';
      
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.startsWith('{') && trimmed.includes('"Success"')) {
          jsonLine = trimmed;
          break;
        }
      }
      
      if (!jsonLine) {
        logger.error(`No JSON found in signing output: ${stdout}`);
        throw new Error('No JSON output from signing script - may need administrator privileges');
      }
      
      let result;
      try {
        result = JSON.parse(jsonLine);
      } catch (parseError) {
        logger.error(`Failed to parse signing JSON: ${jsonLine}`);
        throw new Error(`Invalid JSON from signing script: ${parseError.message}`);
      }
      
      if (!result.Success) {
        throw new Error(result.Error || 'Failed to sign with CNG key');
      }
      
      logger.info(`Successfully signed with CNG key: ${keyName}, Provider: ${result.Provider}`);
      
      return result.Signature;
    } catch (error) {
      logger.error('Error signing with Windows CNG TPM:', error);
      throw error;
    }
  }

  async signWithLinuxTPM(documentHash, keyHandle) {
    try {
      const hashFile = `/tmp/hash_${Date.now()}.bin`;
      const sigFile = `/tmp/sig_${Date.now()}.bin`;
      
      await execAsync(`echo -n "${documentHash}" | xxd -r -p > ${hashFile}`);
      await execAsync(`tpm2_sign -c ${keyHandle} -g sha256 -s rsassa -o ${sigFile} ${hashFile}`);
      const { stdout } = await execAsync(`xxd -p -c 256 ${sigFile}`);
      
      await execAsync(`rm -f ${hashFile} ${sigFile}`);
      
      return stdout.trim();
    } catch (error) {
      logger.error('Error signing with Linux TPM:', error);
      throw error;
    }
  }

  async verifySignature(documentHash, signature, publicKey) {
    try {
      const key = ec.keyFromPublic(publicKey, 'hex');
      return key.verify(documentHash, signature);
    } catch (error) {
      logger.error('Error verifying signature:', error);
      return false;
    }
  }

  async deleteKey(keyHandle, isTPMKey = true) {
    try {
      if (!isTPMKey) {
        return true;
      }

      if (this.isWindows) {
        return await this.deleteWindowsTPMKey(keyHandle);
      } else {
        return await this.deleteLinuxTPMKey(keyHandle);
      }
    } catch (error) {
      logger.error('Error deleting key:', error);
      throw error;
    }
  }

  async deleteWindowsTPMKey(keyHandle) {
    try {
      const path = require('path');
      const scriptPath = path.join(__dirname, '..', 'scripts', 'delete-cng-key.ps1');
      
      // Extract key name from handle (remove TPM_ES256_ prefix if present)
      const keyName = keyHandle.replace('TPM_ES256_', '');
      
      logger.info(`Deleting CNG key: ${keyName}`);
      
      // Use PowerShell 7 if available, fallback to PowerShell 5.1
      let psCommand = 'pwsh';
      try {
        await execAsync('pwsh -Command "Get-Host"');
      } catch {
        psCommand = 'powershell';
      }
      
      // Execute the PowerShell deletion script
      const command = `${psCommand} -ExecutionPolicy Bypass -File "${scriptPath}" -KeyName "${keyName}"`;
      
      const { stdout, stderr } = await execAsync(command, {
        timeout: 10000,
        windowsHide: true
      });
      
      if (stderr && !stderr.includes('Write-Host')) {
        logger.warn(`PowerShell deletion stderr: ${stderr}`);
      }
      
      logger.info(`PowerShell deletion output: ${stdout}`);
      
      // Extract JSON from output
      const lines = stdout.split('\n');
      let jsonLine = '';
      
      for (const line of lines) {
        const trimmed = line.trim();
        if (trimmed.startsWith('{') && trimmed.includes('"Success"')) {
          jsonLine = trimmed;
          break;
        }
      }
      
      if (!jsonLine) {
        logger.error(`No JSON found in deletion output: ${stdout}`);
        throw new Error('No JSON output from deletion script');
      }
      
      let result;
      try {
        result = JSON.parse(jsonLine);
      } catch (parseError) {
        logger.error(`Failed to parse deletion JSON: ${jsonLine}`);
        throw new Error(`Invalid JSON from deletion script: ${parseError.message}`);
      }
      
      if (!result.Success) {
        throw new Error(result.Error || 'Failed to delete CNG key');
      }
      
      logger.info(`Successfully deleted CNG key: ${keyName}`);
      return true;
    } catch (error) {
      logger.error('Error deleting Windows CNG key:', error);
      throw error;
    }
  }

  async deleteLinuxTPMKey(keyHandle) {
    try {
      await execAsync(`tpm2_evictcontrol -C o -c ${keyHandle}`);
      return true;
    } catch (error) {
      logger.error('Error deleting Linux TPM key:', error);
      throw error;
    }
  }

  async generateCSR(keyName, keyHandle, publicKey, commonName, organization, country) {
    try {
      const forge = require('node-forge');
      const csr = forge.pki.createCertificationRequest();
      
      csr.publicKey = forge.pki.publicKeyFromPem(this.convertToPEM(publicKey));
      csr.setSubject([
        { name: 'commonName', value: commonName || keyName },
        { name: 'organizationName', value: organization || 'TPM20 Organization' },
        { name: 'countryName', value: country || 'US' }
      ]);
      
      csr.setAttributes([
        {
          name: 'extensionRequest',
          extensions: [
            {
              name: 'keyUsage',
              keyCertSign: false,
              digitalSignature: true,
              nonRepudiation: true,
              keyEncipherment: false,
              dataEncipherment: false
            }
          ]
        }
      ]);
      
      const csrPem = forge.pki.certificationRequestToPem(csr);
      return csrPem;
    } catch (error) {
      logger.error('Error generating CSR:', error);
      throw error;
    }
  }

  convertToPEM(publicKey) {
    if (publicKey.includes('-----BEGIN')) {
      return publicKey;
    }
    
    return `-----BEGIN PUBLIC KEY-----\n${publicKey}\n-----END PUBLIC KEY-----`;
  }

  calculateHash(content) {
    return crypto.createHash('sha256').update(content).digest('hex');
  }
}

module.exports = new TPMService();