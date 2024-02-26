package fs;

use strict;

use lib '.';
use XFileConfig;
use Session;
use HCE_MD5;


use CGI::Carp qw(fatalsToBrowser);

my ($ses,$f,$db);

my ($user,$utype);

my $hce = HCE_MD5->new($c->{dl_key},"XVideoSharing");

sub run
{
	my ($query,$dbc) = @_;

	return sendBack("111") if $ENV && $ENV{REQUEST_METHOD} ne 'POST';

	$ses = Session->new($query,$dbc);
	$ses->{fast_cgi} = $c->{fast_cgi};
	$ses->{no_escape}=1;
	$f = $ses->f;

	my $REMOTE_ADDR = $ses->getIP;

	return sendBack("OK:".$REMOTE_ADDR) if $f->{op} eq 'test';

	unless($f->{op}=~/torrent/i)
	{
		return sendBack("222") if $ENV && $ENV{HTTP_USER_AGENT} ne $c->{user_agent};
		return sendBack("333") unless $f->{dl_key} eq $c->{dl_key};
	}

	$db ||= $ses->db;

	return sendBack("badip:$REMOTE_ADDR") if $c->{file_server_ip_check} && !($db->SelectOneCached("SELECT host_id FROM Hosts WHERE host_ip=?",$REMOTE_ADDR) || $REMOTE_ADDR eq '127.0.0.1' || $REMOTE_ADDR=~/^0\.0\./);

	return StatsOld() if $f->{op} eq 'stats';

$f->{usr_id} = $db->SelectOne("SELECT usr_id
                               FROM Sessions
                               WHERE session_id=?",$f->{sess_id}) if $f->{sess_id} && !$f->{usr_id};

if($f->{sid})
{
   my $tt = $db->SelectRow("SELECT * FROM Torrents WHERE sid=?",$f->{sid});
   if($tt)
   {
	   $f->{usr_id} = $tt->{usr_id};
	   for(split(/\n/,$tt->{extras}))
	   {
	     /^(.+?)=(.*)$/;
	     $f->{$1} = $2;
	   }
   }
}

$user = undef;

$user = $db->SelectRow("SELECT *, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec
                           FROM Users u 
                           WHERE u.usr_id=?",$f->{usr_id}) if $f->{usr_id};

$user = $db->SelectRow("SELECT *, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec
                        FROM Users u 
                        WHERE u.usr_login=?",$f->{usr_login}) if !$user && $f->{usr_login};

$user ||= $db->SelectRow("SELECT u.*, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec
                        FROM Streams s, Users u 
                        WHERE s.stream_code=?
                        AND s.usr_id=u.usr_id",$f->{name}) if !$user && $f->{app} && $f->{name};

if(!$user && $f->{api_key})
{
  my ($uid,$api_key) = $f->{api_key}=~/^(\d+)(\w{16})$/;
  $user = $db->SelectRow("SELECT *, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec 
			FROM Users 
			WHERE usr_id=? 
			AND usr_api_key=?",$uid,$api_key);
}

if($user)
{
	my $data = $db->SelectARef("SELECT * FROM UserData WHERE usr_id=?",$user->{usr_id});
	$user->{$_->{name}}=$_->{value} for @$data;
}

$utype = $user ? ($user->{exp_sec}>0 ? 'prem' : 'reg') : 'anon';
$c->{$_}=$c->{"$_\_$utype"} for qw(disk_space max_upload_filesize max_rs_leech torrent_dl_slots upload_enabled);


my $sub={
		check_codes				=> \&CheckCodes,

		del_torrent				=> \&TorrentDel,
		add_torrent				=> \&TorrentAdd,
		torrent_stats			=> \&TorrentStats,
		torrent_done			=> \&TorrentDone,

		queue_enc_next			=> \&QueueEncNext,
		enc_progress			=> \&QueueEncProgress,
		queue_enc_done			=> \&QueueEncDone,
		enc_error				=> \&QueueEncError,

		queue_transfer_next		=> \&QueueTransferNext,
		transfer_progress		=> \&QueueTransferProgress,
		queue_transfer_done		=> \&QueueTransferDone,
		transfer_error			=> \&QueueTransferError,

		queue_url_next			=> \&QueueURLNext,
		upload_progress			=> \&QueueURLProgress,
		queue_url_done			=> \&QueueURLDone,
		upload_error			=> \&QueueURLError,
		

		delete_file_db			=> \&DeleteFileDB,
		atop					=> \&ATop,
		next_ftp_server			=> \&NextFTPServer,
		update_file_data		=> \&UpdateFileData,
		streams					=> \&Streams,
		ftp_current				=> \&FTPCurrent,
		delete_disk_next		=> \&DeleteDiskNext,
		save_vtt_next			=> \&SaveVTTNext,
	     }->{ $f->{op} };
if($sub)
{
   return &$sub;
}
elsif($f->{file_name})
{
   return SaveFile();
}
else
{
   return sendBack("nil");
}

}

sub CheckCodes
{
	my @codes = split(/\,/,$f->{codes});
	return sendBack("OK:") unless @codes;
	my @codes2 = grep{/^\w{12}$/} map{/^(\w{12})/;$1} @codes;
	my $ok=[];
	if($f->{host_id}=~/^\d+$/)
	{
		my $field = $f->{ssd} ? "f.srv_id_copy" : "f.srv_id";
		$ok = $db->SelectARef("SELECT file_real 
								FROM Files f, Servers s 
								WHERE f.file_real IN (".join(',', map{"'$_'"}@codes2 ).") 
								AND $field=s.srv_id
								AND s.host_id=$f->{host_id}");
	}
	else
	{
		$ok = $db->SelectARef("SELECT file_real 
								FROM Files 
								WHERE file_real IN (".join(',', map{"'$_'"}@codes2 ).")");
	}
	my %h;
	$h{$_->{file_real}}=1 for @$ok;
	my @bad;
	for my $cc (@codes)
	{
		my ($x) = $cc=~/^(\w{12})/;
		push @bad,$cc unless $h{$x};
	}
	return sendBack( "OK:".join(',',@bad) );
}

sub TorrentDel
{
   logg( "TorrentDel: ".Data::Dumper->Dump([$f]) );
   $db->Exec("DELETE FROM Torrents WHERE sid=?",$f->{sid});
   return sendBack("OK");
}

sub TorrentAdd
{
   $f->{sid} = unpack("H*", $ses->decode32($f->{sid})) if length($f->{sid}) == 32;

   return sendBack("ERROR:This torrent already working") if $db->SelectOne("SELECT sid FROM Torrents WHERE sid=? AND status='WORKING'",$f->{sid});
   return sendBack("ERROR:You're already using $c->{torrent_dl_slots} torrent slots") 
      if $c->{torrent_dl_slots} && $db->SelectOne("SELECT COUNT(*) FROM Torrents WHERE usr_id=? AND status='WORKING'",$user->{usr_id})>=$c->{torrent_dl_slots};

   my $server = $db->SelectRow("SELECT * 
   								FROM Servers 
   								WHERE host_id=? 
   								AND srv_status IN ('ON')
   								AND srv_disk <= srv_disk_max*0.99
   								", $f->{host_id} );
   return sendBack("ERROR:No disks available for torrent on $f->{host_id}") unless $server;

   $db->Exec("INSERT INTO Torrents 
   				SET sid=?, 
   				usr_id=?, 
   				host_id=?, 
   				extras=?, 
   				created=NOW(),
   				updated=NOW()",
              $f->{sid},
              $user->{usr_id},
              $f->{host_id},
              $f->{extras}||'') if $f->{sid};

	my $extra={};
	if($c->{"torrent_dl_speed_$utype"})
	{
			$extra->{"downloadLimit"} = $c->{"torrent_dl_speed_$utype"};
			$extra->{"downloadLimited"} = 'true';
	}
	if($c->{"torrent_up_speed_$utype"})
	{
			$extra->{"uploadLimit"} = $c->{"torrent_up_speed_$utype"};
			$extra->{"uploadLimited"} = 'true';
	}
	if($c->{"torrent_peers_$utype"})
	{
			$extra->{"peer-limit"} = $c->{"torrent_peers_$utype"};
	}
	require JSON;
	my $extra_str=JSON::encode_json($extra);

	return sendBack("OK:$extra_str");
}

sub TorrentStats
{

	$db->Exec("UPDATE Hosts SET host_torrent_active=NOW() WHERE host_id=? AND host_torrent=1",$f->{host_id});

	if($f->{ping})
	{
		print"Content-type: text/html\n\n";
		print'{"status":"OK"}';
		return;
	}

	require JSON;
	my $torrents = JSON::decode_json($f->{data});
	my @deleted_torrents;
	for(@$torrents)
	{
		push @deleted_torrents, $_->{info_hash} if !$db->SelectOne("SELECT * FROM Torrents WHERE sid=?", $_->{info_hash});
		$db->Exec("UPDATE Torrents 
					SET name=?, 
						downloaded=?, 
						uploaded=?, 
						download_speed=?, 
						upload_speed=?, 
						size=?, 
						files=?, 
						host_id=?,
						peers=?,
						updated=FROM_UNIXTIME(?) 
					WHERE sid=?",
				$_->{name}||'',
				$_->{total_done},
				$_->{total_uploaded},
				$_->{download_rate},
				$_->{upload_rate},
				$_->{total_wanted},
				JSON::encode_json($_->{files}||[]),
				$f->{host_id},
				$_->{peers},
				$_->{updated},
				$_->{info_hash});
	}

	print"Content-type: text/html\n\n";
	print JSON::encode_json( { status => 'OK', deleted_torrents => \@deleted_torrents } );
}

sub TorrentDone
{
	require Data::Dumper;

   return sendBack("No sid") if !$f->{sid};
   
   $db->Exec("DELETE FROM Torrents WHERE sid=?",$f->{sid});

   require JSON;
   return sendBack( JSON::encode_json({ status => 'OK', delete => 'true' }) );
}

sub saveFileError
{
    my ($msg) = @_;
    return sendBack("0:0:0:$msg");
}

sub SaveFile
{
   my $server = $db->SelectRow("SELECT * FROM Servers WHERE host_id=? AND disk_id=?", $f->{host_id}, $f->{disk_id} ) if $f->{host_id} && $f->{disk_id};
   $server ||= $db->SelectRow("SELECT * FROM Servers WHERE host_id=? AND srv_status='ON' AND srv_disk <= srv_disk_max ORDER BY RAND() LIMIT 1",$f->{host_id});
   return saveFileError("server/disk not found for $f->{host_id} / $f->{disk_id}") unless $server;
   $f->{disk_id}||=$server->{disk_id};

   my $size  = $f->{file_size}||0;
   my $filename = $f->{file_name};
   my $descr = $f->{file_descr}||'';
   my $md5 = $f->{file_md5}||'';
   #my $thumbr = $f->{audio_thumb};

   if($f->{'retry'})
   {
      my $ff = $db->SelectRow("SELECT * FROM Files WHERE file_size=? AND file_md5=? AND file_created>NOW()-INTERVAL 3 MINUTE ORDER BY file_id LIMIT 1",$size,$md5);
      return sendBack("$ff->{file_id}:$ff->{file_code}:$ff->{file_real}:$utype:OK\nscreenlist=$ff->{file_screenlist}") if $ff;
   }
   
   
   unless($f->{no_limits})
   {
		if( $c->{video_extensions} && $filename!~/\.($c->{video_extensions})$/i && !$c->{allow_non_video_uploads})
		{
			return saveFileError("unallowed video extension");
		}

		$c->{max_upload_filesize}=0 if $user && $user->{usr_adm};
		if( $c->{max_upload_filesize} && $size>$c->{max_upload_filesize}*1024*1024 )
		{
			return saveFileError("file is too big");
		}

		if( $c->{max_upload_length_min} && $f->{file_length} > $c->{max_upload_length_min}*60 && !$c->{allow_non_video_uploads} )
		{
			return saveFileError("video is too long");
		}
		if( $c->{min_upload_length_sec} && $f->{file_length} < $c->{min_upload_length_sec} && !$c->{allow_non_video_uploads} )
		{
			return saveFileError("video is too short");
		}

		my $disk_space_max = $user->{usr_disk_space} || $c->{disk_space};
		if($disk_space_max)
		{
			if($user->{usr_disk_used}+$size/1024 > $disk_space_max*1024**2)
			{
				return saveFileError("not enough disk space on your account");
			}
		}

		if($user->{usr_files_used} >= 50*1000)
		{
			return saveFileError("too many files on your account");
		}

		if($c->{upload_limit_files_last24} && $db->SelectOne("SELECT COUNT(*) FROM Files WHERE file_created>NOW()-INTERVAL 24 HOUR AND usr_id=?",$user->{usr_id}) >= $c->{upload_limit_files_last24})
		{
			return saveFileError("too many files uploaded last 24h");
		}
   }
   
   if($f->{upload_mode} eq 'url' && $f->{url_id})
   {
      my $uu = $db->SelectRow("SELECT * FROM QueueUpload WHERE id=?",$f->{url_id});
      for(split(/\n/,$uu->{extras}))
      {
          /^(.+?)=(.*)$/;
          $f->{$1} = $2;
      }
      $f->{file_code} = $uu->{file_code} if $uu->{file_code};
      $f->{fld_id} = $uu->{fld_id} if $uu->{fld_id};
   }
   
   $filename=~s/%(\d\d)/chr(hex($1))/egs;
   $filename=~s/%/_/gs;
   $filename=~s/\s{2,}/ /gs;
   $filename=~s/[\#\"\0]+/_/gs;
   $filename=~s/[^\w\d\.-\<\>]+/_/g if $c->{sanitize_filename};
   $filename=~s/$c->{fnames_not_allowed}//gi if $c->{fnames_not_allowed};
   
   $descr=~s/</&lt;/gs;
   $descr=~s/>/&gt;/gs;
   $descr=~s/"/&quot;/gs;
   $descr=~s/\(/&#40;/gs;
   $descr=~s/\)/&#41;/gs;

   $f->{file_title}||=$filename;
   $f->{file_title}=~s/\.($c->{video_extensions})$//i;
   $f->{file_title}=~s/\.($c->{audio_extensions})$//i;
   $f->{file_title}=~s/\.($c->{image_extensions})$//i;
   $f->{file_title}=~s/\.($c->{archive_extensions})$//i;
   $f->{file_title}=~s/_+/ /g;
   $f->{file_title}=~s/\.+/ /g;
   $f->{file_title}=~s/\s+(x264|h264|divx|xvid)\s+/ /i;
   $f->{file_title}=~s/[\<\>\#\"\0]+/ /gs;
   $f->{file_title}=~s/$c->{fnames_not_allowed}//gi if $c->{fnames_not_allowed};
   $f->{file_title}=~s/[^\w\d\.\_\-]+/_/g if $c->{sanitize_filename};
   $f->{file_title}=~s/\s+$//g;
   $f->{file_title}=~s/^\s+//g;



   $filename=~s/\.(\w+)$/"$c->{add_filename_postfix}\.$1"/e if $c->{add_filename_postfix};

   my $usr_id = $user ? $user->{usr_id} : 0;
   $usr_id||=0;
   if($c->{uploads_selected_only})
   {
       return saveFileError("You are not allowed to upload files") unless $user->{usr_uploads_on};
   }
   else
   {
       return saveFileError("You are not allowed to upload files") unless $c->{upload_enabled};
   }
   if($f->{fld_name} && $usr_id)
   {
      $f->{fld_id}=0;
      for my $fld ( split(/\//,$f->{fld_name}) )
      {
        $fld=~s/\.($c->{video_extensions})$//i;
        my $fld_id = $db->SelectOne("SELECT fld_id FROM Folders WHERE usr_id=? AND fld_parent_id=? AND fld_name=?",$usr_id,$f->{fld_id},$fld);
        unless($fld_id)
        {
          my $fcode = randchar(10);
          while($db->SelectOne("SELECT fld_id FROM Folders WHERE fld_code=?",$fcode)){$fcode = randchar(10);}
          $db->Exec("INSERT INTO Folders SET usr_id=?, fld_parent_id=?, fld_name=?, fld_code=?", $usr_id, $f->{fld_id}||0, $fld, $fcode);
          $fld_id = $db->getLastInsertId;
        }
        $f->{fld_id}=$fld_id;
      }
   }

   if($c->{m_8} && $user && $user->{usr_notes}=~/DEFAUDIO=(\w+)/i)
   {
   		$f->{effects}.="|default_audio_lang=$1";	
   }
   elsif($c->{m_8} && $user && $user->{usr_default_audio_lang}=~/^\w+$/)
   {
   		$f->{effects}.="|default_audio_lang=$user->{usr_default_audio_lang}";	
   }
   
   
   my $code = $f->{file_code} || randchar(12);
   while($db->SelectOne("SELECT file_id FROM Files WHERE file_code=? OR file_real=?",$code,$code)){$code = randchar(12);}
   my $del_id = randchar(10);
   
   my $ex = $db->master()->SelectRow("SELECT * FROM Files 
   							WHERE file_size=? 
   							AND file_md5=? 
   							ORDER BY file_id 
   							LIMIT 1",$size,$md5) if $c->{anti_dupe_system};

   my ($real,$real_id,$audio_thumb,$video_thumb,$video_thumb_t);
   if($ex)
   {
       $real = $ex->{file_real};
       $real_id = $ex->{file_real_id} || $ex->{file_id};
       $size = $ex->{file_size};
       $server->{srv_id} = $ex->{srv_id};
       $audio_thumb = $ex->{audio_thumb};
       $video_thumb = $ex->{video_thumb};
       $video_thumb_t = $ex->{video_thumb_t};
   } else {
      $audio_thumb = $f->{audio_thumb};
      $video_thumb = $f->{video_thumb};
      $video_thumb_t = $f->{video_thumb_t};      
   }

   $real ||= $code;

   if($c->{approve_required})
   {
      $f->{file_status}='PENDING';
      $f->{file_status}='OK' if $c->{approve_required} && $db->SelectOne("SELECT value FROM UserData WHERE usr_id=? AND name='usr_autoapprove'",$usr_id);
      $f->{file_status}='OK' if $c->{approve_required_first} && $f->{file_status} eq 'PENDING' && $db->SelectOne("SELECT COUNT(*) FROM Files WHERE usr_id=? AND file_status='OK'",$usr_id)>=$c->{approve_required_first};
   }
   $f->{file_status}||='OK';
   my $screenlist=1 if $c->{m_x} && !($c->{m_x_prem_only} && $utype ne 'prem');

   my $file_premium_only = $user->{usr_premium_only} && $db->SelectOne("SELECT value FROM UserData WHERE usr_id=? AND name='files_auto_po'",$usr_id) ? 1 : 0;

   $f->{file_ip} = $ses->convertIP6toIP4($f->{file_ip}) if $f->{file_ip}=~/:/;
   $f->{file_spec_txt}='' unless $c->{save_source_raw_info};

   my $save_code='';
   $f->{file_size_o} = $f->{file_size};
   $f->{file_spec_o} = $f->{file_spec};
   for (@{$c->{quality_letters}},'o','p')
   {
   		$save_code.="file_size_$_=".(  $ex ? $ex->{"file_size_$_"} : $f->{"file_size_$_"}||0 ).",";
   		$save_code.="file_spec_$_='".( $ex ? $ex->{"file_spec_$_"} : $f->{"file_spec_$_"}||'' )."',";
   }
   
   $db->Exec("INSERT INTO Files 
              SET file_name=?, 
                  usr_id=?, 
                  srv_id=?,
                  file_title=?,
                  audio_artist=?,
                  audio_title=?,
                  audio_album=?,
                  audio_genre=?,
                  audio_thumb=?,
                  video_thumb=?,
                  video_thumb_t=?,
                  file_descr=?, 
                  file_fld_id=?, 
                  file_public=?, 
                  file_code=?, 
                  file_real=?, 
                  file_real_id=?, 
                  file_size=?,
                  $save_code
                  file_ip=INET_ATON(?), 
                  file_md5=?, 
                  file_spec_txt=?,
                  file_length=?,
                  cat_id=?,
                  file_status=?,
                  file_src=?,
                  file_screenlist=?,
                  file_premium_only=?, 
                  file_adult=?,
                  file_captions=?,
                  file_created=NOW(), 
                  file_last_download=NOW()",
               $filename,
               $usr_id,
               $server->{srv_id},
               $f->{file_title},
               $f->{audio_artist},
               $f->{audio_title},
               $f->{audio_album},
               $f->{audio_genre},
               $audio_thumb,
               $video_thumb,
               $video_thumb_t,
               $descr,
               $f->{fld_id}||0,
               $f->{file_public}||0,
               $code,
               $real,
               $real_id||0,
               $size,
               $f->{file_ip}||'1.1.1.1',
               $md5,
               $ex->{file_spec_txt}||$f->{file_spec_txt}||'',
               $f->{file_length}||0,
               $f->{cat_id}||0,
               $f->{file_status},
               $f->{file_src},
               $screenlist||0,
               $file_premium_only,
               $f->{file_adult}||0,
               '',
             );

	my $file_id = $db->getLastInsertId;
	$db->Exec("UPDATE Files SET file_real_id=? WHERE file_id=?",$file_id,$file_id) unless $real_id;

   $f->{file_seo} ||= lc $f->{file_title};   # Convert to lowercase and default to file_title if file_seo is not set
   $f->{file_seo} =~ s/\s*-\s*/-/g;          # Replace spaces or hyphens surrounded by spaces with a single hyphen
   $f->{file_seo} =~ s/\s+/-/g;              # Replace one or more spaces with a hyphen
   $f->{file_seo} =~ s/[^\w\d.-]//g;         # Remove any character that is not a word character, digit, dot, or hyphen

   if($c->{video_extensions} && $filename =~ /\.($c->{video_extensions})$/i) {
      $f->{file_seo} .= "-v";             # Append '-v' at the end
   } elsif($c->{audio_extensions} && $filename =~ /\.($c->{audio_extensions})$/i) {
      $f->{file_seo} .= "-a";             # Append '-v' at the end
   } elsif($c->{image_extensions} && $filename =~ /\.($c->{image_extensions})$/i) {
      $f->{file_seo} .= "-i";             # Append '-v' at the end
   } elsif($c->{archive_extensions} && $filename =~ /\.($c->{archive_extensions})$/i) {
      $f->{file_seo} .= "-r";             # Append '-v' at the end
   } else {
      $f->{file_seo} .= "-f";             # Append '-v' at the end
   }

   $db->Exec("UPDATE Files SET file_seo=? WHERE file_id=?",$f->{file_seo},$file_id);

	$size=0 unless $code eq $real;

	$db->Exec("UPDATE Users 
				SET usr_disk_used=usr_disk_used+?,
					usr_files_used = usr_files_used+1
				WHERE usr_id=?", int($size/1024), $usr_id );

	if($f->{file_title}=~/^(.+?)[\s\-\_]+S\d\d?E\d\d?/i)
	{
		$f->{tags}.=",$1";
	}
	require XUtils;
	XUtils::addTagsToFile( $db, $f->{tags}, $file_id );

	XUtils::addExtraFileData( $db, $f, $file_id ) if $c->{file_data_fields};

	$ses->logFile( $real, "Uploaded to host_id=$f->{host_id} to srv_id=$server->{srv_id} to srv_ip=".$ses->getIP );

	if($c->{m_g} && $c->{srt_on} && $c->{srt_auto} && $f->{data_srt})
	{
		my $lng_hash;
		$lng_hash->{$1}=$2 while $c->{srt_auto_langs}=~/(\w+)=(\w+)/g;
		my (@langsaved,$lngdone);
		for(split(/\^\^\^/,$f->{data_srt}))
		{
			my ($lng,$data) = split(/\|\|\|/,$_);
			$lng = lc $lng;
			next unless $lng=~/^\w\w\w$/;
			logg("$code:srt:$lng");
			next unless $lng_hash->{$lng};
			$data=~s/[\s\n\r]$//gis;
			$data=~s/ size="\d+"//gis;
			$data=~s/ face="\w+"//gis;

			next if length($data) < 32;
			next if $lngdone->{$lng}++;

			$db->Exec("INSERT INTO QueueVTT 
						SET file_real_id=?,
						file_code=?,
						host_id=?,
						disk_id=?,
						language=?,
						data=?",
						$real_id||$file_id,
						$code,
						$server->{host_id},
						$server->{disk_id},
						$lng,
						$data);

			push @langsaved, $lng;
		}
	}

	my $edata;
	if($code eq $real)
	{
		my $no_encoding;
      #my $no_audio_encoding;
		my $prem = $utype eq 'prem' ? 1 : 0;
		my $file = {file_real_id => $real_id||$file_id, 
			file_real	=> $real||$code,
			file_id		=> $file_id, 
			srv_id		=> $server->{srv_id},
			host_id		=> $server->{host_id},
			srv_type	=> $server->{srv_type},
			file_spec	=> $f->{file_spec},
			file_spec_o	=> $f->{file_spec},
			file_size_o	=> $size,
			file_name	=> $filename,
			usr_id		=> $usr_id,
			premium		=> $prem,
		};

	$no_encoding = 1 if ($c->{audio_extensions} || $c->{video_extensions}) && $filename !~ /\.($c->{audio_extensions}|$c->{video_extensions})$/i;
    

	require XUtils;
	my $vi = XUtils::vInfo($file,'o');
   #$no_audio_encoding = 1 if ($c->{audio_extensions} && $filename =~ /\.($c->{audio_extensions})$/i && $vi->{vid_audio_bitrate}<199);
	my $audio_codec_pass=1 if $vi->{vid_audio_codec} eq 'AAC';
	my $video_codec_pass=1 if $vi->{vid_codec} eq 'H264';
	my $container_pass=1 if lc($vi->{vid_container}) eq 'mp4';
	$no_encoding=1 if $c->{allow_no_encoding} && 
						$file->{usr_id} && 
						$video_codec_pass && 
						$audio_codec_pass && 
						$container_pass && 
						$db->SelectOne("SELECT value FROM UserData WHERE usr_id=? AND name='usr_no_encoding'",$file->{usr_id});

               

                   

     if($no_encoding)
     {
        if($server->{srv_type} eq 'UPLOADER')
        {
            my $srv_id2 = findServerToTransfer($file);

            $db->Exec("INSERT IGNORE INTO QueueTransfer
                       SET file_real_id=?, 
                           file_real=?, 
                           file_id=?,
                           premium=?, 
                           srv_id1=?,
                           srv_id2=?,
                           created=NOW()", 
                           $file->{file_real_id}, 
                           $file->{file_real}, 
                           $file->{file_id}, 
                           $prem, 
                           $file->{srv_id},
                           $srv_id2
                     ) if $srv_id2;
        }
        else
        {
        }
     }
     else
     {
         if($server->{srv_encode})
         {
             AddEncodeQueue( $file, $utype );
         }
         elsif($server->{srv_type} eq 'UPLOADER' || $server->{srv_type} eq 'STORAGE')
         {
            my $srv_id2 = findServerEncoder();

            $db->Exec("INSERT IGNORE INTO QueueTransfer
                       SET file_real_id=?, 
                           file_real=?, 
                           file_id=?,
                           premium=?, 
                           srv_id1=?,
                           srv_id2=?,
                           created=NOW()", $file->{file_real_id}, 
                                           $file->{file_real}, 
                                           $file->{file_id}, 
                                           $prem, 
                                           $file->{srv_id},
                                           $srv_id2
                                            ) if $srv_id2;
         }
         else
         {

         }
     }
     
   }

   $db->Exec("UPDATE LOW_PRIORITY Servers 
              SET srv_files=srv_files+1, 
                  srv_disk=srv_disk+?, 
                  srv_last_upload=NOW() 
              WHERE srv_id=?", $size, $server->{srv_id} );
   
   $db->Exec("INSERT INTO Stats SET day=CURDATE(), uploads=1 ON DUPLICATE KEY UPDATE uploads=uploads+1");

   $size = sprintf("%.0f",$size/1024**2);
   $db->Exec("INSERT INTO Stats2
              SET usr_id=?, day=CURDATE(),
                  uploads=1, uploads_mb=?
              ON DUPLICATE KEY UPDATE
                  uploads=uploads+1, uploads_mb=uploads_mb+?
             ",$usr_id,$size,$size);

   
   if($screenlist)
   {
	$edata->{screenlist}=1;
	$edata->{$_}=$c->{$_} for qw(m_x_width m_x_cols m_x_rows m_x_logo m_x_th_width m_x_th_height);
   }
   
   $edata->{disk_id}=$f->{disk_id};
   my $extra_data = join "\n", map{"$_=$edata->{$_}"} sort keys %$edata;

   return sendBack("$file_id:$code:$real:$utype:OK\n$extra_data");
}

sub findServerToTransfer
{
    my ($file) = @_;
    my $filter_prem = $file->{premium} ? "AND srv_allow_premium=1" : "AND srv_allow_regular=1";
    my $filter_load = $c->{overload_no_transfer} ? "AND host_out <= host_net_speed*0.9" : "";

    my $srv_id21 = $db->SelectOne("SELECT s.srv_id 
                                  FROM Servers s, Hosts h
                                  WHERE srv_type='STORAGE'
                                  AND srv_status<>'OFF'
                                  AND srv_status<>'READONLY2'
                                  AND srv_disk<srv_disk_max*0.95
                                  AND s.host_id=h.host_id
                                  AND srv_users_only LIKE '%,$file->{usr_id},%'
                                  $filter_prem
                                  $filter_load
                                  ORDER BY RAND()
                                  LIMIT 1");
    return $srv_id21 if $srv_id21;

    my $srv_id2 = $db->SelectOne("SELECT s.srv_id 
                                  FROM Servers s, Hosts h
                                  WHERE srv_type='STORAGE'
                                  AND srv_status<>'OFF'
                                  AND srv_status<>'READONLY2'
                                  AND srv_name NOT LIKE '%cold%'
                                  AND srv_disk<srv_disk_max*0.95
                                  AND s.host_id=h.host_id
                                  $filter_prem
                                  $filter_load
                                  ORDER BY RAND()
                                  LIMIT 1");
    return $srv_id2;
}

sub findServerEncoder
{
   my $srv_ids2 = $db->SelectARef("SELECT srv_id 
                                 FROM Servers 
                                 WHERE srv_type='ENCODER'
                                 AND srv_status<>'OFF'
                                 AND srv_status<>'READONLY2'
                                 AND srv_disk<srv_disk_max*0.95
                                 ORDER BY RAND()
                                 ");

   if($#$srv_ids2==-1)
   {
      $srv_ids2 = $db->SelectARef("SELECT srv_id 
                                 FROM Servers 
                                 WHERE srv_type='STORAGE'
                                 AND srv_encode=1
                                 AND srv_status<>'OFF'
                                 AND srv_status<>'READONLY2'
                                 AND srv_disk<srv_disk_max*0.96
                                 ORDER BY RAND()
                                 ");
   }

   if($#$srv_ids2==-1)
   {
      $srv_ids2 = $db->SelectARef("SELECT srv_id 
                                 FROM Servers 
                                 WHERE srv_type='STORAGE'
                                 AND srv_encode=1
                                 AND srv_status<>'OFF'
                                 AND srv_status<>'READONLY2'
                                 AND srv_disk<srv_disk_max*0.96
                                 ORDER BY RAND()
                                 ");
   }

   return 0 if $#$srv_ids2==-1;
   my $ids = join ',', map{$_->{srv_id}} @$srv_ids2;

   my $idi2 = $db->SelectARef("SELECT q.srv_id, SUM(f.file_length * ABS(100-q.progress)/100 * (CASE quality  WHEN 'n' THEN 1  WHEN 'h' THEN 2  WHEN 'l' THEN 0.5  WHEN 'p' THEN 0.1 ELSE 2.5 END)) as ss
                               FROM QueueEncoding q, Files f
                               WHERE q.srv_id IN ($ids)
                               AND q.file_id = f.file_id
                               AND q.error=''
                               GROUP BY srv_id
                               ORDER BY ss
                              ");
   my $idt2 = $db->SelectARef("SELECT q.srv_id2, SUM(f.file_length) as ss
                               FROM QueueTransfer q, Files f
                               WHERE q.srv_id2 IN ($ids)
                               AND q.file_id = f.file_id
                               AND q.status='PENDING'
                               GROUP BY srv_id2
                               ORDER BY ss
                              ");
   my $ht;
   $ht->{$_->{srv_id2}} = $_->{ss} for @$idt2;

   my $hh;
   $hh->{$_->{srv_id}} = $_->{ss} for @$idi2;

   for(@$srv_ids2)
   {
      $_->{ss} = $hh->{$_->{srv_id}} + $ht->{$_->{srv_id}};
   }

   my @idsort = sort{$a->{ss} <=> $b->{ss}} @$srv_ids2;

   return $idsort[0]->{srv_id};
}

sub AddEncodeQueue
{
	my ($file, $utype) = @_;

	my ($file_real_id, $file_real, $file_id, $srv_id) = ($file->{file_real_id},$file->{file_real},$file->{file_id},$file->{srv_id});

	require XUtils;
	my $vi = XUtils::vInfo($file,'o');

	my $audio_codec_pass=1 if $vi->{vid_audio_codec} eq 'AAC';
	my $video_codec_pass=1 if $vi->{vid_codec} eq 'H264';
	my $container_pass=1 if lc($vi->{vid_container}) eq 'mp4';

	my ($allow, $width, $height, $transcode, $extra, @added);

   if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
      $c->{quality_letters} = ["l"];
   }

	for my $q (@{$c->{quality_letters}})
	{
      # Check if the file has an allowed audio extension and set $allow->{$q} accordingly
      if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
         # Assuming vid_encode_l is a property in $c, replace it with the actual logic you need
         $c->{"vid_encode_l"}=1;
         $allow->{$q} = $c->{"vid_encode_l"}; 
      } else {
         # Existing logic for setting $allow->{$q}
         $allow->{$q} = $c->{"vid_encode_$q"} && $c->{"vid_enc_$utype\_$q"};
      }
		next unless $allow->{$q};
		($width->{$q}, $height->{$q}) = $c->{"vid_resize_$q"}=~/^(\d*)x(\d*)$/;
		if( $video_codec_pass && $vi->{vid_bitrate} && $c->{"vid_transcode_max_bitrate_$q"} && $vi->{vid_bitrate}<=$c->{"vid_transcode_max_bitrate_$q"})
    	{
    		$transcode->{$q} = 1;
    	}
    	if($audio_codec_pass && $vi->{vid_audio_bitrate} && $c->{"vid_transcode_max_abitrate_$q"} && $vi->{vid_audio_bitrate}<=$c->{"vid_transcode_max_abitrate_$q"})
    	{
    		$extra->{$q}.='|transcode_audio=1';
    	}
	}

    my $priority=0;
    $priority+=$c->{enc_queue_premium_priority} if $utype eq 'prem';
    $priority+=$c->{enc_queue_notmp4_priority} unless $file->{file_spec_o}=~/mp4$/i && $file->{file_spec_o}=~/h264/i && $file->{file_spec_o}=~/aac/i;

    if($c->{m_p} && $c->{m_p_parts})
    {
        push @added, addEncodeQueueDB($file, $priority, 'p');
    }

    unless($c->{m_h})
    {
        if($transcode->{n}){ $extra->{n}.='|transcode_video=1'; }
        push @added, addEncodeQueueDB($file, $priority, 'n', $extra->{n}) if $allow->{n};
    }
    else
    {
		my $transcode_added;
		my @qlist = reverse grep{$allow->{$_}} @{$c->{quality_letters}};
		for my $i (0..$#qlist)
		{
			my $q = $qlist[$i];
			my $ql = $i<$#qlist ? $qlist[$i+1] : '';
			my $pass1 = (($width->{$q} && $vi->{vid_width}>=$width->{$q})	|| ($height->{$q} && $vi->{vid_height}>=$height->{$q})) ? 1 : 0;
			$pass1=1 if $i==$#qlist;
			my $pass2 = $ql && (($width->{$ql} && $vi->{vid_width}>=$width->{$ql}*1.2) || ($height->{$ql} && $vi->{vid_height}>=$height->{$ql}*1.2)) ? 1 : 0;
			if($pass1 || $pass2){
				if($transcode->{$q} && !$transcode_added){ $extra->{$q}.='|transcode_video=1'; $transcode_added=1; }
				push @added, addEncodeQueueDB($file, $priority, $q, $extra->{$q});
			}
		}
    }

    $ses->logFile( $file->{file_real}, "Added to Encode on srv_id=$file->{srv_id} Q=".join(',', @added) );
}

sub addEncodeQueueDB
{
	my ($file, $priority, $quality, $extra) = @_;


    if (($c->{audio_extensions} || $c->{video_extensions}) && $file->{file_name} !~ /\.($c->{audio_extensions}|$c->{video_extensions})$/i){
        return;
    }   

	$priority+=$c->{"enc_priority_$quality"};
	$priority+=$c->{enc_queue_transcode_priority} if $extra=~/transcode_video/i;

	$extra .= "|$f->{effects}" if $f->{effects};

	$db->Exec("INSERT IGNORE INTO QueueEncoding
				SET file_real_id=?, 
					file_real=?, 
					file_id=?,
					host_id=?,
					srv_id=?,
					usr_id=?,
					priority=?, 
					quality=?,
					extra=?,
					created=NOW()", 
				$file->{file_real_id},
				$file->{file_real},
				$file->{file_id},
				$file->{host_id},
				$file->{srv_id},
				$file->{usr_id}||0,
				$priority,
				$quality,
				$extra,
				);
	return $quality;
}

sub QueueEncNext
{
   print"Content-type:text/html\n\n";
   my $IP = $ses->getIP;
   my $filter = $f->{host_id}=~/^\d+$/ ? "host_id='$f->{host_id}'" : "srv_ip='$IP'";
   my $list = $db->SelectARefCached("SELECT srv_id FROM Servers WHERE $filter");
   my $servers = join ',', map{$_->{srv_id}} @$list;
   return unless $servers;

   my $queue_ids = $db->master()->SelectARef("SELECT file_real_id FROM QueueTransfer WHERE status='MOVING' AND srv_id1 IN ($servers)");
   my $active_ids = join(',', map{$_->{file_real_id}} @$queue_ids) || 0;
   my $not_transferring_now="AND q.file_real_id NOT IN ($active_ids)" if $active_ids;

   my $per_user_limit;
   if($c->{fair_encoding_slots})
   {
     my $usersall = $db->SelectOne("SELECT COUNT(DISTINCT usr_id) FROM QueueEncoding WHERE srv_id IN ($servers) AND status='PENDING'");

     my $users = $db->SelectARef("SELECT usr_id, COUNT(*) as x
                                  FROM QueueEncoding 
                                  WHERE srv_id IN ($servers) 
                                  AND status='ENCODING' 
                                  AND error='' 
                                  AND updated > NOW()-INTERVAL 30 SECOND
                                  GROUP BY usr_id");
     
     if($usersall>1 && $#$users>-1)
     {
        my $host_max_enc = $db->SelectOneCached("SELECT host_max_enc FROM Hosts WHERE host_id=?",$f->{host_id});
        my $limit = int $host_max_enc/$usersall;
        my @ulimit;
        for(@$users)
        {
          push @ulimit, $_->{usr_id} if $_->{x}>=$limit;
        }
        $per_user_limit = "AND usr_id NOT IN (".join(',',@ulimit).")" if @ulimit;
     }
   }

   my $order = $c->{enc_priority_time} ? "created, priority DESC" : "priority DESC, created";

   my $next = $db->master()->SelectRow("SELECT *
                              FROM QueueEncoding q
                              WHERE srv_id IN ($servers) 
                              AND status='PENDING' 
                              AND q.created < NOW()-INTERVAL 1 SECOND
                              $not_transferring_now
                              $per_user_limit
                              ORDER BY $order
                              LIMIT 1");
   
   return unless $next;

   $db->Exec("UPDATE QueueEncoding SET status='ENCODING', started=NOW(), updated=NOW() WHERE file_real_id=? AND quality=?",$next->{file_real_id},$next->{quality});
   
   require JSON;
   if($next->{file_real} eq 'RESTART')
   {
      $db->Exec("DELETE FROM QueueEncoding WHERE file_real_id=? AND srv_id=?",$next->{file_real_id},$next->{srv_id});
      print JSON::encode_json( { file_real=>$next->{file_real} } );
      return;
   }
   my $disk_id = $db->SelectOneCached("SELECT disk_id FROM Servers WHERE srv_id=?",$next->{srv_id});

   my $settings;
   my @sett = qw(vid_resize
                 vid_quality_mode
                 vid_quality
                 vid_bitrate
                 vid_audio_bitrate
                 vid_audio_rate
                 vid_audio_channels
                 vid_preset
                 vid_fps
                 vid_crf_bitrate_max
                 vid_mobile_support);
   for(@sett)
   {
   		$settings->{$_} = $c->{"$_\_$next->{quality}"} if $_ && $c->{"$_\_$next->{quality}"};
   }
   $settings->{$_} = $c->{$_} for 
   	qw( vid_resize_method 
   		srt_burn
   		srt_burn_font
		srt_burn_size
		srt_burn_margin
		srt_burn_color
		srt_burn_coloroutline
		srt_burn_blackbox
		max_fps_limit
		multi_audio_on
		default_audio_lang
		srt_burn_default_language
		turbo_boost
		);
   if($next->{quality} eq 'p')
   {
      $settings->{$_} = $c->{"$_\_$c->{m_p_source}"} for @sett;
      $settings->{$_} = $c->{$_} for qw(m_p_parts m_p_length m_p_source);
   }
   for(split(/\|/,$next->{extra}))
   {
      /^(.+?)=(.+)$/;
      $settings->{$1} = $2 if $1;
   }
   delete @{$settings}{'multi_audio_on','default_audio_lang'} unless $c->{m_8};

   if($c->{m_v})
   {
       my $file = $db->SelectRow("SELECT * FROM Files WHERE file_id=?",$next->{file_id});
       my $user = $db->SelectRow("SELECT *, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec FROM Users WHERE usr_id=?",$file->{usr_id});
       my $usr_id_dat = $c->{m_v_users} eq 'admin' ? $db->SelectOne("SELECT usr_id FROM Users WHERE usr_adm=1 LIMIT 1") : $file->{usr_id};
       my $stt = $db->SelectARefCached("SELECT * FROM UserData WHERE usr_id=?",$usr_id_dat);
       my $dat;
       $dat->{$_->{name}} = $_->{value} for @$stt;

       $settings->{usr_id} = $usr_id_dat;

       my $pass=1 if $c->{m_v_users} eq 'admin';
       $pass=1 if $c->{m_v_users} eq 'premium' && $user->{exp_sec} > 0;
       $pass=1 if $c->{m_v_users} eq 'special' && $dat->{usr_watermark};
       $pass=1 if $c->{m_v_users} eq 'registered' && $usr_id_dat;
       $pass=0 unless $dat->{watermark_mode};
       if($pass)
       {
           if($dat->{watermark_mode} eq 'image')
           {
               my $wsize = -s "$c->{site_path}/upload-data/watermark_$usr_id_dat.png";
               if($wsize)
               {
                   $dat->{watermark_image_url} = "$c->{site_url}/upload-data/watermark_$usr_id_dat.png";
                   $dat->{watermark_image_size} = $wsize;
               }
           }
           $settings->{$_} = $dat->{$_} for grep {/^watermark_/} keys %$dat;
           $settings->{watermark_padding}||=0;
       }
   }

   if($c->{alt_preset_max_queues})
   {
      $settings->{vid_preset} = $c->{"vid_preset\_$next->{quality}\_alt"} if $db->SelectOne("SELECT COUNT(*) FROM QueueEncoding WHERE srv_id IN ($servers) AND status='PENDING'") > $c->{alt_preset_max_queues};
   }
   
   print JSON::encode_json( { disk_id       => $disk_id, 
                              file_real_id  => $next->{file_real_id}, 
                              file_real     => $next->{file_real}, 
                              type          => $next->{quality}, 
                              settings      => $settings } );
}

sub QueueEncProgress
{
	$f->{progress}=100 if $f->{progress}>100;
	$db->Exec("UPDATE QueueEncoding SET progress=?, fps=?, updated=NOW()
				WHERE file_real=? AND quality=?",$f->{progress},$f->{fps},$f->{file_real},$f->{quality}) if $f->{file_real};
	return sendBack("OK");
}

sub QueueEncDone
{
   my $file = $db->SelectRow("SELECT * FROM Files f, Servers s WHERE f.file_real=? AND f.srv_id=s.srv_id ORDER BY file_id LIMIT 1",$f->{file_real});
   print("Content-type:text/html\n\nError: file not found in db"),return unless $file;
   print("Content-type:text/html\n\nError: invalid quality"),return unless $f->{quality}=~/^\w$/;

   my $size_field = "file_size_$f->{quality}";
   $file->{$size_field} = $f->{file_size};
   $file->{"file_spec_$f->{quality}"} =  $f->{file_spec};
   my $usersize = $f->{file_size};
   my $new_length=",file_length=$f->{length_new}" if $f->{length_new};
   $db->Exec("UPDATE Files 
              SET $size_field=?,
                  file_spec_$f->{quality}=?
                  $new_length
              WHERE file_real=?",$f->{file_size},
                                 $f->{file_spec},
                                 $f->{file_real});

   my $eq = $db->SelectRow("SELECT * FROM QueueEncoding WHERE file_real=? AND quality=?",$f->{file_real},$f->{quality});
   $file->{premium} = $eq->{premium};

   $db->Exec("DELETE FROM QueueEncoding WHERE file_real=? AND quality=?",$f->{file_real},$f->{quality});

   my $other_qualities = $db->SelectOne("SELECT COUNT(*) FROM QueueEncoding WHERE file_real=?",$f->{file_real});
   if(!$other_qualities)
   {
      my $keep_orig = $c->{vid_keep_orig};

   # Check if the file is an audio file
   if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
      $keep_orig = 1;  # Always keep original for audio files
   } else {
      # Your existing logic for non-audio files
      require XUtils;
      my $info_orig = XUtils::vInfo($file,'o');
      my $bestq;
      for (@{$c->{quality_letters}}) { $bestq ||= $_ if $file->{"file_size_$_"}; }
      my $info_best = XUtils::vInfo($file, $bestq);

      $keep_orig = 0 if $info_orig->{vid_height} <= $info_best->{vid_height};

      $keep_orig = 0 if $c->{vid_keep_orig_playable} && !($file->{file_spec_o} =~ /mp4$/i && $file->{file_spec_o} =~ /h264/i && $file->{file_spec_o} =~ /aac/i);
   }

	unless($keep_orig)
	{
		$ses->DeleteFileQuality( $file, 'o', 3 );
		$db->Exec("UPDATE Files SET file_size_o=0, file_spec_o='' WHERE file_real=?",$file->{file_real});
		$usersize-=$file->{file_size_o};
      }

      if($file->{srv_type}=~/^(UPLOADER|ENCODER)$/i)
      {
          my $srv_id2 = findServerToTransfer($file);

          $db->Exec("INSERT IGNORE INTO QueueTransfer
                     SET file_real_id=?, 
                         file_real=?, 
                         file_id=?,
                         premium=?, 
                         srv_id1=?,
                         srv_id2=?,
                         created=NOW()", 
                         $file->{file_real_id}||$file->{file_id}, 
                         $file->{file_real}, 
                         $file->{file_id}, 
                         $eq->{premium}, 
                         $file->{srv_id},
                         $srv_id2
                   ) if $srv_id2;
      }
   }

   $db->Exec("UPDATE Users SET usr_disk_used=usr_disk_used+? WHERE usr_id=?", int($usersize/1024), $file->{usr_id} );

   $db->PurgeCache("filedl$file->{file_code}");
   $db->PurgeCache("filedl$file->{file_real}") if $file->{file_code} ne $file->{file_real};
   $db->PurgeCache("enc$file->{file_real_id}");

   return sendBack("OK");
}

sub QueueEncError
{
   $db->Exec("UPDATE QueueEncoding SET status='ERROR', error=?, fps=0 WHERE file_real_id=?",$f->{error},$f->{file_real_id}) if $f->{file_real_id};
   return sendBack("OK");
}

sub QueueTransferNext
{
	print"Content-type:text/html\n\n";
	my $IP = $ses->getIP;
	my $filter = $f->{host_id}=~/^\d+$/ ? "host_id='$f->{host_id}'" : "srv_ip='$IP'";
	my $list = $db->SelectARef("SELECT srv_id FROM Servers 
								WHERE $filter
								AND (srv_status<>'READONLY2' OR srv_ssd=1)
								AND srv_status<>'OFF'
								AND srv_disk<srv_disk_max*0.95");
	my $servers = join ',', map{$_->{srv_id}} @$list;
	return unless $servers;

	my $active_list;
	my $active_list2;
	if($c->{optimize_hdd_perfomance})
	{
		my $active = $db->SelectARef("SELECT * FROM QueueTransfer
		                             WHERE status='MOVING'
		                             AND UNIX_TIMESTAMP()-UNIX_TIMESTAMP(updated) < 60");
		$active_list = join ',', map{$_->{srv_id2}} @$active;
		$active_list2 = join ',', map{$_->{file_real_id}} @$active;
	}
	$active_list||=0;
	$active_list2||=0;

	my $queue_ids = $db->SelectARef("SELECT file_real_id FROM QueueEncoding WHERE status='ENCODING'");
	my $active_ids = join(',', map{$_->{file_real_id}} @$queue_ids) || 0;

	my $next = $db->master()->SelectRow("SELECT * 
								FROM QueueTransfer
								WHERE srv_id2 IN ($servers) 
								AND status='PENDING' 
								AND srv_id2 NOT IN ($active_list)
								AND file_real_id NOT IN ($active_ids)
								AND file_real_id NOT IN ($active_list2)
								ORDER BY premium DESC, created 
								LIMIT 1");
	return unless $next;
	$db->Exec("UPDATE QueueTransfer SET status='MOVING', started=NOW() WHERE file_real_id=? AND srv_id2=? LIMIT 1",$next->{file_real_id},$next->{srv_id2});

	my $srv1 = $db->SelectRow("SELECT * FROM Servers WHERE srv_id=?",$next->{srv_id1});
	my $srv2 = $db->SelectRow("SELECT * FROM Servers s, Hosts h WHERE s.srv_id=? AND s.host_id=h.host_id",$next->{srv_id2});

	my $file = $db->SelectRow("SELECT * 
								FROM Files f, Servers s
								WHERE f.file_id=? 
								AND f.srv_id=s.srv_id",$next->{file_id});

	$file->{host_transfer_speed} = $srv2->{host_transfer_speed};

	$ses->{transfer_speed} = $srv2->{host_transfer_speed} || $c->{server_transfer_speed} || 25000;

	my @links;
	$ses->{no_ip_check}=1;
	for my $q (@{$c->{quality_letters}},'o','p')
	{
		push @links, 'ENC|'.$ses->genDirectLink( $file, $q, "$file->{file_real}_$q" ).'|'.$file->{"file_size_$q"} if $file->{"file_size_$q"};
	}

	my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
	for(split(/\|/, $file->{file_captions}))
	{
		push @links, "VTT|$file->{srv_htdocs_url}/vtt/$file->{disk_id}/$dx/$file->{file_code}_$_";
	}
	my $clones = $db->SelectARef("SELECT * FROM Files WHERE file_real=? AND file_id<>? AND file_captions<>''", $file->{file_real}, $file->{file_id} );
	for my $ff (@$clones)
	{
		for(split(/\|/, $ff->{file_captions}))
		{
			push @links, "VTT=$file->{srv_htdocs_url}/vtt/$file->{disk_id}/$dx/$ff->{file_code}_$_";
		}
	}

	push @links, map{"IMG|$_"} @{$ses->genThumbURLs($file,{noproxy=>1})};

	print"$srv2->{disk_id}:$next->{file_real_id}:$next->{file_real}\n".join("\n",@links);
}

sub QueueTransferProgress
{
   $f->{speed}=65535 if $f->{speed}>65535;
   $db->Exec("UPDATE QueueTransfer SET transferred=?,speed=? WHERE file_real=? LIMIT 1",$f->{transferred},$f->{speed},$f->{file_real});
   sendBack("OK");
}

sub QueueTransferError
{
    $db->Exec("UPDATE QueueTransfer 
               SET status='ERROR',
                   error=?,
                   speed=0,
                   transferred=0,
                   updated='0000-00-00 00:00:00'
               WHERE file_real=?",$f->{error},$f->{file_real});
    return sendBack("OK");
}

sub QueueTransferDone
{
   my $qq = $db->SelectRow("SELECT * FROM QueueTransfer WHERE file_real=?",$f->{file_real});
   return sendBack("OK=DONE") unless $qq;
   my $file = $db->SelectRow("SELECT * FROM Files WHERE file_real=? LIMIT 1",$qq->{file_real});

   $db->Exec("DELETE FROM QueueTransfer WHERE file_real=? AND srv_id2=? LIMIT 1",$qq->{file_real},$qq->{srv_id2});

   if($qq->{copy})
   {
     $db->Exec("UPDATE Files SET srv_id_copy=? WHERE file_real=? LIMIT 200",$qq->{srv_id2},$qq->{file_real});
     return sendBack("OK=OK");
   }

   $db->Exec("UPDATE Files SET srv_id=? WHERE file_real=?",$qq->{srv_id2},$qq->{file_real});
   $ses->logFile( $qq->{file_real}, "Transferred from $qq->{srv_id1} to $qq->{srv_id2}" );

   $file->{srv_id} = $qq->{srv_id2};
   $db->Exec("UPDATE QueueEncoding SET srv_id=? WHERE file_real=?",$qq->{srv_id2},$qq->{file_real});

   my $srv1 = $db->SelectRowCached("SELECT * FROM Servers WHERE srv_id=?",$qq->{srv_id1});
   my $srv2 = $db->SelectRowCached("SELECT * FROM Servers WHERE srv_id=?",$qq->{srv_id2});
   if($file->{file_size_o} && !($file->{file_size_x}+$file->{file_size_n}+$file->{file_size_h}+$file->{file_size_l}) && ($srv1->{srv_type} eq 'UPLOADER' || $srv2->{srv_type} eq 'ENCODER'))
   {
   	  $db->Exec("DELETE FROM QueueEncoding WHERE file_real=?",$f->{file_real});
      my $user = $db->SelectRow("SELECT *, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec
                                 FROM Users u 
                                 WHERE u.usr_id=?",$file->{usr_id});
      my $utype = $user ? ($user->{exp_sec}>0 ? 'prem' : 'reg') : 'anon';
      AddEncodeQueue( $file, $utype );
   }

   $file->{srv_id} = $qq->{srv_id1};
   $ses->DeleteFileQuality( $file, 0, 3 );

   $db->PurgeCache("filedl$file->{file_code}");
   $db->PurgeCache("filedl$file->{file_real}") if $file->{file_code} ne $file->{file_real};

   return sendBack("OK");
}

sub QueueURLNext
{
	print"Content-type:text/html\n\n";

	my $users_use = $db->SelectARef("SELECT usr_id, SUM(premium) as premium, COUNT(*) as x
									FROM QueueUpload
									WHERE status='WORKING'
									AND updated>NOW()-INTERVAL 30 MINUTE
									GROUP BY usr_id");
	my @usr_exclude;
	for(@$users_use)
	{
	  my $max = $_->{premium} ? $c->{queue_url_working_max_prem} : $c->{queue_url_working_max_reg};
	  push @usr_exclude, $_->{usr_id} if $_->{x}>=$max;
	}
	my $exclude_usr_ids = join ',', @usr_exclude;
	$exclude_usr_ids||=0;

	my $next = $db->master()->SelectRow("SELECT *,INET_NTOA(ip) as ip 
								FROM QueueUpload 
								WHERE status='PENDING' 
								AND usr_id NOT IN ($exclude_usr_ids)
								ORDER BY premium DESC, created 
								LIMIT 1");
	return unless $next;

	my $active_list;
	if($c->{optimize_hdd_perfomance})
	{
		my $active = $db->master()->SelectARef("SELECT srv_id FROM QueueUpload
										WHERE status='WORKING'
										AND UNIX_TIMESTAMP()-UNIX_TIMESTAMP(updated) < 60");
		$active_list = join ',', map{$_->{srv_id}} @$active;
	}
	$active_list||=0;
	my $IP = $ses->getIP;
	my $filter_host = $f->{host_id}=~/^\d+$/ ? "h.host_id='$f->{host_id}'" : "h.host_ip='$IP'";
	my $filter_load = $c->{overload_no_upload} ? "AND host_out <= host_net_speed*0.9" : "";
	my $filter_srv = $next->{srv_id} ? "AND s.srv_id=$next->{srv_id}" : "";
	my $server = $db->master()->SelectRow("SELECT * 
								FROM Servers s, Hosts h
								WHERE $filter_host
								$filter_load
								$filter_srv
								AND srv_status='ON'
								AND s.host_id=h.host_id
								AND srv_id NOT IN ($active_list)
								AND srv_disk<srv_disk_max*0.95
								AND srv_users_only LIKE '%,$next->{usr_id},%'
								ORDER BY RAND()
								LIMIT 1");

	$server ||= $db->master()->SelectRow("SELECT * 
   								FROM Servers s, Hosts h
								WHERE $filter_host
								$filter_load
								$filter_srv
								AND srv_status='ON'
								AND s.host_id=h.host_id
								AND srv_id NOT IN ($active_list)
								AND srv_disk<srv_disk_max*0.95
								AND srv_users_only=''
								ORDER BY RAND()
								LIMIT 1");
	return unless $server;

	$db->Exec("UPDATE QueueUpload SET status='WORKING', srv_id=?, started=NOW() WHERE id=?",$server->{srv_id},$next->{id});

	if($next->{url}=~/drive.google.com\/file\/d\/(.+?)\//i)
	{
		$next->{url}="https://www.googleapis.com/drive/v3/files/$1?key=$c->{google_drive_api_key}&alt=media";
	}

	print"$next->{id}\n$next->{usr_id}\n$next->{ip}\n$server->{srv_id}\n$server->{disk_id}\n$next->{url}\n";
}

sub QueueURLProgress
{
   $f->{speed}=65535 if $f->{speed}>65535;
   $db->Exec("UPDATE QueueUpload SET updated=NOW(), size_full=?, size_dl=?, speed=? WHERE id=?",$f->{size_full},$f->{size_dl},$f->{speed},$f->{id});
   return sendBack("OK");
}

sub QueueURLDone
{
   $db->Exec("DELETE FROM QueueUpload WHERE id=?",$f->{id});
   return sendBack("OK");
}

sub QueueURLError
{
   $f->{error}=~s/0:0:0://;
   $db->Exec("UPDATE QueueUpload SET status='ERROR', error=? WHERE id=?",$f->{error},$f->{id});
   return sendBack("OK");
}

sub randchar
{ 
   my @range = ('0'..'9','a'..'z');
   my $x = int scalar @range;
   join '', map $range[rand $x], 1..shift||1;
}

sub logg
{
   my $msg = shift;
   return unless $c->{fs_logs_on};
   open(FILE,">>logs/fs.log")||return;
   print FILE "$msg\n";
   close FILE;
}

sub ATop
{
   my ($avg,$in,$out,$conn) = split(/:/,$f->{atop});
   $f->{host_id} ||= $db->SelectOne("SELECT host_id FROM Hosts WHERE host_ip=?",$ses->getIP);
   $db->Exec("UPDATE Hosts SET host_avg=?, host_in=?, host_out=?, host_connections=?, host_updated=NOW() WHERE host_id=?",$avg,$in,$out,$conn,$f->{host_id});

   $f->{df}=~s/\r//g;
   $f->{io}=~s/\r//g;

   for(split(/\n/,$f->{df}))
   {
      my ($dev_df,$used) = split(/:/,$_);
      next unless $dev_df;
      $db->Exec("UPDATE LOW_PRIORITY Servers SET srv_disk=? WHERE host_id=? AND disk_dev_df=?", $used*1024, $f->{host_id}, $dev_df ) if $used=~/^\d+$/;
   }

   for(split(/\n/,$f->{io}))
   {
      my ($dev_io,$util) = split(/:/,$_);
      next unless $dev_io;
      $db->Exec("UPDATE LOW_PRIORITY Servers SET disk_util=? WHERE host_id=? AND disk_dev_io=?", sprintf("%.0f",$util), $f->{host_id}, $dev_io );
   }

   return sendBack("OK");
}

sub DeleteFileDB
{
   $db->Exec("DELETE FROM Files WHERE file_id=? AND file_created>NOW()-INTERVAL 3 MINUTE",$f->{file_id});
   $db->Exec("DELETE FROM QueueEncoding WHERE file_real_id=?",$f->{file_id});
   $db->Exec("DELETE FROM QueueTransfer WHERE file_real_id=?",$f->{file_id});
   return sendBack("OK");
}

sub NextFTPServer
{
    my $srv = $db->SelectRow("SELECT * FROM Servers 
                              WHERE host_id=?
                              AND srv_disk <= srv_disk_max*0.99
                              AND srv_status IN ('ON','READONLY')
                              AND srv_ssd<>1
                              ORDER BY RAND()
                             ",$f->{host_id});

    return sendBack("ERROR:No servers available") unless $srv;
    return sendBack("OK:$srv->{srv_id}:$srv->{disk_id}");
}

sub UpdateFileData
{
    my @fields = qw(file_size_o
                    file_size_n
                    file_size_h
                    file_size_x
                    file_size_l
                    file_size_p
                    file_spec_o
                    file_spec_n
                    file_spec_h
                    file_spec_x
                    file_spec_l
                    file_spec_p
                    file_length
                  );
    delete $f->{file_length} unless $f->{file_length};

    my (@keys, @values);
    for(@fields)
    {
        if (defined $f->{$_})
        {
            push @keys, "$_ = ?";
            
            my $value = $f->{$_};
               $value =~ s/;//g;
               $value =~ s/--//g;
            next if $value=~/[\'\`]+/;
            push @values, $value;
        }
    }
    push @values, $f->{file_code};
    $db->Exec("UPDATE Files SET ".join(',',@keys)." WHERE file_real=?", @values) if @keys;

    return sendBack("OK");
}

sub sendBack
{
    print"Content-type:text/html\n\n".shift;
}

sub Streams
{
	print"Content-type:text/html\n\n";
	my $stream = $db->SelectRow("SELECT * FROM Streams WHERE stream_code=?",$f->{name});
	print("Stream not found"),return unless $stream;
	print("Wrong stream key"),return unless $stream->{stream_key} eq $f->{key};

	if($f->{call} eq 'publish' && $f->{name})
	{
		print("Max streams limit reached"),return 
			if $c->{m_q_max_streams_live} && $db->SelectOne("SELECT COUNT(*) FROM Streams WHERE usr_id=? AND stream_live=1",$stream->{usr_id}) >= $c->{m_q_max_streams_live};
		$db->Exec("UPDATE Streams SET stream_live=1, started=NOW(), updated=NOW() WHERE stream_id=?",$stream->{stream_id});
		open FILE, ">$c->{site_path}/streams/$stream->{stream_code}.html";
		print FILE qq|<html><meta http-equiv="refresh" content="0; url=/streamplay/$stream->{stream_code}"><body>Redirecting to player...</body></html>|;
		close FILE;
		print"OK";
	}
	elsif($f->{call} eq 'publish_done' && $f->{name})
	{
		$db->Exec("UPDATE Streams SET stream_live=0 WHERE stream_code=?",$f->{name});
		unlink("$c->{site_path}/streams/$f->{name}.html");
		print"OK:$stream->{stream_record}";
	}
	elsif($f->{call} eq 'record_done' && $f->{name})
	{
		$stream->{stream_record}=0 unless $c->{m_q_allow_recording};
		print"OK:$stream->{stream_record}";
	}
	elsif($f->{call} eq 'update_publish' && $f->{name})
	{
		$db->Exec("UPDATE Streams SET updated=NOW() WHERE stream_code=?",$f->{name});
		print"OK";
	}
}

sub FTPCurrent
{
	print"Content-type:text/html\n\n";
	$db->Exec("UPDATE Hosts SET host_ftp_current=? WHERE host_id=?", $f->{data}, $f->{host_id} ) if $c->{m_f_track_current};
	print"OK";
}

sub DeleteDiskNext
{
	my $list = $db->SelectARef("SELECT * 
								FROM QueueDelete d, Servers s
								WHERE d.del_time<NOW()
								AND d.srv_id = s.srv_id
								AND s.host_id=?
								ORDER BY priority DESC, del_time
								LIMIT 5
								",$f->{host_id});

	for(@$list)
	{
		$db->Exec("DELETE FROM QueueDelete 
					WHERE file_real_id=? 
					AND quality=? 
					AND srv_id=? 
					LIMIT 1", 
					$_->{file_real_id}, 
					$_->{quality}, 
					$_->{srv_id});
	}

	require JSON;
	my $jsout=JSON::encode_json({list=>$list});

	return sendBack("$jsout");
}

sub SaveVTTNext
{
	my $rids = $db->SelectARef("SELECT DISTINCT file_real_id 
								FROM QueueVTT 
								WHERE host_id=?
								ORDER BY file_real_id 
								LIMIT 5",$f->{host_id});
	return sendBack('{"list":[]}') unless $#$rids>-1;
	my $real_ids = join ',', map{$_->{file_real_id}} @$rids;

	my $list = $db->SelectARef("SELECT * 
								FROM QueueVTT
								WHERE host_id=?
								AND file_real_id IN ($real_ids)
								",$f->{host_id});

	$db->Exec("DELETE 
				FROM QueueVTT
				WHERE host_id=?
				AND file_real_id IN ($real_ids)
				",$f->{host_id});

	my $hf;
	for(@$list)
	{
		push @{$hf->{$_->{file_code}}}, $_->{language} unless $_->{no_db_update};
	}
	
	for my $file_code (keys %$hf)
	{
		my $caps = join('|',@{$hf->{$file_code}});
		$db->Exec("UPDATE Files 
					SET file_captions = CASE WHEN LENGTH(file_captions)=0 THEN ? ELSE CONCAT(file_captions,'|',?) END 
					WHERE file_code=?", $caps, $caps, $file_code );
	}

	require JSON;
	my $jsout=JSON::encode_json({list=>$list});

	return sendBack("$jsout");
}

1;
