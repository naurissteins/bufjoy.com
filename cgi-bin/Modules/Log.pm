package Log;

use strict;
use vars qw($VERSION);
use XFSConfig;
use FileHandle;
use File::Path;

$VERSION = "1.00";

sub new {
	my ($class,%args) = @_;
	my $self;
	unless($args{notie}) {
		$self = tie *STDERR, __PACKAGE__, %args;
	} else {
		$self = \%args;
		bless $self, __PACKAGE__;
		open STDERR, "> /dev/null" or die $!;
		$self->OPEN; 		
	}
	$self->{mute}=$args{mute};
	return $self;
}

sub write {
	my $self = shift;
	my $level = shift;
	my $message = shift;
	my $time = gmtime(time);
	my $fd = $self->{FD};
	$message =~ s/\s*$//;
	print $fd "[$time][$$] $message\n";
        print "[$time][$$] $message\n" unless $self->{mute}; 
}

sub log {
	my $self = shift;
	my $message = shift;
	$self->write(1,$message);
}

sub PRINT {
	my $self = shift;
	my $stderr = join '', @_;
	$self->write(1,$stderr); 
}

sub TIEHANDLE{
	my ($class, %args) = @_;;
	my $self = {};
	if ($args{filename}) {
		my $fp = '/dev/null';
		unless($c->{disable_logs}) {
			mkpath "$c->{cgi_dir}/logs";
        		$fp = "$c->{cgi_dir}/logs/$args{filename}";
		}
#		die $fp;
        	open FD, ">> $fp";
        	FD->autoflush(1);
		my $fd = *FD;
		$self->{FD} = $fd;
	}
	bless $self, $class;
}
sub OPEN {
	my $self = shift;
	my $fp = '/dev/null';
	unless($c->{disable_logs}) {
        	$fp = "$c->{cgi_dir}/logs/$self->{filename}";
	}
	open FD, ">> $fp";
        FD->autoflush(1);
	my $fd = *FD;
	$self->{FD} = $fd;

}

sub CLOSE {
	my $self = shift;
	close $self->{FD};
}
sub DESTROY {
	my $self = shift;
	close $self->{FD};
	untie *STDERR;
}

1;
