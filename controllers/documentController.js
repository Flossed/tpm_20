const { logger } = require('../services/generic');
const Document = require('../models/Document');
const TPMKey = require('../models/TPMKey');
const Signature = require('../models/Signature');
const SignedDocument = require('../models/SignedDocument');
const tpmService = require('../services/tpmService');
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['.txt', '.md', '.json'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedTypes.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only .txt, .md, and .json files are allowed.'));
    }
  }
}).single('document');

class DocumentController {
  async listDocuments(req, res) {
    try {
      const documents = await Document.find()
        .sort({ uploadedAt: -1 })
        .lean();
      
      res.render('documents', {
        title: 'Document Management',
        documents: documents,
        success: req.query.success,
        error: req.query.error
      });
    } catch (error) {
      logger.error('Error listing documents:', error);
      res.status(500).render('errorPage', {
        title: 'Error',
        error: 'Failed to retrieve documents'
      });
    }
  }

  async getDocumentsAPI(req, res) {
    try {
      const documents = await Document.find()
        .sort({ uploadedAt: -1 })
        .select('_id fileName fileType fileSize hash uploadedAt signatureCount')
        .lean();
      
      res.json(documents);
    } catch (error) {
      logger.error('Error fetching documents via API:', error);
      res.status(500).json({ error: 'Failed to retrieve documents' });
    }
  }

  async uploadDocument(req, res) {
    upload(req, res, async (err) => {
      if (err) {
        logger.error('Upload error:', err);
        return res.status(400).json({ error: err.message });
      }

      try {
        if (!req.file) {
          return res.status(400).json({ error: 'No file uploaded' });
        }

        const content = req.file.buffer.toString('utf-8');
        const hash = tpmService.calculateHash(content);
        const ext = path.extname(req.file.originalname).toLowerCase();
        
        let fileType = 'text';
        if (ext === '.md') fileType = 'markdown';
        else if (ext === '.json') fileType = 'json';

        const existingDoc = await Document.findOne({ hash: hash });
        if (existingDoc) {
          return res.status(400).json({ error: 'Document with same content already exists' });
        }

        const newDocument = new Document({
          fileName: req.file.originalname,
          fileType: fileType,
          content: content,
          size: req.file.size,
          hash: hash,
          uploadedBy: req.body.uploadedBy || 'user'
        });

        await newDocument.save();
        logger.info(`Document uploaded: ${req.file.originalname}`);

        res.json({
          success: true,
          document: {
            id: newDocument._id,
            fileName: newDocument.fileName,
            fileType: newDocument.fileType,
            size: newDocument.size,
            hash: newDocument.hash,
            uploadedAt: newDocument.uploadedAt
          }
        });
      } catch (error) {
        logger.error('Error saving document:', error);
        res.status(500).json({ error: 'Failed to save document' });
      }
    });
  }

  async viewDocument(req, res) {
    try {
      const { documentId } = req.params;
      
      const document = await Document.findById(documentId).lean();
      if (!document) {
        return res.status(404).render('errorPage', {
          title: 'Error',
          error: 'Document not found'
        });
      }

      const signatures = await Signature.find({ documentId: documentId })
        .populate('keyId', 'name')
        .sort({ signedAt: -1 })
        .lean();

      res.render('documentDetail', {
        title: `Document: ${document.fileName}`,
        document: document,
        signatures: signatures
      });
    } catch (error) {
      logger.error('Error viewing document:', error);
      res.status(500).render('errorPage', {
        title: 'Error',
        error: 'Failed to retrieve document details'
      });
    }
  }

  async showSignPage(req, res) {
    try {
      const { documentId } = req.params;
      
      const document = await Document.findById(documentId).lean();
      if (!document) {
        return res.status(404).render('errorPage', {
          title: 'Error',
          error: 'Document not found'
        });
      }

      const activeKeys = await TPMKey.find({ status: 'active' })
        .select('_id name keyType status metadata usageCount')
        .lean();
      
      logger.info(`Found ${activeKeys.length} active keys for signing`);

      const existingSignatures = await Signature.find({ documentId: documentId })
        .populate('keyId', 'name')
        .sort({ signedAt: -1 })
        .lean();

      res.render('signDocument', {
        title: `Sign Document: ${document.fileName}`,
        document: document,
        keys: activeKeys,
        signatures: existingSignatures
      });
    } catch (error) {
      logger.error('Error showing sign page:', error);
      res.status(500).render('errorPage', {
        title: 'Error',
        error: 'Failed to load signing page'
      });
    }
  }

