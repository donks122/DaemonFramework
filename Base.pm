# ---------------------------------------------------------------------------------
#   Base Class
#
#    Base class for all perl classes.  Includes basic methods available to all
#    classes. Methods may be overridden by children if neccessary.
#
# ---------------------------------------------------------------------------------

package Base;

use strict;
use Storable ();
use POSIX 'uname';

$Base::debug_level ||= 0;

# -------------------------------------------------------
#   Class Constructor  
# -------------------------------------------------------

sub new {
    my ( $self, $hash ) = @_;

  # ------------------------------------------------------
  #    Create new hash ref/obj ref (Copy Constructor)  
  # ------------------------------------------------------

    my $type = ref( $self ) || $self;
    my $obj = ref( $self ) ? &Storable::dclone( $self ) : { };
    my $new = bless( $obj, $type );

  # ------------------------------------------------------
  #    Initialize properties (copy $hash into $new)
  # ------------------------------------------------------

    if ( $hash && ref $hash ) {
	while ( my ( $key, $value ) = each %$hash ) {
	    $new->{$key} = $value if ! ref $value;
	}
    }

    return $new;
}

# -------------------------------------------------------
#   Get Properties Method  
# -------------------------------------------------------

sub get {
    my $self = shift;
    return map( $self->{$_}, @_ );
}

# -------------------------------------------------------
#   Set Properties Method  
# -------------------------------------------------------

sub set {
    my ( $self, $hash ) = @_; 
    return 0 if ! $hash || ! ref $hash;

    while ( my ( $key, $value ) = each %$hash ) {
	$self->{$key} = $value;
    }

    return 1;
}

# -------------------------------------------------------
#   Deep (Recursive) Clone Object Instance
# -------------------------------------------------------

sub dclone {
    my ( $self ) = @_;
    return &Storable::dclone( $self );
}

# -------------------------------------------------------
#   Serialize Object Instance 
# -------------------------------------------------------

sub freeze {
    my ( $self ) = @_;
    return &Storable::nfreeze( $self );
}

# -------------------------------------------------------
#   Inflate Object Instance (Class/Object Method)
# -------------------------------------------------------

sub thaw {
    my ( $self, $buffer ) = @_;
    return &Storable::thaw( $buffer );
}

# -------------------------------------------------------
#   Print
# -------------------------------------------------------

sub print {
    my ( $self ) = @_;
  
    my $type = ref( $self ) || $self;
    print STDERR "\nOBJECT TYPE: $type\n";
    print STDERR "--------------------------------\n";

    my ($key, $value);
    foreach $key ( sort keys %$self ) {
	$value = $self->{$key} || '';  
	printf STDERR "%-25s %s\n", "KEY: [$key]", "VALUE: [$value]";
    }
    print STDERR "\n";
}

# -------------------------------------------------------
#   Debug  
# -------------------------------------------------------

sub dbg {
    my $self = shift @_;
    my $type = uc( ref( $self ) || $self );

    print STDERR "$type DBG: ", @_, "\n" if $Base::debug_level;
}

# -------------------------------------------------------
#   hostinfo : POSIX::uname into self
# -------------------------------------------------------

sub hostinfo {
    my ( $self ) = @_;

    @{$self}{ qw{sysname nodename release version machine} } = POSIX::uname();
}

# ------------------------------------------------------------ 
#   log_debug : prints into STDERR
# ------------------------------------------------------------ 
 
sub log_debug { 
    my $self = shift @_;

    my ( $package, $filename, $line ) = caller(0);
    print STDERR '[' . localtime() . "][$package][$$] ", @_, "\n"; 
    return 1; 
}

1;

