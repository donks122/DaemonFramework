#! /usr/bin/perl -w -I ..

# ---------------------------------------------------------------------------------
#   Init Class
#
#    Init contains methods to read and write config (.ini) files.  
#
#    1.  Each line in a config file can contain at most one key/value pair.  
#
#    2.  All keys are demoted to lower case during loading.
#
#    3.  Any portion of a line following a '#' and including the '#' is ignored.
#
# ---------------------------------------------------------------------------------

package Init;

use strict;
use Base ();

@Init::ISA = ( 'Base' );

# ---------------------------------------------------------------------------------
#  Object Constructor
# ---------------------------------------------------------------------------------

sub new {
    my ( $self, $hash ) = @_;

    my $obj = $self->SUPER::new( $self, $hash );
    $obj->hostinfo();

    return $obj;
}

# ---------------------------------------------------------------------------------
#    Read Method 
# ---------------------------------------------------------------------------------

sub read {
    my ( $self, $file ) = @_;
    return 0 if ! $file;

    $Config::config = undef;
    eval { require( $file ); };

    if ( ref $Config::config ) {
	$self->set( $Config::config );
    } else {
	warn "WARNING: Unable to read $file as a config file\n";
	return 0;
    }

    return 1;
}

1;
