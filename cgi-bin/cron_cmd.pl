#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;

exit if $ENV{REMOTE_ADDR};

my $cmd_file = "$c->{cgi_dir}/temp/cmd.txt";
exit unless -s $cmd_file;

open FILE, $cmd_file;
my @cmds = <FILE>;
close FILE;
unlink $cmd_file;

my $done;
chomp(@cmds);
for my $x (@cmds)
{
	next if $done->{$x}++;
	print"Execute $x\n";
	if($x eq 'nginx-restart')
	{
		`/usr/local/nginx/sbin/nginx -s stop;sleep 1;killall nginx;sleep 1;/usr/local/nginx/sbin/nginx`;
	}
	elsif($x eq 'daemons-restart')
	{
		`killall enc.pl;killall ffmpeg;killall url_upload.pl;killall transfer.pl`;
	}
	elsif($x eq 'logs-clean')
	{
		for("/var/www/logs/error_log",
			"/var/www/logs/access_log",
			"/usr/local/nginx/logs/error.log",
			"/usr/local/nginx/logs/traffic_hls.log",
			"/usr/local/nginx/logs/traffic_hls2.log",
			"/usr/local/nginx/logs/traffic_mp4.log",
			"$c->{cgi_dir}/logs/transfer.txt",
			"$c->{cgi_dir}/logs/upload.txt",
			"$c->{cgi_dir}/logs/enc.txt")
		{
			`>$_` if -s $_;
		}
	}
	elsif($x eq 'torrents-clean')
	{
		`rm -rf $c->{cgi_dir}/Torrents/workdir/*` if -d "$c->{cgi_dir}/Torrents/workdir";
	}
	elsif($x eq 'hls-clean')
	{
		`rm -rf /home/proxy_hls/*` if -d "/home/proxy_hls";
		`rm -rf /disk2/proxy_hls/*` if -d "/disk2/proxy_hls";
		`rm -rf /disk3/proxy_hls/*` if -d "/disk3/proxy_hls";
		`rm -rf /disk4/proxy_hls/*` if -d "/disk4/proxy_hls";
	}
}