#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use File::Path;
use LWP::UserAgent;
use HTTP::Request::Common;
$HTTP::Request::Common::DYNAMIC_FILE_UPLOAD = 1;
use File::Copy;
use Digest::MD5;
use XUpload;

die"Error1" unless $ENV{REQUEST_METHOD} eq 'POST';
my ($mua);

my $q = CGI->new();
my $f;
$f->{$_}=$q->param($_) for $q->param;

&PreviewUpload if $f->{op} eq 'preview_upload';
&GetHostInfo if $f->{op} eq 'get_host_info';

return Streams() if $f->{call} && $f->{app} && $f->{name};

sleep(2),Send( "OK:0:ERROR: dl_key is wrong") if $c->{dl_key} && $f->{dl_key} ne $c->{dl_key};

$c->{ffmpeg}||="$c->{cgi_dir}/ffmpeg";


die"Error2" if $c->{user_agent} && $ENV{HTTP_USER_AGENT} ne $c->{user_agent};
die"Error3:$ENV{HTTP_X_REAL_IP}" if $c->{main_server_ip} && $ENV{HTTP_X_REAL_IP}!~/^$c->{main_server_ip}$/;

my $sub={
         del_files      => \&DeleteFiles,
         test           => \&Test,
         test_host      => \&TestHost,
         update_conf    => \&UpdateConfig,
         check_files    => \&CheckFiles,
         get_file_stats => \&GetFileStats,
         import_list    => \&ImportList,
         import_list_do => \&ImportListDo,
         torrent_kill   => \&TorrentKill,
         torrent_status => \&TorrentStatus,
         transfer2      => \&TransferFiles2,
         delete_file_spec => \&DeleteFileSpec,
         gen_snapshots  => \&GenSnapshots,
         rethumb        => \&ReThumb,
         rethumb_audio  => \&ReThumbAudio,
         reparse        => \&ReParse,
         rescreen       => \&ReScreen,
         reslide        => \&ReSlide,
         thumb_upload   => \&ThumbUpload,
         thumb_upload_audio   => \&ThumbUploadAudio,
         add_ftp_users  => \&AddFTPUsers,
         get_video_info => \&GetVideoInfo,
         get_dev        => \&GetDevices,
         move_mode      => \&MoveMode,
         root_cmd		=> \&RootCMD,
         srt_delete		=> \&SRTDelete,
         srt_upload		=> \&SRTUpload,
         srt_clone		=> \&SRTClone,
	}->{ $f->{op} };
if($sub)
{
   &$sub;
}
else
{
   die"Error4";
}
exit;


sub DeleteFiles
{
   my $list = $f->{list};
   Send('OK') unless $list;
   $|++;
   print"Content-type:text/html\n\n";
   
   my $disk_id = $f->{disk_id};
   print("Invalid disk_id: $disk_id"),exit unless $disk_id=~/^\d+$/;
   my $udir = "$c->{cgi_dir}/uploads/$f->{disk_id}";
   my $idir = "$c->{htdocs_dir}/i/$disk_id";

   for my $x (split(/:/,$list))
   {
      my ($file_id,$file_code,$audio_thumb,$video_thumb,$video_thumb_t)=split('-',$x);
      my $dx = sprintf("%05d",$file_id/$c->{files_per_folder});

      unlink <$udir/$dx/$file_code\_*>;
      unlink <$idir/$dx/$file_code*>;
      unlink <$idir/$dx/$audio_thumb>;
      unlink <$idir/$dx/$video_thumb>;
      unlink <$idir/$dx/$video_thumb_t>;
      print"\n";
   }
   print"OK";
}

sub DeleteFileSpec
{
   print"Content-type:text/html\n\n";
   my $disk_id = $f->{disk_id};
   print("Invalid disk_id: $disk_id"),exit unless $disk_id=~/^\d+$/;
   $f->{file_real} =~ s/\W//g;
   $f->{type} =~ s/\W//g;

   my $dx = sprintf("%05d",$f->{file_real_id}/$c->{files_per_folder});

   if($f->{type})
   {
       unlink("$c->{cgi_dir}/uploads/$f->{disk_id}/$dx/$f->{file_real}_$f->{type}");
   }
   if($f->{original} || $f->{type} eq 'o')
   {
       unlink("$c->{cgi_dir}/orig/$f->{disk_id}/$dx/$f->{file_real}");
       unlink("$c->{cgi_dir}/uploads/$f->{disk_id}/$dx/$f->{file_real}_o");
   }
   print"OK";
}

