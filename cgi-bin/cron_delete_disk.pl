#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;
use File::Pid::Quick qw( logs/deletedisk.pid );
use XUpload;
use JSON;

exit if $ENV{REMOTE_ADDR}; # console only
my $cx;

start:

exit if $cx++ > 600;

my $str = XUpload::postMain({
								op		=> "delete_disk_next",
							})->content;

my $dd = eval { JSON::decode_json($str) };
print("Invalid JSON answer: $str\n"),sleep(5),goto start if $@;

print("Error: $dd->{error}\n"),sleep(5),goto start if $dd->{error};

for my $x (@{$dd->{list}})
{
	print"$x->{disk_id} : $x->{file_real_id} : $x->{file_real} : $x->{quality} : $x->{audio_thumb} : $x->{video_thumb} $x->{video_thumb_t}\n";
	my $dx = sprintf("%05d",$x->{file_real_id}/$c->{files_per_folder});
	my $fdir = "$c->{cgi_dir}/uploads/$x->{disk_id}/$dx";
	my $idir = "$c->{htdocs_dir}/i/$x->{disk_id}/$dx";
	my ($real,$quality,$audio_thumb,$video_thumb,$video_thumb_t) = ($x->{file_real},$x->{quality},$x->{audio_thumb},$x->{video_thumb},$x->{video_thumb_t});
	if($quality)
	{
		print"del $fdir/$real\_$quality\n";
		unlink "$fdir/$real\_$quality";
	}
	else
	{
		print"del $fdir/$real\_*\ndel $idir/$real*\ndel $idir/$audio_thumb\ndel $idir/$video_thumb\ndel $idir/$video_thumb_t\n";
      	unlink <$fdir/$real\_*>;
      	unlink <$idir/$real*>;
		unlink <$idir/$audio_thumb>;
		unlink <$idir/$video_thumb>;
		unlink <$idir/$video_thumb_t>;
	}
}

print".\n";
sleep 5;
goto start;
