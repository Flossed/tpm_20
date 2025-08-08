/* File                                : manageDataModel.js
   Author                              : Daniel S. A. Khan
   Copywrite                           : Daniel S. A. Khan (c) 2025
   Description                         : ORM for the application. 
   Notes                               :

*/


const errorCatalog                     =   require( './errorCatalog' );
const {logger,applicationName}         =   require( './generic' );



function getModel ( model )
{   try
    {   logger.trace( applicationName + ':manageDataModel:getModel:Started ' );

        switch ( model )
        {   case 'login'               :   return errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'],'', { login,loginHist } );
            default                    :   return errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'],':manageDataModel:getModel:Unknown Model requested:[' + model + ']' );
        }
    }
    catch ( ex )
    {   const result                   =   { ...errorCatalog.exception };
        result.body.extendedMessage = applicationName + ':manageDataModel:getModel:An exception occurred: [' + ex + '].';
        logger.exception( result.body.extendedMessage );
        return result;
    }
}



async function createRecord ( model,dbRecord )
{   try
    {   const  responseRecord          =   {};
        logger.trace( applicationName + ':manageDataModel:createRecord:Started ' );
        const result                   =   { ...errorCatalog.noError };
        const response                 =   await getModel( model );

        if ( response.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:createRecord:Technical error:' + response.returnMsg );
            logger.error( applicationName + ':manageDataModel:createRecord:Technical error:Extended Message:' + response.body.extendedMessage );
            logger.trace( applicationName + ':manageDataModel:createRecord:Done!' );
            return response;
        }

        const dbModel                  =    response.body.payload;
        const  record                  =   new dbModel[Object.keys( dbModel )[0]]( { ...dbRecord } )  ;

        delete record._id;
        logger.debug( applicationName + ':manageDataModel:createRecord:Creating record.', record._doc );
        try
        {   const retVal               =   await dbModel[Object.keys( dbModel )[0]].create( { ...record._doc } );
            responseRecord.createRec   =   retVal._doc;
            const hist                 =   { ...retVal._doc };
            const histResponse         =   await createHistoricalRecord( dbModel[Object.keys( dbModel )[1]], hist );            

            if ( histResponse.returnCode !== errorCatalog.errors['NO_ERROR'] )
            {   logger.error( applicationName + ':manageDataModel:createRecord:Technical error:' + histResponse.returnMsg );
                logger.trace( applicationName + ':manageDataModel:createRecord:Done!' );
                return histResponse;
            }
            
            responseRecord.histRec     =   histResponse.body;
            result.body                =   responseRecord;
        }
        catch ( ex )
        {   const validationErrors     =   [];
            if ( typeof ex.errors === 'undefined' )
            {   const result           =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'],':manageDataModel:createRecord:An exception occurred: [' + ex + '].', responseRecord );
                logger.exception( result.body.extendedMessage );
                logger.trace( applicationName + ':manageDataModel:createRecord:Done!' );
                 return result;
            }

            for ( const field in ex.errors )
            {   const valErr  = {};
                if ( ex.errors[field].name.includes( 'ValidatorError' ) )
                {   valErr.name        =   ex.errors[field].name;
                    valErr.message     =   ex.errors[field].message;
                    valErr.path        =   ex.errors[field].path;
                    validationErrors.push( valErr );
                }
            }
            const result               =  errorCatalog.getErrorStructure( errorCatalog.errors['VALIDATIONERROR'],':manageDataModel:createRecord:Validation errors occurred: ', validationErrors );
            logger.trace( applicationName + ':manageDataModel:createRecord:Done!' );
            return result;
        }
        logger.trace( applicationName + ':manageDataModel:createRecord:Done!' );
        return errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'],'Blue Skies:', responseRecord );
    }
    catch ( ex )
    {   const result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'],':manageDataModel:createRecord:An exception occurred: [' + ex + '].' );
        logger.exception( result.body.extendedMessage );
        logger.trace( applicationName + ':manageDataModel:createRecord:Done!' );
        return result;
    }
}