sub CheckFiles
{
	my $list = $f->{list};
	Send('OK') unless $list;
	my $dir = "$c->{cgi_dir}/uploads/$f->{disk_id}";
	my @arr = split(/:/,$list);
	my @nofiles;
	for my $x (@arr)
	{
		my ($file_id,$file_code)=split('-',$x);
		my $dx = sprintf("%05d",$file_id/$c->{files_per_folder});
		my $exist;
		for ('n','h','l','x','o')
		{
			$exist=1,last if -s "$dir/$dx/$file_code\_$_";
		}
		$exist=1 if -s "$c->{cgi_dir}/orig/$f->{disk_id}/$dx/$file_code";
		push @nofiles, $file_code unless $exist;
	}
	Send("OK:".join ',',@nofiles );
}

sub AddFTPUsers
{
  my $ftp_dir = '/home/ftp';

  $|++;
  print"Content-type:text/html\n\nOK";
  my $hh;
  $f->{list}=~s/\r//g;
  for( split(/\n/,$f->{list}) )
  {
    my ($login,$pass) = split(/:/,$_);
    $hh->{$login} = $pass;
  }

  opendir(DIR, $ftp_dir) || Send("Error:cant open ftp dir $ftp_dir");
  foreach my $fn (readdir(DIR))
  {
     next if $fn =~ /^\.{1,2}$/;
     next unless -d "$ftp_dir/$fn";
     print"\n";
     rmtree("$ftp_dir/$fn") unless $hh->{$fn};
  }
  closedir DIR;

  open FF, ">$c->{cgi_dir}/logs/ftp.users";
  my $salt = get_salt();
  for my $login ( keys %$hh )
  {
    my $pass = $hh->{$login};
    my $hash = crypt($pass, $salt);
    print FF "$login:$hash:48:48::$ftp_dir/$login:/bin/false\n";
  }

  exit;
}

sub get_salt {
        my $rands = substr(time(),-4);
        my $salt = ('a'..'z')[int(($rands/100)%26)];
        $salt .= ('a'..'z')[int(($rands%100)%26)];
        return($salt);
}

sub GetFileStats
{
   my $size;
   $f->{disk_id} =~ s/\W//g;
   my ($files,$ss) = scanDir("$c->{cgi_dir}/uploads/$f->{disk_id}");
   $size+=$ss;

   my (undef,$ss)  = scanDir("$c->{cgi_dir}/orig/$f->{disk_id}");
   $size+=$ss;

   my (undef,$ss)  = scanDir("$c->{htdocs_dir}/i/$f->{disk_id}");
   $size+=$ss;

   Send("OK:$files:$size");
}

sub scanDir
{
   my ($dir) = @_;
   return (0,0) unless -d $dir;
   opendir(DIR, $dir) || Send("Error:cant open dir $dir:$!");
   my ($files,$size)=(0,0);
   while( defined(my $fn=readdir(DIR)) )
   {
      next if $fn=~/^\.{1,2}$/ || !-d "$dir/$fn";

      opendir(DIR2, "$dir/$fn")||next;
      while( defined(my $fn2=readdir(DIR2)) )
      {
         next if $fn2 =~ /^\.{1,2}$/;
         $files++;
         $size += -s "$dir/$fn/$fn2";
      }
      closedir(DIR2);
   }
   return ($files,$size);
}

sub filter
{
  return sort @_;
}

my @arrf;

