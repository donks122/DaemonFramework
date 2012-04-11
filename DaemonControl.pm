#! /usr/bin/perl -w

# ------------------------------------------
#  DaemonCTRL Script 
# ------------------------------------------

package DaemonControl;

use strict;

use Getopt::Std;
use POSIX qw(setsid WNOHANG :signal_h);

my $mailerDelay = 0;

sub start_child {

    my ( $module_name, $instance, $args ) = @_;

    $SIG{HUP}  = \&start::sig_soft;
    $SIG{INT}  = \&start::sig_hard;
    $SIG{TERM} = \&start::sig_hard;

    $module_name =~ s/.pm$//i;

    my $module_list = [ [ $module_name, 1 ] ];

    @ARGV = ( 'start', $module_name, '-I', $instance, '-p', $args );

    return DaemonControl::exec( $module_list, \@ARGV );
}

sub exec {

    my ( $module_list, $args ) = @_;

    undef %DaemonControl::ps_cmds;

    die "DaemonControl ERROR: module_list is empty!\n" if ( scalar @$module_list <= 0 );

    my $usage = "USAGE: DaemonControl [-F] [-u user] [-a] [-I instance] [-c config] {start|stop} [module]\n";
    $usage .= "       DaemonControl [-u user] [-a] show\n";

    my $osName    = `uname -s`;
    my $psFlags   = '-ef';
    my $child_pid = 0;

    $psFlags = '-ef --cols 250' if ( $osName =~ /Linux/ );

    # ------------------------------------------------
    #  Get Command Line Parameters
    #
    #-F force a hard signal on all
    #
    # ------------------------------------------------

    use vars qw ($opt_F $opt_r $opt_u $opt_a $opt_I $opt_c $opt_p);

    $opt_F = 0;

    $opt_r = undef;

    $opt_u = '';

    $opt_a = 0;

    $opt_I = -1;

    $opt_c = '';

    $opt_p = '';

    my ( $i, $stop_action );

    for ( $i = 0; $i < scalar @ARGV; $i++ ) {

        if ( substr( $ARGV[$i], 0, 1 ) eq '-' ) {

            if ( $ARGV[$i] eq '-a' ) {
                $opt_a = 1;
                splice( @ARGV, $i, 1 );
                $i--;
            }
            elsif ( $ARGV[$i] eq '-F' ) {
                $opt_F = 1;
                splice( @ARGV, $i, 1 );
                $i--;
            }
            elsif ( $ARGV[$i] eq '-u' ) {
                $opt_u = $ARGV[ $i + 1 ];
                splice( @ARGV, $i, 2 );
                $i -= 2;
            }
            elsif ( $ARGV[$i] eq '-r' ) {
                $opt_r = $ARGV[ $i + 1 ];
                splice( @ARGV, $i, 2 );
                $i -= 2;
            }
            elsif ( $ARGV[$i] eq '-I' ) {
                $opt_I = $ARGV[ $i + 1 ];
                splice( @ARGV, $i, 2 );
                $i -= 2;
            }
            elsif ( $ARGV[$i] eq '-c' ) {
                $opt_c = "-c $ARGV[$i+1]";
                splice( @ARGV, $i, 2 );
                $i -= 2;
            }
            elsif ( $ARGV[$i] eq '-p' ) {
                $opt_p = "-p$ARGV[$i+1]";
                splice( @ARGV, $i, 2 );
                $i -= 2;
            }
            else {
                die "$usage\n";
            }

        }
        else {
            $stop_action = 1 if ( $ARGV[$i] =~ /stop/i );
        }
    }

    my ( $action, $module_name ) = @$args;

    $module_name =~ s/\.pm$// if ($module_name);

    my $base_dir = `pwd`;;

    my $release = $opt_r || "prod";

    my $log_dir = "./logs/prod";

    my $whoami;

    if ($opt_u) {

        $whoami = $opt_u;

    }
    else {

        $whoami = `whoami`;

        chomp $whoami;
    }

    # ------------------------------------------
    #   Handle Action Tag
    # ------------------------------------------

    $action = lc($action);

    my ( $module, $number, $instance );

    if ( !open PSFILE, "ps $psFlags |" ) {
        warn "ERROR: Unable To Open ps $psFlags Pipe\n";
    }
    else {

        map { push @$_, [] } @$module_list;

    }

    my ( $line, $uid, $pid, $ppid, $c, $stime, $tty, $time, $cmd );

    while (<PSFILE>) {
        $line = $_;

        chomp $line;
        $line =~ s/^\s+//;

        next if !$line;
        next if !( $line =~ /perl|MxServer/ );

        ( $uid, $pid, $ppid, $c, $stime, $tty, $time, $cmd ) = split /\s+/, $line, 8;

        next if !$cmd;

        next if !$opt_a && $whoami ne $uid;

        $DaemonControl::ps_cmds{$cmd}{$pid} = [ $uid, $pid, $ppid, $c, $stime, $tty, $time, $cmd ];

        map {

            ($module) = @$_;

            if ( $cmd =~ /$module/i ) {
                $cmd =~ /\-i(\d+)/;
                push @{ $_->[2] }, [ $uid, $pid, $ppid, $c, $stime, $tty, $time, $cmd, $1 || '0' ];
            }

        } @$module_list;

    }

    close PSFILE;

    # -------------------------------------
    #   Module Name, Number Of Instances
    # -------------------------------------

    my $done_flg = 0;

    if ( $action eq 'start' ) {

        foreach (@$module_list) {

            ( $module, $number ) = @$_;

            next if ( $module_name && $module_name ne $module );

            if ( $opt_I >= 0 ) {

                $done_flg = 1;

                $child_pid = &start( $log_dir, $release, $module, $opt_I, $opt_c, "-n $number", $opt_p );

            }
            else {

                for ( $instance = 0; $instance < $number; $instance++ ) {
                    $done_flg = 1;
                    $child_pid = &start( $log_dir, $release, $module, $instance, $opt_c, "-n $number", $opt_p );
                }
            }
        }

    }
    elsif ( $action eq 'stop' ) {

        my ( $module, $number, $instance, $ps, $i );

        foreach (@$module_list) {
            ( $module, $number, $ps ) = @$_;
            next if ( $module_name && $module_name ne $module );
            if ( $opt_I >= 0 ) {
                $done_flg = 1;
                &stop( $module, $opt_I );
            }
            else {
                for ( $i = 0; $i < scalar(@$ps); $i++ ) {
                    $done_flg = 1;
                    &stop( $module, $ps->[$i]->[8] );
                }
            }
        }
    }
    elsif ( $action eq 'show' ) {
        $done_flg = 1;
        my $psl;

        my $str = sprintf "\nMODULE  WHO    Inst %10s %5s %5s START_TIME\n", "UID", "PID", "PPID";
        print STDOUT $str;
        print STDOUT "===========================================================\n\n";

        foreach (@$module_list) {
            ( $module, $number, $psl ) = @$_;

            $str = sprintf "%-10s ", $module;
            print STDOUT $str;

            if ( scalar @$psl == 0 ) {
                print STDOUT "          **** NOT RUNNING ****\n\n";
                next;
            }

            print STDOUT "\n";

            for ( my $i = 0; $i < scalar @$psl; $i++ ) {

                my ( $uid, $pid, $ppid, $c, $stime, $tty, $time, $cmd, $instance ) = @{ $psl->[$i] };

                my $who = $ppid == 1 ? 'PARENT' : "CHILD ";

                $str = sprintf "\t$who $instance %10s %5d %5d $stime\n", $uid, $pid, $ppid;
                print STDOUT $str;

            }
            print STDOUT "\n";
        }
    }
    else {

        die "$usage\n";
    }

    if ( !$done_flg ) {
        die "DaemonControl: Can't perform action: \'$action $module_name\', since module is not defined!\n";
    }

    return $child_pid;
}