async function createHistoricalRecord ( model, record )
{   try
    {   logger.trace( applicationName + ':manageDataModel:createHistoricalRecord:Started.' );
        logger.debug( applicationName + ':manageDataModel:createHistoricalRecord:recording historical record with ID:[' + record._id + '].' );
        const hist                     =   { ...record };
        hist.storedVersion             =   parseInt( record.__v );
        const now                      =   new Date();
        hist.recordTime                =   now.getTime();
        hist.originalRecordID          =   record._id;
        if ( typeof hist.recordStatus === 'undefined' )
        {   hist.recordStatus          =   'Active';
        }
        delete hist._id;
        const dbcreateReponse          =   await model.create( { ...hist } );
        const result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'],'Historical record Created', dbcreateReponse );
        logger.trace( applicationName + ':manageDataModel:createHistoricalRecord:Done.' );
        return result;
   }
   catch ( ex )
   {   const result                    =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'],':manageDataModel:createHistoricalRecord:An exception occurred: [' + ex + '].' );
       logger.exception( result.body.extendedMessage );
       logger.trace( applicationName + ':manageDataModel:createHistoricalRecord:Done!' );
       return result;
   }
}



async function getRecord ( model, recordID )
{   try
    {   logger.trace( applicationName + ':manageDataModel:getRecord:Started ' );
        const response                  =   getModel( model );

        if ( response.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:getRecord:Technical error:' + response.returnMsg );
            logger.error( applicationName + ':manageDataModel:getRecord:Technical error:Extended Message:' + response.body.extendedMessage );
            logger.trace( applicationName + ':manageDataModel:getRecord:Done!' );
            return response;
        }

        const dbModel                  =    response.body.payload;
        const record                   =    {};
        record.payload                 =   await dbModel.body[Object.keys( dbModel.body )[0]].find( { _id: recordID } );
        if ( record.payload.length ===  0 )
        {   const retVal               =   errorCatalog.getErrorStructure( errorCatalog.errors['BAD_RESULT'],':manageDataModel:getModel:no data found for recordID:[' + recordID + ']' );
            logger.error( retVal.body.extendedMessage );
            return retVal;
        }
        logger.trace( applicationName + ':manageDataModel:getRecord:Done.' );
        return record;
   }
   catch ( ex )
   {   const  result                =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:getRecord:An exception occurred: [' + ex + '].' );
       logger.exception( result.body.extendedMessage );
       logger.trace( applicationName + ':manageDataModel:getRecord:Done!' );
       return result;
   }
}



async function getRecords ( model )
{   try
    {   logger.trace( applicationName + ':manageDataModel:getRecords:Started ' );
        const dbModel                  =   getModel( model );
        if ( dbModel.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:getRecords:Technical error: Model not found.' );
            return dbModel;
        }
        const payload                  =   await dbModel.body.payload[Object.keys( dbModel.body.payload )[0]].find();
        const response                 =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'], ':manageDataModel:getRecords:Done.',payload );
        logger.trace( applicationName + response.extendedMessage );
        return response;
   }
   catch ( ex )
   {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:getRecords:An exception occurred: [' + ex + '].' );
       logger.exception( result.body.extendedMessage );
       logger.trace( applicationName + ':manageDataModel:getRecords:Done!' );
       return result;
   }
}



async function getHistoricalRecord ( model, recordID )
{   try
    {   logger.trace( applicationName + ':manageDataModel:getHistoricalRecord:Started ' );
        const dbModel                  =   getModel( model );
        if ( dbModel.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:getRecords:Technical error: Model not found.' );
            return dbModel;
        }
        const response                 =   await dbModel.body.payload[Object.keys( dbModel.body.payload )[1]].find( { _id: recordID } );
        if ( response.length ===  0 )
        {   const result               =   errorCatalog.getErrorStructure( errorCatalog.errors['BAD_RESULT'], ':manageDataModel:getHistoricalRecord:no data found for recordID:[' + recordID + ']' );
            logger.error( result.body.extendedMessage );
            return result;
        }
        const result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'], ':manageDataModel:getHistoricalRecord:found data for recordID:[' + recordID + ']', response[0] );
        logger.trace( applicationName + ':manageDataModel:getHistoricalRecord:Done.' );
        return result;
   }
   catch ( ex )
   {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:getHistoricalRecord:An exception occurred: [' + ex + '].' );
       logger.exception( result.body.extendedMessage );
       logger.trace( applicationName + ':manageDataModel:getHistoricalRecord:Done!' );
       return result;
   }
}



