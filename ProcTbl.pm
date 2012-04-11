#! /usr/bin/perl -w 


# ---------------------------------------------------------------------------------
#   ProcTbl Class
#
#   $proc_tbl->update( $count_delta ) method executes proc_ins( ..... ) 
#   stored procedure inserting/updating row in prod_tbl with current process 
#   statistics
#
# ---------------------------------------------------------------------------------

use strict;
package ProcTbl;

use Base;
@ProcTbl::ISA = ( 'Base' );

use DBI;
my $dbh = DBI->connect('dbi:mysql:database=daemon','uname','password');

# ---------------------------------------------------------------------------------
#  Object Constructor
# ---------------------------------------------------------------------------------

sub new {
    my ($self, $hash) = @_;

    if ( ! exists $hash->{proc_tbl_disable} ) {
	$hash->{proc_tbl_disable} = 1;   
    }

    my $obj = &Base::new($self, $hash);

    my $localtime = localtime;
    $obj->hostinfo();
    $obj->{proc_text} = [ "STARTING PROCESS: $localtime" ];
    $obj->update( 0 );

    return $obj;
}

# ---------------------------------------------------------------------------------
#   Update Method 
# ---------------------------------------------------------------------------------

sub update {
    my ($self, $count_delta) = @_;

    return if $self->{proc_tbl_disable};

    $count_delta ||= 0;

    $self->{total_count} ||= 0;
    $self->{total_count} += 1;

    $self->{count_delta} ||= 0;
    $self->{count_delta} += $count_delta;

    my $last_time = $self->{last_time} || 0;
    my $elapsed_time = (time() - $last_time);

    return if ( $elapsed_time < 20 ); 

    my $current_rate = int($self->{count_delta} / $elapsed_time);

    $self->{count_delta} = 0;
    $self->{last_time} = time();

    my $total_count = $self->{total_count} || 0;
    my $nodename = $self->{nodename};
    my $instance = $self->{instance} || 0;
    my $proc_name = $self->{proc_name} || $self->{module_name} || '';

    my $text_list = $self->{proc_text};
    my $text = join "\n", @$text_list;

    my $class;
    if ( $text =~ /ERROR/i ) {
	$class = 'error';
    }  else {
	$class = 'event';
    }

  # -------------------------------------------------------------------------------
  #   Update Database
  # -------------------------------------------------------------------------------

    $text = substr( $text, 0, 4000 );
#my $dbh = DBI->connect('dbi:mysql:host=mysql:database=o2_bizmo','bizmo','8uiSm2lz');
#    $dbh->do("REPLACE INTO proc_tbl ($class,$$,$proc_name,$instance,$nodename,$text)");
$dbh->do("REPLACE INTO proc_tbl (proc_pid,proc_name,proc_text,machine_name) values ($$,$proc_name,$text,$nodename)");

}

# ---------------------------------------------------------------------------------
#   Delete Method 
# ---------------------------------------------------------------------------------

sub delete {
    my ($self) = @_;
 
    return if $self->{proc_tbl_disable};

    my $nodename = $self->{nodename};
    my $proc_name = $self->{proc_name} || $self->{module_name} || '';

  # -------------------------------------------------------------------------------
  #   Update Database
  # -------------------------------------------------------------------------------

    return if $self->{proc_tbl_disable};
#my $dbh = DBI->connect('dbi:mysql:host=mysql:database=o2_bizmo','bizmo','8uiSm2lz');

    $dbh->do (q{
    DELETE FROM proc_tbl
    WHERE proc_pid = ?
    AND proc_name = ?
    AND machine_name = ?
}, $$, $proc_name, $nodename);
}

# ---------------------------------------------------------------------------------
#   Queue Proc Text Lines
# ---------------------------------------------------------------------------------

sub proc_text {
    my ($self, $new_text) = @_;

    return if $self->{proc_tbl_disable};

    my $text_list = $self->{proc_text} ||= [ ];
    push @$text_list, split /\n/, $new_text;

    if ( scalar( @$text_list ) > 20 ) {
	splice @$text_list, 0, scalar(@$text_list) - 20;
    }
}

# ---------------------------------------------------------------------------------
#   Write Sys Action Record
# ---------------------------------------------------------------------------------

sub sys_action {
    my ( $self, $class, $text ) = @_;

    return if $self->{proc_tbl_disable};
    
    my $instance = $self->{instance} || 0;
    my $nodename = $self->{nodename};
    my $proc_name = $self->{proc_name} || $self->{module_name} || '';
    
    if ( ! $class ) {
	if ( $text =~ /ERROR/i ) {
	    $class = 'error';
	}  else {
	    $class = 'event';
	}
    }
    
    $text = substr( $text, 0, 4000 );

    $dbh->do("REPLACE INTO proc_tbl (proc_pid,proc_name,proc_text,machine_name) values ($$,$proc_name,$text,$nodename)");


}

1;

