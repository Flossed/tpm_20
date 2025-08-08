
const { expect } = require('chai');
const sinon = require('sinon');
const tpmService = require('../services/tpmService');

describe('TPM Service', () => {
  let sandbox;

  beforeEach(() => {
    sandbox = sinon.createSandbox();
  });

  afterEach(() => {
    sandbox.restore();
  });

  describe('checkTPMAvailability', () => {
    it('should detect TPM availability on Windows', async () => {
      const originalPlatform = Object.getOwnPropertyDescriptor(process, 'platform');
      Object.defineProperty(process, 'platform', {
        value: 'win32'
      });

      await tpmService.checkTPMAvailability();
      
      if (originalPlatform) {
        Object.defineProperty(process, 'platform', originalPlatform);
      }
    });

    it('should detect TPM availability on Linux', async () => {
      const originalPlatform = Object.getOwnPropertyDescriptor(process, 'platform');
      Object.defineProperty(process, 'platform', {
        value: 'linux'
      });

      await tpmService.checkTPMAvailability();
      
      if (originalPlatform) {
        Object.defineProperty(process, 'platform', originalPlatform);
      }
    });
  });

  describe('createES256KeyPair', () => {
    it('should create a software key pair when TPM is not available', async () => {
      tpmService.tpmAvailable = false;
      
      const result = await tpmService.createES256KeyPair('testKey');
      
      expect(result).to.have.property('name', 'testKey');
      expect(result).to.have.property('handle');
      expect(result).to.have.property('publicKey');
      expect(result).to.have.property('inTPM', false);
    });

    it('should handle key creation errors', async () => {
      tpmService.tpmAvailable = false;
      sandbox.stub(tpmService, 'createSoftwareES256KeyPair').throws(new Error('Key creation failed'));
      
      try {
        await tpmService.createES256KeyPair('testKey');
        expect.fail('Should have thrown an error');
      } catch (error) {
        expect(error.message).to.equal('Key creation failed');
      }
    });
  });

  describe('calculateHash', () => {
    it('should calculate SHA256 hash of content', () => {
      const content = 'Hello, World!';
      const hash = tpmService.calculateHash(content);
      
      expect(hash).to.be.a('string');
      expect(hash).to.have.lengthOf(64);
      expect(hash).to.equal('dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f');
    });

    it('should produce different hashes for different content', () => {
      const hash1 = tpmService.calculateHash('content1');
      const hash2 = tpmService.calculateHash('content2');
      
      expect(hash1).to.not.equal(hash2);
    });
  });

  describe('convertToPEM', () => {
    it('should return PEM if already in PEM format', () => {
      const pemKey = '-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA\n-----END PUBLIC KEY-----';
      const result = tpmService.convertToPEM(pemKey);
      
      expect(result).to.equal(pemKey);
    });

    it('should convert to PEM format if not already', () => {
      const rawKey = 'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA';
      const result = tpmService.convertToPEM(rawKey);
      
      expect(result).to.include('-----BEGIN PUBLIC KEY-----');
      expect(result).to.include('-----END PUBLIC KEY-----');
      expect(result).to.include(rawKey);
    });
  });

  describe('signWithSoftwareKey', () => {
    it('should sign data with software key', () => {
      const documentHash = tpmService.calculateHash('test document');
      const keyPair = tpmService.ec.genKeyPair();
      const privateKey = keyPair.getPrivate('hex');
      
      const signature = tpmService.signWithSoftwareKey(documentHash, privateKey);
      
      expect(signature).to.be.a('string');
      expect(signature.length).to.be.greaterThan(0);
    });
  });

  describe('verifySignature', () => {
    it('should verify valid signature', async () => {
      const documentHash = tpmService.calculateHash('test document');
      const keyPair = tpmService.ec.genKeyPair();
      const privateKey = keyPair.getPrivate('hex');
      const publicKey = keyPair.getPublic('hex');
      
      const signature = tpmService.signWithSoftwareKey(documentHash, privateKey);
      const isValid = await tpmService.verifySignature(documentHash, signature, publicKey);
      
      expect(isValid).to.be.true;
    });

    it('should reject invalid signature', async () => {
      const documentHash = tpmService.calculateHash('test document');
      const keyPair1 = tpmService.ec.genKeyPair();
      const keyPair2 = tpmService.ec.genKeyPair();
      const privateKey1 = keyPair1.getPrivate('hex');
      const publicKey2 = keyPair2.getPublic('hex');
      
      const signature = tpmService.signWithSoftwareKey(documentHash, privateKey1);
      const isValid = await tpmService.verifySignature(documentHash, signature, publicKey2);
      
      expect(isValid).to.be.false;
    });
  });
});