const mongoose = require('mongoose');

const SignatureSchema = new mongoose.Schema({
  documentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Document',
    required: true
  },
  keyId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'TPMKey',
    required: true
  },
  signature: {
    type: String,
    required: true
  },
  algorithm: {
    type: String,
    default: 'ES256'
  },
  documentHash: {
    type: String,
    required: true
  },
  signedAt: {
    type: Date,
    default: Date.now
  },
  signedBy: {
    type: String,
    default: 'system'
  },
  verificationStatus: {
    type: String,
    enum: ['valid', 'invalid', 'pending', 'expired'],
    default: 'pending'
  },
  lastVerified: {
    type: Date,
    default: null
  },
  verificationCount: {
    type: Number,
    default: 0
  },
  metadata: {
    type: Map,
    of: String
  }
}, {
  timestamps: true,
  collection: 'signatures'
});

SignatureSchema.index({ documentId: 1 });
SignatureSchema.index({ keyId: 1 });
SignatureSchema.index({ signedAt: -1 });
SignatureSchema.index({ verificationStatus: 1 });

module.exports = mongoose.model('Signature', SignatureSchema);