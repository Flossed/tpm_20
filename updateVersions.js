/* File             : updateVersions.js.js
   Author           : Daniel S. A. Khan
   Copywrite        : Daniel S. A. Khan (c) 2024
   Description      : running this script will update the version number and last fix information in the default.config file
   Notes            :
*/

const fs                               =   require( 'fs' );

const { execSync }                     =   require( 'child_process' );
const {logger}                         =   require( './services/generic' );
const {applicationName}                =   require( './services/generic' );
const {dbName}                         =   require( './services/generic' );
const currentConfig                    =   require( './config/default.json' );

const   getTagCommand                  =   'git tag -n10 ';
const   getCurrentTagCommand           =   'git describe --tags --abbrev=0';
const   currentVersions                  =   {};



function getCurrentVersions ()
{   const tagList                      =   execSync( getTagCommand ).toString().split( '\n' );
    const currentTag                   =   execSync( getCurrentTagCommand ).toString().split( '\n' );
    currentVersions.tagList            =   tagList;
    currentVersions.dbName             =   dbName;
    currentVersions.currentTag         =   currentTag;
    return currentVersions;
}

function  getConfig ()
{   try
    {   logger.trace( applicationName + ':index:getConfig:Starting' );
        logger.trace( applicationName + ':index:getConfig:Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':index:getConfig:An exception Occurred:[' + ex + ']' );
    }
}



function updateConfig ( version, description )
{   try
    {   logger.trace( applicationName + ':index:updateConfig:Starting' );
        const versionString            = 'Version: [' + version  + ']';
        const descriptionString        = 'Last Fix: [' + description + ']';
        logger.info(  versionString.padEnd( '58',' ' ) + '*' );
        logger.info(  descriptionString.padEnd( '58',' ' ) + '*' );
        console.log( 'Current COnfiguration: ', currentConfig );
        currentConfig.application.version = version;
        currentConfig.application.lastFix = description;
        console.log( 'Updated Configuration: ', currentConfig );
        const data                     =   JSON.stringify( currentConfig );
        const result                   =   fs.writeFileSync( './config/default.json', data  );
        logger.trace( applicationName + ':index:updateConfig:Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + ':index:updateConfig:An exception Occurred:[' + ex + ']' );
    }
}



function main ()
{   try
    {   logger.trace( applicationName + ':index:main:Starting' );
        getConfig();
        const currentVersions          = getCurrentVersions();
        const lastFix                  = currentVersions.tagList.length < 2 ? '' : currentVersions.tagList[currentVersions.tagList.length - 2].slice( 16 );
        const version                  = currentVersions.currentTag[0];
        updateConfig( version, lastFix );
        logger.trace( applicationName + ':index:main:Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + 'index:main:An exception Occurred:[' + ex + ']' );
    }
}



main();