# TPM 2.0 Document Signing Application

A web application for creating ES256 keypairs using hardware TPM (Trusted Platform Module) and signing documents securely.

## Features

- **Hardware TPM Integration**: Create and manage ES256 keypairs stored in hardware TPM
- **Document Management**: Upload and manage text, markdown, and JSON documents
- **Digital Signatures**: Sign documents using TPM-protected keys
- **Signature Verification**: Verify document signatures against TPM
- **Certificate Management**: Generate CSRs and manage certificates for keys
- **Cross-platform Support**: Works on Windows (TPM 2.0) and Linux (tpm2-tools)

## Tech Stack

- **Backend**: Node.js, Express.js
- **Database**: MongoDB
- **Security**: Hardware TPM 2.0
- **Cryptography**: ES256 (ECDSA with P-256 and SHA-256)
- **Frontend**: EJS templates, Bootstrap 5
- **Logging**: @zandd/app-logger

## Prerequisites

- Node.js (v14 or higher)
- MongoDB (accessible at `mongodb://192.168.129.197:27017/tpm20`)
- TPM 2.0 hardware module
- Windows: TPM 2.0 enabled in BIOS/UEFI
- Linux: tpm2-tools package installed

## Installation

1. Clone the repository:
```bash
git clone https://github.com/Flossed/tpm_20.git
cd tpm_20
```

2. Install dependencies:
```bash
npm install
```

3. Configure the application:
   - Edit `config/default.json` for your environment
   - Ensure MongoDB is running and accessible

4. Start the application:
```bash
npm start
```

## Usage

### Key Management

1. **Create Key**: Navigate to Keys page and click "Create New Key"
2. **View Key Details**: Click on any key to see its public key and details
3. **Generate CSR**: From key details, generate a Certificate Signing Request
4. **Delete Key**: Remove keys from TPM (with confirmation)

### Document Signing

1. **Upload Document**: Upload .txt, .md, or .json files
2. **Sign Document**: Select a document and choose a TPM key to sign
3. **Verify Signature**: Check signature validity against the TPM
4. **View Signatures**: See all signatures for a document

## API Endpoints

### Key Management
- `GET /api/keys` - List all keys
- `POST /api/keys` - Create new key
- `GET /api/keys/:id` - Get key details
- `DELETE /api/keys/:id` - Delete key
- `POST /api/keys/:id/csr` - Generate CSR
- `POST /api/keys/:id/certificate` - Upload certificate

### Document Management
- `GET /api/documents` - List all documents
- `POST /api/documents` - Upload document
- `GET /api/documents/:id` - Get document details
- `DELETE /api/documents/:id` - Delete document
- `POST /api/documents/:id/sign` - Sign document
- `POST /api/signatures/:id/verify` - Verify signature

## Security Considerations

- All private keys are stored in hardware TPM and never exposed
- Documents are hashed using SHA-256 before signing
- Signatures use ES256 (ECDSA with P-256 curve)
- TPM operations require appropriate system permissions

## Testing

Run tests with coverage:
```bash
npm run test:coverage
```

Watch mode for development:
```bash
npm run test:watch
```

## Configuration

Edit `config/default.json`:
```json
{
  "server": {
    "port": 3000,
    "host": "localhost"
  },
  "mongodb": {
    "uri": "mongodb://192.168.129.197:27017/tpm20"
  },
  "tpm": {
    "enabled": true,
    "fallbackToSoftware": true
  }
}
```

## Development

### Project Structure
```
tpm_20/
├── config/           # Configuration files
├── controllers/      # MVC Controllers
├── documentation/    # Project documentation
├── models/          # Mongoose models
├── public/          # Static assets (CSS, JS, images)
├── services/        # Business logic and TPM service
├── test/            # Test files
├── views/           # EJS templates
└── index.js         # Main application file
```

### Running in Development
```bash
npm run dev
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For issues and questions, please use the [GitHub Issues](https://github.com/Flossed/tpm_20/issues) page.

## Acknowledgments

- TPM 2.0 Specification by Trusted Computing Group
- Node.js cryptographic libraries
- MongoDB for document storage
