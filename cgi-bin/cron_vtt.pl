#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;
use File::Pid::Quick qw( logs/vtt.pid );
use XUpload;
use JSON;

exit if $ENV{REMOTE_ADDR}; # console only
my $cx;

start:

exit if $cx++ > 600;

my $str = XUpload::postMain({
								op		=> "save_vtt_next",
							})->content;

my $dd = eval { JSON::decode_json($str) };
print("Invalid JSON answer: $str\n"),sleep(5),goto start if $@;

for my $x (@{$dd->{list}})
{
	print"$x->{disk_id} : $x->{file_real_id} : $x->{file_code} : $x->{language}\n";
	my $dx = sprintf("%05d",$x->{file_real_id}/$c->{files_per_folder});
	my $fdir = "$c->{cgi_dir}/uploads/$x->{disk_id}/$dx";
	print"save $fdir/$x->{file_code}_$x->{language}\n";
	open FILE, ">$fdir/$x->{file_code}_$x->{language}";
	print FILE $x->{data};
	close FILE;
}

print".\n";
sleep (@{$dd->{list}} > 3 ? 0 : 2);

goto start;
