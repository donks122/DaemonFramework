#! /usr/bin/perl -w 

# ---------------------------------------------------------------------------------
#   Report Class
#
#   $self->monitor() works in an endless loop 
#   sleeps for 1 day until the next pass 
#
# ---------------------------------------------------------------------------------

use strict;
package Report;

use Base ();
use POSIX ();
use DBI;
use Time::Local;

@Report::ISA = ( 'Base' );

# -------------------------------------------------------
#   Class constructor.
# -------------------------------------------------------

sub new {
    my ($self, $hash) = @_;
    my $obj = &Base::new( $self, $hash );
    %$obj = %$hash;
    return $obj;
}

# -------------------------------------------------------
#   Action Method
# -------------------------------------------------------

sub action {
    my ($self) = @_;
    
    $self->{debug} ||= 0;
    
    $self->{type} ||= 'lastday';

    my $sleep_time = 86400 if($self->{type} eq 'lastday');

    warn "Starting instance [$self->{instance}], num_instances [$self->{num_instances}]\n";

    while ( ! &start::get_exit_flg( ) ) {
	eval {$self->monitor();};
        if($self->{type} ne 'lastday') {
          warn( "EXITING: Completed Reporting for $self->{type}..\n" );
          exit();
        }
	warn "Sleeping [$sleep_time] seconds ..... \n";
	sleep( $sleep_time );
    }

    warn( "EXITING: Graceful shutdown.......\n" );
    exit();
}

# -------------------------------------------------------
# monitor method  
# -------------------------------------------------------

sub monitor {
    my ($self) = @_;

}
sub IsLeapYear
{
    my $year = shift;
    return 0 if $year % 4;
    return 1 if $year % 100;
    return 0 if $year % 400;
    return 1;
}

sub epoch2time ($){
    my $time = shift;
    my ($sec, $min, $hour, $day,$month,$year) = (localtime($time))[0,1,2,3,4,5,6];
    $hour = sprintf "%02d",$hour;
    $min = sprintf "%02d",$min;
    $month = $month + 1;
    $year += 1900;
    my $newdate = "$year-$month-$day";
    my $newtime = "$hour" . ':' . "$min";
    return ($newdate,$newtime);
}

sub time2epoch ($){
    my $date = shift;
    my $time = shift;
    my ($year,$month,$day) = split("-",$date);
    my ($hours,$min,$sec) = split(":",$time);
    $month = $month - 1;
    my $newtime = timelocal($sec,$min,$hours,$day,$month,$year);
    return $newtime;
}


    
return 1;
}


=pod
=head1 NAME

Report - $Revision: 1.1 $

=head1 SYNOPSIS

Called through daemonctrl process

=back

=head1 DESCRIPTION

$self->monitor() works in an endless loop retrieving all the orders for last day
and sleeps for 1 day until the next pass

=head1 OVERVIEW

None

=head1 CONSTRUCTOR

new($hash) : Pass the hash for this instance

=over 4

=back

=head1 METHODS

The Report code is called through daemonctrl process. This should not
be called in any other logic. The public method is only public to the
controller process. For further information read daemonctrl help

=over 4

=item action()

Works in an endless loop retrieving the next available block of status
records from the local status_tbl, executing the requested action, and
sleeping for a few seconds until the next pass.

=back

=head1 AUTHOR

Sandeep Nyamati( sandeep.nyamati@gmail.com ) 

=head1 SEE ALSO

DaemonControl.pm , daemonctrl

=cut

1;
