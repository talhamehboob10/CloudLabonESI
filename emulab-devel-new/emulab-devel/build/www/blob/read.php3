<?php

if( preg_match( "(/(\w+)/([\w-]+)$)D",
    $_SERVER[ 'PATH_INFO' ], $matches ) == 1 ) {
    $key = $matches[ 1 ];
    $blob = $matches[ 2 ];
    $hash = "";
} else {
    header( "HTTP/1.0 404 Not found" );

    echo( "<html><head><title>Not found</title></head>\n" );
    echo( "<body><p>The URL given was not a valid blob spefication.</p></body></html>\n" );
    return;
}

if( preg_match( "/(\w+)/D", $_GET[ 'hash' ], $matches ) == 1 ) {
    $hash = "-h " . $matches[ 1 ];
}

header( "Content-type: application/octet-stream" );
passthru( "/users/mshobana/emulab-devel/build/sbin/readblob $hash $key $blob", $retval );

if( $retval == 2 ) {
    header( "HTTP/1.0 304 Not modified" );
} else if( $retval > 0 ) {
    header( "HTTP/1.0 403 Forbidden" );
    header( "Content-type: text/html" );

    echo( "<html><head><title>Forbidden</title></head>\n" );
    echo( "<body><p>The blob specified could not be accessed.</p></body></html>\n" );
}

return;
?>
<?php

if( preg_match( "(/(\w+)/([\w-]+)$)D",
    $_SERVER[ 'PATH_INFO' ], $matches ) == 1 ) {
    $key = $matches[ 1 ];
    $blob = $matches[ 2 ];
    $hash = "";
} else {
    header( "HTTP/1.0 404 Not found" );

    echo( "<html><head><title>Not found</title></head>\n" );
    echo( "<body><p>The URL given was not a valid blob spefication.</p></body></html>\n" );
    return;
}

if( preg_match( "/(\w+)/D", $_GET[ 'hash' ], $matches ) == 1 ) {
    $hash = "-h " . $matches[ 1 ];
}

header( "Content-type: application/octet-stream" );
passthru( "/users/mshobana/emulab-devel/build/sbin/readblob $hash $key $blob", $retval );

if( $retval == 2 ) {
    header( "HTTP/1.0 304 Not modified" );
} else if( $retval > 0 ) {
    header( "HTTP/1.0 403 Forbidden" );
    header( "Content-type: text/html" );

    echo( "<html><head><title>Forbidden</title></head>\n" );
    echo( "<body><p>The blob specified could not be accessed.</p></body></html>\n" );
}

return;
?>
