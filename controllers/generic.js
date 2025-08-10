/* File             : generic.js
   Author           : Daniel S. A. Khan
   Copywrite        : Daniel S. A. Khan (c) 2025
   Description      : File that has all the controllers for the views
   Notes            :

*/

const {logger,applicationName}          =   require( '../services/generic' );
const { getCurrentVersions }            =   require( '../services/manageVersion' );
const { privacyPolicy }                 =   require( '../terms/terms' );
const { termsOfService }                =   require( '../terms/terms' );
const { cookiePolicy }                  =   require( '../terms/terms' );
const versionInformation                =   getCurrentVersions();



async function unknownHandler ( req,res )
{   try
    {   logger.trace( applicationName + ':generic:unknownHandler():Started' );
        logger.error( applicationName + ':generic:unknownHandler():Unknown Path:[' + req.originalUrl + '].' );
        res.render( 'unknown', { currentVersions:versionInformation} );
        logger.trace( applicationName + ':generic:unknownHandler():Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':generic:unknownHandler():An exception occurred :[' + ex + '].' );
    }
}



async function aboutHandler ( req,res )
{   try
    {   logger.trace( applicationName + ':generic:aboutHandler():Started' );
        res.render( 'about', { currentVersions:versionInformation} );
        logger.trace( applicationName + ':generic:aboutHandler():Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':generic:aboutHandler():An exception occurred :[' + ex + '].' );
    }
}



async function homeHandler ( req,res )
{   try
    {   logger.trace( applicationName + ':generic:homeHandler():Started' );
        
        // Import models for dashboard stats
        const TPMKey = require('../models/TPMKey');
        const Document = require('../models/Document');
        const Signature = require('../models/Signature');
        
        // Fetch dashboard statistics
        const [keys, documents, signatures] = await Promise.all([
            TPMKey.find({ status: { $ne: 'deleted' } }).lean(),
            Document.find().lean(),
            Signature.find().lean()
        ]);
        
        res.render( 'main' , { 
            currentVersions: versionInformation,
            keys: keys,
            documents: documents,
            signatures: signatures
        });
        logger.trace( applicationName + ':generic:homeHandler():Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':generic:homeHandler():An exception occurred :[' + ex + '].' );
        res.render( 'main' , { 
            currentVersions: versionInformation,
            keys: [],
            documents: [],
            signatures: []
        });
    }
}



async function exceptionHandler ( req,res )
{   try
    {   logger.trace( applicationName + ':generic:exceptionHandler():Started' );
        res.render( 'errorPage' , { currentVersions:versionInformation} );
        logger.trace( applicationName + ':generic:exceptionHandler():Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':generic:exceptionHandler():An exception occurred :[' + ex + '].' );
    }
}



function findTerm ( originalString, searchString )
{   try
    {   if ( originalString.includes( searchString ) )
        {   return originalString;
        }
        return null;
    }
    catch ( ex )
    {   logger.exception( applicationName + ':generic:findterm():An exception occurred :[' + ex + '].' );
        return null;
    }
}

async function addDataHandler ( req,res )
{   try
    {   logger.trace( applicationName + ':generic:addDataHandler():Started' );
        res.render( 'addData' , { currentVersions:versionInformation} );
        logger.trace( applicationName + ':generic:addDataHandler():Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':generic:addDataHandler():An exception occurred :[' + ex + '].' );
    }
}


async function main ( req, res )
{   try
    {   logger.trace( applicationName + ':generic:main():Started' );

        switch ( req.originalUrl )
        {  case '/'                                      :   homeHandler ( req,res );
                                                             break;
           case '/about'                                 :   aboutHandler( req,res );
                                                             break;
           case '/addData'                               :   res.render( 'addData', { currentVersions:versionInformation} );
                                                             break;
           case '/cookie-policy'                         :   res.render( 'cookiePolicy',  cookiePolicy  );
                                                             break;
           case '/privacy-policy'                        :   res.render( 'privacyPolicy', privacyPolicy  );
                                                             break;
           case '/terms-of-service'                      :   res.render( 'termsOfService', termsOfService );
                                                             break;
           default                                       :   logger.debug( applicationName + ':generic:main():Request URL is [' + req.originalUrl + '].' );

                                                             unknownHandler( req,res );
                                                             break;
        }
        logger.trace( applicationName + ':generic:main():Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':generic:main():An exception occurred: [' + ex + '].' );
        //exceptionHandler( req,res );
    }
}
async function privacyPolicyHandler(req, res) {
    try {
        logger.trace(applicationName + ':generic:privacyPolicyHandler():Started');
        res.render('privacyPolicy', privacyPolicy);
        logger.trace(applicationName + ':generic:privacyPolicyHandler():Done');
    } catch (ex) {
        logger.exception(applicationName + ':generic:privacyPolicyHandler():An exception occurred :[' + ex + '].');
    }
}

async function termsOfServiceHandler(req, res) {
    try {
        logger.trace(applicationName + ':generic:termsOfServiceHandler():Started');
        res.render('termsOfService', termsOfService);
        logger.trace(applicationName + ':generic:termsOfServiceHandler():Done');
    } catch (ex) {
        logger.exception(applicationName + ':generic:termsOfServiceHandler():An exception occurred :[' + ex + '].');
    }
}

async function cookiePolicyHandler(req, res) {
    try {
        logger.trace(applicationName + ':generic:cookiePolicyHandler():Started');
        res.render('cookiePolicy', cookiePolicy);
        logger.trace(applicationName + ':generic:cookiePolicyHandler():Done');
    } catch (ex) {
        logger.exception(applicationName + ':generic:cookiePolicyHandler():An exception occurred :[' + ex + '].');
    }
}

module.exports.main = main;
module.exports.about = aboutHandler;
module.exports.privacyPolicy = privacyPolicyHandler;
module.exports.termsOfService = termsOfServiceHandler;
module.exports.cookiePolicy = cookiePolicyHandler;
module.exports.unknown = unknownHandler;