async function getHistoricalRecords ( model )
{   try
    {   logger.trace( applicationName + ':manageDataModel:getHistoricalRecords:Started ' );
        const dbModel                  =   getModel( model );
        if ( dbModel.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:getRecords:Technical error: Model not found.' );
            return dbModel;
        }
        const response                 =   await dbModel.body.payload[Object.keys( dbModel.body.payload )[1]].find();
        const result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'], ':manageDataModel:getHistoricalRecords:Done.', response );
        logger.trace( applicationName + result.extendedMessage );
        return result;
   }
   catch ( ex )
   {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:getHistoricalRecords:An exception occurred: [' + ex + '].' );
       logger.exception( result.body.extendedMessage );
       logger.trace( applicationName + ':manageDataModel:getHistoricalRecords:Done!' );
       return result;
   }
}



async function  updateRecord ( model, record )
{   try
    {   logger.trace( applicationName + ':manageDataModel:updateRecord:Started.' );
        logger.debug( applicationName + ':manageDataModel:updateRecord:updateRecord record with ID:[' + record._id + '].' );
        const dbModel                  =   getModel( model );
        if ( dbModel.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:getRecords:Technical error: Model not found.' );
            return dbModel;
        }

        try
        {   const tempRec              =   { ...record };
            tempRec.__v                =   parseInt( record.__v ) + 1;
            const createRec            =   await dbModel.body.payload[Object.keys( dbModel.body.payload )[0]].findByIdAndUpdate( record._id, { ...tempRec }, { useFindAndModify: false, new: true, runValidators: true } );
            const histRec              =   await createHistoricalRecord( dbModel.body.payload[Object.keys( dbModel.body.payload )[1]], { ...createRec._doc } );

            if ( histRec.returnCode !== errorCatalog.errors['NO_ERROR'] )
            {   logger.error( applicationName + ':manageDataModel:updateRecord:Technical error:' + histRec.returnMsg );
                logger.trace( applicationName + ':manageDataModel:updateRecord:Done!' );
                return histRec;
            }
            const responseRecord       =   {};
            responseRecord.createRec   =   createRec._doc;
            responseRecord.histRec     =   histRec.body.payload;
            const  result              =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'], 'Blue Skies', responseRecord );
            logger.trace( applicationName + ':manageDataModel:updateRecord:Done.' );
            return result;
        }
        catch ( ex )
        {   const validationErrors     =   [];
            for ( const field in ex.errors )
            {   const valErr           =   {};
                if ( ex.errors[field].name.includes( 'ValidatorError' ) )
                {   valErr.name        =   ex.errors[field].name;
                    valErr.message     =   ex.errors[field].message;
                    valErr.path        =   ex.errors[field].path;
                    validationErrors.push( valErr );
                }
            }
            const  resultE                   =   errorCatalog.getErrorStructure( errorCatalog.errors['VALIDATIONERROR'], ':manageDataModel:updateRecord:Validation errors occurred: ', validationErrors );
            logger.trace( applicationName + ':manageDataModel:updateRecord:Done!' );
            return resultE;
        }
    }
    catch ( ex )
    {   const  resultEx                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:updateRecord:An exception occurred: [' + ex + '].' );
        logger.exception( resultEx.body.extendedMessage );
        logger.trace( applicationName + ':manageDataModel:updateRecord:Done!' );
        return resultEx;
    }
}



