const { logger } = require('../services/generic');
const TPMKey = require('../models/TPMKey');
const tpmService = require('../services/tpmService');

class KeyManagementController {
  async listKeys(req, res) {
    try {
      const keys = await TPMKey.find({ status: { $ne: 'deleted' } })
        .sort({ createdAt: -1 })
        .lean();
      
      res.render('keys', {
        title: 'TPM Key Management',
        keys: keys,
        success: req.query.success,
        error: req.query.error
      });
    } catch (error) {
      logger.error('Error listing keys:', error);
      res.status(500).render('errorPage', {
        title: 'Error',
        error: 'Failed to retrieve keys'
      });
    }
  }

  async getKeysAPI(req, res) {
    try {
      const keys = await TPMKey.find({ status: { $ne: 'deleted' } })
        .sort({ createdAt: -1 })
        .select('_id name keyType status createdAt usageCount lastUsed')
        .lean();
      
      res.json(keys);
    } catch (error) {
      logger.error('Error fetching keys via API:', error);
      res.status(500).json({ error: 'Failed to retrieve keys' });
    }
  }

  async createKey(req, res) {
    try {
      const { keyName, description } = req.body;
      
      if (!keyName) {
        return res.status(400).json({ error: 'Key name is required' });
      }
      
      const existingKey = await TPMKey.findOne({ name: keyName });
      if (existingKey) {
        return res.status(400).json({ error: 'Key name already exists' });
      }
      
      const keyData = await tpmService.createES256KeyPair(keyName);
      
      const metadata = new Map([
        ['description', description || ''],
        ['inTPM', keyData.inTPM ? 'true' : 'false']
      ]);
      
      // Add Windows certificate flag and provider if present
      if (keyData.windowsCert) {
        metadata.set('windowsCert', 'true');
        if (keyData.provider) {
          metadata.set('provider', keyData.provider);
        }
        logger.info(`Created Windows certificate for key ${keyName} using provider: ${keyData.provider}`);
      }
      
      // Store private key in metadata for software keys (not ideal for production!)
      if (!keyData.inTPM && keyData.privateKey) {
        metadata.set('privateKey', keyData.privateKey);
        if (!keyData.windowsCert) {
          logger.warn(`Storing software private key for ${keyName} - consider using hardware TPM for production`);
        }
      }
      
      const newKey = new TPMKey({
        name: keyName,
        tpmHandle: keyData.handle,
        publicKey: keyData.publicKey,
        metadata: metadata
      });
      
      await newKey.save();
      logger.info(`Created new TPM key: ${keyName}`);
      
      res.json({
        success: true,
        key: {
          id: newKey._id,
          name: newKey.name,
          publicKey: newKey.publicKey,
          createdAt: newKey.createdAt
        }
      });
    } catch (error) {
      logger.error('Error creating key:', error);
      res.status(500).json({ error: 'Failed to create key' });
    }
  }

  async deleteKey(req, res) {
    try {
      const { keyId } = req.params;
      
      const key = await TPMKey.findById(keyId);
      if (!key) {
        return res.status(404).json({ error: 'Key not found' });
      }
      
      const isTPMKey = key.metadata && key.metadata.get('inTPM') === 'true';
      await tpmService.deleteKey(key.tpmHandle, isTPMKey);
      
      key.status = 'deleted';
      await key.save();
      
      logger.info(`Deleted TPM key: ${key.name}`);
      
      res.json({ success: true, message: 'Key deleted successfully' });
    } catch (error) {
      logger.error('Error deleting key:', error);
      res.status(500).json({ error: 'Failed to delete key' });
    }
  }

  async viewKey(req, res) {
    try {
      const { keyId } = req.params;
      
      const key = await TPMKey.findById(keyId).lean();
      if (!key) {
        return res.status(404).render('errorPage', {
          title: 'Error',
          error: 'Key not found'
        });
      }
      
      res.render('keyDetail', {
        title: `Key: ${key.name}`,
        key: key
      });
    } catch (error) {
      logger.error('Error viewing key:', error);
      res.status(500).render('errorPage', {
        title: 'Error',
        error: 'Failed to retrieve key details'
      });
    }
  }

  async generateCSR(req, res) {
    try {
      const { keyId } = req.params;
      const { commonName, organization, country } = req.body;
      
      const key = await TPMKey.findById(keyId);
      if (!key) {
        return res.status(404).json({ error: 'Key not found' });
      }
      
      const csr = await tpmService.generateCSR(
        key.name,
        key.tpmHandle,
        key.publicKey,
        commonName,
        organization,
        country
      );
      
      key.certificateRequest = csr;
      await key.save();
      
      logger.info(`Generated CSR for key: ${key.name}`);
      
      res.json({
        success: true,
        csr: csr
      });
    } catch (error) {
      logger.error('Error generating CSR:', error);
      res.status(500).json({ error: 'Failed to generate CSR' });
    }
  }

  async uploadCertificate(req, res) {
    try {
      const { keyId } = req.params;
      const { certificate } = req.body;
      
      const key = await TPMKey.findById(keyId);
      if (!key) {
        return res.status(404).json({ error: 'Key not found' });
      }
      
      key.certificate = certificate;
      await key.save();
      
      logger.info(`Uploaded certificate for key: ${key.name}`);
      
      res.json({
        success: true,
        message: 'Certificate uploaded successfully'
      });
    } catch (error) {
      logger.error('Error uploading certificate:', error);
      res.status(500).json({ error: 'Failed to upload certificate' });
    }
  }

  async getKeysStats(req, res) {
    try {
      const totalKeys = await TPMKey.countDocuments({ status: { $ne: 'deleted' } });
      const activeKeys = await TPMKey.countDocuments({ status: 'active' });
      const tpmKeys = await TPMKey.countDocuments({ 
        status: { $ne: 'deleted' },
        'metadata.inTPM': 'true' 
      });
      
      res.json({
        total: totalKeys,
        active: activeKeys,
        tpmBacked: tpmKeys,
        softwareBacked: totalKeys - tpmKeys
      });
    } catch (error) {
      logger.error('Error fetching key stats:', error);
      res.status(500).json({ error: 'Failed to fetch key statistics' });
    }
  }
}

module.exports = new KeyManagementController();