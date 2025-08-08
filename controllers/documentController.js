const { logger } = require('../services/generic');
const Document = require('../models/Document');
const TPMKey = require('../models/TPMKey');
const Signature = require('../models/Signature');
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
      const isTPMKey = key.metadata && key.metadata.get('inTPM') === 'true';
      
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