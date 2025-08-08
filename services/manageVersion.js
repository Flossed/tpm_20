/* File             : manageVersion.js
   Author           : Daniel S. A. Khan
   Copywrite        : Daniel S. A. Khan (c) 2025
   Description      : This file contains the version management functions for the application.
   Notes            :
*/

const {dbName}                          =   require( './generic' );
const {version}                         =   require( './generic' );
const {lastFix}                         =   require( './generic' );


const currentVersions                   =   {};


function getCurrentVersions ()
{   currentVersions.tagList            =   lastFix;
    currentVersions.dbName             =   dbName;
    currentVersions.currentTag         =   version;
    return currentVersions;
}


module.exports                         =   { getCurrentVersions};