# ------------------------------------------
#   Start Process
# ------------------------------------------

sub start {
    my ( $log_dir, $release, $module, $instance, $opt_c, $opt_n, $opt_p ) = @_;

    my ($cmd);

    if ( grep( /-i\s*$instance\s+/, grep( /-m\s*$module\b/, keys %DaemonControl::ps_cmds ) ) ) {
        print "START FAILED: Process Currently Running [$module] Instance $instance\n";
    }
    else {
        my $opts;

        if ($opt_p) {
            $opts = '-l';
        }
        else {
            $opts = '-ls';
        }

        $cmd = "(./start -m$module -i$instance $opts $opt_c $opt_n $opt_p)";

        warn "STARTING: $cmd\n";

        if ($opt_p) {

            my $pid;

            if ( $pid = fork() ) {

                #parent
                return $pid;
            }
            elsif ( !defined($pid) ) {
                warn "Fork ERROR for $cmd";
                return 0;
            }
            else {

                $cmd = "(./start -m$module -i$instance $opts $opt_c $opt_n $opt_p)";
                CORE::exec( "./start", "-m$module", "-i$instance", $opts, $opt_n, $opt_p, $opt_c );
                die "error execing...";
            }

        }
        else {

            #close STDIN; close STDOUT; close STDERR;
            # redirect standard file descriptors from and to /dev/null
            # so that random output doesn't wind up on the user's terminal
            open( STDIN,  '/dev/null' )  or die "Can't read /dev/null: $!";
            open( STDOUT, '>/dev/null' ) or die "Can't write to /dev/null: $!";

            system "$cmd";
        }
    }

    return 0;
}