  async signDocument(req, res) {
    try {
      const { documentId } = req.params;
      const { keyId } = req.body;

      if (!keyId) {
        return res.status(400).json({ error: 'Key ID is required' });
      }

      const document = await Document.findById(documentId);
      if (!document) {
        return res.status(404).json({ error: 'Document not found' });
      }

      const key = await TPMKey.findById(keyId);
      if (!key || key.status !== 'active') {
        return res.status(404).json({ error: 'Active key not found' });
      }

      const documentHash = document.hash;
      const isTPMKey = key.inTPM === true;
      
      // For software keys, use the private key; for TPM keys, use the handle
      const keyMaterial = isTPMKey ? key.tpmHandle : (key.metadata.get('privateKey') || key.tpmHandle);
      const signature = await tpmService.signDocument(documentHash, keyMaterial, isTPMKey);

      const newSignature = new Signature({
        documentId: documentId,
        keyId: keyId,
        signature: signature,
        documentHash: documentHash,
        signedBy: req.body.signedBy || 'user'
      });

      await newSignature.save();

      key.lastUsed = new Date();
      key.usageCount = (key.usageCount || 0) + 1;
      await key.save();

      // Create signed document with embedded signature
      logger.info('About to call createSignedDocument method');
      try {
        logger.info('Calling createSignedDocument with:', {
          documentId: document._id,
          signatureId: newSignature._id,
          keyName: key.name,
          signatureLength: signature.length
        });
        await this.createSignedDocument(document, newSignature, key, signature);
        logger.info('createSignedDocument completed successfully');
      } catch (createError) {
        logger.error('Error creating signed document (signing still succeeded):', {
          message: createError.message,
          stack: createError.stack,
          name: createError.name,
          code: createError.code,
          fullError: createError
        });
        // Don't throw - signing was successful even if signed document creation failed
      }

      logger.info(`Document signed: ${document.fileName} with key: ${key.name}`);

      res.json({
        success: true,
        signature: {
          id: newSignature._id,
          signature: signature,
          signedAt: newSignature.signedAt
        }
      });
    } catch (error) {
      logger.error('Error signing document:', error);
      res.status(500).json({ error: 'Failed to sign document' });
    }
  }

  async createSignedDocument(document, signature, key, signatureValue) {
    try {
      logger.info('Creating signed documents for:', document.fileName);
      // Create different formats of signed documents
      const formats = ['embedded', 'detached'];
      
      for (const format of formats) {
        logger.info(`Creating ${format} signed document`);
        let signedContent = '';
        let fileName = '';
        
        if (format === 'embedded') {
          // Embed signature metadata and signature in the document
          logger.info('Creating embedded signed document content');
          signedContent = this.createEmbeddedSignedDocument(document, signature, key, signatureValue);
          fileName = this.generateSignedFileName(document.fileName, key.name, 'signed');
          logger.info('Embedded content created successfully');
        } else if (format === 'detached') {
          // Create a separate signature file
          logger.info('Creating detached signature content');
          signedContent = this.createDetachedSignature(document, signature, key, signatureValue);
          fileName = this.generateSignedFileName(document.fileName, key.name, 'sig');
          logger.info('Detached content created successfully');
        }
        
        logger.info(`Generated content for ${format}, size: ${signedContent.length}, fileName: ${fileName}`);
        
        const signedDoc = new SignedDocument({
          originalDocumentId: document._id,
          signatureId: signature._id,
          fileName: fileName,
          fileType: document.fileType,
          content: signedContent,
          size: Buffer.byteLength(signedContent, 'utf8'),
          format: format,
          signatureMetadata: {
            keyName: key.name,
            algorithm: 'ES256',
            provider: key.metadata?.inTPM === 'true' ? 'Hardware TPM' : 'Software',
            signedAt: signature.signedAt,
            signedBy: signature.signedBy,
            isHardwareTPM: key.metadata?.inTPM === 'true'
          },
          createdBy: signature.signedBy
        });
        
        logger.info(`Saving ${format} signed document to database`);
        await signedDoc.save();
        logger.info(`Created ${format} signed document: ${fileName}`);
      }
      logger.info('All signed documents created successfully');
    } catch (error) {
      logger.error('Error creating signed document:', {
        message: error.message,
        stack: error.stack,
        name: error.name,
        code: error.code,
        fullError: error
      });
      throw error; // Re-throw to help identify the issue
    }
  }

  createEmbeddedSignedDocument(document, signature, key, signatureValue) {
    const metadata = {
      originalDocument: {
        fileName: document.fileName,
        fileType: document.fileType,
        hash: document.hash,
        uploadedAt: document.uploadedAt,
        uploadedBy: document.uploadedBy
      },
      signature: {
        id: signature._id.toString(),
        algorithm: 'ES256',
        value: signatureValue,
        documentHash: signature.documentHash,
        signedAt: signature.signedAt,
        signedBy: signature.signedBy
      },
      key: {
        name: key.name,
        type: key.keyType,
        provider: key.metadata?.inTPM === 'true' ? 'Hardware TPM' : 'Software',
        isHardwareTPM: key.metadata?.inTPM === 'true'
      }
    };

    // Create signed document based on file type
    if (document.fileType === 'json') {
      try {
        const originalJson = JSON.parse(document.content);
        const signedJson = {
          ...originalJson,
          _digitalSignature: metadata
        };
        return JSON.stringify(signedJson, null, 2);
      } catch (error) {
        // If JSON parsing fails, treat as text
        return this.createTextSignedDocument(document.content, metadata);
      }
    } else {
      // For text and markdown files
      return this.createTextSignedDocument(document.content, metadata);
    }
  }

