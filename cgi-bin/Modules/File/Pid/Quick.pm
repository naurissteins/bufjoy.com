package File::Pid::Quick;

use 5.006;
use strict;
use warnings;

our $VERSION = '1.02';

use Carp;
use Fcntl qw( :flock );
use File::Basename qw( basename );
use File::Spec::Functions qw( tmpdir catfile );

our @pid_files_created;
our $verbose;
our $timeout;

sub import($;@) {
    my $package = shift;
    my $filename;
    my $manual;
    while(scalar @_) {
        my $item = shift;
        if($item eq 'verbose') {
            $verbose = 1;
        } elsif($item eq 'manual') {
            $manual = 1;
        } elsif($item eq 'timeout') {
            $timeout = shift;
            unless(defined $timeout and $timeout =~ /^\d+$/ and int($timeout) eq $timeout and $timeout > 0) {
                carp 'Invalid timeout ' . (defined $timeout ? '"' . $timeout . '"' : '(undefined)');
                exit 1;
            }
        } else {
            if(defined $filename) {
                carp 'Invalid option "' . $item . '" (filename ' . $filename . ' already set)';
                exit 1;
            }
            $filename = $item;
        }
    }
    __PACKAGE__->check($filename, $timeout, 1)
        unless $^C or ($manual and not defined $filename);
}

END {
    foreach my $pid_file_created (@pid_files_created) {
        next
            unless open my $pid_in, '<', $pid_file_created;
        my $pid = <$pid_in>;
        chomp $pid;
        $pid =~ s/\s.*//o;
        if($pid == $$) {
	        if($^O =~ /^MSWin/) {
		        close $pid_in;
		        undef $pid_in;
			}
            if(unlink $pid_file_created) {
                warn "Deleted $pid_file_created for PID $$\n"
                    if $verbose;
            } else {
                warn "Could not delete $pid_file_created for PID $$\n";
            }
        } else {
            warn "$pid_file_created had PID $pid, not $$, leaving in place\n"
                if $verbose;
        }
        close $pid_in
	        if defined $pid_in;
    }
}

sub check($;$$$) {
    my $package = shift;
    my $pid_file = shift;
    my $use_timeout = shift;
    my $warn_and_exit = shift;
    $pid_file = catfile(tmpdir, basename($0) . '.pid')
        unless defined $pid_file;
    $use_timeout = $timeout
        unless defined $use_timeout;
    if(defined $use_timeout and ($use_timeout =~ /\D/ or int($use_timeout) ne $use_timeout or $use_timeout < 0)) {
        if($warn_and_exit) {
            carp 'Invalid timeout "' . $use_timeout . '"';
            exit 1;
        } else {
            croak 'Invalid timeout "' . $use_timeout . '"';
        }
    }
    if(open my $pid_in, '<', $pid_file) {
        flock $pid_in, LOCK_SH;
        my $pid_data = <$pid_in>;
        chomp $pid_data;
        my $pid;
        my $ptime;
        if($pid_data =~ /(\d+)\s+(\d+)/o) {
            $pid = $1;
            $ptime = $2;
        } else {
            $pid = $pid_data;
        }
        if($pid != $$ and kill 0, $pid) {
            my $name = basename($0);
            if($timeout and $ptime < time - $timeout) {
                my $elapsed = time - $ptime;
                warn "Timing out current $name on $timeout sec vs. $elapsed sec, sending SIGTERM and rewriting $pid_file\n"
                    if $verbose;
                kill 'TERM', $pid;
            } else {
                if($warn_and_exit) {
                    warn "Running $name found via $pid_file, process $pid, exiting\n";
                    exit 1;
                } else {
                    die "Running $name found via $pid_file, process $pid, exiting\n";
                }
            }
        }
        close $pid_in;
    }
    unless(grep { $_ eq $pid_file } @pid_files_created) {
	    my $pid_out;
        unless(open $pid_out, '>', $pid_file) {
            if($warn_and_exit) {
                warn "Cannot write $pid_file: $!\n";
                exit 1;
            } else {
                die "Cannot write $pid_file: $!\n";
            }
        }
        flock $pid_out, LOCK_EX;
        print $pid_out $$, ' ', time, "\n";
        close $pid_out;
        push @pid_files_created, $pid_file;
        warn "Created $pid_file for PID $$\n"
            if $verbose;
    }
}

sub recheck($;$$) {
    my $package = shift;
    my $timeout = shift;
    my $warn_and_exit = shift;
    warn "no PID files created\n"
        unless scalar @pid_files_created;
    foreach my $pid_file_created (@pid_files_created) {
        $package->check($pid_file_created, $timeout, $warn_and_exit);
    }
}

1;
