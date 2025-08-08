const { expect } = require('chai');
const mongoose = require('mongoose');
const Document = require('../models/Document');
const TPMKey = require('../models/TPMKey');
const Signature = require('../models/Signature');

describe('MongoDB Models', () => {
  before(async () => {
    await mongoose.connect('mongodb://192.168.129.197:27017/tpm20_test', {
      useNewUrlParser: true,
      useUnifiedTopology: true
    });
  });

  after(async () => {
    await mongoose.connection.close();
  });

  beforeEach(async () => {
    await Document.deleteMany({});
    await TPMKey.deleteMany({});
    await Signature.deleteMany({});
  });

  describe('Document Model', () => {
    it('should create a valid document', async () => {
      const doc = new Document({
        fileName: 'test.txt',
        fileType: 'text',
        content: 'Test content',
        size: 12,
        hash: 'abc123'
      });

      const saved = await doc.save();
      
      expect(saved.fileName).to.equal('test.txt');
      expect(saved.fileType).to.equal('text');
      expect(saved.content).to.equal('Test content');
      expect(saved.size).to.equal(12);
      expect(saved.hash).to.equal('abc123');
    });

    it('should require required fields', async () => {
      const doc = new Document({
        fileName: 'test.txt'
      });

      try {
        await doc.save();
        expect.fail('Should have thrown validation error');
      } catch (error) {
        expect(error).to.be.instanceOf(mongoose.Error.ValidationError);
      }
    });

    it('should validate file type enum', async () => {
      const doc = new Document({
        fileName: 'test.txt',
        fileType: 'invalid',
        content: 'Test',
        size: 4,
        hash: 'abc'
      });

      try {
        await doc.save();
        expect.fail('Should have thrown validation error');
      } catch (error) {
        expect(error).to.be.instanceOf(mongoose.Error.ValidationError);
      }
    });
  });

  describe('TPMKey Model', () => {
    it('should create a valid TPM key', async () => {
      const key = new TPMKey({
        name: 'TestKey',
        tpmHandle: '0x81000001',
        publicKey: 'public-key-data'
      });

      const saved = await key.save();
      
      expect(saved.name).to.equal('TestKey');
      expect(saved.tpmHandle).to.equal('0x81000001');
      expect(saved.publicKey).to.equal('public-key-data');
      expect(saved.keyType).to.equal('ES256');
      expect(saved.status).to.equal('active');
      expect(saved.usageCount).to.equal(0);
    });

    it('should enforce unique key names', async () => {
      const key1 = new TPMKey({
        name: 'UniqueKey',
        tpmHandle: '0x81000001',
        publicKey: 'key1'
      });
      await key1.save();

      const key2 = new TPMKey({
        name: 'UniqueKey',
        tpmHandle: '0x81000002',
        publicKey: 'key2'
      });

      try {
        await key2.save();
        expect.fail('Should have thrown duplicate key error');
      } catch (error) {
        expect(error.code).to.equal(11000);
      }
    });

    it('should validate status enum', async () => {
      const key = new TPMKey({
        name: 'TestKey',
        tpmHandle: '0x81000001',
        publicKey: 'public-key',
        status: 'invalid'
      });

      try {
        await key.save();
        expect.fail('Should have thrown validation error');
      } catch (error) {
        expect(error).to.be.instanceOf(mongoose.Error.ValidationError);
      }
    });
  });

  describe('Signature Model', () => {
    it('should create a valid signature', async () => {
      const doc = await new Document({
        fileName: 'test.txt',
        fileType: 'text',
        content: 'Test',
        size: 4,
        hash: 'abc123'
      }).save();

      const key = await new TPMKey({
        name: 'SignKey',
        tpmHandle: '0x81000001',
        publicKey: 'public-key'
      }).save();

      const sig = new Signature({
        documentId: doc._id,
        keyId: key._id,
        signature: 'signature-data',
        documentHash: 'abc123'
      });

      const saved = await sig.save();
      
      expect(saved.documentId.toString()).to.equal(doc._id.toString());
      expect(saved.keyId.toString()).to.equal(key._id.toString());
      expect(saved.signature).to.equal('signature-data');
      expect(saved.algorithm).to.equal('ES256');
      expect(saved.verificationStatus).to.equal('pending');
      expect(saved.verificationCount).to.equal(0);
    });

    it('should require document and key references', async () => {
      const sig = new Signature({
        signature: 'signature-data',
        documentHash: 'abc123'
      });

      try {
        await sig.save();
        expect.fail('Should have thrown validation error');
      } catch (error) {
        expect(error).to.be.instanceOf(mongoose.Error.ValidationError);
      }
    });

    it('should validate verification status enum', async () => {
      const doc = await new Document({
        fileName: 'test.txt',
        fileType: 'text',
        content: 'Test',
        size: 4,
        hash: 'abc123'
      }).save();

      const key = await new TPMKey({
        name: 'SignKey',
        tpmHandle: '0x81000001',
        publicKey: 'public-key'
      }).save();

      const sig = new Signature({
        documentId: doc._id,
        keyId: key._id,
        signature: 'signature-data',
        documentHash: 'abc123',
        verificationStatus: 'invalid-status'
      });

      try {
        await sig.save();
        expect.fail('Should have thrown validation error');
      } catch (error) {
        expect(error).to.be.instanceOf(mongoose.Error.ValidationError);
      }
    });
  });
});