  createTextSignedDocument(content, metadata) {
    const signatureBlock = `
---BEGIN DIGITAL SIGNATURE---
Document Hash: ${metadata.signature.documentHash}
Signature Algorithm: ${metadata.signature.algorithm}
Signature Value: ${metadata.signature.value}
Signed By: ${metadata.signature.signedBy}
Signed At: ${metadata.signature.signedAt}
Key Name: ${metadata.key.name}
Key Provider: ${metadata.key.provider}
Hardware TPM: ${metadata.key.isHardwareTPM}
---END DIGITAL SIGNATURE---`;

    return content + '\n\n' + signatureBlock;
  }

  createDetachedSignature(document, signature, key, signatureValue) {
    const signatureData = {
      documentInfo: {
        fileName: document.fileName,
        fileType: document.fileType,
        hash: document.hash,
        size: document.size
      },
      signature: {
        id: signature._id.toString(),
        algorithm: 'ES256',
        value: signatureValue,
        documentHash: signature.documentHash,
        signedAt: signature.signedAt,
        signedBy: signature.signedBy
      },
      key: {
        name: key.name,
        type: key.keyType,
        provider: key.metadata?.inTPM === 'true' ? 'Hardware TPM' : 'Software',
        isHardwareTPM: key.metadata?.inTPM === 'true'
      },
      verification: {
        instructions: 'To verify this signature, use the original document and this signature file with a compatible verification tool.',
        format: 'TPM 2.0 Detached Signature'
      }
    };

    return JSON.stringify(signatureData, null, 2);
  }

  generateSignedFileName(originalFileName, keyName, suffix) {
    const ext = path.extname(originalFileName);
    const baseName = path.basename(originalFileName, ext);
    const timestamp = new Date().toISOString().replace(/[:.]/g, '-').substring(0, 19);
    
    if (suffix === 'sig') {
      return `${baseName}_${keyName}_${timestamp}.sig`;
    } else {
      return `${baseName}_${keyName}_${suffix}${ext}`;
    }
  }

  async getSignatureDetails(req, res) {
    try {
      const { signatureId } = req.params;

      const signature = await Signature.findById(signatureId)
        .populate('documentId', 'fileName')
        .populate('keyId', 'name')
        .lean();

      if (!signature) {
        return res.status(404).json({ error: 'Signature not found' });
      }

      res.json(signature);
    } catch (error) {
      logger.error('Error fetching signature details:', error);
      res.status(500).json({ error: 'Failed to fetch signature details' });
    }
  }

  async verifySignature(req, res) {
    try {
      const { signatureId } = req.params;

      const signature = await Signature.findById(signatureId)
        .populate('documentId')
        .populate('keyId');

      if (!signature) {
        return res.status(404).json({ error: 'Signature not found' });
      }

      const document = signature.documentId;
      const key = signature.keyId;

      const currentHash = tpmService.calculateHash(document.content);
      
      let isValid = false;
      if (currentHash === signature.documentHash) {
        isValid = await tpmService.verifySignature(
          signature.documentHash,
          signature.signature,
          key.publicKey
        );
      }

      signature.verificationStatus = isValid ? 'valid' : 'invalid';
      signature.lastVerified = new Date();
      signature.verificationCount = (signature.verificationCount || 0) + 1;
      await signature.save();

      logger.info(`Signature verified: ${signature._id} - ${isValid ? 'Valid' : 'Invalid'}`);

      res.json({
        success: true,
        valid: isValid,
        message: isValid ? 
          'Signature is valid' : 
          'Signature is invalid or document has been modified'
      });
    } catch (error) {
      logger.error('Error verifying signature:', error);
      res.status(500).json({ error: 'Failed to verify signature' });
    }
  }

  async deleteSignature(req, res) {
    try {
      const { signatureId } = req.params;

      const signature = await Signature.findById(signatureId);
      if (!signature) {
        return res.status(404).json({ error: 'Signature not found' });
      }

      // Store document ID for response
      const documentId = signature.documentId;

      // Delete the signature
      await Signature.findByIdAndDelete(signatureId);

      logger.info(`Signature deleted: ${signatureId} from document: ${documentId}`);

      res.json({
        success: true,
        message: 'Signature deleted successfully',
        documentId: documentId
      });
    } catch (error) {
      logger.error('Error deleting signature:', error);
      res.status(500).json({ error: 'Failed to delete signature' });
    }
  }

