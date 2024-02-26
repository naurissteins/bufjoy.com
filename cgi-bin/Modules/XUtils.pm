package XUtils;
use strict;
use XFileConfig;


sub CheckAuth
{
  my ($ses, $sess_id) = @_;
  $sess_id ||= $ses->getCookie( $ses->{auth_cook} ) || $ses->f->{sess_id};
  my $f = $ses->f;
  my $db = $ses->db;
  return undef unless $sess_id;

  $ses->{user} = $db->SelectARefCachedKey("ses$sess_id", 180, "SELECT u.*, s.session_id,
                                        UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec,
                                        UNIX_TIMESTAMP()-UNIX_TIMESTAMP(last_time) as dtt
                                 FROM Users u, Sessions s 
                                 WHERE s.session_id=? 
                                 AND s.usr_id=u.usr_id",$sess_id)->[0];
  unless($ses->{user})
  {
     sleep 1;
     return undef;
  }
  if($ses->{user}->{usr_status} eq 'BANNED')
  {
     delete $ses->{user};
     $ses->{returning}=1;
     return $ses->message($ses->{lang}->{lng_login_your_account_banned});
  }
  if($ses->{user}->{dtt}>180)
  {
     $db->Exec("UPDATE Sessions SET last_time=NOW() WHERE session_id=?",$sess_id);
     $db->Exec("UPDATE Users SET usr_lastlogin=NOW(), usr_lastip=INET_ATON(?) WHERE usr_id=?", $ses->getIP, $ses->{user}->{usr_id} );
  }
  $ses->{user}->{premium}=1 if $ses->{user}->{exp_sec}>0;
  if($c->{email_validation_code} && $ses->{user}->{usr_login_code} && $ses->f->{op}!~/^(login_code|logout)$/)
  {
     $ses->{returning}=1;
     return $ses->PrintTemplate("login_code.html", %{$ses->{user}});
  }
  if($c->{m_d} && $ses->{user}->{usr_mod})
  {
      $ses->{lang}->{$_}=$c->{$_} for qw[m_d_f m_d_a m_d_c m_d_featured m_d_file_approve];
      $ses->{lang}->{usr_mod}=1;
  }
  if($c->{m_d} && $ses->{user}->{usr_notes}=~/LEGAL=\d+/i)
  {
      $ses->{lang}->{usr_legal}=1;
  }
  #$ses->setCookie( $ses->{auth_cook} , $sess_id );
  return $ses->{user};
}

sub addTagsToFile
{
    my ($db, $tags, $file_id) = @_;
    for my $tag (split(/\s*\,\s*/,$tags))
    {
       utf8::decode($tag);
       $tag=lc $tag;
       $tag=~s/[^\w\s\.\&]+//g;
       utf8::encode($tag);
       next if length($tag)<=2;
       my $tag_id = $db->SelectOne("SELECT tag_id FROM Tags WHERE tag_value=?",$tag);
       unless($tag_id)
       {
          $db->Exec("INSERT INTO Tags SET tag_value=?",$tag);
          $tag_id = $db->getLastInsertId;
       }
       $db->Exec("INSERT IGNORE INTO Tags2Files SET file_id=?, tag_id=?",$file_id,$tag_id);
    }
}

sub addExtraFileData
{
    my ($db,$f,$file_id) = @_;
      my $extra_fields;
      $extra_fields->{$_}=1 for split /\s*\,\s*/, $c->{file_data_fields};
      my %extra;
      $extra{$_}=$f->{"extra_$_"} for grep {$extra_fields->{$_}} map{s/^extra_//;$_} grep{/^extra_/} keys %$f;
      for my $kk (keys %extra)
      {
          $extra{$kk}=~s/^\s+//g;
          $extra{$kk}=~s/\s+$//g;
          $db->Exec("INSERT INTO FilesData SET file_id=?, name=?, value=?", $file_id, $kk, $extra{$kk} ) if $extra{$kk};
      }
}

sub vInfo
{
    my ($file,$mode) = @_;
    my $extra="_$mode";
    my $x={};
    $x->{file_size} = $file->{"file_size$extra"};
    return {} unless $x->{file_size};
    $x->{file_size_mb} = makeFileSize( $file->{"file_size$extra"} );
    return $x unless $file->{"file_spec$extra"};
    my @fields=qw(vid_length vid_width vid_height vid_bitrate vid_audio_bitrate vid_audio_rate vid_codec vid_audio_codec vid_fps vid_container);
    my @vinfo = split(/\|/, $file->{"file_spec$extra"} );
    $x->{$fields[$_]}=$vinfo[$_] for (0..$#fields);
    $x->{vid_codec}=~s/ffo//i;
    $x->{vid_codec}=~s/ff//i;
    $x->{vid_codec}=uc $x->{vid_codec};
    $x->{vid_audio_codec}=~s/faad/AAC/i;
    $x->{vid_audio_codec}=~s/ff//i;
    $x->{vid_audio_codec}=uc $x->{vid_audio_codec};
    $x->{vid_fps}=~s/\.000//;
    #$x->{vid_length2} = sprintf("%02d:%02d:%02d",int($x->{file_length}/3600),int(($x->{file_length}%3600)/60),$x->{file_length}%60);
    $x->{vid_length_txt} = sprintf("%02d:%02d:%02d",int($x->{vid_length}/3600),int(($x->{vid_length}%3600)/60),$x->{vid_length}%60);
    $x->{vid_length_txt}=~s/^00:(\d\d:\d\d)$/$1/;
    $x->{vid_container}||='mp4';
    return $x;
}

sub makeFileSize
{
   my ($size)=@_;
   return '' unless $size;
   return "$size B" if $size<=1024;
   return sprintf("%.0f KB",$size/1024) if $size<=1024*1024;
   return sprintf("%.01f MB",$size/1048576) if $size<=1024*1024*1024;
   return sprintf("%.01f GB",$size/1073741824);
}

sub getIPBlockedStatus
{
	my ($db,$name,$ip) = @_;
	return 0 unless $c->{m_7};
	return 0 unless $ip=~/^\d+.\d+.\d+.\d+$/;
	return 0 unless -e "$c->{cgi_path}/logs/$name.dat";
	unless($db->{$name} && $db->{$name}->{ips})
	{
		require Storable;
		eval { $db->{$name} = Storable::retrieve("$c->{cgi_path}/logs/$name.dat")||{}; };
		return unless $db->{$name} && $db->{$name}->{ips};
		return 0 if $db->{$name}->{exp} && $db->{$name}->{exp}<time;
	}
	
	if($db->{$name}->{hashdata})
	{
		require Socket;
		return $db->{$name}->{ips}->{Socket::inet_aton($ip)} || 0;
	}
	else
	{
		require SSIPLookup;
		return $db->{$name}->{ips}->lookup($ip) || 0;
	}
}

sub isBannedIP
{
	# 1.1.1.1,2.3.4.*
	my ($ip,$banned) = @_;
	$banned=~s/\,\s*/|/g;
	$banned=~s/\./\\./g;
	$banned=~s/\*/\\d+/g;
	return 1 if $ip=~/^($banned)$/i;
}
sub isBannedCountry
{
	# US|CA,UA
	my ($country,$banned) = @_;
	$banned=~s/\,\s*/|/g;
	return $1 if $country=~/^($banned)$/i;
}

1;
