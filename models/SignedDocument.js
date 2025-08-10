const mongoose = require('mongoose');

const SignedDocumentSchema = new mongoose.Schema({
  originalDocumentId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Document',
    required: true
  },
  signatureId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Signature',
    required: true
  },
  fileName: {
    type: String,
    required: true,
    trim: true
  },
  fileType: {
    type: String,
    required: true,
    enum: ['text', 'markdown', 'json']
  },
  content: {
    type: String,
    required: true
  },
  size: {
    type: Number,
    required: true
  },
  format: {
    type: String,
    required: true,
    enum: ['embedded', 'detached', 'pkcs7'],
    default: 'embedded'
  },
  signatureMetadata: {
    keyName: String,
    algorithm: String,
    provider: String,
    signedAt: Date,
    signedBy: String,
    isHardwareTPM: Boolean
  },
  createdBy: {
    type: String,
    default: 'system'
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  metadata: {
    type: Map,
    of: String
  }
}, {
  timestamps: true,
  collection: 'signeddocuments'
});

SignedDocumentSchema.index({ originalDocumentId: 1 });
SignedDocumentSchema.index({ signatureId: 1 });
SignedDocumentSchema.index({ fileName: 1 });
SignedDocumentSchema.index({ createdAt: -1 });

module.exports = mongoose.model('SignedDocument', SignedDocumentSchema);