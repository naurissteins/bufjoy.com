#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;
use XUpload;
use LWP::UserAgent;

exit if $ENV{REMOTE_ADDR}; # allow only run from console

exit unless $c->{host_max_trans};
my @xx=`ps ax|grep transfer.pl`;
@xx = grep {$_!=$$} map{/^\s*(\d+)/;$1} grep{/perl/} @xx;
print join("\n", @xx),"\n";
print("reached max processes list\n"),exit if scalar(@xx)>=$c->{host_max_trans};

my $restart;
$SIG{HUP} = sub { $restart=1 };

my $cx;
my $ua  = LWP::UserAgent->new(agent => $c->{user_agent}, timeout => 360);

require Log;
my $log = Log->new(filename=>'transfer.txt');

my ($disk_id,$real_id,$code,$links);
my ($current_bytes,$old_size,$old_time);

while($cx++<100)
{
   $log->log("Exiting on HUP restart signal"),exit if $restart;
   my $str = XUpload::postMain(
		                       {
		                       op           => "queue_transfer_next",
		                       }
		                      )->content;

   print(".$str\n"),sleep(1+$c->{host_max_trans}*5),next unless $str;
   $log->log("FS:$str");
   ($disk_id,$real_id,$code,$links)=$str=~/^(\d+):(\d+):(\w+)\n(.+)$/s;
   sleep(10),next unless $code;

   my $dx = sprintf("%05d",$real_id/$c->{files_per_folder});
   my $error;

   ($current_bytes,$old_size,$old_time)=(0,0,0);

   for( split(/\n/,$links) )
   {
      my ($type,$url,$size_db) = split(/\|/,$_);
      my ($fname) = $url=~/\/([^\/]+)$/;
      $fname=~s/\?.+$//;
      my $dir="$c->{cgi_dir}/uploads/$disk_id/$dx" if $type=~/^(ENC|VTT)$/;
      $dir="$c->{htdocs_dir}/i/$disk_id/$dx" if $type=~/^(IMG)$/;
      unless(-d $dir)
      {
         my $mode = 0777;
         mkdir $dir, $mode;
         chmod $mode,$dir;
      }

    ### Get filesize ###
    my $link_size=0;
    if($size_db)
    {
    	$link_size=$size_db;
    }
    else
    {
    	$link_size=32;
    }
    # my $request  = HTTP::Request->new( HEAD => $url );
    # my $link_size = $ua->request( $request )->content_length;
    # print"SIZE:$link_size\n";
    ####################

      my $file="$dir/$fname";
      print"DL-$type $url to $file\n";
      if(-f $file)
      {
      	print("$code-$type $fname: already have on disk same size\n"),next if $link_size == -s $file;
      	print("$code-$type $fname: already have on disk recently modified\n"),next if time-(lstat($file))[9] < 180;
      }

      #my $res = $ua->get( $url , ':content_file'=>$file );
      open FILE, ">$file";
      my $res = $ua->get( $url , ':content_cb'=>\&hook_url, ':read_size_hint' => 4*1024*1024 );
      close FILE;
      my $fsize = -s $file;
      $log->log("Received size $code-$type: $fsize of $link_size");
      if(!$res->is_success || !-e $file || ($fsize<50 && $type ne 'VTT') || $fsize < $link_size)
      {
         if(!$res->is_success)
         {
			$log->log("ERROR: $code-$type:".$res->status_line);
			$error.="$code-$type: returned ".$res->status_line if $type=~/^(ENC)$/i;
			if($type eq 'VTT' && !-e $file){ print"Make empty $file\n"; open FIL, ">$file"; close FIL; } # create empty VTT to fix HLS play
         }
         else
         {
         	$log->log("ERROR: $code-$type: file size error: $fsize < $link_size");
			$error.="$code-$type: received $fsize instead of $link_size" if $type=~/^(ENC)$/i;
         }
         unlink($file) if -e $file && $fsize<50;
      }
      last if $error;
   }

	sub hook_url
	{
		my ($buffer) = @_;
		print FILE $buffer;
		$current_bytes+=length($buffer);

		if(time>$old_time+15)
		{
			my $speed_kb = sprintf("%.0f", ($current_bytes-$old_size)/1024/(time-$old_time) );
			$old_time = time;
			$old_size = $current_bytes;
			XUpload::postMainQuick(
			{
				op				=> "transfer_progress",
				file_real_id	=> $real_id,
				file_real		=> $code,
				transferred		=> $current_bytes,
				speed			=> $speed_kb,
			});
		}
	}

	unless($error)
	{
		my $str = XUpload::postMain( {
			op           => "queue_transfer_done",
			file_real_id => $real_id,
			file_real    => $code,
		} )->content;
		print"Update DB: $str\n";
	}
	else
	{
		my $str = XUpload::postMain( {
			op           => "transfer_error",
			file_real_id => $real_id,
			file_real    => $code,
			error        => $error,
		} )->content;
		print"Had errors, sent report: $str\n";
	}

	sleep 1;
}
