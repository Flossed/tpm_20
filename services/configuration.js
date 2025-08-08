/* File             : configuration.js
   Author           : Daniel S. A. Khan
   Copywrite        : Daniel S. A. Khan (c) 2025  
   Description      :  Configuration file for the Personal Assistant Application, allows to read
                       configuration from a file and return the value of a key.
   Notes            :  
*/
const nconf                            =   require('nconf'); 
function Config()
{   try
    {   var environment    
        console.log("configuration:Config:Starting")                
        nconf.file("default", "./config/default.json");
    } 
    catch(ex)
    {   console.log("configuration:Config:An Exception occurred:["+ex+"]")
    }
}

Config.prototype.get = function(key) 
{    return nconf.get(key);
};
module.exports = new Config();
