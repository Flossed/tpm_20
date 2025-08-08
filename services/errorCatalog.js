/* File             : errorCatalog.js
   Author           : Daniel S. A. Khan
   Copywrite        : Daniel S. A. Khan (c) 2022 -2025
   Description      :
   Notes            :

*/


/*
   structure
    {  returnCode: <int>,   // generic for all errors
      returnMsg: <string>,  // generic message pertaining to errorMessage
      body: <object>
    }
    body structure
    {  extendedMessage: <string>, //customized to process
       payload: <object>          // customized to process
    }

*/
const {logger,applicationName}         =   require( './generic' );
class Enum
{   constructor ( ...values )
    {   values.forEach( ( value, index ) => { this[value] = index; this[index] = value; } );
        Object.freeze( this );
    }
}

const errors                           = new Enum(   'NO_ERROR',
                                                     'BAD_REQUEST',
                                                     'BAD_RESULT',
                                                     'EXCEPTION',
                                                     'VALIDATIONERROR',
                                                     'BAD_DATARECORD',
                                                     'NO_ENTRIES',
                                                     'EXISTING_DATARECORD',
                                                     'USERPWD_COMBINATION_NOT_FOUND',
                                                     'USERPWD_INCORRECT',
                                                     'USER_EMAIL_NOT_FOUND',
                                                     'SYSTEM_ERROR',
                                                     'EXISTING_DATARECORD',
                                                     'EMAIL_UNKNOWN_MAILBOX',
                                                     'UNKNOWN_EMAIL_ERROR',
                                                     'EMAIL_UNKNOWN_DOMAIN',
                                                     'NO_SECURITY_TOKEN',
                                                     'SECURITY_TOKEN_NOT_FOUND',
                                                     'SECURITY_TOKEN_EXPIRED',
                                                     'SECURITY_TOKEN_FOUND',
                                                     'SECURITY_TOKEN_INVALID',
                                                     'RECORD_NOT_FOUND',
                                                     'BAD_STATE'
                                                 );

const catalog                          =   [ { returnCode: errors.SECURITY_TOKEN_FOUND,
                                              returnMsg: 'SECURITY_TOKEN_FOUND: The security token was found',
                                              body : {}
                                            },
                                            { returnCode: errors.USERPWD_INCORRECT,
                                              returnMsg: 'USERPWD_INCORRECT: The user password is incorrect',
                                              body : {}
                                            },
                                            { returnCode: errors.BAD_STATE,
                                              returnMsg: 'Bad State: The user record is found to be in an invalid state.',
                                              body : {}
                                            },
                                            { returnCode: errors.NO_SECURITY_TOKEN,
                                              returnMsg: 'NO_SECURITY_TOKEN: no security token provided',
                                              body : {}
                                            },
                                            { returnCode: errors.RECORD_NOT_FOUND,
                                              returnMsg: 'RECORD_NOT_FOUND: The requested record was not found',
                                              body : {}
                                            },
                                            { returnCode: errors.SECURITY_TOKEN_NOT_FOUND,
                                              returnMsg: 'SECURITY_TOKEN_NOT_FOUND: The security token doesn\'t exist',
                                              body : {}
                                            },
                                            { returnCode: errors.SECURITY_TOKEN_EXPIRED,
                                              returnMsg: 'SECURITY_TOKEN_EXPIRED: The security token has expired',
                                              body : {}
                                            },
                                            { returnCode: errors.NO_ERROR,
                                              returnMsg: 'NO_ERROR: no errors occurred, all blue skies',
                                              body : {}
                                            },
                                            { returnCode: errors.BAD_REQUEST,
                                              returnMsg: 'Bad Request: Can\'t understand request: request contains either contains parameters that cannot be handled',
                                              body : {}
                                            },
                                            { returnCode: errors.BAD_RESULT,
                                              returnMsg: 'Bad Result: API returned an error',
                                              body : {}
                                            },
                                            { returnCode: errors.SYSTEM_ERROR,
                                              returnMsg: 'System Error: Bumped into bad coding practices, call houston!',
                                              body : {}
                                            },
                                            { returnCode: errors.USERPWD_COMBINATION_NOT_FOUND,
                                              returnMsg: 'Data Error: username password combination not found.',
                                              body : {}
                                            },
                                            { returnCode: errors.USER_EMAIL_NOT_FOUND,
                                              returnMsg: 'Data Error: user email was not found.',
                                              body : {}
                                            },
                                            { returnCode: errors.EXCEPTION,
                                              returnMsg: 'Exception: An Exception Occurred',
                                              body : {}
                                            },
                                            { returnCode: errors.EXISTING_DATARECORD,
                                              returnMsg: 'Data Error: Data record already exists.',
                                              body : {}
                                            }
                                            ,
                                            { returnCode: errors.VALIDATIONERROR,
                                              returnMsg: 'Data Error: The input data doesn\'t validate correctly.',
                                              body : {}
                                            },
                                            { returnCode: errors.EMAIL_UNKNOWN_MAILBOX,
                                              returnMsg: 'Email Error: The Email server responded with a \'user unknown\' error.',
                                              body : {}
                                            },
                                            { returnCode: errors.UNKNOWN_EMAIL_ERROR,
                                              returnMsg: 'Email Error: an unknown error occurred whilst sending the email.',
                                              body : {}
                                            },
                                            { returnCode: errors.EMAIL_UNKNOWN_DOMAIN,
                                              returnMsg: 'Email Error: an unknown domain was used in the requested as email account.',
                                              body : {}
                                            }
                                           ];

/*Note  : while managing errors the following resolve errorCode, and errors[errorCode]
          errors.error is undefined, so it is not used.
*/

function getErrorStructure ( errorCode, extendedMessage, payload )
{   try
    {   if ( errors[errorCode] === undefined || catalog.filter( ( item ) => item.returnCode === errorCode ) [0] === undefined )
        {   logger.error( `${applicationName}: getErrorMessage: Invalid error code: [${errorCode}]` );
            const responseError = getErrorStructure( errors['SYSTEM_ERROR'] );
            return responseError;
        }
        const tmp = { ... catalog.filter( ( item ) => item.returnCode === errorCode ) [0] };
        const responseError = JSON.parse( JSON.stringify( tmp ) );
         if ( extendedMessage )
         {   responseError.body.extendedMessage = extendedMessage;
         }
         if ( payload )
         {   responseError.body.payload = payload;
         }
         logger.debug( `${applicationName}: getErrorMessage: Returning error structure for error code: [${errorCode}]` );
         logger.debug( `${applicationName}: getErrorMessage: Error structure is:`, responseError );
         return responseError;
    }
    catch ( e )
    {   logger.error( `${applicationName}: getErrorMessage: Invalid error code: ${errorCode}` );
        return getErrorStructure( errors['EXCEPTION'] );
    }
}


module.exports.errors                          = errors;
module.exports.catalog                          = catalog;
module.exports.getErrorStructure                 = getErrorStructure;
