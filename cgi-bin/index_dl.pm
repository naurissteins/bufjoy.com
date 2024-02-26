package index_dl;

use strict;
#use warnings;
use XFileConfig;
use Session;
use XUtils;
use HCE_MD5;
use CGI::Carp qw(fatalsToBrowser);

my ($ses,$f,$db,$ipt);

$c->{ip_not_allowed}=~s/\./\\./g;

my $hce = HCE_MD5->new($c->{dl_key},"XVideoSharing");

sub run
{
	my ($query,$dbc) = @_;

	$ses = Session->new($query,$dbc);
	$ses->{fast_cgi} = $c->{fast_cgi};

	if($c->{ip_not_allowed} && $ses->getIP=~/$c->{ip_not_allowed}/)
	{
	   return sendBack("Your IP was banned by administrator");
	}

	return sendBack($c->{maintenance_full_msg}||"The website is under maintenance.","Site maintenance") if $c->{maintenance_full};

    if($c->{banned_countries} && $ENV{HTTP_USER_AGENT} ne $c->{user_agent})
    {
        my $country = $ses->getMyCountry;
        return sendBack("Your country is not allowed on this site") if $country=~/^($c->{banned_countries})$/i;
    }

	$f = $ses->f;
	$f->{op}||='';

	return GetSlides() if $f->{op} eq 'get_slides';

	$db ||= $ses->db;

	XUtils::CheckAuth($ses);
	return if $ses->{returning};


   return $ses->message($ses->{error}) if $ses->{error};

   $ses->{utype} = $ses->getUser ? ($ses->getUser->{premium} ? 'prem' : 'reg') : 'anon';

   $c->{$_}=$c->{"$_\_$ses->{utype}"} for qw( download_countdown
                                              captcha
                                              ads
                                              bw_limit
                                              down_speed
                                              add_download_delay
                                              max_download_filesize
                                              video_embed
                                              file_dl_delay
                                              download
                                              download_orig
                                              pre_download
                                              max_watch_time
                                              video_time_limit
                                              time_slider
                                              video_player
                                              upload_enabled
                                              m_p_show
                                              m_q_streaming
                                              download_o
                                            );

   my $sub={
       download1		=> \&Download1,
       download_orig	=> \&DownloadOriginal,
       embed			=> \&Embed,
	   embed2			=> \&Embed2,
       x1				=> \&X1,
       enc_status		=> \&EncStatus,
       get_vid_versions	=> \&getVideoVersions,
       deurl			=> \&DeURL,
       view				=> \&View,
       view2			=> \&View2,
       #get_slides    => \&GetSlides,
       related			=> \&Related,
       pair				=> \&Pair,
       stream_page		=> \&StreamPage,
       stream_player	=> \&StreamPlayer,
       stream_ping		=> \&StreamPing,
       iproxy			=> \&IProxy,
       playerddl		=> \&PlayerDDL,
       download_versions=> \&DownloadOriginalVersions,
            }->{ $f->{op} };
   return &$sub if $sub;

   IndexPage();
}

###################################

sub X1
{
  return $ses->message("IP:".$ses->getIP);
}

sub IndexPage
{
    $ses->{expires}="+$c->{caching_expire}s" if $c->{caching_expire};
    $f->{op}='index';
    $ses->PrintTemplate("index_page.html",
                        index_featured_on    => $c->{index_featured_on},
                        index_most_viewed_on => $c->{index_most_viewed_on},
                        index_most_rated_on  => $c->{index_most_rated_on},
                        index_just_added_on  => $c->{index_just_added_on},
                        index_live_streams_on => $c->{index_live_streams_on},
                        'm_z'        => $c->{m_z},
                        'm_z_cols'   => $c->{m_z_cols},
                        'm_z_rows'   => $c->{m_z_rows},
                       );
}

