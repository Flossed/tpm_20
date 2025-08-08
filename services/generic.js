/* File                                : generic.js
   Author                              : Daniel S. A. Khan
   Copywrite                           : Daniel S. A. Khan (c) 2025
   Description                         : This file contains the generic functions for the application.
   Notes                               :

*/
const config                           =   require( '../services/configuration' );
const Logger                           =   require( '@zandd/app-logger' );
const logFileName                      =   config.get( 'application:logFileName' );
const applicationName                  =   config.get( 'application:applicationName' );
const ApplicationPort                  =   config.get( 'application:ServiceEndPointPort' );
const outputToBrowser                  =   config.get( 'application:outputToBrowser' );
const logTracelevel                    =   config.get( 'application:logTracelevel' );
const consoleOutput                    =   config.get( 'application:consoleOutput' );
const logPath                          =   config.get( 'application:logPath' );
const dbName                            =  config.get( 'application:dbName' );
const version                          =   config.get( 'application:version' );
const lastFix                          =   config.get( 'application:lastFix' );

const logConfig = {   logTracelevel: logTracelevel,        // Log level: exception|error|warn|info|http|trace|debug
                      consoleOutput: consoleOutput,          // Console output: 'on'|'off'
                      logPath: logPath,           // Path for log files
                      dateLocale: 'de-DE',          // Date formatting locale
                      fileRotation: true,           // Enable daily file rotation
                      maxFileSize: '20m',           // Maximum file size before rotation
                      maxFiles: '14d'               // Keep files for 14 days
                  };


const logger                           =   new Logger( logFileName, logConfig );

module.exports.logger                  =   logger;
module.exports.applicationName         =   applicationName;
module.exports.ApplicationPort         =   ApplicationPort;
module.exports.outputToBrowser         =   outputToBrowser;
module.exports.logTracelevel           =   logTracelevel;
module.exports.consoleOutput           =   consoleOutput;
module.exports.logPath                 =   logPath;
module.exports.dbName                  =   dbName;
module.exports.version                 =   version;
module.exports.lastFix                 =   lastFix;
module.exports.logFileName             =   logFileName;
