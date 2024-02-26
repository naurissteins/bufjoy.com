#!/usr/bin/perl
use strict;
use lib '.';
use XFileConfig;
use File::Pid::Quick qw( logs/emails.pid );
use Session;
use XUtils;
use Log;
Log->new(filename => 'emails.log');

my $ses = Session->new();
my $db= $ses->db;

my $cx=1;

while(1)
{
	exit if $cx++>7200;
	my $x = $db->SelectRow("SELECT * FROM QueueEmail ORDER BY priority DESC, created");
	sleep(1),next unless $x;
	print STDERR "To $x->{email_to}";
	print"Sending to $x->{email_to}\n";
	$db->Exec("DELETE FROM QueueEmail WHERE id=?",$x->{id});
	next unless $x->{email_to};
	$ses->SendMail( $x->{email_to}, $x->{email_from}, $x->{subject}, $x->{body}, $x->{txt} );
	sleep(1) unless $cx % 3;
}
