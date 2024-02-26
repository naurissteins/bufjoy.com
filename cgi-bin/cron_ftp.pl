#!/usr/bin/perl
use strict;
use lib '.';
use FindBin;
use lib $FindBin::Bin;
use lib "$FindBin::Bin/Modules";
use utf8;
use File::Find;
use File::Path qw( rmtree );
use XFSConfig;
use XUpload;
use File::Pid::Quick qw( manual );

exit if $ENV{REMOTE_ADDR};

require Log;
my $log = Log->new(filename=>'upload_ftp.txt', mute=>0);

my $ftp_dir = '/home/ftp';

if($ARGV[2]=~/^MFMT \d+ (.+)$/)
{
	my $file = "$ftp_dir/$ARGV[0]$ARGV[1]/$1";
	$file=~s/\/\//\//g;
	print STDERR "MFMT file:$file";
	exit unless -f $file;
	exit if -s $file<1024*1024*5; # skip files less 5 MB
	handleFile( $file, $ARGV[3] );
	exit;
}

#File::Pid::Quick->check();

# mins after modification to process
my $file_age = $c->{m_f_sync_files_after} || 5;

# delete old empty user subdirs older X days, 0 to disable
my $cleanup_old_subdirs = 7;

my ($srv_id,$disk_id,$processed);

print("FTP dir does not exist ($ftp_dir)\n"),exit unless -d $ftp_dir;

sendCurrentUploads();

find({wanted => \&wanted, preprocess => \&filter }, $ftp_dir);


sub filter
{
  return sort @_;
}

sub wanted
{
 next if $_ eq '.';

 #my $dir  = $File::Find::dir;
 my $file = $File::Find::name;
 my $mtime = (lstat($file))[9];
 my $mdt = time - $mtime;

 # Delete old empy subdirs
 if($cleanup_old_subdirs &&
    -d $file && 
    #$dir ne $ftp_dir && 
    $mdt>3600*24*$cleanup_old_subdirs &&
    isEmpty($file)
   )
 {
     print"Deleting empy old dir $file\n";
     rmtree($file);
     next;
 }

 next unless -f $file;
 
 next if $mdt < 60*$file_age;

 handleFile( $file );

}

sub handleFile
{
	my ($filepath, $ip) = @_;
 
	my ($dir,$filename) = $filepath=~/^$ftp_dir\/(.+)\/(.+)$/i;
	my ($user,$folder);
	if($dir=~/\//)
	{
		($user,$folder) = $dir=~/^(.+?)\/(.+)$/;
	}
	else
	{
		$user = $dir;
	}

	my $full_dir="$ftp_dir/$dir";
	print "User:$user\n";
	print "Folder:$folder\n";
	print "Filename: $filename\n";

	unless($processed && $srv_id && $disk_id)
	{
		my $res = XUpload::postMain(
		{
			op		=> 'next_ftp_server',
			host_id	=> $c->{host_id},
		}
		)->content;
		($srv_id,$disk_id)=($1,$2) if $res=~/^OK:(\d+):(\d+)$/;
		print("$res\n"),exit unless $srv_id && $disk_id;
		print"srv_id=$srv_id, disk_id=$disk_id\n";
	}

 my ($file,$f);
 $file->{file_tmp} = "$full_dir/temp";
 print"t:$filepath:$file->{file_tmp}\n";
 rename($filepath, $file->{file_tmp});
 $file->{file_name_orig} = $filename;
 $file->{file_public} = 1;
 $file->{usr_login}= $user;
 $f->{fld_name} = $folder;
 $f->{srv_id} = $srv_id;
 $f->{disk_id} = $disk_id;
 $f->{ip} = $ip || '1.1.1.1';

 # --------------------
 $XUpload::log = $log;
 $file = XUpload::ProcessFile($file,$f);
 # --------------------

 print $file->{file_status} ? "status:$file->{file_status}\n" : "file_code:$file->{file_code}\n";
 if($file->{file_status})
 {
     unlink($file->{file_tmp}); # some error from main logic
 }
 else
 {
     $processed=0 if ++$processed>10; # ask for new srv/disk ids after 10 files processed
 }
 unlink($file->{file_tmp}); # delete just to make sure
}

sub isEmpty
{
    opendir(DIR,shift) or return;	

    for( readdir DIR )
    {
       if( !/^\.\.?$/ )
       {
          closedir DIR;
          return 0;
       }
    }
    closedir DIR;
    return 1;            
}

sub sendCurrentUploads
{
	my $x = `ftpwho -v`;
	return unless $x=~/up for/;
	my $list;
	while($x=~/(\d+) (\w+)\s+\[.+?STOR (.+?)\n.+?KB\/s: ([\d\.]+).+?client: (.+?)\n/gis)
	{
	  my ($pid,$user,$fname,$speed,$client) = ($1,$2,$3,$4,$5);
	  utf8::decode($fname);
	  my $size = -s "$ftp_dir/$2/$3";
	  $size = sprintf("%.0f", $size/1048576 ) if $size;
	  my ($ip) = $client=~/\[(.+?)\]/;
	  push @$list, { pid=>$pid, user=>$user, filename=>$fname, speed=>int $speed, ip=>$ip, size=>$size };
	}
	my $data;
	$data->{uploads} = $list;
	$data->{updated} = time;
	$data->{disk_used} = `du -sm /home/ftp`;
	$data->{disk_used}=~s/^(\d+).+/$1/s;
	require JSON;
	my $res = XUpload::postMain(
		                         {
		                         op     => 'ftp_current',
		                         host_id=> $c->{host_id},
		                         data => JSON::encode_json($data),
		                         }
		                        )->content;
	print"fs-current:$res\n".JSON::encode_json($data)."\n";
}