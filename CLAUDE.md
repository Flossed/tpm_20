# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a TPM 2.0 Document Signing Application built with Node.js/Express that creates ES256 keypairs using hardware TPM (Trusted Platform Module) and signs documents securely. The application supports both Windows and Linux platforms with fallback to software keys when TPM is unavailable.

## Development Commands

### Start/Development
- `npm start` - Start the application using nodemon (port 10200)
- `npm run dev` - Same as npm start (development mode)

### Testing
- `npm test` - Run all tests with Mocha (10 second timeout)
- `npm run test:watch` - Run tests in watch mode
- `npm run test:coverage` - Run tests with NYC coverage reporting
- `npm run test:single` - Run a single test file (specify file with additional args)

### Utilities
- `npm run updateVersions` - Update version information across the application

### Linting
- Uses ESLint (configured in package.json devDependencies)

## Database Configuration

- MongoDB connection: `mongodb://192.168.129.197:27017/tpm20`
- Test database: `mongodb://192.168.129.197:27017/tpm20_test`
- Uses Mongoose ODM with debug mode enabled

## Architecture Overview

### MVC Structure
- **Controllers**: Handle HTTP requests and responses
  - `keyManagementController.js` - TPM key CRUD operations
  - `documentController.js` - Document upload/signing operations
  - `generic.js` - Generic routes (main, about, privacy, etc.)
  
- **Models**: Mongoose schemas for MongoDB
  - `TPMKey.js` - TPM key metadata and certificates
  - `Document.js` - Document storage and metadata
  - `Signature.js` - Digital signature records
  
- **Services**: Business logic and external integrations
  - `tpmService.js` - Core TPM operations (Windows PowerShell/Linux tpm2-tools)
  - `generic.js` - Configuration and logging setup using @zandd/app-logger
  - `configuration.js` - nconf-based configuration management
  - `errorCatalog.js` - Centralized error handling

### Key Technical Details

**TPM Integration**:
- Cross-platform TPM support (Windows PowerShell commands vs Linux tpm2-tools)
- Hardware availability detection with software fallback
- ES256 (ECDSA P-256) key generation and signing
- Key persistence in TPM with handle management

**Security Features**:
- Hardware-backed private keys (never exposed)
- SHA-256 document hashing
- Certificate Request (CSR) generation using node-forge
- Digital signature verification

**Configuration Management**:
- Uses nconf with `config/default.json`
- Environment-specific settings (development/production)
- Centralized logging with @zandd/app-logger

### File Upload Handling
- Supports .txt, .md, .json files (10MB max size)
- Uses express-fileupload middleware
- Temporary file processing in ./temp directory

### Frontend
- EJS templating engine
- Bootstrap 5 with Bootstrap Icons
- Static assets served from public/
- Multi-language support (English/Dutch) in public/lang/

## Testing Strategy

The application uses Mocha with Chai for testing:
- Model tests: `test/models.test.js`
- Service tests: `test/tpmService.test.js`
- Controller tests: `test/generic-controller-tests.js`

Coverage requirements (NYC configuration):
- 80% minimum coverage for lines, statements, functions, and branches

## Development Notes

- Application runs on port 10200 (configured in config/default.json)
- Logging configured with daily file rotation (14-day retention, 20MB max size)
- CORS enabled for cross-origin requests
- Session management with express-session (24-hour cookie expiry)
- Bootstrap CSS/JS served from node_modules

## Key Routes
- `/keys` - Key management interface
- `/documents` - Document management interface
- `/api/keys/*` - REST API for key operations
- `/api/documents/*` - REST API for document operations
- `/api/signatures/*` - Signature verification endpoints

## Platform-Specific Behavior

**Windows**:
- Uses PowerShell commands for TPM operations
- Certificate store integration (`Cert:\CurrentUser\My`)
- Microsoft Platform Crypto Provider

**Linux**:
- Uses tpm2-tools command-line utilities
- File-based key persistence and operations
- Manual handle management for persistent keys