sub start_daemon {
    my ($module) = @_;

    if ( grep( /perl \.\/$module/, keys %DaemonControl::ps_cmds ) ) {
        print "START FAILED: Process Currently Running [$module]\n";
        return 0;
    }

    my $cmd = "(./$module)";

    system("$cmd");

    return 0;
}

# ------------------------------------------
#   Stop Process(es)
# ------------------------------------------

sub stop {
    my ( $module, $instance ) = @_;

    my (%kill_pid);
    my ( $uid, $pid, $ppid, $c, $stime, $tty, $time, $cmd );

    #foreach $cmd ( grep( /-i\s*$instance/, grep( /-m\s*$module\b/, keys(%DaemonControl::ps_cmds) ) ) ) {

    foreach $cmd ( keys %DaemonControl::ps_cmds ) {

        # ------------------------------------------
        #   Kill Parent
        # ------------------------------------------

        foreach $pid ( keys %{ $DaemonControl::ps_cmds{$cmd} } ) {
            ( $uid, $pid, $ppid, $c, $stime, $tty, $time, $cmd ) = @{ $DaemonControl::ps_cmds{$cmd}{$pid} };

                if ( $ppid > 1 ) {
                    if ( $DaemonControl::ps_cmds{$cmd}{$ppid} && !$kill_pid{$ppid} ) {
                        $kill_pid{$ppid} = 1;
                        print "STOPPING PARENT [$ppid]: $cmd\n";
                        killit( $ppid, $opt_F );
                    }

                    if ( !$kill_pid{$pid} ) {
                        $kill_pid{$pid} = 1;
                        print "STOPPING CHILD [$pid]: $cmd\n";
                        killit( $pid, $opt_F );
                    }

                }
                elsif ( !$kill_pid{$pid} ) {
                    $kill_pid{$pid} = 1;
                    print "STOPPING PROC [$pid]: $cmd\n";
                    killit( $pid, $opt_F );
                }
            }
    }
}

sub killit {
    my ( $pid, $force_flg ) = @_;

    my $sig = '-HUP';

    $sig = '-9' if ($force_flg);

    system "kill $sig $pid";
}

sub killterm {
    my ( $pid, $force_flg ) = @_;

    my $sig = 'TERM';

    $sig = 'KILL' if ( $force_flg );

    kill $sig => ($pid);
}

sub get_module_instance {

    my ( $log_dir, $release, $module, $ppid, $pid ) = @_;

    my @pid_files = `ls $log_dir/$module.I*.pid`;

    return -1 if ( scalar @pid_files <= 0 );

    my $mod_instance = -1;

    foreach (@pid_files) {

        $_ =~ /\.I(\d+)\.pid/;

        $mod_instance = $1;

        next if ( !open PID, "<$_" );

        my $line = <PID>;

        chomp $line;

        my ( $mod_ppid, $mod_pid ) = split / /, $line;

        close PID;

        if ( $mod_pid == $$pid ) {
            $$ppid = $mod_ppid;
            return $mod_instance;
        }

    }

    return -1;

}

1;

