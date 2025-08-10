/* File             : index.js
   Author           : Daniel S. A. Khan
   Copywrite        : Daniel S. A. Khan (c) 2025
   Description      : Main file for the TPM 2.0 Document Signing Application
   Notes            :

*/


const mongoose                         =   require( 'mongoose' );
const express                          =   require( 'express' );
const bodyParser                       =   require( 'body-parser' );
const fileUpload                       =   require( 'express-fileupload' );
const favicon                          =   require( 'serve-favicon' );
const path                             =   require( 'path' );
const cors                             =   require( 'cors' );




const {logger}                         =   require( './services/generic' );
const {ApplicationPort}                =   require( './services/generic' );
const {applicationName}                =   require( './services/generic' );
const {dbName}                         =   require( './services/generic' );
const {version}                        =   require( './services/generic' );
const {lastFix}                        =   require( './services/generic' );
const errorObject                      =   require( './services/errorCatalog' );


const db                                =   mongoose.connection;
const app                               =   express();



// eslint-disable-next-line no-undef
const directoryName                     = __dirname;
app.set( 'view engine','ejs' );
mongoose.set('debug', true);
//mongoose.connect( dbName );

mongoose.connect(  dbName );
app.use( bodyParser.json() );
// app.use( fileUpload() ); // Disabled - using multer for file uploads instead
app.use( bodyParser.urlencoded( {extended:true} ) );
app.use( express.static( 'public' ) );
app.use( favicon( path.join( directoryName, 'public', 'img', 'zandd.ico' ) ) );
app.use( cors() );
app.use( '/css',express.static( path.join( directoryName, 'node_modules/bootstrap/dist/css' ) ) );
app.use( '/bootstrap-icons', express.static( path.join( __dirname, 'node_modules/bootstrap-icons' ) ) );

 



app.use( function ( req, res, next )
{   res.header( 'Access-Control-Allow-Origin', '*' );
    res.header( 'Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept' );
    next();
} );


const genCntrl                          = require( './controllers/generic' );
const keyManagementController          = require( './controllers/keyManagementController' );
const documentController               = require( './controllers/documentController' );



function setRouting ()
{   try
    {   logger.trace( applicationName + ':index:setRouting:Started ' );        
        
        // Key Management Routes
        app.get( '/keys', keyManagementController.listKeys );
        app.get( '/keys/:keyId', keyManagementController.viewKey );
        app.get( '/tpm', keyManagementController.showTPMManagement.bind(keyManagementController) );
        app.get( '/api/keys', keyManagementController.getKeysAPI );
        app.get( '/api/keys/stats', keyManagementController.getKeysStats.bind(keyManagementController) );
        app.post( '/api/keys', keyManagementController.createKey.bind(keyManagementController) );
        app.delete( '/api/keys/:keyId', keyManagementController.deleteKey.bind(keyManagementController) );
        app.post( '/api/keys/:keyId/csr', keyManagementController.generateCSR.bind(keyManagementController) );
        app.post( '/api/keys/:keyId/certificate', keyManagementController.uploadCertificate.bind(keyManagementController) );
        
        // Document Management Routes
        app.get( '/documents', documentController.listDocuments );
        app.get( '/documents/:documentId', documentController.viewDocument );
        app.get( '/documents/:documentId/sign', documentController.showSignPage );
        app.get( '/api/documents', documentController.getDocumentsAPI );
        app.get( '/api/documents/stats', documentController.getDocumentsStats.bind(documentController) );
        app.post( '/api/documents', documentController.uploadDocument );
        app.delete( '/api/documents/:documentId', documentController.deleteDocument );
        app.post( '/api/documents/:documentId/sign', documentController.signDocument.bind(documentController) );
        
        // Stats and Activity Routes (must come before parameterized routes)
        app.get( '/api/signatures/stats', documentController.getSignaturesStats.bind(documentController) );
        
        // Signature routes with parameters
        app.get( '/api/signatures/:signatureId', documentController.getSignatureDetails );
        app.post( '/api/signatures/:signatureId/verify', documentController.verifySignature );
        app.delete( '/api/signatures/:signatureId', documentController.deleteSignature );
        
        // Signed Document Routes
        app.get( '/api/documents/:documentId/signed', documentController.getSignedDocuments );
        app.get( '/api/signeddocuments/:signedDocId/download', documentController.downloadSignedDocument );
        app.delete( '/api/signeddocuments/:signedDocId', documentController.deleteSignedDocument );
        
        app.get( '/api/activity/recent', documentController.getRecentActivity );
        
        // Generic Routes
        app.get( '/', genCntrl.main );
        app.get( '/about', genCntrl.about );
        app.get( '/privacy', genCntrl.privacyPolicy );
        app.get( '/terms', genCntrl.termsOfService );
        app.get( '/cookies', genCntrl.cookiePolicy );
        
        // Catch-all route
        app.use( '*', genCntrl.unknown );
        
        logger.trace( applicationName + ':index:setRouting:Done ' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':index:setRouting:An exception Occured:[' + ex + ']' );
    }
}


async function initializeServices ()
{   try
    {   logger.trace( applicationName + ':index:initializeServices: Starting' );

        const timeStamp                = new Date();
        const dbNameArray              = dbName.split( '/' );

        const appNameString            = 'Starting ' + applicationName;
        const timeStampString          = 'Time: ' + timeStamp.toLocaleTimeString( 'de-DE' );
        const dateString               = 'Date: ' + timeStamp.toLocaleDateString( 'de-DE' );
        const portString               = 'App listening on port [' + ApplicationPort + ']';
        const dbString                 = 'DB Name: [' + dbNameArray[dbNameArray.length - 1] + ']';
        const versionString            = 'Version: [' + version  + ']';
        const lastFixString            = 'Last Fix: [' + lastFix + ']';

        logger.info( '********************************************************************************' );
        logger.info( '*'.padEnd( 21 ,' ' ) + appNameString.padEnd( '58',' ' ) + '*' );
        logger.info( '*'.padEnd( 21 ,' ' ) + timeStampString.padEnd( '58',' ' ) + '*' );
        logger.info( '*'.padEnd( 21 ,' ' ) + dateString.padEnd( '58',' ' ) + '*' );
        logger.info( '*'.padEnd( 21 ,' ' ) + portString.padEnd( '58',' ' ) + '*' );
        logger.info( '*'.padEnd( 21 ,' ' ) + dbString.padEnd( '58',' ' ) + '*' );
        logger.info( '*'.padEnd( 21 ,' ' ) + versionString.padEnd( '58',' ' ) + '*' );
        logger.info( '*'.padEnd( 21 ,' ' ) + lastFixString.padEnd( '58',' ' ) + '*' );
        logger.info( '********************************************************************************' );

        db.on( 'error', console.error.bind( console, 'connection error: ' ) );
        db.once( 'open',function () { console.log( 'Connected to DB' ); } );

        logger.trace( applicationName + ':index:initializeServices: Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':index:initializeServices:An exception occured:[' + ex + ']' );
    }
}


function main ()
{   try
    {   logger.trace( applicationName + ':index:main:Starting' );
        setRouting();
        initializeServices();
        logger.trace( applicationName + ':index:main:Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + 'index:main:An exception Occurred:[' + ex + ']' );
    }
}

module.exports = app.listen( ApplicationPort );
main();