async function deleteRecord ( model, record )
{   try
    {   logger.trace( applicationName + ':manageDataModel:deleteRecord:Started.' );
        logger.debug( applicationName + ':manageDataModel:deleteRecord:deleting record with ID:[' + record._id + '].' );
        const dbModel                  =   getModel( model );
        if ( dbModel.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:getRecords:Technical error: Model not found.' );
            return dbModel;
        }
        record.recordStatus            =   'Deleted';
        const histRecResponse          =   await createHistoricalRecord( dbModel.body.payload[Object.keys( dbModel.body.payload )[1]], record );
        if ( histRecResponse.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:deleteRecord:Technical error:' + histRecResponse.returnMsg );
            logger.trace( applicationName + ':manageDataModel:deleteRecord:Done.' );
            return histRecResponse;
        }
        const response                 =   await dbModel.body.payload[Object.keys( dbModel.body.payload )[0]].findByIdAndDelete( record._id );
        const result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'], ':manageDataModel:deleteRecord:Done.', response );

        logger.debug( applicationName + ':manageDataModel:deleteRecord:Result: ' + JSON.stringify( response ) );
        logger.trace( applicationName + ':manageDataModel:deleteRecord:Done.' );
        return result;
    }
    catch ( ex )
    {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:deleteRecord:An exception occurred: [' + ex + '].' );
        logger.exception( result.body.extendedMessage );
        logger.trace( applicationName + ':manageDataModel:deleteRecord:Done!' );
        return result;
    }
}



async function checkRecord ( model, criterea )
{   try
    {   logger.trace( applicationName + ':manageDataModel:checkRecord:Started ' );
        const dbModel                  =   getModel( model );
        if ( dbModel.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:getRecords:Technical error: Model not found.' );
            return dbModel;
        }        
        const response                 =   await dbModel.body.payload[Object.keys( dbModel.body.payload )[0]].find( criterea );        
        console.log( response );
        const result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'], ':manageDataModel:checkRecord:Done.', response );
        logger.trace( applicationName + ':manageDataModel:checkRecord:Done.' );
        return result;
   }
   catch ( ex )
   {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:checkRecord:An exception occurred: [' + ex + '].' );
       logger.exception( result.body.extendedMessage );
       logger.trace( applicationName + ':manageDataModel:checkRecord:Done!' );
       return result;
   }
}



async function duplicateRecord (  model, record )
{   try
    {   let localRec;
        logger.trace( applicationName + ':manageDataModel:duplicateRecord:Started.' );
        logger.debug( applicationName + ':manageDataModel:duplicateRecord:Duplicating record with ID:[' + record._id + '].' );
        localRec                       =   {};
        localRec                       =   { ...record };
        delete localRec._id;
        const duplicate                   =   await createRecord( model, localRec );

        const result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'], ':manageDataModel:duplicateRecord:Done.', duplicate );
        logger.debug( applicationName + ':manageDataModel:duplicateRecord:Result:', duplicate );
        logger.trace( applicationName + ':manageDataModel:duplicateRecord:Done.' );
        return result;
   }
   catch ( ex )
   {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:duplicateRecord:An exception occurred: [' + ex + '].' );
       logger.exception( result.body.extendedMessage );
       logger.trace( applicationName + ':manageDataModel:duplicateRecord:Done!' );
       return result;
   }
}



