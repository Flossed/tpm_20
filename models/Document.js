const mongoose = require('mongoose');

const DocumentSchema = new mongoose.Schema({
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
  hash: {
    type: String,
    required: true
  },
  uploadedBy: {
    type: String,
    default: 'system'
  },
  uploadedAt: {
    type: Date,
    default: Date.now
  },
  metadata: {
    type: Map,
    of: String
  }
}, {
  timestamps: true,
  collection: 'documents'
});

DocumentSchema.index({ fileName: 1 });
DocumentSchema.index({ uploadedAt: -1 });
DocumentSchema.index({ hash: 1 });

module.exports = mongoose.model('Document', DocumentSchema);