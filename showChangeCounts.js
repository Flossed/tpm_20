/* File             : showChangeCounts.js
   Author           : Daniel S. A. Khan
   Copywrite        : Daniel S. A. Khan (c) 2025
   Description      : running this script show the changes done on the project today. it is based on the logfile, and will check the
                      restarts of the application, to make sure this one makes sense use nodmon to run the application, nodemon will
                      restart the application when a change is detected.
                      to assure nodemon doesn't go ballisctic use the nodemon.,json to trottle the restarts and delay them a bit.
   Notes            :
*/

const fs                               =   require( 'fs' ) .promises;
const {logger}                         =   require( './services/generic' );
const {applicationName}                =   require( './services/generic' );
const {logFileName}                    =   require( './services/generic' );
const { logPath }                      =   require( './services/generic' );


const options                          =   {   month : '2-digit',
                                               day   : '2-digit',
                                               year  : 'numeric',
                                               hour  : '2-digit',
                                               minute: '2-digit',
                                               second: '2-digit'
                                           };

async function getCurrentLogFile ()
{   try
    {   logger.trace( applicationName + ':index:getCurrentLogFile:Starting' );
        const dateFormat               =   () => { return new Date( Date.now() ).toLocaleString( 'de-DE', options ); };
        const temp                     =   dateFormat().split( ',' ) ;
        const datestruct               =   temp[0].split( '.' );
        const date                     =   datestruct[2] + datestruct[0] + datestruct[1];
        const logFileNameStr           =   logPath + logFileName   + '-' + date + '.log';

        const data                       =   await fs.readFile( logFileNameStr );
        const fileContents               =  data.toString() ;
        const strMatch                 = 'Starting ' + logFileName;
        const restartCount = ( fileContents.match( new RegExp( strMatch, 'g' ) ) || [] ).length;
        logger.trace( applicationName + ':index:getCurrentLogFile:Done' );
        return restartCount;
    }
    catch ( ex )
    {   logger.exception( applicationName + ':index:getCurrentLogFile:An exception occurred :[' + ex + '].' );
    }
}



async function main ()
{   try
    {   logger.trace( applicationName + ':index:main:Starting' );
        const restartCount             =   await getCurrentLogFile();
        logger.debug( applicationName + ':index:main:restartCount:[' + restartCount + '].' );
        logger.trace( applicationName + ':index:main:Done' );
    }
    catch ( ex )
    {   logger.exception( applicationName + 'index:main:An exception Occurred:[' + ex + ']' );
    }
}

main();