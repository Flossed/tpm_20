const mongoose = require('mongoose');

const TPMKeySchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  keyType: {
    type: String,
    default: 'ES256',
    enum: ['ES256']
  },
  tpmHandle: {
    type: String,
    required: true
  },
  publicKey: {
    type: String,
    required: true
  },
  certificateRequest: {
    type: String,
    default: null
  },
  certificate: {
    type: String,
    default: null
  },
  createdBy: {
    type: String,
    default: 'system'
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  lastUsed: {
    type: Date,
    default: null
  },
  usageCount: {
    type: Number,
    default: 0
  },
  status: {
    type: String,
    enum: ['active', 'disabled', 'deleted'],
    default: 'active'
  },
  metadata: {
    type: Map,
    of: String
  }
}, {
  timestamps: true,
  collection: 'tpmkeys'
});

TPMKeySchema.index({ name: 1 }, { unique: true });
TPMKeySchema.index({ tpmHandle: 1 }, { unique: true });
TPMKeySchema.index({ status: 1 });
TPMKeySchema.index({ createdAt: -1 });

module.exports = mongoose.model('TPMKey', TPMKeySchema);