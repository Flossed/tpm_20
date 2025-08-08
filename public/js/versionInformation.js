function showVersionInformation ()
{   try
    {   const currentVersions          =  document.getElementById( 'currentVersions' ).value ;
        console.log('Current Version Information:', currentVersions );

        if ( currentVersions.length > 0 )
        {   const currentVersionsObj   =   JSON.parse( currentVersions );
            console.log( 'todolist:showVersionInformation():currentVersions:', currentVersionsObj );
            const br                   = document.createElement( 'br' );

            const versionItems         =   document.getElementById( 'versionItems' );
            const container            = document.createElement( 'span' );
            const versionNode          =   document.createTextNode( 'Version : ' + currentVersionsObj.currentTag );
            
            versionItems.appendChild( versionNode );
            versionItems.appendChild( br );
            const dbType               =   currentVersionsObj.dbName.split( '/' ).pop().includes( 'TST' ) ? 'test' : 'production';

            const dbNode               =   document.createTextNode( 'Database : ' +  dbType );
            container.appendChild( dbNode );

            versionItems.appendChild( container );
            if ( dbType === 'test' )
            {   container.style.color =  'red' ;
                container.style.fontSize  = 'large';
            }
            else
            {   container.style.color =  'black' ;
            }
        }
    }
    catch ( err )
    {   console.log( 'todolist:showVersionInformation():an exception occurred:', err );
    }
}


showVersionInformation();