sub wanted
{
 next if $_ eq '.';

 my $file = $File::Find::name;
 my $mtime = (lstat($file))[9];
 my $mdt = time - $mtime;

 next unless -f $file;
 
 next if $mdt < 60*3;

 my $ss = -s $file;

 my ($fld,$fname) = $file=~/^(.+)\/([^\/]+)$/;
 $fld=~s/^.+ImportFiles\/?//;

 push @arrf, { folder=>$fld, filename=>$fname, size=>$ss };

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

sub ImportList
{
	require File::Find;
	File::Find::find({wanted => \&wanted, preprocess => \&filter }, "$c->{cgi_dir}/ImportFiles");

	require JSON;
	Send( JSON::to_json(\@arrf, {utf8 => 0}) );
}

sub ImportListDo
{
	my $cx=0;
	require File::Find;
	File::Find::find({wanted => \&wanted, preprocess => \&filter }, "$c->{cgi_dir}/ImportFiles");
	for my $x (@arrf)
	{
		my $file = {file_tmp=>"$c->{cgi_dir}/ImportFiles/$x->{folder}/$x->{filename}", 
					file_name_orig=>$x->{filename}, 
					file_public=>$f->{pub}, 
					usr_id=>$f->{usr_id}, 
					no_limits=>1};
		$f->{fld_name}=$x->{folder}||'';
		$f->{ip}='1.1.1.1';
		$file = XUpload::ProcessFile($file,$f);
		unlink("$c->{cgi_dir}/ImportFiles/$x->{folder}/$x->{filename}") if $f->{delete_after};
		$cx++ unless $file->{file_status};
		last if $cx>50;
	}

	Send("OK:$cx") unless $f->{call} eq 'publish_done';
}

sub Test
{
   my @tests;
   $f->{disk_id} =~ s/\D//g;
   my $temp_dir = "$c->{cgi_dir}/temp/$f->{disk_id}";
   my $upload_dir = "$c->{cgi_dir}/uploads/$f->{disk_id}";
   my $img_dir = "$c->{htdocs_dir}/i/$f->{disk_id}";

   chmod 0777, $temp_dir;
   chmod 0777, $upload_dir;
   chmod 0777, $img_dir;

   push @tests, -d $temp_dir ? 'temp dir exist: OK' : mkdir($temp_dir) ? 'temp dir exist: OK' : 'temp dir exist: ERROR';
   push @tests, mkdir("$temp_dir/test") ? 'temp dir mkdir: OK' : 'temp dir mkdir: ERROR';
   push @tests, rmdir("$temp_dir/test") ? 'temp dir rmdir: OK' : 'temp dir rmdir: ERROR';

   push @tests, -d $upload_dir ? 'upload dir exist: OK' : mkdir($upload_dir) ? 'upload dir exist: OK' : 'upload dir exist: ERROR';
   push @tests, mkdir("$upload_dir/test") ? 'upload dir mkdir: OK' : 'upload dir mkdir: ERROR';
   push @tests, rmdir("$upload_dir/test") ? 'upload dir rmdir: OK' : 'upload dir rmdir: ERROR';

   push @tests, -d $img_dir ? 'img dir exist: OK' : mkdir($img_dir) ? 'img dir exist: OK' : 'img dir exist: ERROR';
   push @tests, mkdir("$img_dir/test") ? 'img dir mkdir: OK' : 'img dir mkdir: ERROR';
   push @tests, rmdir("$img_dir/test") ? 'img dir rmdir: OK' : 'img dir rmdir: ERROR';

   Send( "OK:".join('|',@tests) );
}

sub TestHost
{
   my @tests;

   chmod 0666, 'XFSConfig.pm';

   push @tests, -d "$c->{cgi_dir}/temp" ? 'temp dir exist: OK' : 'temp dir exist: ERROR';
   push @tests, -d "$c->{cgi_dir}/uploads" ? 'upload dir exist: OK' : 'upload dir exist: ERROR';
   push @tests, -d "$c->{htdocs_dir}/i" ? 'img dir exist: OK' : 'img dir exist: ERROR';

   push @tests, open(F,'XFSConfig.pm') ? 'config read: OK' : 'config read: ERROR';
   push @tests, open(F,'>>XFSConfig.pm') ? 'config write: OK' : 'config write: ERROR';

   $c->{site_url} ||= $f->{site_url};
   my $res = XUpload::postMain( {
		                          op => 'test'
		                       }
		                      );
   push @tests, $res->content =~ /^OK/ ? 'fs.cgi: OK' : 'fs.cgi: ERROR '.$res->content;
   my ($ip) = $res->content =~ /^OK:(.*)/;

   if($f->{util_test})
   {
      my $x = `$c->{ffmpeg} 2>&1`;
      push @tests, $x=~/version/is ? 'ffmpeg: OK' : 'ffmpeg: ERROR';

      if($c->{mp4box_path})
      {
          my $mp4 = $c->{mp4box_path}||'MP4Box';
          my $x = `$mp4`;
          push @tests, $x=~/option/is ? 'MP4Box: OK' : 'MP4Box: ERROR';
      }

      my $x = `atop 1 1`;
      push @tests, $x=~/CPL/is ? 'atop: OK' : 'atop: ERROR';

      my $x = `iostat`;
      push @tests, $x=~/iowait/is ? 'iostat: OK' : 'iostat: ERROR';

      my $x = `convert`;
      push @tests, $x=~/ImageMagick/is ? 'ImageMagick convert: OK' : 'ImageMagick convert: ERROR';
   }
   
   Send( "OK:$ip:".join('|',@tests) );
}

sub UpdateConfig
{
   my $str = $f->{data};
   my $cc;
   for(split(/\~/,$str))
   {
      /^(.+?):(.*)$/;
      $cc->{$1}=$2;
   }

   my $conf;
   open(F,"$c->{cgi_dir}/XFSConfig.pm")||Send("Can't read Config");
   $conf.=$_ while <F>;
   close F;

   for my $x (keys %{$cc})
   {
      my $val = $cc->{$x};
      $conf=~s/$x\s*=>\s*(\S+)\s*,/"$x => '$val',"/e;
   }

   open(F,">$c->{cgi_dir}/temp/xfs.txt")||Send("Can't write to disk: disk is full?");
   print F "x\n" for 1..2002;
   close F;
   Send("Can't correctly write to disk: disk is full?") if -s "$c->{cgi_dir}/temp/xfs.txt" < 4000;
   unlink("$c->{cgi_dir}/temp/xfs.txt");

   open(F,">$c->{cgi_dir}/XFSConfig.pm")||Send("Can't write Config");
   print F $conf;
   close F;

   if($f->{restart_daemons})
   {
   		`killall -HUP enc.pl url_upload.pl transfer.pl`;
   }

   Send('OK');
}

sub TorrentKill
{
	require File::Slurp;
	my $pid = File::Slurp::read_file("$c->{cgi_dir}/Torrents/transmission.pid") if -e "$c->{cgi_dir}/Torrents/transmission.pid";
	print"Content-type:text/html\n\n";
	return $pid && kill(15, $pid) ? 'OK' : '';
	exit;
}

sub TorrentStatus
{
	require File::Slurp;
	my $pid = File::Slurp::read_file("$c->{cgi_dir}/Torrents/transmission.pid") if -e "$c->{cgi_dir}/Torrents/transmission.pid";
	print"Content-type:text/html\n\n";
   	print $pid && kill(0, $pid) ? 'ON' : '';
   	exit;
}

sub Send
{
   my $txt = shift;
   print"Content-type:text/html\n\n";
   print $txt;
   exit;
}

sub randchar
{ 
   my @range = ('0'..'9','a'..'z');
   my $x = int scalar @range;
   join '', map $range[rand $x], 1..shift||1;
}

sub daemonize
{
    defined( my $pid = fork ) or die "Can't fork: $!";
    print("Content-type:text/html\n\nOK"),exit if $pid;
    close STDOUT              or die "Can't close STDOUT: $!";
    $SIG{CHLD} = 'IGNORE';
}

sub GenSnapshots
{
    my $snaps = $f->{m_s_samples};
    my $length = $f->{file_length};
    my $dt = $length / ($snaps-1);

    my $dx = sprintf("%05d",$f->{file_id}/$c->{files_per_folder});
    $f->{file_code} =~ s/\W+//g;
    $f->{disk_id} =~ s/\D+//g;
    $f->{create} =~ s/[^\d\.]+//g;
    Send("Error:invalid params") unless $f->{file_code}=~/^\w{12}$/ && $f->{disk_id}=~/^\d+$/;
    
    my $dir="$c->{cgi_dir}/uploads/$f->{disk_id}/$dx";
    my $file;
    for('h','n','x','o','l')
    {
    	if(-e "$dir/$f->{file_code}_$_"){ $file="$dir/$f->{file_code}_$_"; last; }
    }
    mkdir("$c->{htdocs_dir}/i/tmp") unless -d "$c->{htdocs_dir}/i/tmp";
    my $temp_dir = "$c->{htdocs_dir}/i/tmp/$f->{file_code}";
    mkdir($temp_dir);

    my @arr;

    if($f->{create})
    {
        my $idir = "$c->{htdocs_dir}/i/$f->{disk_id}/$dx";
        XUpload::makeSnap($file, "$idir/$f->{file_code}.jpg", $f->{create});
        unlink("$idir/$f->{file_code}_t.jpg");
	    my $res = `convert $idir/$f->{file_code}.jpg -resize 720x405^ -gravity center -extent 720x405 $idir/$f->{file_code}_t.jpg`;
        if($res=~/invalid/i)
        {
           `convert $idir/$f->{file_code}.jpg -resize 720x405 -gravity center $idir/$f->{file_code}_t.jpg`;
        }
        my $oldfiles = "$temp_dir/";
        unlink <$oldfiles*>;
        rmdir($temp_dir);
        Send("OK");
    }

    if($f->{preview})
    {
        my @tt = ($f->{preview}-1, $f->{preview}, $f->{preview}+1);
        my @arr;
        for my $t (@tt)
        {
            $t = sprintf("%.01f",$t);
            XUpload::makeSnap($file, "$temp_dir/$t.jpg", $t, 640);
            push @arr, "$t";
        }
        Send( join("\n",@arr) );
    }

    for my $i (0..$snaps-1)
    {
        my $t = $i * $dt;
        $t = 3 if $i==0;
        $t = $length-3 if $i==$snaps-1;
        my $t = sprintf("%.01f",$t);
        XUpload::makeSnap($file, "$temp_dir/$t.jpg", $t, 384, -1, 'fast');
        push @arr, "$t";
    }
    Send( join("\n",@arr) );
}

sub ReThumb
{
    for( split(/:/,$f->{list}) )
    {
        my ($disk_id,$file_id,$file_code,$file_length,$video_thumb,$video_thumb_t) = $_=~/^(\d+)-(\d+)-(\w+)-(\d+)-([\w\.]+)-([\w\.]+)$/;
        my $dx = sprintf("%05d",$file_id/$c->{files_per_folder});
        my $fdir = "$c->{cgi_dir}/uploads/$disk_id/$dx";
        mkdir($fdir) unless -d $fdir;

        my $file = "$fdir/$file_code\_h";
           $file = "$fdir/$file_code\_n" unless -f $file;
           $file = "$fdir/$file_code\_x" unless -f $file;
           $file = "$fdir/$file_code\_o" unless -f $file;
           $file = "$fdir/$file_code\_l" unless -f $file;
           
        next unless -f $file;   
        my $idir = "$c->{htdocs_dir}/i/$disk_id/$dx";
        mkdir($idir) unless -d $idir;

        $c->{thumb_position} = sprintf("%.1f",$file_length*$1/100) if $c->{thumb_position}=~/^([\d\.]+)%$/;
        $c->{thumb_position}=5 unless $c->{thumb_position}=~/^[\d\.]+$/;
        $c->{thumb_position}=3 if $c->{thumb_position}<3;

        XUpload::makeSnap($file, "$idir/$video_thumb", $c->{thumb_position}, 0, 0, 'fast');
        
        unlink("$idir/$video_thumb_t");
        my $res = `convert $idir/$video_thumb -resize 720x405^ -gravity center -extent 720x405 $idir/$video_thumb_t`;
        if($res=~/invalid/i)
        {
           `convert $idir/$video_thumb -resize 720x405 $idir/$video_thumb_t`;
        }
    }
    Send("OK");
}

sub ReThumbAudio
{
    for( split(/:/,$f->{list}) )
    {
        my ($disk_id,$file_id,$file_code,$file_length,$audio_thumb) = $_=~/^(\d+)-(\d+)-(\w+)-(\d+)-([\w\.]+)$/;
        my $dx = sprintf("%05d",$file_id/$c->{files_per_folder});
        my $fdir = "$c->{cgi_dir}/uploads/$disk_id/$dx";
        mkdir($fdir) unless -d $fdir;

        my $file = "$fdir/$file_code\_h";
           $file = "$fdir/$file_code\_n" unless -f $file;
           $file = "$fdir/$file_code\_x" unless -f $file;
           $file = "$fdir/$file_code\_o" unless -f $file;
           $file = "$fdir/$file_code\_l" unless -f $file;
           
        next unless -f $file;   
        my $idir = "$c->{htdocs_dir}/i/$disk_id/$dx";
        mkdir($idir) unless -d $idir;

        XUpload::audioCover($file, "$idir/$audio_thumb");
    }
    Send("OK");
}

sub ReScreen
{
    for( split(/:/,$f->{list}) )
    {
        my ($disk_id,$file_id,$file_code,$file_length,$file_name) = $_=~/^(\d+)-(\d+)-(\w+)-(\d+)-(.+)$/;
        my $dx = sprintf("%05d",$file_id/$c->{files_per_folder});
        my $fdir = "$c->{cgi_dir}/uploads/$disk_id/$dx";
        my $idir = "$c->{htdocs_dir}/i/$disk_id/$dx";

        my $file_path = "$fdir/$file_code\_h";
           $file_path = "$fdir/$file_code\_n" unless -f $file_path;
           $file_path = "$fdir/$file_code\_l" unless -f $file_path;
           $file_path = "$fdir/$file_code\_x" unless -f $file_path;
           $file_path = "$fdir/$file_code\_o" unless -f $file_path;

        my $file = { file_code => $file_code, disk_id => $disk_id, file_length => $file_length, file_name_orig => $file_name };

        my $extra;
		for(split /\n/, $f->{extra})
		{
			/^(.+?)=(.*)$/;
			$extra->{$1}=$2;
		}

        XUpload::createScreenlist( $file_path, $file, $f, $idir, $extra );
    }
    Send("OK");
}

sub ReSlide
{
    for( split(/:/,$f->{list}) )
    {
        my ($disk_id,$file_id,$file_code,$file_length) = $_=~/^(\d+)-(\d+)-(\w+)-(\d+)$/;
        

        my $file = { file_real		=> $file_code, 
        			file_real_id	=> $file_id,
        			file_length 	=> $file_length,
        			disk_id			=> $disk_id,
        		};

        my $error = XUpload::createTimeslides( $file );
        Send($error) if $error;
   }
    Send("OK");
}

sub ReParse
{
    for( split(/:/,$f->{list}) )
    {
        my ($disk_id,$file_id,$file_code) = $_=~/^(\d+)-(\d+)-(\w+)$/;
        my $dx = sprintf("%05d",$file_id/$c->{files_per_folder});

        my $udir = "$c->{cgi_dir}/uploads/$disk_id/$dx";

        my ($data,$file_length);

		for my $q ('o','n','h','l','x','p')
		{
			$data->{"file_size_$q"} = -s "$udir/$file_code\_$q" || 0;
			$data->{"file_spec_$q"} = $data->{"file_size_$q"} ? XUpload::getVideoInfo("$udir/$file_code\_$q",$f) : '';
			$file_length ||= $f->{ID_LENGTH};
		}

        my $res = XUpload::postMain(
			                        {
			                           op 			=> 'update_file_data',
			                           file_code  	=> $file_code,
			                           file_length  => $file_length||0,
			                           %$data,
			                        }
			                       );
    }

    Send("OK");
}

sub ThumbUpload
{
    Send("Invalid input") unless $f->{disk_id}=~/^\d+$/ && $f->{file_code}=~/^\w{12}$/;
    my $dx = sprintf("%05d",$f->{file_id}/$c->{files_per_folder});
    my $dir = "$c->{htdocs_dir}/i/$f->{disk_id}/$dx";

   # Unlink the old video_thumb file
   if (($f->{old_video_thumb} && -e "$dir/$f->{old_video_thumb}") || ($f->{old_video_thumb_t} && -e "$dir/$f->{old_video_thumb_t}")) {
      unlink "$dir/$f->{old_video_thumb}" or warn "Could not delete old video_thumb: $!" if $f->{old_video_thumb};
      unlink "$dir/$f->{old_video_thumb_t}" or warn "Could not delete old video_thumb_t: $!" if $f->{old_video_thumb_t};
   }

    my $file = $q->tmpFileName( $q->param('file') );
    move($file,"$dir/$f->{video_thumb}");
    chmod 0666, "$dir/$f->{video_thumb}";
    `convert $dir/$f->{video_thumb} -resize 720x405^ -gravity center -extent 720x405 $dir/$f->{video_thumb_t}`;
    chmod 0666, "$dir/$f->{video_thumb_t}";
    Send("OK");
}

sub ThumbUploadAudio
{
    Send("Invalid input") unless $f->{disk_id}=~/^\d+$/ && $f->{file_code}=~/^\w{12}$/;
    my $dx = sprintf("%05d",$f->{file_id}/$c->{files_per_folder});
    my $dir = "$c->{htdocs_dir}/i/$f->{disk_id}/$dx";

    # Unlink the old audio_thumb file
    if ($f->{old_audio_thumb} && -e "$dir/$f->{old_audio_thumb}") {
        unlink "$dir/$f->{old_audio_thumb}" or warn "Could not delete old audio_thumb: $!";
    }

    my $file = $q->tmpFileName( $q->param('file') );
    move($file,"$dir/$f->{file_code}.jpg");
    chmod 0666, "$dir/$f->{file_code}.jpg";
    # Convert the image and create a thumbnail
    `convert $dir/$f->{file_code}.jpg -resize 500x500^ -gravity center -extent 500x500 $dir/$f->{audio_thumb}`;
    chmod 0666, "$dir/$f->{audio_thumb}";
    # Delete the original image file
    unlink "$dir/$f->{file_code}.jpg" or warn "Could not delete original image: $!";
    Send("OK");
}

sub PreviewUpload
{
    die"Invalid input" unless $f->{disk_id}=~/^\d+$/ && $f->{file_code}=~/^\w{12}$/;
    require Digest::MD5;
    my $md5 = Digest::MD5::md5_hex($f->{file_id}.$f->{file_code}.$c->{dl_key});
    Send("Error md5") unless $md5 eq $f->{md5};
    my $dx = sprintf("%05d",$f->{file_id}/$c->{files_per_folder});
    my $dir = "$c->{cgi_dir}/uploads/$f->{disk_id}/$dx";
    my $file = $q->tmpFileName( $q->param('file') );
    move($file,"$dir/$f->{file_code}_p");
    chmod 0666, "$dir/$f->{file_code}_p";
    my $sizep = -s "$dir/$f->{file_code}_p";

    my $res = XUpload::postMain({
		                           op     => 'update_file_data',
		                           file_code  => $f->{file_code},
		                           file_size_p  => $sizep,
		                        }
		                       );
    
    print $q->redirect(-uri => "$c->{site_url}/?op=file_edit&file_code=$f->{file_code}");
    exit;
}

sub GetVideoInfo
{
    $f->{file_code} =~ s/\W//g;
    $f->{disk_id} =~ s/\D//g;
    my $dx = sprintf("%05d",$f->{file_id}/$c->{files_per_folder});
    my $file = "$c->{cgi_dir}/uploads/$f->{disk_id}/$dx/$f->{file_code}_$f->{mode}";
    Send("File not found") unless -f $file;
    my $file_spec = XUpload::getVideoInfo($file,$f);
    Send("OK:$file_spec");
}

sub GetDevices
{
    my $out="DF:<br>";
    my $df=`df -BG -P`;
    for(split(/\n/,$df))
    {
      my ($dev,$total,$used,$free,$usedprc,$mount) = $_=~/^(.+?)\s+(\d+)G\s+(\d+)G\s+(\d+)G\s+(\d+%)\s+(.+)/gis;
      next unless $dev;
      next if $dev=~/^(tmpfs)$/i;
      $dev=~s/^\/dev\///;
      $dev=~s/^(.+)\/(.+)$/$2/;
      my $realtotal = $used+$free-1;
      $realtotal = 10*int($realtotal/10) if $realtotal>100;
      $out.=qq[<a href='#' onclick="\$('input[name=disk_dev_df]').val('$dev');return false;"><b>$dev</b></a> used: $used GB, free: <a href='#' onclick="\$('input[name=srv_disk_max]').val('$realtotal');return false;">$free</a> GB ($mount)<br>];
    }

    $out.="<br>IO:<br>";
    my $io=`iostat`;
    $io=~s/^.+Device://is;
    while($io=~/\n([\w\-]+)\s+/gis)
    {
      $out.=qq[<a href='#' onclick="\$('input[name=disk_dev_io]').val('$1');return false;"><b>$1</b></a><br>];
    }
    Send($out);
}

sub MoveMode
{
    my $dx = sprintf("%05d",$f->{file_id}/$c->{files_per_folder});
    die"Invalid input" unless $f->{disk_id}=~/^\d+$/ && $f->{file_code}=~/^\w{12}$/ && $f->{mode1}=~/^\w$/ && $f->{mode2}=~/^\w$/;
    
    my $file1 = "$c->{cgi_dir}/uploads/$f->{disk_id}/$dx/$f->{file_code}_$f->{mode1}";
    Send("File not found 1") unless -f $file1;

    my $file2 = "$c->{cgi_dir}/uploads/$f->{disk_id}/$dx/$f->{file_code}_$f->{mode2}";
    rename( $file1, $file2 ) || Send("Not able to rename file: $!");

    Send("OK");
}

sub GetHostInfo
{
	my $out;
	open FILE, "/proc/meminfo";
	my $mem = <FILE>;
	close FILE;
	my ($ram) = $mem=~/MemTotal:\s+(\d+) kB/;
	$ram = sprintf("%.1f", $ram/1024/1024 );
	$out="RAM: $ram GB";

	open FILE, "/proc/cpuinfo";
	my $cpu = join '', <FILE>;
	close FILE;
	my @arr = split /\n\n/, $cpu;
	$cpu=$arr[$#arr];
	my ($cpus) = $cpu=~/processor\s+: (\d+)/i;
	$cpus++;
	my ($model) = $cpu=~/model name\s+: (.+?)\n/i;
	$model=~s/\(R\)//g;
	$model=~s/\(TM\)//g;
	$out.="<br>CPU model: $model<br>CPU cores: $cpus";

	my $netfile = "/sys/class/net/eth0/speed";
	$netfile="/sys/class/net/bond0/speed" unless -f $netfile;
	$netfile="/sys/class/net/bond1/speed" unless -f $netfile;
	$netfile="/sys/class/net/eth1/speed" unless -f $netfile;
	if(-f $netfile)
	{
		open FILE, $netfile;
		my $net = <FILE>;
		close FILE;
		$out.="<br>Net speed: $net Mbps";
	}
	
	Send($out);
}

sub Streams
{
	print("Content-type:text/html\n\n"),exit unless $f->{call}=~/^(publish|publish_done|record_done|update_publish)$/;
	$f->{flashver}=$f->{pageurl}=$f->{swfurl}='';
	logg('streams',$f);	

	my $res = XUpload::postMain({
		                        op    	=> 'streams',
		                        host_id => $c->{host_id},
		                        call 	=> $f->{call},
		                        app 	=> $f->{app},
		                        name 	=> $f->{name},
		                        addr 	=> $f->{addr},
		                        time 	=> $f->{time},
		                        key		=> $f->{key},
		                       }
		                      );
	unless($res->content=~/^OK/)
	{
		logg('streams', "fs error:".$res->content);
		print("Status: 404 Not found\n\n"),exit if $f->{call} eq 'publish';
	}
	print"Content-type:text/html\n\n";
	if($f->{call} eq 'record_done' && $f->{recorder}!~/preview/)
	{
		my (undef,$record)=split(/:/,$res->content);
		logg('streams', "rec:$record");
		if($record)
		{
			$f->{ip}=$f->{addr};
			$f->{fld_name}="Stream $f->{name}";
			my ($fn) = $f->{path}=~/\/([^\/]+)$/;
			my $file = {file_tmp=>$f->{path}, file_name_orig=>$fn, file_public=>1, usr_id=>0, no_limits=>1};
      		$file = XUpload::ProcessFile($file,$f);
      		logg('streams', "process: $f->{path} : $fn : ".$file->{file_status});
			logg('streams', "done import.");
		}
		else
		{
			unlink($f->{path});
		}
	}
	exit;
}

sub RootCMD
{
	Send('ERROR') unless $f->{cmd}=~/^[\w\-\_\=\:\.]+$/;
	open FILE, ">>$c->{cgi_dir}/temp/cmd.txt";
	print FILE "$f->{cmd}\n";
	Send('OK');
}

sub logg
{
	my ($type,$msg,$exit) = @_;
	return unless $type && $msg;
	if(ref $msg)
	{
		require Data::Dumper;
		$msg = Data::Dumper->Dump([$msg]);
	}
	open FILE, ">>logs/$type.txt" || return;
	print FILE $msg."\n";
	close FILE;
	print STDERR $msg."\n";
	print("Content-type:text/html\n\n$exit") if $exit && $exit ne 'exit';
	exit if $exit;
}

sub SRTDelete
{
	return logg('srt',"invalid language",'exit') unless $f->{language}=~/^\w\w\w$/;
	return logg('srt',"invalid code",'exit') unless $f->{file_code}=~/^\w{12}$/;
	return logg('srt',"invalid dx",'exit') unless $f->{dx}=~/^\d+$/;
	my $path = "$c->{cgi_dir}/uploads/$f->{disk_id}/$f->{dx}/$f->{file_code}_$f->{language}";
	unlink($path);
	Send('OK');
}

sub SRTUpload
{
	return logg('srt',"invalid language",'exit') unless $f->{language}=~/^\w\w\w$/;
	return logg('srt',"invalid code",'exit') unless $f->{file_code}=~/^\w{12}$/;
	return logg('srt',"invalid dx",'exit') unless $f->{dx}=~/^\d+$/;
	my $path = "$c->{cgi_dir}/uploads/$f->{disk_id}/$f->{dx}/$f->{file_code}_$f->{language}";
	open FILE, ">$path";
	print FILE $f->{data};
	close FILE;
	Send('OK');
}

sub SRTClone
{
	my $dir = "$c->{cgi_dir}/uploads/$f->{disk_id}/$f->{dx}";
	return logg('srt',"invalid code1",'exit') unless $f->{file_code}=~/^\w{12}$/;
	return logg('srt',"invalid code2",'exit') unless $f->{file_code_new}=~/^\w{12}$/;
	return logg('srt',"invalid dx",'exit') unless $f->{dx}=~/^\d+$/ && -d $dir;
	for(split(/\|/,$f->{languages}))
	{
		next unless $_=~/^\w\w\w$/;
		copy("$dir/$f->{file_code}_$_", "$dir/$f->{file_code_new}_$_");
	}
	Send('OK');
}