sub Login
{
  ($f->{login}, $f->{password}) = split(':',$ses->decode_base64($ENV{HTTP_CGI_AUTHORIZATION}));
  $ses->{user} = $db->SelectRow("SELECT *, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec
                                 FROM Users
                                 WHERE usr_login=?
                                 AND usr_password=ENCODE(?,?)", $f->{login}, $f->{password}, $c->{pasword_salt} );
  unless($ses->{user})
  {
     $ses->{error}="Invalid user";
     return undef;
  }

  $ses->{user}->{premium}=1 if $ses->{user}->{exp_sec}>0;
  if($ses->{user}->{usr_status} eq 'PENDING')
  {
     delete $ses->{user};
     $ses->{error}="Account not confirmed";
     return;
  }
  if($ses->{user}->{usr_status} eq 'BANNED')
  {
     delete $ses->{user};
     $ses->{error}="Banned account";
     return;
  }
};

sub Download1Checks
{
   my ($file) = @_;

   $file->{message} = "$ses->{lang}->{lng_download_for_premium_users_only}<br><a href='$c->{site_url}/premium.html'>$ses->{lang}->{lng_download_upgrade_to_premium_now}</a>" if $file->{usr_premium_dl_only} && $ses->{utype} ne 'prem';

   if(!$c->{video_player})
   {
       my $link = $ses->getUser ? "$c->{site_url}/premium.html" : "$c->{site_url}/?op=registration";
       $file->{message} = "$ses->{lang}->{lng_download_cant_watch_free_account}<br><a href='$link'>$ses->{lang}->{lng_download_upgrade_your_account}</a> $ses->{lang}->{lng_download_to_watch_no_limits}";
   }

   if($file->{file_size_p} && $c->{m_p_show} && $c->{m_p})
   {
       #$file->{video_preview_url} = DownloadGenLink($file,"v.mp4",'p');
       $file->{preview}=1;
       $file->{preview_message} = "$ses->{lang}->{lng_download_can_watch_preview_only}<br><a href='$c->{site_url}/premium.html'>$ses->{lang}->{lng_download_upgrade_your_account}</a> $ses->{lang}->{lng_download_to_watch_no_limits}";
       $file->{file_title}.=" ($ses->{lang}->{lng_download_preview})";
   }

   if($file->{file_status} ne 'OK' && !($ses->getUser && $ses->getUser->{usr_adm}))
   {
       $file->{message} = $file->{file_status} eq 'PENDING' ? $ses->{lang}->{lng_download_file_is_pending} : $ses->{lang}->{lng_download_file_is_locked};
       $file->{no_dl_btn} = 1;
   }

   if($file->{file_premium_only} && $ses->{utype} ne 'prem')
   {
       $file->{message} = "$ses->{lang}->{lng_download_for_premium_users_only}<br><a href='$c->{site_url}/premium.html'>$ses->{lang}->{lng_download_upgrade_to_premium_now}</a>";
       $file->{no_dl_btn} = 1;
   }

   if($file->{cat_premium} && $ses->{utype} ne 'prem')
   {
       $file->{message} = "$ses->{lang}->{lng_download_for_premium_users_only}<br><br><a href='$c->{site_url}/premium.html'>$ses->{lang}->{lng_download_upgrade_to_premium_now}</a>";
       $file->{no_dl_btn} = 1;
   }

   if($c->{bad_referers} && $ENV{HTTP_REFERER})
   {
       $file->{message}="Video temporarily not available" if $ENV{HTTP_REFERER}=~/$c->{bad_referers}/i;
   }

   if($c->{bad_agents} && $ENV{HTTP_USER_AGENT})
   {
       $file->{message}="Video not available" if $ENV{HTTP_USER_AGENT}=~/$c->{bad_agents}/i;
   }

   return $file;
}

sub P2P_Logic
{
	my ($file) = @_;
	my (undef,undef,undef,$hh,undef,undef) = $ses->getTime;

	if($c->{p2p_on} && $c->{m_r})
	{
		my $p2p=1;
		$p2p=0 if $c->{p2p_min_views} && $file->{file_views} < $c->{p2p_min_views};
		$p2p=0 if $c->{p2p_min_host_out} && $file->{host_out} < $c->{p2p_min_host_out};
		$p2p=0 if $c->{p2p_only_srvname_with} && $file->{srv_name}!~/$c->{p2p_only_srvname_with}/i;
		$p2p=0 if $c->{p2p_min_views_30m} && $p2p && $db->SelectOne("SELECT COUNT(*) FROM Views WHERE file_id=? AND created>NOW()-INTERVAL 30 MINUTE",$file->{file_id}) < $c->{p2p_min_views_30m};
		$p2p=0 if $c->{p2p_hours} && $hh!~/^($c->{p2p_hours})$/;
		$file->{p2p} = $p2p;
	}
}

sub Download1
{
	return $ses->message($c->{maintenance_download_msg}||"Downloads are temporarily disabled due to site maintenance","Site maintenance") if $c->{maintenance_download};
	return $ses->message("Video pages disabled") if $c->{video_page_disabled};

	if($c->{m_7} && $c->{m_7_video_download1} && ($c->{m_7_video_noserver}||$c->{m_7_video_noproxy}||$c->{m_7_video_notor}))
	{
		my $is_server = XUtils::getIPBlockedStatus( $ses->db, 'ipserver', $ses->getIP ) if $c->{m_7_video_noserver};
		my $is_proxy  = XUtils::getIPBlockedStatus( $ses->db, 'ipproxy', $ses->getIP ) if $c->{m_7_video_noproxy} && !$is_server;
		my $is_tor    = XUtils::getIPBlockedStatus( $ses->db, 'iptor', $ses->getIP ) if $c->{m_7_video_notor} && !$is_server && !$is_proxy;
		my $is_black  = XUtils::getIPBlockedStatus( $ses->db, 'ipblack', $ses->getIP ) if !$is_server && !$is_proxy && !$is_tor;
		if( $is_server || $is_proxy || $is_tor || $is_black )
		{
			my $is_white = XUtils::getIPBlockedStatus( $ses->db, 'ipwhite', $ses->getIP );
			$db->Exec("INSERT INTO StatsMisc
						SET usr_id=0, day=CURDATE(), name='ipblock_blocked', value=1
						ON DUPLICATE KEY
						UPDATE value=value+1") if $c->{m_7_stats} && !$is_white;
			if($is_white)
			{
				# do nothing
				#return $ses->message('white');
			}
			elsif($c->{m_7_video_action} eq 'redirect')
			{
				return $ses->redirect($c->{site_url});
			}
			elsif($c->{m_7_video_action} eq 'message' && $c->{m_7_video_action_message_txt})
			{
				return $ses->message($c->{m_7_video_action_message_txt});
			}
			elsif($c->{m_7_video_action} eq 'badlink')
			{
				$ses->{badlink}=1;
			}
		}
	}

	if($c->{watch_require_recaptcha})
	{
		unless(checkRecaptchaHash())
		{
			return $ses->PrintTemplate("download1_recaptcha.html", id => $f->{id}, recaptcha => $ses->genRecaptcha('auto') );
		}
	}

	#$f->{referer}||= $ses->getCookie('referer') || $ENV{HTTP_REFERER};
	$f->{referer} = $ses->getDomain( $ENV{HTTP_REFERER} );

	if($c->{m_a} && $c->{m_a_hide_redirect} && $f->{id} && !$f->{hash})
	{
		$ses->setCookie('id',$f->{id},'+1m');
		$ses->setCookie('referer',$f->{referer},'+1m');
		my $code = $ses->randchar(13);
		return $ses->redirect("/$code.html");
	}

	$f->{id}||=$ses->getCookie('id');

	my $premium = $ses->getUser && $ses->getUser->{premium};

	my $file = $ses->getFileRecord2( $f->{id} );

	my $fname2 = lc $file->{file_name} if $file;
	$fname2=~s/\s/_/g;
	$fname2=~s/\.\w{2,5}$//;$fname2=~s/\.\w{2,5}$//;

	#return $ses->redirect("$c->{site_url}/?op=del_file&id=$f->{id}&del_id=$1") if $ENV{REQUEST_URI}=~/\?killcode=(\w+)$/i;
	#return $ses->message("No such file with this filename") if $file && $fname && $fname2 ne lc $fname;

	my $reason;
	unless($file)
	{
		$reason = $db->SelectRowCached(300,"SELECT * FROM DelReasons WHERE file_code=?",$f->{id});
		$db->Exec("UPDATE DelReasons SET last_access=NOW() WHERE file_code=?",$reason->{file_code}) if $reason;
	}

	my $fname=$file->{file_title} if $file;
	$fname=$reason->{file_name} if $reason;
	$fname=~s/[_\.-]+/ /g;
	$fname=~s/([a-z])([A-Z][a-z])/$1 $2/g;
	my @fn = grep{length($_)>2 && $_!~/(www|net|ddl)/i}split(/[\s\.]+/, $fname);
	$ses->{page_title} = $ses->{lang}->{lng_download_watch}." ".join(' ',@fn);
	$ses->{meta_descr} = $ses->{lang}->{lng_download_watch_video}." ".join(' ',@fn);
	$ses->{meta_keywords} = lc join(', ',@fn);

	#$file->{file_title_txt} = $ses->shortenString( $file->{file_title}||$file->{file_name}, 80 );

	return $ses->PrintTemplate("download1_deleted.html",%$reason) if $reason;
	return $ses->PrintTemplate("download1_no_file.html") unless $file;

	return $ses->message("Videos of this user were blocked") if $file->{usr_notes}=~/BLOCKVIDEOS/i;

	P2P_Logic($file) if $c->{p2p_on};

	return $ses->message("This server is in maintenance mode. Refresh this page in some minutes.") if $file->{srv_status} eq 'OFF';

	$ses->loadUserData($file);

	$file->{referer} = $f->{referer};

	return $ses->message($ses->{lang}->{lng_download_watch_embed_only}) if $file->{usr_embed_access_only};
	# if($file->{banned_countries})
	# {
	# 		my $country = $ses->getMyCountry;
	# 		return $ses->message("Video error: RC1$country"."RC") if $country=~/^($file->{banned_countries})$/i;
	# }
	return $ses->message("Video error: RC1".$ses->getMyCountry."RC") if $file->{banned_countries} && XUtils::isBannedCountry($ses->getMyCountry, $file->{banned_countries});
	return $ses->message("Video error: RI1RI") if $file->{banned_ips} && XUtils::isBannedIP($ses->getIP, $file->{banned_ips});

	$file->{file_title} ||= $fname2;

	$file->{download_link} = $ses->makeFileLink($file);

	if($f->{op} eq 'download1' && $c->{pre_download} && $f->{hash})
	{
		$f->{hash}='' unless $ses->HashCheck($f->{hash},$file->{file_id});
	}

	if($f->{op} eq 'download1' && $c->{pre_download} && !$f->{hash})
	{
	my $hash = $ses->HashSave($file->{file_id},$c->{download_countdown});
	return $ses->PrintTemplate("download0.html",
								%{$file},
								m_j_hide  => $c->{m_j_hide} && $c->{m_j},
								countdown => $c->{download_countdown},
								hash      => $hash,
								aff       => $file->{usr_id},
								referer   => $f->{referer} );
	}

	Download2('no_checks') if	$premium &&
								!$c->{captcha} &&
								!$c->{download_countdown} &&
								$ses->getUser->{usr_direct_downloads};

	my $category = $db->SelectRowCached(300,"SELECT * FROM Categories WHERE cat_id=?",$file->{cat_id}) if $file->{cat_id};
	$file->{category} = $file->{category2} = $category->{cat_name};
	$file->{category2} =~ s/\s+/+/g;
	$file->{cat_premium} = $category->{cat_premium};

	# If file is transfering
	$file->{transfer} = $db->SelectOne("SELECT s.srv_name FROM QueueTransfer q, Servers s WHERE q.file_real_id=? AND q.srv_id2=s.srv_id",$file->{file_real_id});

	# If not video or audio file
	$file->{not_video_audio} = ($c->{audio_extensions} || $c->{video_extensions}) && $file->{file_name}!~/\.($c->{audio_extensions}|$c->{video_extensions})$/i;

	# If not video or audio file
	$file->{not_video_audio_image} = ($c->{audio_extensions} || $c->{video_extensions} || $c->{image_extensions}) && $file->{file_name}!~/\.($c->{audio_extensions}|$c->{video_extensions}|$c->{image_extensions})$/i;

	# If audio and video file
	$file->{is_video_audio} = ($c->{audio_extensions} || $c->{video_extensions}) && $file->{file_name} =~ /\.($c->{audio_extensions}|$c->{video_extensions})$/i;

	# If Image file
	$file->{is_image} = $c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i;

	# If audio file
	$file->{is_audio} = $c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i;

	# If audio file
	$file->{is_video} = $c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i;


	if($file->{audio_title} && $file->{audio_artist}) {
		$file->{audio_title_artist}=1;
	}

	$file = Download1Checks($file);
	if(!$file->{is_audio}) {
		if($file->{message})
		{
			$file->{video_wait}=1;
			$file->{msg2}=$file->{message};
			$file->{message}='';
		}
	} else {
		$file->{message}='';
	}

	$file->{ophash} = $ses->HashSave($file->{file_id},0);

	$file->{file_descr}=~s/\n/<br>/gs;

	my @plans;
	if($c->{payment_plans} && !$premium && $c->{enabled_prem})
	{
		for( split(/,/,$c->{payment_plans}) )
		{
			/([\d\.]+)=(\d+)/;
			push @plans, { amount=>$1, days=>$2, site_url=>$c->{site_url} };
		}
	}
	if($c->{enable_file_comments} && !$c->{highload_mode})
	{
		$file->{comments} = CommentsList(1,$file->{file_id});
	}
	if($c->{show_more_files} && !$c->{highload_mode} && $c->{more_files_number})
	{
		$file->{more_files} = getMoreFiles($file,$c->{more_files_number});

		$ses->processVideoList($file->{more_files});
		$file->{files} = $file->{more_files};
	}

	if($ENV{QUERY_STRING}=~/list=(\w+)/i && !$c->{highload_mode})
	{
		$file->{playlist} = $1;
		my $pl = $db->SelectRow("SELECT * FROM Playlists WHERE pls_code=?",$file->{playlist});
		my $curr = $db->SelectRow("SELECT * FROM Files2Playlists f2p WHERE f2p.pls_id=? AND file_id=?", $pl->{pls_id}, $file->{file_id} );
		if($pl && $curr)
		{
			my $prev = $db->SelectRow("SELECT * FROM Files f, Files2Playlists f2p
										WHERE f2p.pls_id=?
										AND f2p.created<?
										AND f2p.file_id=f.file_id
										ORDER BY created DESC
										LIMIT 1", $pl->{pls_id}, $curr->{created} );
			my $next = $db->SelectRow("SELECT * FROM Files f, Files2Playlists f2p
										WHERE f2p.pls_id=?
										AND f2p.created>?
										AND f2p.file_id=f.file_id
										ORDER BY created
										LIMIT 1", $pl->{pls_id}, $curr->{created} );
			if($prev)
			{
				$file->{"playlist_prev_title"} = $ses->shortenString($prev->{file_title},32);
				$file->{"playlist_prev"} = $ses->makeFileLink($prev)."?list=$file->{playlist}";
			}
			if($next)
			{
				$file->{"playlist_next_title"} = $ses->shortenString($next->{file_title},32);
				$file->{"playlist_next"} = $ses->makeFileLink($next)."?list=$file->{playlist}";
			}
		}
	}

	$file->{embed_code} = $ses->makeEmbedCode($file);

	$file->{add_to_account}=1 if $ses->getUser && $c->{file_cloning};# && $file->{usr_id}!=$ses->getUserId;
	$c->{ads}=0 if $c->{bad_ads_words} && ($file->{file_name}=~/$c->{bad_ads_words}/is || $file->{file_descr}=~/$c->{bad_ads_words}/is);
	#$file->{video_ads}=1 if $c->{m_ads} && $c->{ads};
	$file->{video_ads}=1 if $c->{ads};
	$file->{video_ads}=0 if $file->{usr_notes}=~/NOADS/i;
	$file->{vast_ads}=$file->{video_ads};
	#$file->{vast_ads}=0 if  $c->{vast_alt_ads_hide} && $file->{usr_ads_mode}; # Alt Ads off
	$file->{vast_ads}=0 if $c->{vast_countries} && $ses->getMyCountry!~/^($c->{vast_countries})$/i;
	$file->{video_embed_code}=1 if $c->{video_embed};
	if($c->{alt_ads_mode})
	{
		$file->{usr_ads_mode}||=0;
		$file->{$_}=1 for split /[\,\s]+/, $c->{"alt_ads_tags$file->{usr_ads_mode}"};
		$file->{vast_ads}=0 unless $file->{vast};
	}

	selectAds($file) if $c->{m_9};

	VideoMakeCode($file);

	my $tags = $db->SelectARefCached("SELECT * FROM Tags t, Tags2Files t2f WHERE t2f.file_id=? AND t2f.tag_id=t.tag_id",$file->{file_id}) if !$c->{highload_mode};
	for(@$tags)
	{
		$_->{tag_value2}=$_->{tag_value};
		$_->{tag_value2}=~s/ /\+/g;
	}

	$file->{voted} = $db->SelectOneCached(10,"SELECT vote FROM Votes WHERE file_id=? AND usr_id=?",$file->{file_id},$ses->getUserId) if $ses->getUserId;
	$file->{"voted_".{-1 => 'down', 1 => 'up'}->{$file->{voted}}} = ' active';
	my $votes = $db->SelectARefCached(30,"SELECT vote, COUNT(*) as num FROM Votes WHERE file_id=? GROUP BY vote",$file->{file_id});
	for(@$votes)
	{
		$file->{likes}=$_->{num} if $_->{vote}==1;
		$file->{dislikes}=$_->{num} if $_->{vote}==-1;
	}
	$file->{likes}||=0;
	$file->{dislikes}||=0;
	$file->{likes_percent}=sprintf("%.1f",100*$file->{likes}/($file->{likes}+$file->{dislikes})) if $file->{likes} || $file->{dislikes};
	$file->{likes_percent}=50 unless $file->{likes} || $file->{dislikes};

	my $user_vote = $db->SelectRow("SELECT vote FROM Votes WHERE file_id=? AND usr_id=?", $file->{file_id}, $ses->getUserId);

	my $vote_action = 'up';
	my $vote_title = "Like this!";
	if ($user_vote) {
		if ($user_vote->{vote} == 1) {
			$vote_action = 'down';
			$vote_title = "Don't like this!";
		}
	}


	$file->{edit_ok}=1 if ($file->{usr_id} && $file->{usr_id}==$ses->getUserId) || $ses->getUser && $ses->getUser->{usr_adm};
	$file->{download_original}=1 if $c->{download} && !$file->{no_dl_btn};

	$file->{download_original}=0 unless $file->{file_size_o} || $file->{file_size_n} || $file->{file_size_h} || $file->{file_size_l} || $file->{file_size_x};

	if($ses->getUser && $ses->getUser->{usr_adm})
	{
		$file->{featured}=1 if $db->SelectOneCached("SELECT file_id FROM FilesFeatured WHERE file_id=?",$file->{file_id});
	}

	$file->{extra_data} = $db->SelectARefCached("SELECT * FROM FilesData WHERE file_id=?",$file->{file_id}) if $c->{file_data_fields};
	for(@{$file->{extra_data}})
	{
		$_->{value2} = $_->{value};
		$_->{value2} =~ s/\s+/+/g;
	}

	# if($ses->getUserId)
	# {
	#     $file->{favorited}=1 if $db->SelectOne("SELECT file_id FROM Favorites WHERE usr_id=? AND file_id=?",$ses->getUserId,$file->{file_id});
	# }
	# else
	unless($ses->getUserId)
	{
		$file->{favorited}=1 if $ses->getCookie("fav")=~/$file->{file_code}/i;
	}

	my $file_seo = $db->SelectOne("SELECT file_seo FROM Files WHERE file_id=?",$file->{file_id});

	$file->{deurl} = $ses->shortenURL($file->{file_id}) if $c->{m_j};

	$file->{versions} = getVideoVersions($file) if $file->{download_original};

	$file->{downloads}=1 if $file->{download_original};

	#return $ses->PrintTemplate("download_file_only.html", %$file, dl_link => $ses->makeDownloadLink($file,'o') ) if $c->{video_extensions} && $file->{file_name}!~/\.($c->{video_extensions})$/i;

	$file->{playlists} = $db->SelectARefCached("SELECT p.*, COUNT(f.file_id) as num
												FROM Playlists p
												LEFT JOIN Files2Playlists f ON p.pls_id=f.pls_id
												WHERE p.usr_id=?
												AND p.pls_name <> 'Watch later'
												GROUP BY p.pls_id", $ses->getUserId ) if $ses->getUserId && !$c->{highload_mode};

	$file->{playlist_watch_later} = $db->SelectOneCached("SELECT COUNT(f.file_id) as num
														FROM Playlists p
														LEFT JOIN Files2Playlists f ON p.pls_id=f.pls_id
														WHERE p.usr_id=?
														AND p.pls_name = 'Watch later'
														GROUP BY p.pls_id", $ses->getUserId )||0 if $ses->getUserId && !$c->{highload_mode};


	$file->{ispremium} = $file->{exp_sec}>0;
	$file->{usr_channel_name}||=$file->{file_usr_login};
	$file->{user_channel_avatar} = $db->SelectOne("SELECT usr_avatar FROM Users WHERE usr_login=?", $file->{file_usr_login});
	$file->{usr_disable_adb} = $c->{force_disable_adb}==2 ? $file->{usr_disable_adb} : $c->{force_disable_adb};

	# Enable/Disable file comments
	$file->{usr_comment_global} = $db->SelectOne("SELECT usr_comment_global FROM Users WHERE usr_id=?",$file->{usr_id});

	# Enable/Disable file downloads
	$file->{usr_file_dl_global} = $db->SelectOne("SELECT usr_file_dl_global FROM Users WHERE usr_id=?",$file->{usr_id});

	# Enable / Disable comments
	if($file->{usr_comment_global} == 0 && $file->{file_comments} == 2) {
		$file->{file_comments_on} = 1;
	} elsif($file->{usr_comment_global} == 1 && $file->{file_comments} == 3) {
		$file->{file_comments_on} = 0;
	} elsif($file->{usr_comment_global} == 0) {
		$file->{file_comments_on} = 0;
	} else {
		$file->{file_comments_on} = 1;
	}

	# Enable / Disable Downloads
	if($file->{usr_file_dl_global} == 0 && $file->{file_download_on} == 3) {
		$file->{downloads_off} = 0;
	} elsif($file->{usr_file_dl_global} == 1 && $file->{file_download_on} == 2) {
		$file->{downloads_off} = 1;
	} elsif($file->{usr_file_dl_global} == 1) {
		$file->{downloads_off} = 0;
	} else {
		$file->{downloads_off} = 1;
	}

	# template for mobiles
	my $tmpl = $ses->isMobile ? "download1_mobile.html" : "download1.html";

	# If files status locked by admin
	$file->{"file_status_$file->{file_status}"} = ' selected';

	# Comments
	my $comments = $db->SelectARef("
		SELECT COUNT(c.cmt_id) as comment_count
		FROM Files f
		LEFT JOIN Comments c ON c.cmt_ext_id = f.file_id AND c.cmt_type = 1
		WHERE f.file_id = ?
		GROUP BY f.file_id
	", $file->{file_id});

	$file->{comment_count} = my $comment_count = $comments->[0]->{comment_count} // 0;


	# User short name
	if (defined $file->{usr_login} && length $file->{usr_login} >= 1) {
		$file->{usr_login_short_dl} = substr($file->{usr_login}, 0, 1);
	} else {
		$file->{usr_login_short_dl} = $file->{usr_login} // '';
	}

	# If JW Player
	$file->{jwplayer} = ($c->{player} eq 'jw8') ? 1 : 0;

	return $ses->PrintTemplate($tmpl,
								%{$file},
								#%{$c},
								'msg'           => $f->{msg}||$file->{message},
								'site_name'     => $c->{site_name},
								'countdown'     => $c->{download_countdown},
								'premium'       => $premium,
								'aff'           => $file->{usr_id},
								'referer'       => $f->{referer},
								#'more_files'    => $more_files,
								'cmt_type'      => 1,
								'cmt_ext_id'    => $file->{file_id},
								'rnd1'          => $ses->randchar(6),
								'tags'          => $tags,
								'vote_action'	=> $vote_action,
								"comments_$c->{enable_file_comments}" => 1,
								#'hash'          => $hash,
	);
}

sub DownloadOriginal
{
   return $ses->message($c->{maintenance_download_msg}||"Downloads are temporarily disabled due to site maintenance","Site maintenance") if $c->{maintenance_download};
   return $ses->message("Video pages disabled") if $c->{video_page_disabled};

	my $mode = $f->{mode};

	# $f->{referer} = $ses->getDomain( $ENV{HTTP_REFERER} );

	# $ses->setCookie('id',$f->{id},'+1m');
	# $ses->setCookie('referer',$f->{referer},'+1m');
	# my $code = $ses->randchar(13);
	# return $ses->redirect("/d/$code\_$mode");

	# $f->{id}||=$ses->getCookie('id');

   my $usr_id = $ses->getUser ? $ses->getUserId : 0;
   my $file = $ses->getFileRecord( $f->{id} );
   return $ses->message("No such file=$f->{id}") unless $file;

   # Return if downloads disabled
   $file->{usr_file_dl_global} = $db->SelectOne("SELECT usr_file_dl_global FROM Users WHERE usr_id=?",$file->{usr_id});
   return $ses->message("Downloads are disabled for this file") if ($file->{usr_file_dl_global} == 0 && $file->{file_download_on} == 3) || ($file->{usr_file_dl_global} == 1 && $file->{file_download_on} == 1|$file->{file_download_on} == 3) || $file->{file_dl_link};


   $file->{usr_channel_name}||=$file->{file_usr_login};
   $file->{user_channel_avatar} = $db->SelectOne("SELECT usr_avatar FROM Users WHERE usr_login=?", $file->{file_usr_login});

	# Extracting file extension from file_name
	if ($file->{file_name} =~ /\.([^.]+)$/) {
		$file->{file_extension} = $1;
	} else {
		$file->{file_extension} = ''; # Set to empty if no extension found
	}

	# If Image file
	$file->{is_image} = $c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i;

	# If audio file
	$file->{is_audio} = $c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i;

	# If audio file
	$file->{is_video} = $c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i;

	$file->{ispremium} = $file->{exp_sec}>0;

   $file->{download_link} = $ses->makeFileLink($file);

   $ses->getVideoInfo($file);

   ($file->{message},$file->{no_dl_btn}) = DownloadOriginalChecks($file);

   $file->{file_size_txt} = $ses->makeFileSize( $file->{"file_size_$f->{mode}"} );

   if(!$f->{hash} || $file->{message})
   {
      if($c->{download_orig_recaptcha_v3})
      {
      	$file->{download_orig_recaptcha_v3}=1;
      	$file->{recaptcha3_pub_key}=$c->{recaptcha3_pub_key};
      }
      my $hash = $ses->HashSave($file->{file_id},1);
      return $ses->PrintTemplate("download_file1.html",
                                 msg => $file->{message},
                                 %$file,
                                 mode => $f->{mode},
                                 hash => $hash,
								 #'referer'       => $f->{referer},
                                );
   }


   $file->{file_size} = $file->{"file_size_$mode"};
   $file->{file_name}.='.mp4' if $mode ne 'o' && $file->{file_name}!~/\.mp4$/i;
   #$file->{file_name}=~s/\s+/_/g;

   # Remove quetion marks
   $file->{file_name}=~s/\?//g;

   $file->{download}=1;
   $file->{direct_link} = $ses->genDirectLink( $file, $mode, $file->{file_name} );

   #TrackDownload($file,$mode);
   TrackView($file);

   $file->{fsize} = $ses->makeFileSize($file->{file_size});

   return $ses->PrintTemplate("download_file2.html",
                       %{$file},
                       symlink_expire   => $c->{symlink_expire},
                       ip               => $ses->getIP,
					   #ip               => generate_random_ip(),
                      );
}

sub DownloadOriginalChecks
{
   my ($file) = @_;

   $f->{mode}||='n';
   return "This version is not available for this video",'nobtn' unless $file->{"file_size_$f->{mode}"};
   #return "You are not able to download original videos",'nobtn' if $f->{mode} eq 'o' && !$c->{download_orig};
   return "You are not able to download this type of videos",'nobtn' unless $c->{"vid_play_$ses->{utype}_$f->{mode}"};
   return "You are not able to download videos",'nobtn' unless $c->{download};

   return "Security error0" if $f->{hash} && $ENV{REQUEST_METHOD} ne 'POST';
   return "Security error1" if $f->{hash} && !$ses->HashCheck($f->{hash},$file->{file_id});

   if($f->{hash} && $c->{download_orig_recaptcha_v3})
   {
   		my $score = $ses->checkRecaptcha3();
		return "Downloads disabled 62$score" if $score < 20;
   }

   if($file->{usr_premium_dl_only} && $ses->{utype} ne 'prem')
   {
       return "$ses->{lang}->{lng_download_for_premium_users_only}<br><a href='/premium.html'>$ses->{lang}->{lng_download_upgrade_to_premium_now}</a>",'nobtn';
   }


   if($c->{max_download_filesize} && ($file->{"file_size_$f->{mode}"} > $c->{max_download_filesize}*1048576))
   {
      return "$ses->{lang}->{lng_download_can_download_files_up_to} $c->{max_download_filesize} MB.<br><a href='/premium.html'>$ses->{lang}->{lng_download_upgrade_to_premium_now}</a> $ses->{lang}->{lng_download_to_download_bigger_files}.";
   }

   my $usr_id = $ses->getUserId;
   my $ip = $ses->getIP;

   if($c->{file_dl_delay} || $c->{add_download_delay})
   {
      #my $cond = $usr_id ? "ip=INET_ATON('$ip') OR usr_id=$usr_id" : "ip=INET_ATON('$ip')";
      my $last = $db->SelectRow("SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(created) as dt
                                 FROM Views
                                 WHERE ip=INET_ATON(?)
                                 AND download=1
                                 ORDER BY created DESC
                                 LIMIT 1", $ip );
      my $wait;
      $wait = $c->{file_dl_delay} - $last->{dt} if $last && $c->{file_dl_delay};
      $wait = int($c->{add_download_delay}*$last->{size}/(100*1048576)) - $last->{dt} if $last && $c->{add_download_delay};

      if($wait>0)
      {
         require Time::Elapsed;
         my $et = new Time::Elapsed;
         my $elapsed = $et->convert($wait);
         my $premiumdl = "<br><br>$ses->{lang}->{lng_download_dl_files_instantly_with_premium}" if $c->{enabled_prem};
         return "$ses->{lang}->{lng_download_you_have_to_wait} $elapsed $ses->{lang}->{lng_download_untill_next_dl}$premiumdl";
      }
   }

   if($c->{bw_limit})
   {
      #my $cond = $ses->getUser ? "usr_id=".$ses->getUserId : "ip=INET_ATON('".$ses->getIP."')";
      my $bw = $db->SelectOne("SELECT SUM(size)
      							FROM Views
      							WHERE ip=INET_ATON(?)
      							AND download=1
      							AND created > NOW()-INTERVAL ? DAY",
      							$ses->getIP, $c->{bw_limit_days} );
      return "$ses->{lang}->{lng_download_reached_dl_limit}: $c->{bw_limit} MB $ses->{lang}->{lng_download_for_last} $c->{bw_limit_days} $ses->{lang}->{lng_download_days}"
         if ($bw > $c->{bw_limit}*1024**3);
   }

   if($file->{file_status} ne 'OK')
   {
       return $ses->{lang}->{lng_download_file_is_pending} if $file->{file_status} eq 'PENDING';
       return $ses->{lang}->{lng_download_file_is_locked} if $file->{file_status} eq 'LOCKED';
       return "Unknown file status";
   }

   return '';
}

sub DownloadOriginalVersions
{
   return $ses->message($c->{maintenance_download_msg}||"Downloads are temporarily disabled due to site maintenance","Site maintenance") if $c->{maintenance_download};
   return $ses->message("Video pages disabled") if $c->{video_page_disabled};

   my $usr_id = $ses->getUser ? $ses->getUserId : 0;
   my $file = $ses->getFileRecord( $f->{id} );
   return $ses->message("No such file=$f->{id}") unless $file;

   my $versions = getVideoVersions($file);

   return $ses->PrintTemplate("download_file_versions.html",
                       			%{$file},
                       			versions => $versions,
                       			);
}

# sub genDirectLinkOld
# {
#    my ( $file, $quality, $expire, $fname, $hash_only )=@_;
#    #require HCE_MD5;
#    #my $hce = HCE_MD5->new($c->{dl_key},"XVideoSharing");
#    my $usr_id = $ses->getUser ? $ses->getUserId : 0;
#    my $dx = sprintf("%d",($file->{file_real_id}||$file->{file_id})/$c->{files_per_folder});
#    my $watch_speed = $c->{"watch_speed_$quality"} || $c->{watch_speed_h} || $c->{watch_speed_n};
#    if($c->{"watch_speed_auto_$quality"} && $file->{file_length})
#    {
#       $watch_speed = int 1.4*$file->{"file_size_$quality"}/$file->{file_length}/1024;
#    }
#    my $speed = $file->{download} ? $c->{down_speed} : $watch_speed;
#    $expire ||= $c->{symlink_expire}*60;
#    my $flags;
#    $flags |= 1 if $file->{download}; # Dowload
#    $flags |= 2 if $f->{embed};  # Embedded
#    #$flags |= 4 if $f->{embed};  # Transfer
#    $flags |= 8 if $c->{no_video_ip_check} || $c->{no_ipcheck_countries} && $ses->getMyCountry=~/^($c->{no_ipcheck_countries})$/; # Disable IP check
#    $flags |= 16 if $c->{no_ipcheck_mobile} && $ses->isMobile;

#    #my $ip = $c->{no_video_ip_check} ? '0.0.0.0' : $ses->getIP;
#    my $ip = $ses->getIP;
#    $expire=-600 if $ses->{badlink}; # expired link for banned IP
#    $expire=-100 if $c->{player_hidden_link} && $c->{player}=~/^(jw8|vjs)$/ && $f->{op}!~/^(playerddl|download_orig)$/;

#    my $hash = encode32( $hce->hce_block_encrypt(pack("SCLLSA12ASC4LC",
#                                                        $c->{video_time_limit}||0,
#                                                        $file->{disk_id},
#                                                        $file->{file_id},
#                                                        $usr_id,
#                                                        $dx,
#                                                        $file->{file_real},
#                                                        $quality,
#                                                        $speed,
#                                                        split(/\./,$ip),
#                                                        time+60*$expire,
#                                                        $flags)) );
#    #$file->{file_name}=~s/%/%25/g;
#    return $hash if $hash_only;
#    $fname||=$file->{file_name};
#    #$file->{srv_htdocs_url}="http://xis.tt/cgi-bin/r.cgi/$file->{srv_id}";
#    return "$file->{srv_htdocs_url}/$hash/$fname";
# }

# Transfers special link
# sub genDirectLink2
# {
#    my ($file,$mode,$fname)=@_;
#    my $speed = $file->{host_transfer_speed} || $c->{server_transfer_speed} || 25000; # KB, 15000 = 150 mbit/s
#    #require HCE_MD5;
#    #my $hce = HCE_MD5->new($c->{dl_key},"XVideoSharing");
#    my $usr_id = 0;
#    my $dx = sprintf("%d",($file->{file_real_id}||$file->{file_id})/$c->{files_per_folder});
#    my $flags=4; # transfer flag
#    my $hash = encode32( $hce->hce_block_encrypt(pack("SCLLSA12ASC4LC",
#                                                        0,
#                                                        $file->{disk_id},
#                                                        $file->{file_id},
#                                                        $usr_id,
#                                                        $dx,
#                                                        $file->{file_real},
#                                                        $mode,
#                                                        $speed,
#                                                        0,0,0,0,
#                                                        time+60*9200,
#                                                        $flags)) );
#    $fname ||= $file->{file_real};
#    return "$file->{srv_htdocs_url}/$hash/$fname";
# }

sub VideoMakeCode
{
	my ($file,$info) = @_;

	$ses->getVideoInfo($file);
	my $vx = $ses->vInfo($file,'n');

	$vx->{vid_width}  ||= $file->{vid_width}||640;
	$vx->{vid_height} ||= $file->{vid_height}||360;

	($file->{play_w},$file->{play_h}) = ( $vx->{vid_width} , $vx->{vid_height} );
	if($c->{m_v_width})
	{
		if($c->{m_v_width} && $c->{m_v_height})
		{
			($file->{play_w},$file->{play_h}) = ($c->{m_v_width},$c->{m_v_height});
		}
		else # using only player width
		{
			$file->{play_w} = $c->{m_v_width};
			$file->{play_h} = sprintf("%.0f", $c->{m_v_width} * $vx->{vid_height}/$vx->{vid_width} );
		}
	}

	# Embed override
	$file->{play_w}=$f->{w} if $f->{w};
	$file->{play_h}=$f->{h} if $f->{h};

	return $file if $info eq 'info';

	###############

	if($c->{noplay_from_uploader_encoder} && $file->{srv_type}=~/^(UPLOADER|ENCODER)$/)
	{
		$file->{msg2} = "<p class='text-lg font-bold text-gray-300 sm:text-2x1'>Video is processing now</p>
							<span id='enc_pp' class='text-gray-400'>...</span>";

		$file->{msg_audio} = "<p class='text-lg font-bold text-yellow-300 sm:text-2x1'>Audio is processing now</p>
							<span id='enc_pp' class='text-gray-400'>...</span>";
		$file->{video_wait}=1;
		$file->{enc_status}=1;
		return $file;
	}

	return $file if $file->{video_wait};

	my ($play,$playprem) = $ses->getPlayVersions($file);
	if(!keys %$play) # no qualities to play
	{
		if(keys %$playprem)
		{
			$file->{msg2}="Upgrade your account to watch this video now.";
			$file->{msg_audio}="Upgrade your account to watch this video now.";
		}
		else
		{
			my $enc = $db->SelectOne("SELECT COUNT(*) FROM QueueEncoding WHERE file_real=?",$file->{file_real});
			if($enc)
			{
				$file->{msg2} ||= "$ses->{lang}->{lng_download_video_processing_now} <span id='enc_pp' class='text-gray-400'>...</span>";
				$file->{msg_audio} ||= "$ses->{lang}->{lng_download_video_processing_now} <span id='enc_pp' class='text-gray-400'>...</span>";
				$file->{enc_status}=1;
			}
			else
			{
				$file->{msg2}="No video qualities available.<br>System error.";
				$file->{msg_audio}="No video qualities available.<br>System error.";
			}
		}
		$file->{video_wait}=1;
		return $file;
	}

	my $preview = $file->{file_size_p} && $c->{m_p_show} && $c->{m_p} ? 1 : 0;
	if($preview)
	{
		$play={};
		$play->{p}=1;
	}

	my @dlinks;
	my @qletters;

	# Check if audio extensions and file name pattern match, and file_spec_l is true
	if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i && $file->{file_spec_l}) {
		@qletters = ('l');
	} else {
		@qletters = $preview ? ('p') : (@{$c->{quality_letters}}, 'o');
	}

	for my $q (@qletters)
	{
		my $vi = $ses->vInfo($file,$q);
		my $label = $c->{quality_labels}->{$q};
		$label = "$vi->{vid_height}p" if $c->{quality_labels_mode}==1;
		$label = "$vi->{vid_width}x$vi->{vid_height}" if $c->{quality_labels_mode}==2;
		$label.=' '.($vi->{vid_bitrate}+$vi->{vid_audio_bitrate}).' kbps' if $c->{quality_labels_bitrate};
		push @dlinks, {
						mode => $q,
						direct_link => $ses->genDirectLink($file, $q, "$q"),
						#direct_link => $ses->genDirectLink($file, $q, "$q.mp4"),
						label => $label,
						height => $vi->{vid_height},
						} if $play->{$q};
	}
	$file->{direct_links} = \@dlinks;


	$file->{hls_direct} = $ses->genHLSLink($file, $play) if $c->{m_r};

	return $file if $info eq 'direct';

	$file->{captions_list} = $ses->getCaptionsLinks($file);

	my $player = $c->{player};
	my $player_audio = $c->{player_audio};

	# Check if the file is an audio file
	if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
		# Use player_audio for audio files
		( $file->{video_code_html}, $file->{video_code_js} ) = $ses->getPlugins('Player')->makePlayerCode( $f, $file, $c, $player_audio );
	} else {
		# Use the regular player for non-audio files
		( $file->{video_code_html}, $file->{video_code_js} ) = $ses->getPlugins('Player')->makePlayerCode( $f, $file, $c, $player );
	}

	$file->{video_code_js} = encodeJS( $file->{video_code_js} );

	return $file;
}

sub encodeJS
{
  my ($s) = @_;
  require Pack;
  $s = &Pack::pack($s,36,0,0) if $c->{player_js_encode};
  return "<script type='text/javascript'>$s</script>";
}

sub checkRecaptchaHash
{
	my $passed=0;
	my $ip = join '', (split(/\./, $ses->getIP))[0,1,2];
	if($f->{'g-recaptcha-response'} && $ENV{REQUEST_METHOD} eq 'POST')
	{
		if($ses->checkRecaptcha)
		{
			$passed=1;
			require Digest::SHA;
			my $exp = time + $c->{watch_require_recaptcha_expire}*60;
	 		my $hash = Digest::SHA::sha1_hex("$exp-$ip-$c->{dl_key}-$c->{user_agent}");
			$ses->setCookie("vcap$ip","$exp-$hash","+$c->{watch_require_recaptcha_expire}m");
		}
	}
	if(!$passed && $ses->getCookie("vcap$ip"))
	{
		my ($exp,$hash) = $ses->getCookie("vcap$ip")=~/^(\d+)-(.+)$/;
		if($exp > time)
		{
		 	require Digest::SHA;
		 	my $hash2 = Digest::SHA::sha1_hex("$exp-$ip-$c->{dl_key}-$c->{user_agent}");
		 	$passed=1 if $hash eq $hash2;
		}
	}
	return $passed;
}

sub Embed
{
   $ses->{xframe}=1;
   $ses->{form}->{no_hdr}=1;
   $f->{referer}=$1 if $ENV{REQUEST_URI}=~/referer=(.+)/i;
   my $referer = $ENV{HTTP_REFERER}=~/(emb\.html|\/e\/)/i ? $f->{referer} : $ENV{HTTP_REFERER};

   return $ses->message("Embeds disabled")  if $c->{embed_disabled};
   return $ses->message("Embeds disabled2") if $c->{embed_disable_noref} && !$referer;
   return $ses->message("Embeds disabled3") if $c->{embed_disable_except_domains} && $referer && $ses->getDomain($referer)!~/^($c->{embed_disable_except_domains})$/i;
   return $ses->message("Embeds disabled4") if $c->{embed_disable_only_domains} && $ses->getDomain($referer)=~/^($c->{embed_disable_only_domains})$/i;
   #return $ses->message("Embeds disabled5") if $ENV{HTTP_SEC_FETCH_DEST} eq 'iframe' && !$ENV{HTTP_REFERER}; #&& $ENV{HTTP_SEC_FETCH_SITE} eq 'cross-site'

   if($c->{static_embed_recaptcha_v3})
   {
	return $ses->message("Embeds disabled61") unless $ENV{REQUEST_METHOD} eq 'POST';
	my $score = $ses->checkRecaptcha3();
	return $ses->message("Embeds disabled62$score") if $score < 20;
   }

   if($c->{m_7} && $c->{m_7_video_embed} && ($c->{m_7_video_noserver}||$c->{m_7_video_noproxy}||$c->{m_7_video_notor}))
   {
   		my $is_server = XUtils::getIPBlockedStatus( $ses->db, 'ipserver', $ses->getIP ) if $c->{m_7_video_noserver};
   		my $is_proxy  = XUtils::getIPBlockedStatus( $ses->db, 'ipproxy', $ses->getIP ) if $c->{m_7_video_noproxy} && !$is_server;
   		my $is_tor    = XUtils::getIPBlockedStatus( $ses->db, 'iptor', $ses->getIP ) if $c->{m_7_video_notor} && !$is_server && !$is_proxy;
   		my $is_black  = XUtils::getIPBlockedStatus( $ses->db, 'ipblack', $ses->getIP ) if !$is_server && !$is_proxy && !$is_tor;
   		if( $is_server || $is_proxy || $is_tor || $is_black )
   		{
   			my $is_white = XUtils::getIPBlockedStatus( $ses->db, 'ipwhite', $ses->getIP );
   			$db->Exec("INSERT INTO StatsMisc
		              SET usr_id=0, day=CURDATE(), name='ipblock_blocked', value=1
		              ON DUPLICATE KEY
		              UPDATE value=value+1") if $c->{m_7_stats} && !$is_white;
   			if($is_white)
   			{
   				# do nothing
   				#return $ses->message('white');
   			}
   			elsif($c->{m_7_video_action} eq 'redirect')
   			{
   				return $ses->redirect($c->{site_url});
   			}
   			elsif($c->{m_7_video_action} eq 'message' && $c->{m_7_video_action_message_txt})
   			{
   				return $ses->message($c->{m_7_video_action_message_txt});
   			}
   			elsif($c->{m_7_video_action} eq 'badlink')
   			{
   				$ses->{badlink}=1;
   			}
   		}
   }
   if($c->{watch_require_recaptcha})
   {
   	 unless(checkRecaptchaHash())
   	 {
   	 	return $ses->PrintTemplate("video_embed_recaptcha.html", file_id => $f->{file_id}, recaptcha => $ses->genRecaptcha('auto') );
   	 }
   }
   my $file = $ses->getFileRecord2( $f->{file_id} );
   return $ses->PrintTemplate("video_embed_deleted.html") unless $file;
   return sendBack("Video embed restricted for this user") unless $c->{"video_embed_$file->{owner_type}"};
   return sendBack("This server is in maintenance mode. Refresh this page in some minutes.") if $file->{srv_status} eq 'OFF';
   $file->{autostart}=1 if $ENV{REQUEST_URI}=~/auto=1/ || $f->{auto} eq '1';

   return sendBack("Videos of this user were blocked") if $file->{usr_notes}=~/BLOCKVIDEOS/i;

   $ses->loadUserData($file);

   $file->{referer} = $ses->getDomain($referer);

   if($file->{embed_domain_allowed})
   {
     my $dhash;
     $dhash->{$_}=1 for split /\s*,\s*/, $file->{embed_domain_allowed};
     my ($domain) = $referer=~/\/\/(.+?)(\/|$)/i;
     $domain=~s/www\.//;
     return sendBack("Video embed restricted for this domain") if $domain && !$dhash->{lc($domain)};
   }
   # if($file->{banned_countries})
   # {
   # 		my $country = $ses->getMyCountry;
   # 		return print("Content-type:text/html\n\nVideo error: RC2$country"."RC") if $country=~/^($file->{banned_countries})$/i;
   # }
   return sendBack("Video error: RC2".$ses->getMyCountry."RC") if $file->{banned_countries} && XUtils::isBannedCountry($ses->getMyCountry, $file->{banned_countries});
   return sendBack("Video error: RI2RI") if $file->{banned_ips} && XUtils::isBannedIP($ses->getIP, $file->{banned_ips});
   $f->{embed}=$file->{embed}=1;
   $file = Download1Checks($file);
   if($file->{message})
   {
       $file->{video_wait}=1;
       $file->{msg2}=$file->{message};
       $file->{message}='';
   }

   P2P_Logic($file) if $c->{p2p_on};

   $file->{ophash} = $ses->HashSave($file->{file_id},0);

   $file->{embed_code} = $ses->makeEmbedCode($file);

   $file->{video_ads} = $c->{ads} ? 1 : 0;
   $file->{video_ads} = 0 if $file->{usr_notes}=~/NOADS/i;
   $file->{vast_ads}=$file->{video_ads};
   #$file->{vast_ads}=0 if $c->{vast_alt_ads_hide} && $file->{usr_ads_mode}; # Alt Ads off
   $file->{vast_ads}=0 if $c->{vast_countries} && $ses->getMyCountry!~/^($c->{vast_countries})$/i;

   if($c->{alt_ads_mode})
   {
   		$file->{usr_ads_mode}||=0;
   		$file->{$_}=1 for split /[\,\s]+/, $c->{"alt_ads_tags$file->{usr_ads_mode}"};
   		$file->{vast_ads}=0 unless $file->{vast};
   }

   selectAds($file) if $c->{m_9};

   VideoMakeCode($file);

   #return print("Content-type:text/html\n\nCan't create video code") unless $file->{video_code};

   $file->{referer}||=$referer;
   $file->{'aff'} = $file->{usr_id};
   $file->{usr_disable_adb} = $c->{force_disable_adb}==2 ? $file->{usr_disable_adb} : $c->{force_disable_adb};

	my $tmpl; # Declare $tmpl variable

	# Check if file extension is in the audio extensions list
	if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
		$tmpl = "audio_embed.html"; # Use audio embed template for audio files
	} else {
		# Use mobile or standard video embed template based on whether the client is mobile
		$tmpl = $ses->isMobile ? "video_embed_mobile.html" : "video_embed.html";
	}

   return $ses->PrintTemplate($tmpl,
                              %$file,
                             );
}

sub Embed2
{
   $ses->{xframe}=1;
   $ses->{form}->{no_hdr}=1;
   $f->{referer}=$1 if $ENV{REQUEST_URI}=~/referer=(.+)/i;
   my $referer = $ENV{HTTP_REFERER}=~/(emb\.html|\/e\/)/i ? $f->{referer} : $ENV{HTTP_REFERER};

   return $ses->message("Embeds disabled")  if $c->{embed_disabled};
   return $ses->message("Embeds disabled2") if $c->{embed_disable_noref} && !$referer;
   return $ses->message("Embeds disabled3") if $c->{embed_disable_except_domains} && $referer && $ses->getDomain($referer)!~/^($c->{embed_disable_except_domains})$/i;
   return $ses->message("Embeds disabled4") if $c->{embed_disable_only_domains} && $ses->getDomain($referer)=~/^($c->{embed_disable_only_domains})$/i;
   #return $ses->message("Embeds disabled5") if $ENV{HTTP_SEC_FETCH_DEST} eq 'iframe' && !$ENV{HTTP_REFERER}; #&& $ENV{HTTP_SEC_FETCH_SITE} eq 'cross-site'

   if($c->{static_embed_recaptcha_v3})
   {
	return $ses->message("Embeds disabled61") unless $ENV{REQUEST_METHOD} eq 'POST';
	my $score = $ses->checkRecaptcha3();
	return $ses->message("Embeds disabled62$score") if $score < 20;
   }

   if($c->{m_7} && $c->{m_7_video_embed} && ($c->{m_7_video_noserver}||$c->{m_7_video_noproxy}||$c->{m_7_video_notor}))
   {
   		my $is_server = XUtils::getIPBlockedStatus( $ses->db, 'ipserver', $ses->getIP ) if $c->{m_7_video_noserver};
   		my $is_proxy  = XUtils::getIPBlockedStatus( $ses->db, 'ipproxy', $ses->getIP ) if $c->{m_7_video_noproxy} && !$is_server;
   		my $is_tor    = XUtils::getIPBlockedStatus( $ses->db, 'iptor', $ses->getIP ) if $c->{m_7_video_notor} && !$is_server && !$is_proxy;
   		my $is_black  = XUtils::getIPBlockedStatus( $ses->db, 'ipblack', $ses->getIP ) if !$is_server && !$is_proxy && !$is_tor;
   		if( $is_server || $is_proxy || $is_tor || $is_black )
   		{
   			my $is_white = XUtils::getIPBlockedStatus( $ses->db, 'ipwhite', $ses->getIP );
   			$db->Exec("INSERT INTO StatsMisc
		              SET usr_id=0, day=CURDATE(), name='ipblock_blocked', value=1
		              ON DUPLICATE KEY
		              UPDATE value=value+1") if $c->{m_7_stats} && !$is_white;
   			if($is_white)
   			{
   				# do nothing
   				#return $ses->message('white');
   			}
   			elsif($c->{m_7_video_action} eq 'redirect')
   			{
   				return $ses->redirect($c->{site_url});
   			}
   			elsif($c->{m_7_video_action} eq 'message' && $c->{m_7_video_action_message_txt})
   			{
   				return $ses->message($c->{m_7_video_action_message_txt});
   			}
   			elsif($c->{m_7_video_action} eq 'badlink')
   			{
   				$ses->{badlink}=1;
   			}
   		}
   }
   if($c->{watch_require_recaptcha})
   {
   	 unless(checkRecaptchaHash())
   	 {
   	 	return $ses->PrintTemplate("video_embed_recaptcha.html", file_code => $f->{file_code}, recaptcha => $ses->genRecaptcha('auto') );
   	 }
   }
   my $file = $ses->getFileRecord( $f->{file_code} );
   return $ses->PrintTemplate("video_embed_deleted.html") unless $file;
   return sendBack("Video embed restricted for this user") unless $c->{"video_embed_$file->{owner_type}"};
   return sendBack("This server is in maintenance mode. Refresh this page in some minutes.") if $file->{srv_status} eq 'OFF';
   $file->{autostart}=1 if $ENV{REQUEST_URI}=~/auto=1/ || $f->{auto} eq '1';

   return sendBack("Videos of this user were blocked") if $file->{usr_notes}=~/BLOCKVIDEOS/i;

   $ses->loadUserData($file);

   $file->{referer} = $ses->getDomain($referer);

   if($file->{embed_domain_allowed})
   {
     my $dhash;
     $dhash->{$_}=1 for split /\s*,\s*/, $file->{embed_domain_allowed};
     my ($domain) = $referer=~/\/\/(.+?)(\/|$)/i;
     $domain=~s/www\.//;
     return sendBack("Video embed restricted for this domain") if $domain && !$dhash->{lc($domain)};
   }
   # if($file->{banned_countries})
   # {
   # 		my $country = $ses->getMyCountry;
   # 		return print("Content-type:text/html\n\nVideo error: RC2$country"."RC") if $country=~/^($file->{banned_countries})$/i;
   # }
   return sendBack("Video error: RC2".$ses->getMyCountry."RC") if $file->{banned_countries} && XUtils::isBannedCountry($ses->getMyCountry, $file->{banned_countries});
   return sendBack("Video error: RI2RI") if $file->{banned_ips} && XUtils::isBannedIP($ses->getIP, $file->{banned_ips});
   $f->{embed}=$file->{embed}=1;
   $file = Download1Checks($file);
   if($file->{message})
   {
       $file->{video_wait}=1;
       $file->{msg2}=$file->{message};
       $file->{message}='';
   }

   P2P_Logic($file) if $c->{p2p_on};

   $file->{ophash} = $ses->HashSave($file->{file_id},0);

   $file->{embed_code} = $ses->makeEmbedCode($file);

   $file->{video_ads} = $c->{ads} ? 1 : 0;
   $file->{video_ads} = 0 if $file->{usr_notes}=~/NOADS/i;
   $file->{vast_ads}=$file->{video_ads};
   #$file->{vast_ads}=0 if $c->{vast_alt_ads_hide} && $file->{usr_ads_mode}; # Alt Ads off
   $file->{vast_ads}=0 if $c->{vast_countries} && $ses->getMyCountry!~/^($c->{vast_countries})$/i;

   if($c->{alt_ads_mode})
   {
   		$file->{usr_ads_mode}||=0;
   		$file->{$_}=1 for split /[\,\s]+/, $c->{"alt_ads_tags$file->{usr_ads_mode}"};
   		$file->{vast_ads}=0 unless $file->{vast};
   }

   selectAds($file) if $c->{m_9};

   VideoMakeCode($file);

   #return print("Content-type:text/html\n\nCan't create video code") unless $file->{video_code};

   $file->{referer}||=$referer;
   $file->{'aff'} = $file->{usr_id};
   $file->{usr_disable_adb} = $c->{force_disable_adb}==2 ? $file->{usr_disable_adb} : $c->{force_disable_adb};

	my $tmpl; # Declare $tmpl variable

	# Check if file extension is in the audio extensions list
	if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
		$tmpl = "audio_embed2.html"; # Use audio embed template for audio files
	} else {
		# Use mobile or standard video embed template based on whether the client is mobile
		$tmpl = $ses->isMobile ? "video_embed_mobile.html" : "video_embed.html";
	}

   return $ses->PrintTemplate($tmpl,
                              %$file,
                             );
}

sub View
{
  print"Access-Control-Allow-Origin: *\n";
  print"Content-type:text/html\n\n";
  my $file = $db->SelectRow("SELECT *, INET_NTOA(file_ip) as file_ip FROM Files WHERE file_code=?",$f->{file_code});
  return unless $file;
  return unless $ses->HashCheck($f->{hash},$file->{file_id});
  TrackView2($file);
  #my $views = $db->SelectOne("SELECT file_views FROM Files WHERE file_id=?",$file->{file_id});
  $file->{file_views}++;
  print"$file->{file_views}";
  return;
}

sub View2
{
  print"Content-type:text/html\n\n";
  return unless $ENV{REQUEST_METHOD} eq 'POST';
  print("OK"),return unless $ENV{HTTP_CONTENT_CACHE} eq 'no-cache';
  return unless $ENV{HTTP_REFERER}=~/$ses->{domain}/;

  my ($file_id,$i1,$i2,$tmin,$md5) = split(/-/,$f->{hash});
  # my $dt = time - $tmin;

  return unless $ses->HashCheck($f->{hash});

  my $ip = $ses->getIP;
  my $time = time;
  my $watched = sprintf("%.0f",$f->{w});
  open(FILE,">>logs/views.txt");
  print FILE "$ip:$file_id:$time:$watched\n";
  close FILE;

  print"OK";
}

sub TrackView
{
	my ($file) = @_;

	# my $referer = $ses->getCookie('ref_url') || '';
	# $referer='' if $referer=~/$c->{site_url}/i;
	# $referer=~s/^https?:\/\///i;
	#    $referer=~s/^www\.//i;
	#    $referer=~s/\/$//i;
	#    $referer=~s/^(.+?)\/.+$/$1/;

	my $referer = $ses->getDomain($f->{referer});

	my $premium = $ses->getUser && $ses->getUser->{premium};

	$db->Exec("INSERT INTO TmpFiles
					SET file_id=?, downloads=1
					ON DUPLICATE KEY UPDATE downloads=downloads+1
					", $file->{file_id} );

    $db->Exec("INSERT IGNORE INTO Downloads
               SET file_id=?,
			   	   usr_id=?,
                   owner_id=?,
                   ip=INET_ATON(?),
                   referer=?,
                   created=NOW(),
                   premium=?,
                   country=?,
                   download=?
                   ",
                     $file->{file_id},
					 $ses->getUserId||0,
                     $file->{usr_id}||0,
                     $ses->getIP,
					 #generate_random_ip(),
                     $referer||'',
                     $premium||0,
                     $ses->getMyCountry,
                     $file->{download}||0,
            );
}

sub TrackView2
{
	my ($file) = @_;

	my $referer = $ses->getDomain($f->{referer});

	my $premium = $ses->getUser && $ses->getUser->{premium};

	$db->Exec("INSERT INTO TmpFiles
					SET file_id=?, views=1
					ON DUPLICATE KEY UPDATE views=views+1
					", $file->{file_id} );

    $db->Exec("INSERT IGNORE INTO Views
               SET file_id=?,
			   	   usr_id=?,
                   owner_id=?,
                   ip=INET_ATON(?),
                   referer=?,
                   created=NOW(),
                   embed=?,
                   adb=?,
                   premium=?,
				   views_full=1,
                   country=?
                   ",
                     $file->{file_id},
                     $ses->getUserId||0,
					 $file->{usr_id}||0,
                     $ses->getIP,
					 #generate_random_ip(),
                     $referer||'',
                     $f->{embed}||0,
                     $f->{adb}||0,
                     $premium||0,
                     $ses->getMyCountry,
            );
}

sub generate_random_ip {
my @ip_list = (
    '89.38.96.187',
    '89.38.96.188',
    '89.38.96.189',
	'89.39.105.98',
	'23.81.209.96',
	'23.81.209.97',
	'212.8.240.128',
	'212.8.240.129',
	'212.8.240.130',
	'212.8.240.131',
	'109.236.87.76',
	'109.236.87.78',
	'103.120.66.35',
	'103.9.76.189',
	'104.200.132.6',
	'134.19.189.61',
	'155.94.183.3',
	'172.98.66.12',
	'181.214.48.22',
    # ... other IPs
);
    return $ip_list[rand @ip_list];
}

sub CommentsList
{
	my ($cmt_type,$cmt_ext_id) = @_;
	my $list = $db->SelectARef("SELECT *, INET_NTOA(cmt_ip) as ip, DATE_FORMAT(created,'%M %e, %Y') as date, usr_avatar, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec2
								FROM Comments AS c, Users AS u
								WHERE c.cmt_type=?
								AND c.cmt_ext_id=?
								AND c.usr_id=u.usr_id
								ORDER BY c.created DESC", $cmt_type, $cmt_ext_id);

	for (@$list)
	{
		$_->{cmt_text}=~s/\n/<br>/gs;
		$_->{cmt_name} = "<a href='$_->{cmt_website}'>$_->{cmt_name}</a>" if $_->{cmt_website};
		$_->{ispremium} = $_->{exp_sec2}>0;
		$_->{usr_channel_name}||=$_->{usr_login};

		# Extracting the first two letters of the usr_login
		if (defined $_->{usr_login} && length $_->{usr_login} >= 1) {
			$_->{usr_login_short} = substr($_->{usr_login}, 0, 1);
		} else {
			# Handle cases where usr_login is undefined or shorter than 2 characters
			$_->{usr_login_short} = $_->{usr_login} // '';
		}

		if($ses->getUser && $ses->getUser->{usr_adm})
		{
			$_->{email} = $_->{cmt_email};
			$_->{adm} = 1;
		}
	}

	return $list;
}

sub encode32
{
    $_=shift;
    my($l,$e);
    $_=unpack('B*',$_);
    s/(.....)/000$1/g;
    $l=length;
    if($l & 7)
    {
    	$e=substr($_,$l & ~7);
    	$_=substr($_,0,$l & ~7);
    	$_.="000$e" . '0' x (5-length $e);
    }
    $_=pack('B*', $_);
    tr|\0-\37|A-Z2-7|;
    lc($_);
}

sub EncStatus
{
   print"Content-type:text/html\n\n";
   my $enc = $db->SelectRowCachedKey("enc$f->{id}",30,
   							"SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(started) as started2
                             FROM QueueEncoding
                             WHERE file_real_id=?
                             ORDER BY progress DESC",$f->{id});
   unless($enc)
   {
      my $file = $db->SelectRow("SELECT * FROM Files f, Servers s WHERE f.file_id=? AND f.srv_id=s.srv_id",$f->{id});

      print("\$('#enc_pp').html('Transferring')"),return if $c->{noplay_from_uploader_encoder} && $file->{srv_type}=~/^(UPLOADER|ENCODER)$/;

      my $qq = $db->SelectRow("SELECT * FROM QueueTransfer WHERE file_real_id=?",$f->{id});
      print("\$('#enc_pp').html('Transferring to other server')"),return if $qq->{srv_id2};

      print("window.setTimeout('window.location.reload()',3000);"),return if $file && ($file->{file_size_n} || $file->{file_size_l} || $file->{file_size_h});

      print("\$('#enc_pp').html('Internal problem')");

      return;
   }
   if($enc->{error})
   {
       print"\$('#enc_pp').html('Encoding failed')";
   }
   elsif($enc->{status} eq 'PENDING')
   {
      #my $prem="AND premium=1" if $enc->{premium};
      $enc->{priority}||=0;
      my $filter = $c->{enc_priority_time} ? "AND created<='$enc->{created}' AND priority>$enc->{priority}" : "AND priority>=$enc->{priority} AND created<'$enc->{created}'";
      my $qq = $db->SelectOne("SELECT COUNT(DISTINCT file_real_id)
      							FROM QueueEncoding
      							WHERE srv_id=?
      							AND file_real<>?
      							$filter",
      							$enc->{srv_id},
      							$enc->{file_real},
      							);
      $qq++;
      print"\$('#enc_pp').html('$ses->{lang}->{lng_download_pending_in_queue} #$qq')";
   }
   else
   {
      my $left = int $enc->{started2} * (100 / $enc->{progress} - 1) if $enc->{progress}>1;

      my $out = $enc->{quality} eq 'p' ? "Generating preview" : "$ses->{lang}->{lng_download_encoding_done_prc}: $enc->{progress}%<br>$left $ses->{lang}->{lng_download_seconds_left}";
      print"\$('#enc_pp').html('$out')";
   }
   return;
}

sub getVideoVersions
{
    my ($file) = @_;
    my @versions;
    for my $mode ('o',reverse @{$c->{quality_letters}},'p')
    {
      next unless $file->{"file_size_$mode"};
      my $x = $ses->vInfo($file,$mode);
      $x->{vid_title} = $c->{quality_labels_full}->{$mode};
      $x->{vid_mode} = $mode||'o';
      $x->{file_code} = $file->{file_code};
      $x->{quality_download_link} = $ses->makeDownloadLink($file,$x->{vid_mode});
      $x->{not_available}=1 unless $c->{"vid_play_$ses->{utype}_$mode"};
      push @versions, $x;
    }
    return \@versions;
}

sub DeURL
{
    $ses->{form}->{no_hdr}=1;
    $ses->PrintTemplate("deurl.html", msg => "Invalid link ID") unless $f->{id}=~/^\w+$/;
    my $file_id = $ses->decode_base36($f->{id});
    my $file = $db->SelectRow("SELECT * FROM Files WHERE file_id=?",$file_id);
    $ses->PrintTemplate("deurl.html", msg => "File was deleted") unless $file;
    $ses->PrintTemplate("deurl.html",
                        %$file,
                        m_j_hide    => $c->{m_j_hide},
                        m_j_instant => $c->{m_j_instant},
                       );
}

sub formatTime
{
   my $l = shift;
   my $hh = sprintf("%02d",$l/3600);
   my $mm = sprintf("%02d",($l%3600)/60);
   my $ss = sprintf("%02d",$l%60);
   my $sss= sprintf("%03d",1000*($l - $hh*3600 - $mm*60 - $ss));
   return "$hh:$mm:$ss.$sss";
   #die"$hh,$mm,$ss" if $l>2;
   #my $tt = sprintf("%02d:%02d:%.03f", $hh, $mm, $ss );
   #$tt=~s/^00:(\d\d:\d\d)$/$1/;
}

sub GetSlides
{
    print"Content-type: text/vtt\n\n";
    # if($c->{m_u})
    # {
    #   my $res = $ses->db->cacheDB->get("s-$f->{file_code}");
    #   print($res),return if $res;
    # }
    #my $file = $db->SelectRowCached("SELECT * FROM Files f, Servers s WHERE f.file_code=? AND f.srv_id=s.srv_id",$f->{file_code});
    #return unless $file;

    #$ses->getVideoInfo($file);

    my $out="WEBVTT\n\n";

    #my ($fw,$fh) = (108,60);
    my ($fw,$fh) = ($c->{thumb_width},$c->{thumb_height});
    my $frames = $c->{m_z_cols}*$c->{m_z_rows};
    my $dt = $f->{length}/$frames;
    my $url = $f->{url};
    for my $i (0..$frames-1)
    {
        my $x = $fw * ($i % $c->{m_z_cols});
        my $y = $fh * int($i / $c->{m_z_cols});
        my $x2 = $fw;
        my $y2 = $fh;
        my $t1 = formatTime( $i*$dt );
        my $t2 = formatTime( ($i+1)*$dt );
        $out.="$t1 --> $t2\n$url#xywh=$x,$y,$x2,$y2\n\n";
    }

    $ses->db->cacheDB->set("s-$f->{file_code}", $out, 60*60) if $c->{m_u};

    print $out;
}

sub sendBack
{
    print"Content-type:text/html\n\n".shift;
}

sub getMoreFiles
{
      my ($file,$more_files_number) = @_;
      $more_files_number ||= $c->{more_files_number};
      my @more_files;
      if($file->{file_fld_id})
      {
          my $more_files1 = $db->SelectARefCached(600,"SELECT f.*, s.*, u.usr_login as usr_login_v
                                        FROM (Files f, Servers s)
                                        LEFT JOIN Users u ON f.usr_id=u.usr_id
                                        WHERE f.usr_id=?
                                        AND file_fld_id=?
                                        AND file_public=1
                                        AND (file_size_n>0 OR file_size_p>0)
                                        AND file_title>?
                                        AND file_id<>?
                                        AND f.srv_id=s.srv_id
                                        ORDER BY file_title
                                        LIMIT ?", $file->{usr_id}, $file->{file_fld_id}, $file->{file_title}, $file->{file_id}, $more_files_number-1 );
          my $limit_post = $more_files_number - $#$more_files1 - 1;
          my $more_files2 = $db->SelectARefCached(600,"SELECT f.*, s.*, u.usr_login as usr_login_v
                                                FROM (Files f, Servers s)
                                                LEFT JOIN Users u ON f.usr_id=u.usr_id
                                                WHERE f.usr_id=?
                                                AND file_fld_id=?
                                                AND file_public=1
                                                AND (file_size_n>0 OR file_size_p>0)
                                                AND file_title<?
                                                AND file_id<>?
                                                AND f.srv_id=s.srv_id
                                                ORDER BY file_title
                                                LIMIT ?", $file->{usr_id}, $file->{file_fld_id}, $file->{file_title}, $file->{file_id}, $limit_post );
          push @more_files, @$more_files1;
          push @more_files, @$more_files2;
          return \@more_files if @more_files;
      }

        my ($core) = $file->{file_title}=~/^(.+?)\s(EP\d+|E\d+|S\d+E\d+)/i;
        $core=~s/[\'\"]+//g;
        if($core)
        {
         my $more_files1 = $db->SelectARefCached("SELECT f.*, s.*, u.usr_login as usr_login_v
                                        FROM (Files f, Servers s)
                                        LEFT JOIN Users u ON f.usr_id=u.usr_id
                                        WHERE f.usr_id=?
                                        AND file_size_n>0
                                        AND file_title LIKE \"$core %\"
                                        AND file_id>?
                                        AND f.srv_id=s.srv_id
                                        ORDER BY file_id
                                        LIMIT ?",$file->{usr_id},$file->{file_id},$more_files_number-1);

        my $limit_pre = $more_files_number - $#$more_files1 - 1;
        my $more_files_pre = $db->SelectARefCached("SELECT f.*, s.*, u.usr_login as usr_login_v
                                          FROM (Files f, Servers s)
                                          LEFT JOIN Users u ON f.usr_id=u.usr_id
                                          WHERE f.usr_id=?
                                          AND file_size_n>0
                                          AND file_title LIKE \"$core %\"
                                          AND file_id<?
                                          AND f.srv_id=s.srv_id
                                          ORDER BY file_id DESC
                                          LIMIT ?",$file->{usr_id},$file->{file_id},$limit_pre);
        @$more_files_pre = reverse @$more_files_pre;
        #unshift @$more_files, @$more_files_pre;
        push @more_files, @$more_files_pre;
        push @more_files, @$more_files1;
        return \@more_files if @more_files;
       }


         my $more_files1 = $db->SelectARefCached(600,"SELECT f.*, s.*, u.usr_login as usr_login_v
                                        FROM (Files f, Servers s)
                                        LEFT JOIN Users u ON f.usr_id=u.usr_id
                                        WHERE f.usr_id=?
                                        AND file_public=1
                                        AND file_size_n>0
                                        AND cat_id=?
                                        AND file_id>?
                                        AND f.srv_id=s.srv_id
                                        ORDER BY file_id
                                        LIMIT ?",$file->{usr_id},$file->{cat_id},$file->{file_id},$more_files_number-1);

        my $limit_pre = $more_files_number - $#$more_files1 - 1;
        my $more_files_pre = $db->SelectARefCached(600,"SELECT f.*, s.*, u.usr_login as usr_login_v
                                          FROM (Files f, Servers s)
                                          LEFT JOIN Users u ON f.usr_id=u.usr_id
                                          WHERE f.usr_id=?
                                          AND file_public=1
                                          AND file_size_n>0
                                          AND cat_id=?
                                          AND file_id<?
                                          AND f.srv_id=s.srv_id
                                          ORDER BY file_id DESC
                                          LIMIT ?",$file->{usr_id},$file->{cat_id},$file->{file_id},$limit_pre);
        @$more_files_pre = reverse @$more_files_pre;
        #unshift @$more_files, @$more_files_pre;
        push @more_files, @$more_files_pre;
        push @more_files, @$more_files1;
        return \@more_files;

      # for(@more_files)
      # {
      #    $_->{file_title_txt} = $ses->shortenString( $_->{file_title}||$_->{file_name}, $c->{display_max_filename} );
      #    $_->{download_link} = $ses->makeFileLink($_);
      #    $_->{file_name} =~ s/_/ /g;
      #    $ses->getVideoInfo($_);
      # }
      #return \@more_files;
}

sub Related
{
     print"Content-type:application/rss+xml\n\n";
     return unless $c->{player_related};
     return if $c->{highload_mode};
     my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{code});
     return $ses->message("No file") unless $file;
     my $more_files = getMoreFiles($file,$c->{player_related});
     $ses->processVideoList($more_files);

      print qq[<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/"><channel>\n];
      for(@$more_files)
      {
      	$_->{file_title}=~s/\&/\&amp;/g;
        print qq[<item>
<title>$_->{file_title}</title>
<link>$_->{download_link}</link>
<media:thumbnail url="$_->{video_thumb_url}"/></item>];
      }
      print qq[</channel></rss>];
}

# https://github.com/tknorris/script.module.urlresolver/tree/master/lib/urlresolver/plugins
# sub Pair
# {
# 	$ses->{form}->{no_hdr}=1;
# 	if($ENV{REQUEST_URI}=~/file_code=(\w{12})\&check/i)
# 	{
# 		$f->{file_code} = $1;
# 		require JSON;
# 		print"Content-type:text/plain\n\n";
# 		print(JSON::encode_json({"status"=>"false", "response"=>"Not paired or expired"})),return unless $db->SelectOne("SELECT ip FROM Pairs WHERE ip=INET_ATON(?) AND created>NOW()-INTERVAL ? HOUR", $ses->getIP, $c->{m_5_hours} );
# 		my $file = $db->SelectRow("SELECT * FROM Files f, Servers s WHERE f.file_code=? AND f.srv_id=s.srv_id",$f->{file_code});
# 		print(JSON::encode_json({"status"=>"false", "response"=>"File not found"})),return unless $file;
# 		my $hh;
# 		my $name_n=$c->{vid_resize_n};
# 		my $name_h=$c->{vid_resize_h};
# 		my $name_l=$c->{vid_resize_l};
# 		$name_n="$1p" if $name_n=~/x(\d+)$/i;
# 		$name_h="$1p" if $name_h=~/x(\d+)$/i;
# 		$name_l="$1p" if $name_l=~/x(\d+)$/i;
# 		$hh->{$name_n} = genDirectLink2($file,'n',"$file->{file_real}_n.mp4") if $file->{file_size_n};
#    		$hh->{$name_h} = genDirectLink2($file,'h',"$file->{file_real}_h.mp4") if $file->{file_size_h};
#    		$hh->{$name_l} = genDirectLink2($file,'l',"$file->{file_real}_l.mp4") if $file->{file_size_l};
#    		print JSON::encode_json( { "status"=>"true", "response"=>$hh } );
#    		return;
# 	}
# 	if($f->{pair})
# 	{
# 		return $ses->redirect_msg('/pair',"Invalid captcha") if $c->{m_5_captcha} && !$ses->checkRecaptcha;
# 		my $paired = $db->SelectOne("SELECT ip FROM Pairs WHERE ip=INET_ATON(?) AND created>NOW()-INTERVAL ? HOUR", $ses->getIP, $c->{m_5_hours} );
# 		$db->Exec("INSERT INTO Pairs SET ip=INET_ATON(?), created=NOW()",$ses->getIP) unless $paired;
# 		return $ses->PrintTemplate("pair.html", ip => $ses->getIP, pair_hours => $c->{m_5_hours}, paired => 1 );
# 	}
# 	my $captcha = $c->{m_5_captcha} ? $ses->genRecaptcha : '';
# 	return $ses->PrintTemplate("pair.html", ip => $ses->getIP, pair_hours => $c->{m_5_hours}, captcha => $captcha );
# }

sub StreamPage
{
	my $stream = $db->SelectRowCached("SELECT * FROM Streams s, Users u
										WHERE s.stream_code=?
										AND s.usr_id=u.usr_id",$f->{stream_code});
	return $ses->message("Stream was deleted or stream code is wrong") unless $stream;
	$stream->{stream_descr}=~s/\n/<br>/g;
	return $ses->PrintTemplate("stream_page.html",
								%$stream,
								);
}

sub StreamPlayer
{
	$ses->{form}->{no_hdr}=1;
	my $stream = $db->SelectRow("SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(started) as dt
										FROM Streams s, Hosts h, Users u
										WHERE s.stream_code=?
										AND s.usr_id=u.usr_id
										AND s.host_id=h.host_id",$f->{stream_code});
	return sendBack("Stream not found") unless $stream;
	return sendBack(qq|<html><meta http-equiv="refresh" content="5"><body>Starting the stream in a few seconds...</body></html>|),return if $stream->{dt}<15;
	return sendBack(qq|<html><meta http-equiv="refresh" content="15"><body>Stream is OFFLINE</body></html>|),return if $stream->{stream_live}==0;
	$stream->{m_q_stop_invis_after}=$c->{m_q_stop_invis_after};
	my $custom = '_jw8' if $c->{player} eq 'jw8';
	$stream->{jw8_key} = $c->{jw8_key};
	return $ses->PrintTemplate("stream_player$custom.html",
								%$stream,
								);
}

sub StreamPing
{
	print("Content-type:application/javascript\n\n");
	return unless $f->{stream_id}=~/^\d+$/;

	unless($f->{check})
	{
		$db->Exec("INSERT INTO Stream2IP
					SET stream_id=?, ip=INET_ATON(?), created=NOW()
					ON DUPLICATE KEY UPDATE created=NOW()",
					$f->{stream_id}, $ses->getIP );
		return;
	}
	my $online = $db->SelectOne("SELECT COUNT(*) FROM Stream2IP WHERE stream_id=? AND created>NOW()-INTERVAL 60 SECOND", $f->{stream_id});
	print"\$('#online').text('$online');";
}

sub IProxy
{
	 my ($code) = $f->{name}=~/(\w{12})0000\./i;
	    ($code) = $f->{name}=~/(\w{12})[\.\_]/i unless $code;

	print($ses->{cgi_query}->header(-status => 404)),return unless $c->{m_i} && $code;

	my $file = $db->SelectRowCached("SELECT * FROM Files f, Servers s WHERE f.file_code=? AND f.srv_id=s.srv_id LIMIT 1",$code);
	return $ses->redirect("$c->{site_url}/images/default.jpg") unless $file;
	$f->{name}=~s/^\w{12}/$file->{file_real}/ if $file->{file_real} ne $file->{file_code};

	my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
	return $ses->redirect("$file->{srv_htdocs_url}/i/$file->{disk_id}/$dx/$f->{name}");
}

sub PlayerDDL
{
	print"Content-type:application/json\n\n";
	print(JSON::XS::encode_json([{"error"=>"nofile"}])),return unless $ENV{REQUEST_METHOD} eq 'POST';
	my $file = $db->SelectRowCached("SELECT * FROM Files WHERE file_code=?",$f->{file_code});
	require JSON::XS;
	print(JSON::XS::encode_json([{"error"=>"nofile"}])),return unless $file;
	print(JSON::XS::encode_json([{"error"=>"badhash"}])),return unless $ses->HashCheck($f->{hash},$file->{file_id});
	VideoMakeCode($file,'direct');
	my $link = $file->{hls_direct}||$file->{dash_direct}||$file->{direct_link};
	#$link
	my @tracks=();
	if($c->{srt_on} && $c->{srt_langs})
	{
		my @arr = split /\s*\,\s*/, $c->{srt_langs};
		my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
		my $dir = "$c->{site_path}/srt/$dx";
		my $srt_cook = $ses->getCookie("srt_cook");
		my @list;
		my $srtauto=',"default": true' if $c->{srt_auto_enable};
		for(@arr)
		{
		  push @tracks, {file => "/srt/$dx/$file->{file_code}_$_.vtt", label => $_, kind => "captions"} if -f "$dir/$file->{file_code}_$_.vtt";
		  push @tracks, {file => "/srt/$dx/$file->{file_code}_$_.srt", label => $_, kind => "captions"} if -f "$dir/$file->{file_code}_$_.srt";
		  push @tracks, {file => "/srt/$dx/$file->{file_code}_$_\_$srt_cook.vtt", label => "My: $_", kind => "captions"} if -f "$dir/$file->{file_code}_$_\_$srt_cook.vtt";
		}
	}
	push @tracks, {file => "/dl?b=get_slides&length=$file->{file_length}&url=$file->{img_timeslide_url}", kind => "thumbnails"} if $c->{m_z} && $c->{time_slider};
	$link =~ tr/012567/567012/;
	my $seed = $ses->randchar(16);
	if($c->{player_hidden_link_tear})
	{
		require Crypt::Tea_JS;
		$link = Crypt::Tea_JS::encrypt($link, $seed);
		$seed =~ tr/012567/567012/;
	}

	if($c->{player} eq 'jw8')
	{
		my $ff = { "file"=>"$link", "image"=>"$file->{player_img}", "tracks"=>\@tracks, seed=>$seed };
		print(JSON::XS::encode_json([$ff]));
	}
	elsif($c->{player} eq 'vjs')
	{
		my $ff = { "src"=>"$link", seed=>$seed };
		print(JSON::XS::encode_json($ff));
	}
}

sub selectAds
{
	my ($file) = @_;
	$file->{premium}=1 if $file->{exp_sec}>0;
	my $owner_ads_on = $ses->checkModSpecialRights('m_9',$file);
	if($owner_ads_on || $c->{m_9_override_id})
	{
		my $ads = $db->SelectARefCached("SELECT * FROM Ads WHERE usr_id=? AND ad_adult=? AND ad_disabled=0", $file->{usr_id}, $file->{file_adult} ) if $owner_ads_on;
		   $ads = $db->SelectARefCached("SELECT * FROM Ads WHERE usr_id=? AND ad_adult=? AND ad_disabled=0", $c->{m_9_override_id}, $file->{file_adult} ) if !$ads && $c->{m_9_override_id};
		my $sum;
		$sum+=$_->{ad_weight} for @$ads;
		$sum||=1;
		my $rnd = int(rand $sum);
		my $i;
		my $ad;
		for(@$ads)
		{
			$i+=$_->{ad_weight};
			if($rnd < $i){ $ad=$_; last; }
		}
		$file->{ad_code} = $ad->{ad_code};
	}
}

1;