async function restoreRecord ( model, histRecordID )
{   try
    {   logger.trace( applicationName + ':manageDataModel:restoreRecord:Started.' );
        const dbModel                  =   getModel( model );
        if ( dbModel.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:getRecords:Technical error: Model not found.' );
            return dbModel;
        }
        if ( typeof histRecordID === 'undefined' || histRecordID.length === 0 )
        {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['BAD_REQUEST'], ':manageDataModel:restoreRecord:No historical record ID provided.' );
            logger.error( applicationName + result.body.extendedMessage );
             return result;
        }

        const histRecord               =   await dbModel.body.payload[Object.keys( dbModel.body.payload )[1]].findById( histRecordID );
        if ( histRecord == null )
        {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['BAD_REQUEST'], ':manageDataModel:restoreRecord:No historical record ID found!.' );
            logger.error( applicationName + result.body.extendedMessage );
            return result;
        }

        const dataRecord               =   { ... histRecord._doc };
        delete dataRecord._id;
        delete dataRecord.__v;
        delete dataRecord.recordTime;
        delete dataRecord.storedVersion;
        delete dataRecord.originalRecordID;
        delete dataRecord.recordStatus;
        const newRecord                =   await createRecord( model, dataRecord );
        if ( newRecord.returnCode !== 0 )
        {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['BAD_REQUEST'], ':manageDataModel:restoreRecord:Could not create a new Record.' );
            logger.error( applicationName + result.body.extendedMessage );
            return result;
        }

        const tempRec                  =   { ... histRecord._doc };
        tempRec.__v                    =   parseInt( tempRec.__v ) + 1;
        const now                      =   new Date();
        tempRec.recordTime             =   now.getTime();
        tempRec.restoredRecordID       =   newRecord.body.createRec._id;
        tempRec.recordStatus           =   'RESTORED';
        await dbModel.body.payload[Object.keys( dbModel.body.payload )[1]].findByIdAndUpdate( histRecordID, { ...tempRec }, { useFindAndModify: false, new: true } );

        const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'], ':manageDataModel:restoreRecord:Created a new Record.',newRecord.body );
        return result;
    }
    catch ( ex )
    {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:restoreRecord:An exception occurred: [' + ex + '].' );
        logger.exception( result.body.extendedMessage );
        logger.trace( applicationName + ':manageDataModel:restoreRecord:Done!' );
        return result;
   }
}



async function validateRecord ( model, dbRecord )
{   try
    {   logger.trace( applicationName + ':manageDataModel:validateRecord:Started ' );
        logger.debug( applicationName + ':manageDataModel:validateRecord:Validating record.' );
        const dbModel                  =   getModel( model );
        if ( dbModel.returnCode !== errorCatalog.errors['NO_ERROR'] )
        {   logger.error( applicationName + ':manageDataModel:getRecords:Technical error: Model not found.' );
            return dbModel;
        }
        const  record                  =    new dbModel.body.payload[Object.keys( dbModel.body.payload )[0]]( { ...dbRecord } )  ;
        const errors                   =   record.validateSync();
        const errorList                =   [];
        if ( errors !== undefined )
        {   Object.values( errors.errors ).forEach( ( error ) => { errorList.push( error.properties ); } ) ;
            const  result              =   errorCatalog.getErrorStructure( errorCatalog.errors['VALIDATIONERROR'], ':manageDataModel:validateRecord:Validation errors occurred', errorList );
            logger.error( applicationName + result.extendedMessage );
            return                           result;
        }
        const  result              =   errorCatalog.getErrorStructure( errorCatalog.errors['NO_ERROR'], ':manageDataModel:validateRecord:No Validation errors occurred', errorList );
        logger.trace( applicationName + ':manageDataModel:validateRecord:Done!' );
        return                           result;
   }
   catch ( ex )
   {   const  result                   =   errorCatalog.getErrorStructure( errorCatalog.errors['EXCEPTION'], ':manageDataModel:validateRecord:An exception occurred: [' + ex + '].' );
        logger.exception( result.body.extendedMessage );
        logger.trace( applicationName + ':manageDataModel:validateRecord:Done!' );
        return result;
   }
}



module.exports.createRecord            =   createRecord;
module.exports.createHistoricalRecord  =   createHistoricalRecord;
module.exports.getRecord               =   getRecord;
module.exports.getRecords              =   getRecords;
module.exports.getHistoricalRecord     =   getHistoricalRecord;
module.exports.getHistoricalRecords    =   getHistoricalRecords;
module.exports.updateRecord            =   updateRecord;
module.exports.deleteRecord            =   deleteRecord;
module.exports.checkRecord             =   checkRecord;
module.exports.duplicateRecord         =   duplicateRecord;
module.exports.restoreRecord           =   restoreRecord;
module.exports.validateRecord          =   validateRecord;