  async deleteDocument(req, res) {
    try {
      const { documentId } = req.params;

      const signatures = await Signature.find({ documentId: documentId });
      if (signatures.length > 0) {
        return res.status(400).json({ 
          error: 'Cannot delete document with existing signatures' 
        });
      }

      const document = await Document.findByIdAndDelete(documentId);
      if (!document) {
        return res.status(404).json({ error: 'Document not found' });
      }

      logger.info(`Document deleted: ${document.fileName}`);

      res.json({
        success: true,
        message: 'Document deleted successfully'
      });
    } catch (error) {
      logger.error('Error deleting document:', error);
      res.status(500).json({ error: 'Failed to delete document' });
    }
  }

  async getDocumentsStats(req, res) {
    try {
      const totalDocs = await Document.countDocuments();
      const signedDocs = await Document.countDocuments({ signatureCount: { $gt: 0 } });
      
      const fileTypes = await Document.aggregate([
        { $group: { _id: '$fileType', count: { $sum: 1 } } }
      ]);
      
      res.json({
        total: totalDocs,
        signed: signedDocs,
        unsigned: totalDocs - signedDocs,
        byType: fileTypes
      });
    } catch (error) {
      logger.error('Error fetching document stats:', error);
      res.status(500).json({ error: 'Failed to fetch document statistics' });
    }
  }

  async getSignaturesStats(req, res) {
    try {
      const totalSigs = await Signature.countDocuments();
      const validSigs = await Signature.countDocuments({ verificationStatus: 'valid' });
      const pendingSigs = await Signature.countDocuments({ verificationStatus: 'pending' });
      
      res.json({
        total: totalSigs,
        valid: validSigs,
        pending: pendingSigs,
        invalid: totalSigs - validSigs - pendingSigs
      });
    } catch (error) {
      logger.error('Error fetching signature stats:', error);
      res.status(500).json({ error: 'Failed to fetch signature statistics' });
    }
  }

  async getSignedDocuments(req, res) {
    try {
      const { documentId } = req.params;
      
      const signedDocs = await SignedDocument.find({ originalDocumentId: documentId })
        .populate('signatureId', 'signedAt signedBy')
        .sort({ createdAt: -1 })
        .lean();
      
      res.json(signedDocs);
    } catch (error) {
      logger.error('Error fetching signed documents:', error);
      res.status(500).json({ error: 'Failed to fetch signed documents' });
    }
  }

  async downloadSignedDocument(req, res) {
    try {
      const { signedDocId } = req.params;
      
      const signedDoc = await SignedDocument.findById(signedDocId);
      if (!signedDoc) {
        return res.status(404).json({ error: 'Signed document not found' });
      }
      
      res.setHeader('Content-Disposition', `attachment; filename="${signedDoc.fileName}"`);
      res.setHeader('Content-Type', 'application/octet-stream');
      res.send(signedDoc.content);
      
      logger.info(`Downloaded signed document: ${signedDoc.fileName}`);
    } catch (error) {
      logger.error('Error downloading signed document:', error);
      res.status(500).json({ error: 'Failed to download signed document' });
    }
  }

  async deleteSignedDocument(req, res) {
    try {
      const { signedDocId } = req.params;
      
      const signedDoc = await SignedDocument.findByIdAndDelete(signedDocId);
      if (!signedDoc) {
        return res.status(404).json({ error: 'Signed document not found' });
      }
      
      logger.info(`Deleted signed document: ${signedDoc.fileName}`);
      
      res.json({
        success: true,
        message: 'Signed document deleted successfully'
      });
    } catch (error) {
      logger.error('Error deleting signed document:', error);
      res.status(500).json({ error: 'Failed to delete signed document' });
    }
  }

  async getRecentActivity(req, res) {
    try {
      const recentKeys = await TPMKey.find({ status: { $ne: 'deleted' } })
        .sort({ createdAt: -1 })
        .limit(5)
        .select('name createdAt');
      
      const recentDocs = await Document.find()
        .sort({ uploadedAt: -1 })
        .limit(5)
        .select('fileName uploadedAt');
      
      const recentSigs = await Signature.find()
        .sort({ signedAt: -1 })
        .limit(5)
        .populate('documentId', 'fileName')
        .populate('keyId', 'name');
      
      res.json({
        recentKeys,
        recentDocuments: recentDocs,
        recentSignatures: recentSigs
      });
    } catch (error) {
      logger.error('Error fetching recent activity:', error);
      res.status(500).json({ error: 'Failed to fetch recent activity' });
    }
  }
}

module.exports = new DocumentController();