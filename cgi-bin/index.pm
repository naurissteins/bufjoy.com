package index;

### SibSoft.net ###
use strict;
use utf8;
use lib '.';
#use CGI::Carp qw(fatalsToBrowser);
use XFileConfig;
use Session;
use XUtils;
use File::Basename;
use File::ReadBackwards; # To read the log file backwards
use HTML::Template::Pro;

my ($ses,$f,$db,$ipt,$utype);
$c->{ip_not_allowed}=~s/\./\\./g;

sub run
{
	my ($query,$dbc) = @_;

	$ses = Session->new($query,$dbc);

	$ses->{fast_cgi} = $c->{fast_cgi};

	if($c->{ip_not_allowed} && $ses->getIP=~/$c->{ip_not_allowed}/)
	{
		return sendBack("Your IP was banned by administrator");
	}

	$f = $ses->f;
	$f->{op}||='';
	my $op = $f->{op};
	$db ||= $ses->db;

	if($c->{banned_countries})
	{
		 my $country=$ses->getMyCountry;
		 return $ses->message("Your country is not allowed on this site") if $country=~/^($c->{banned_countries})$/i;
	}

	if($f->{design}=~/^(\d+)$/)
	{
		$ses->setCookie("design",$1,'+300d');
		return $ses->redirect($c->{site_url});
	}
	&ChangeLanguage if $f->{lang};

my $db = $ses->db;
XUtils::CheckAuth($ses) unless $f->{op} eq 'login';
return if $ses->{returning};
return $ses->message($c->{maintenance_full_msg}||"The website is under maintenance.","Site maintenance") if $c->{maintenance_full} && $f->{op}!~/^(admin_|login)/i;

$ses->loadUserData();

if($ses->getUser && $ses->getUser->{usr_allowed_ips} && $f->{op} ne 'logout')
{
  my $pass;
  for my $ip (split(/,\s*/,$ses->getUser->{usr_allowed_ips}))
  {
	 $ip=~s/\.\*//g;
	 $ip=~s/\./\\\./g;
	 $pass=1 if $ses->getIP =~ /^$ip/;
  }
  unless($pass)
  {
	 $ses->setCookie($ses->{auth_cook},"");
	 $ses->{user}={};
	 return $ses->message("You can't login from this IP.");
  }
}

$utype = $ses->getUser ? ($ses->getUser->{premium} ? 'prem' : 'reg') : 'anon';

$c->{$_}=$c->{"$_\_$utype"} for qw(max_upload_files
											  disk_space
											  max_upload_filesize
											  max_upload_files
											  download_countdown
											  captcha
											  ads
											  bw_limit
											  remote_url
											  direct_links
											  down_speed
											  add_download_delay
											  max_download_filesize
											  torrent_dl_slots
											  video_embed
											  video_dl_orig
											  max_watch_time
											  fullscreen
											  pre_download
											  queue_url
											  queue_url_max
											  upload_enabled
											  max_folders_limit
											  );

RegisterExternal('twitter')	  if $f->{tid} && $f->{tname} && $f->{op} eq 'register_ext';

my $sub={
	 login			=> \&LoginPage,
	 news			 => \&News,
	 news_details  => \&NewsDetails,
	 contact		 => \&Contact,
	 registration  => \&Register,
	 register_save => \&RegisterSave,
	 register_ext  => \&RegisterExternal,
	 resend_activation => \&ResendActivationCode,
	 upload_result => \&UploadResult,
	 #download1	  => \&Download1,
	 #download2	  => \&Download2,
	 page			 => \&Page,
	 page_static	=> \&PageStatic,
	 forgot_pass	=> \&ForgotPass,
	 contact_send  => \&ContactSend,
	 user_public	=> \&UserPublic,
	 tags			=> \&Tags,
	 user_folder	=> \&UserFolder,
	 user_playlist	=> \&UserPlaylist,
	 payments		=> \&Payments,
	 checkfiles	 => \&CheckFiles,
	 search		  => \&Search,
	 creator			=> \&Creator,
	 change_lang	=> \&ChangeLanguage,
	 report_file	=> \&ReportFile,
	 api_get_limits => \&APIGetLimits,
	 comment_add	=> \&CommentAdd,
	 cmt_del		 => \&CommentDel,
	 del_file		=> \&DelFile,
	 links			=> \&Links,
	 video_embed	=> \&VideoEmbed,
	 unsubscribe	=> \&EmailUnsubscribe,
	 api_reseller  => \&APIReseller,
	 make_money	 => \&MakeMoneyPage,
	 upload_srt	 => \&UploadSRT,
	 vote			 => \&Vote,
	 api_reference => \&APIReference,
	 my_ads		  => \&MyAds,
	 my_ads_form	  => \&MyAdsForm,
	 x1				=> \&X1,
	 msg			  => \&Msg,

			}->{ $f->{op} };

return &$sub if $sub;

return PaymentComplete($1) if $ENV{QUERY_STRING}=~/payment_complete=(.+)/;
return PaymentComplete($1) if $ENV{QUERY_STRING}=~/lr_merchant_ref=(\d+)/;

return RegisterConfirm() if $f->{confirm_account};

$sub={
	 upload				=> \&Upload,
	 upload_file			=> \&UploadFile,
	 upload_url			=> \&UploadURL,
	 upload_torrent		=> \&UploadTorrent,
	 upload_clone		=> \&UploadClone,
	 upload_ftp			=> \&UploadFTP,
	 upload_tus			=> \&UploadTUS,
	 my_account			=> \&MyAccount,

	 my_password			=> \&MyPassword,
	 my_email			=> \&MyEmail,
	 my_referrals		=> \&MyReferrals,
	 my_files			=> \&MyFiles,
	 my_files_deleted	=> \&MyFilesDeleted,
	 my_files_export		=> \&MyFilesExport,
	 my_files_dmca		=> \&MyFilesDMCA,
	 my_views			=> \&MyViews,
	 my_reports			=> \&MyReports,
	 my_reports_day		=> \&MyReportsDay,
	 my_torrents			=> \&MyTorrents,
	 my_reseller			=> \&MyReseller,
	 my_watermark		=> \&MyWatermark,
	 my_snapshot			=> \&MySnapshot,
	 my_playlists		=> \&MyPlaylists,
	 my_playlist_files	=> \&MyPlaylistFiles,
	 file_edit			=> \&FileEdit,
	 fld_edit			=> \&FolderEdit,
	 request_money		=> \&RequestMoney,
	 add_to_playlist		=> \&AddToPlaylist,
	 moderator_files		=> \&ModeratorFiles,
	 moderator_files_approve => \&ModeratorFilesApprove,
	 moderator_reports	=> \&ModeratorReports,
	 moderator_comments	=> \&ModeratorComments,
	 moderator_files_featured => \&ModeratorFilesFeatured,
	 folder_search		=> \&FolderSearch,
	 legal_tool			=> \&LegalTool,
	 ajax_new_folder		=> \&AjaxNewFolder,
	 stream_form			=> \&StreamForm,
	 stream_save			=> \&StreamSave,
	 my_streams		  	=> \&MyStreams,
	 login_code		  	=> \&LoginCode,
	 ajax_find_copies 	=> \&AjaxFindCopies,
	 ticket_create	  	=> \&TicketCreate,
	 ticket_list	  	  	=> \&TicketList,
	 ticket_view		  	=> \&TicketView,
	 ticket_reply	  	=> \&TicketReply,
	 admin_ticket_list	=> \&AdminTicketList,
	 admin_ticket_view	=> \&AdminTicketView,
	 admin_ticket_reply	=> \&AdminTicketReply,
	 logout				=> sub{$ses->Logout},
	 #### Custom ###
	 dashboard			=> \&Dashboard,
	 serverlogs         => \&ServerLogs,
	 ### Custom ###

	 }->{ $f->{op} };

if($ENV{HTTP_REFERER} && $sub && !$ses->{ref_ok})
{
	my ($dm)=$ENV{HTTP_REFERER}=~/\/\/([^\/]+)/;
	$dm=~s/^(www|main|srt)\.//;
	$dm=~s/:.*$//;
	my $pass = 1 if $ses->{domain} eq $dm;
	$pass = 1 if !$pass && $db->SelectOne("SELECT srv_id FROM Servers WHERE srv_cgi_url LIKE CONCAT('https://',?,'%')",$dm);
	$pass=1 if $ENV{HTTP_REFERER} eq 'https://www.facebook.com/' && $ENV{REQUEST_URI}=~/my_account/; # social login fix
	print("Content-type:text/html\n\nGo to <a href='$ENV{REQUEST_URI}'>http://$ses->{domain}$ENV{REQUEST_URI}</a>"),return unless $pass;
}

if($sub && $ses->getUser)
{
	#return $ses->message("Access denied") if $f->{op}=~/^admin_/i && !$ses->getUser->{usr_adm} && $f->{op}!~/^(admin_reports|admin_comments)$/i;
	&$sub;
}
elsif($sub)
{
	$f->{redirect}=$ENV{REQUEST_URI};
	LoginPage();
}
else
{
	IndexPage();
}

}

sub X1
{
  return $ses->message("IP:".$ses->getIP." Country:".$ses->getMyCountry);
  #return $ses->message("Country:".$ses->getCountryCode('1.2.3.4'));
}

sub sendBack
{
	 print"Content-type:text/html\n\n".shift;
}

sub LoginPage
{
	if($f->{login} || $f->{method})
	{
		my $user = Login();
		unless($user)
	  {
		  $db->Exec("INSERT INTO LoginProtect SET usr_id=?, ip=INET_ATON(?)", $ses->{user}->{usr_id}||0, $ses->getIP);
		  $f->{msg}=$ses->{lang}->{lng_login_incorrect_username_or_password};
		  delete $ses->{user};
	  }
	}
	$f->{login}||=$ses->getCookie('login');
	$f->{redirect}=~s/[\0\"\'\<\>]+//g;
	$f->{login}=~s/[\0\"\'\<\>]+//g;
	my $recaptcha=$ses->genRecaptcha if $c->{login_captcha} || $f->{ca} || $db->SelectOne("SELECT COUNT(*) FROM LoginProtect WHERE ip=INET_ATON(?) AND created>NOW()-INTERVAL ? HOUR",$ses->getIP,$c->{login_fail_last_hours}) > $c->{login_fail_max_attemps};
	$recaptcha='' unless $c->{recaptcha_pub_key} && $c->{recaptcha_pri_key};
	$ses->PrintTemplate("login.html",
								msg=>$f->{msg},
								login=>$f->{login},
								redirect=>$f->{redirect},
								'external_sites_login'	=> $c->{m_l},
								recaptcha => $recaptcha,
								%$c,
							 );
}

sub Login
{
  my ($no_redirect,$instant) = @_;

  if($f->{method} && !($f->{login} && $f->{password}))
  {
	 # Login through the external plugins
	 my $url = $ses->getPlugins('Login')->get_auth_url($f);
	 return $ses->message("Login failed") if !$url;
	 return $ses->redirect($url);
  }

  #($f->{login}, $f->{password}) = split(':',$ses->decode_base64($ENV{HTTP_CGI_AUTHORIZATION})) if $instant;
  #$f->{login}=~s/[^\w\-\_]+//g;
  #my $usr_id = $db->SelectOneCached("SELECT usr_id FROM Users WHERE usr_login=?",$f->{login}) || 0;

  $f->{login}=~s/[^\w\.\@\-\_]+//gi;

  $ses->{user} = $db->SelectRow("SELECT *, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec
											FROM Users
											WHERE usr_login=?", $f->{login} );

  return 0 unless $ses->{user};

  my $captcha_required=1 if $c->{login_fail_max_attemps} && $c->{login_fail_last_hours} && $c->{recaptcha_pub_key} && $c->{recaptcha_pri_key} &&
		  $db->SelectOne("SELECT COUNT(*) FROM LoginProtect
								WHERE (ip=INET_ATON(?) OR usr_id=?)
								AND created>NOW()-INTERVAL ? HOUR", $ses->getIP, $ses->{user}->{usr_id}, $c->{login_fail_last_hours}) > $c->{login_fail_max_attemps};
  $captcha_required=1 if $c->{login_captcha} && !$f->{method};
  $captcha_required=0 unless $c->{recaptcha_pub_key} && $c->{recaptcha_pri_key};
  return $ses->redirect_msg("?op=login&ca=1","Captcha required") if $captcha_required && !$ses->checkRecaptcha;

  if($ses->{user}->{hashedpass})
  {
	 return 0 unless $ses->{user}->{usr_password} eq $f->{password};
  }
  else
  {
	 return 0 unless $ses->checkPasswdHash( $f->{password} );
  }
	# if($ses->{user}->{usr_password} =~ /^sha256:/)
	# {
	#	 require MIME::Base64;
	  # require PBKDF2::Tiny;
	#	 my ($algo, $turns, $salt, $data) = split(/:/, $ses->{user}->{usr_password});
	#	 return 0 unless PBKDF2::Tiny::verify( MIME::Base64::decode_base64($data), 'SHA-256', $f->{password}, MIME::Base64::decode_base64($salt), $turns );
	# }
	# else
	# {
	#	 # Legacy passwords
	#	 my $check_pass = $db->SelectOne("SELECT DECODE(usr_password, ?) FROM Users WHERE usr_id=?", $c->{pasword_salt}, $ses->{user}->{usr_id});
	#	 return 0 unless $check_pass eq $f->{password};
	# }
	$db->Exec("DELETE FROM LoginProtect WHERE ip=INET_ATON(?) AND created>NOW()-INTERVAL ? HOUR", $ses->getIP, $c->{login_fail_last_hours});


  $ses->{user}->{premium}=1 if $ses->{user}->{exp_sec}>0;
  if($ses->{user}->{usr_status} eq 'PENDING')
  {
	  my $id = $ses->{user}->{usr_id}."-".$ses->{user}->{usr_login};
	  delete $ses->{user};
	  return $ses->message("$ses->{lang}->{lng_login_account_not_confirmed_yet}<br><a href='?op=resend_activation&d=$id'>$ses->{lang}->{lng_login_resend_me_activation_email}</a>");
  }
  if($ses->{user}->{usr_status} eq 'BANNED')
  {
	  delete $ses->{user};
	  return $ses->redirect_msg('login.html', $ses->{lang}->{lng_login_your_account_banned} );
  }
  return if $instant;

  if($c->{login_limit1_ips} && $c->{login_limit1_hours})
  {
		my $ip = $ses->getIP;
		my $filter_ip = $c->{login_limit1_subnets} ? "AND (ip<INET_ATON('$ip')-65792 OR ip>INET_ATON('$ip')+65792)" : "AND ip<>INET_ATON('$ip')";
		my $diff_ips = $db->SelectOne("SELECT COUNT(distinct ip)
												 FROM LoginHistory
												 WHERE usr_id=?
												 AND created>NOW()-INTERVAL ? HOUR
												 $filter_ip
												",$ses->{user}->{usr_id},$c->{login_limit1_hours});

		return $ses->redirect_msg('login.html',"You've logged from $c->{login_limit1_ips} different IPs last $c->{login_limit1_hours} hours.<br>Do not share your account details with others.<br>Try to login again in a few minutes.") if $diff_ips>=$c->{login_limit1_ips};
  }
  if($c->{login_limit2_max} && $c->{login_limit2_hours})
  {
		my $logins = $db->SelectOne("SELECT COUNT(*) FROM LoginHistory WHERE usr_id=? AND created>NOW()-INTERVAL ? HOUR",$ses->{user}->{usr_id},$c->{login_limit2_hours});
		return $ses->redirect_msg('login.html',"You've logged in over $c->{login_limit2_max} times last $c->{login_limit2_hours} hours.<br>Login to your account blocked for some time.<br>Try to login again in a few minutes.") if $logins>=$c->{login_limit2_max};
  }

  $ses->loadUserData();

  if($ses->{user}->{usr_logout_sessions})
  {
  	$db->Exec("DELETE FROM Sessions WHERE usr_id=?",$ses->{user}->{usr_id});
  }
  if($ses->{user}->{usr_email_newip})
  {
  	if($db->SelectOne("SELECT COUNT(*) FROM LoginHistory WHERE usr_id=? AND created>NOW()-INTERVAL 24 HOUR AND ip<>INET_ATON(?)", $ses->{user}->{usr_id}, $ses->getIP ) > 0)
  	{
		my $t = $ses->CreateTemplate("login_email_newip.html");
		 $t->param( 'ip'=>$ses->getIP, agent => $ENV{HTTP_USER_AGENT} );
		 $ses->SendMailQueue($ses->{user}->{usr_email}, $c->{email_from}, "$c->{site_name}: account logged in from new IP", $t->output);
  	}
  }

  my $sess_id = $ses->randchar(16);
  #$db->Exec("DELETE FROM Sessions WHERE last_time + INTERVAL 5 DAY < NOW()");
  $db->Exec("INSERT INTO Sessions SET session_id=?, usr_id=?, ip=INET_ATON(?), last_time=NOW()",$sess_id,$ses->{user}->{usr_id},$ses->getIP);
  $db->Exec("UPDATE Users SET usr_lastlogin=NOW(), usr_lastip=INET_ATON(?) WHERE usr_id=?", $ses->getIP, $ses->{user}->{usr_id} );
  $db->Exec("INSERT INTO LoginHistory SET usr_id=?, ip=INET_ATON(?), agent=?", $ses->{user}->{usr_id}, $ses->getIP, $ENV{HTTP_USER_AGENT}||'');
  $ses->setCookie( $ses->{auth_cook} , $sess_id, '+30d' );
  $ses->setCookie('login',$f->{login},'+6M');

  if( $c->{email_validation_code}==2 ||
  	 ($c->{email_validation_code}==1 && $ses->{user}->{usr_adm}) ||
  	 ($c->{email_validation_code}==3 && $ses->{user}->{usr_notes}=~/LOGINEMAILVALIDATE/i)
  	)
  {
	 my $t = $ses->CreateTemplate("login_email_code.html");
	 my $login_code = $ses->randchar(10);
	 $db->Exec("UPDATE Users SET usr_login_code=? WHERE usr_id=?",$login_code,$ses->{user}->{usr_id});
	$t->param( 'ip'=>$ses->getIP, agent => $ses->getBrowser, login_code => $login_code );
	$ses->SendMailQueue($ses->{user}->{usr_email},$c->{email_from},"$c->{site_name}: login security code",$t->output);
	#return $ses->message($t->output);
  }

  return $ses->redirect( $f->{redirect} ) if $f->{redirect} && $f->{redirect}!~/login\.html$/i;
  return $ses->redirect( "$c->{site_url}/dashboard" ) unless $no_redirect;

  return $ses->{user};
}

sub LoginCode
{
	if($f->{code} eq $ses->getUser->{usr_login_code})
	{
	  $db->Exec("UPDATE Users SET usr_login_code='' WHERE usr_id=?",$ses->getUserId);
	  return $ses->redirect("/?op=my_account");
	}
	else
	{
	  return $ses->redirect_msg("/?op=my_account","Invalid code");
	}
}

sub Register
{
	my ($msg) = @_;
	$msg='' if ref($msg) eq 'CGI::Fast';
	#$msg='' if ref $msg ne 'SCALAR';
	my %secure = $ses->SecSave( 'register', 5, 'captcha' );
	$f->{$_}=$ses->SecureStr($f->{$_}) for qw(usr_login usr_email usr_pay_email);
	my $aff=$1 if $f->{aff_id}=~/^(\d+)$/;
	return $ses->message("Error: $ses->{lang}->{lng_registration_max_lim_reached}") if $ses->{"\x70"."\x6C\x67"}->{1} && $db->SelectOne("SELECT COUNT(*) FROM Users")>=100;
	my @payout_list = map{ {name=>$_} } split(/\s*\,\s*/,$c->{payout_systems});
	my @extra = map{ {name=>$_,field=>'usr_extra_'.lc($_)} } split(/\s*\,\s*/,$c->{extra_user_fields});
	$ses->PrintTemplate("registration.html",
							  #%captcha,
							  #'rand' => $rand,
							  %secure,
							  'usr_login' => $f->{usr_login},
							  'usr_email' => $f->{usr_email},
							  'usr_pay_email' => $f->{usr_pay_email},
							  "pay_type_$f->{usr_pay_type}"  => 1,
							  'msg'			  => $f->{msg}||$msg,
							  'payout_list'	=> \@payout_list,
							  'external_sites_login'	=> $c->{m_l},
							  %$c,
							  'extra_fields'			  => \@extra,
							  aff			 => $aff,
							 );
}

sub RegisterSave
{
	return $ses->redirect($c->{site_url}) unless $ENV{REQUEST_METHOD} eq 'POST';
	return Register() unless $ses->SecCheck( $f->{'rand'}, 'register', $f->{code}, 'captcha' );
	return Register("Error: $ses->{lang}->{lng_registration_username_too_short}") if length($f->{usr_login})<3;
	return Register("Error: $ses->{lang}->{lng_registration_username_too_long}") if length($f->{usr_login})>15;
	return Register("Error: Invalid login: reserved word") if $f->{usr_login}=~/^(admin|images|captchas|files)$/;
	return Register("Error: $ses->{lang}->{lng_registration_invalid_username}") unless $f->{usr_login}=~/^[\w\-\_]+$/;
	return Register("Error: Password contain bad symbols") if $f->{usr_password}=~/[<>"]/;
	return Register("Error: $ses->{lang}->{lng_registration_password_too_short}") if length($f->{usr_password})<4;
	return Register("Error: $ses->{lang}->{lng_registration_password_too_long}") if length($f->{usr_password})>32;
	return Register("Error: $ses->{lang}->{lng_registration_passwords_dont_match}") if $f->{usr_password} ne $f->{usr_password2};
	return Register("Error: $ses->{lang}->{lng_registration_email_invalid}") unless $f->{usr_email}=~/^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
	return Register("Error: $ses->{lang}->{lng_registration_mail_server_banned}") if $c->{mailhosts_not_allowed} && $f->{usr_email}=~/\@$c->{mailhosts_not_allowed}/i;
	return Register("Error: $ses->{lang}->{lng_registration_username_already_used}")  if $db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$f->{usr_login});
	return Register("Error: $ses->{lang}->{lng_registration_email_already_used}") if $db->SelectOne("SELECT usr_id FROM Users WHERE usr_email=?",$f->{usr_email});
	my $confirm_key = $ses->randchar(8) if $c->{registration_confirm_email};
	my $usr_status = $confirm_key ? 'PENDING' : 'OK';
	my $premium_days=0;
	$f->{coupon_code} = lc $f->{coupon_code};
	my $aff = $ses->getCookie('aff')||0;
	$f->{usr_pay_email}=~s/[^\w\-\_\.\@]+//g;
	$f->{usr_pay_type}=~s/[^\w\-\_]+//g;

	if($c->{coupons} && $f->{coupon_code})
	{
		my $hh;
		for(split(/\|/,$c->{coupons}))
		{
			$hh->{lc($1)}=$2 if /^(.+?)=(\d+)$/;
		}
		$premium_days = $hh->{$f->{coupon_code}};
		return Register("Invalid coupon code") unless $premium_days;
	}

	my $passwd_hash = $ses->genPasswdHash( $f->{usr_password} );

	$db->Exec("INSERT INTO Users
				  SET usr_login=?,
						usr_email=?,
						usr_password=?,
						usr_created=NOW(),
						usr_password_changed=CURDATE(),
						usr_premium_expire=NOW()+INTERVAL ? DAY,
						usr_security_lock=?,
						usr_status=?,
						usr_aff_id=?,
						usr_pay_email=?,
						usr_pay_type=?",$f->{usr_login},
											  $f->{usr_email},
											  $passwd_hash,
											  $premium_days,
											  $confirm_key||'',
											  $usr_status,
											  $aff,
											  $f->{usr_pay_email}||'',
											  $f->{usr_pay_type}||'');
	my $usr_id=$db->getLastInsertId;
	$db->Exec("INSERT INTO Stats SET day=CURDATE(), registered=1 ON DUPLICATE KEY UPDATE registered=registered+1");
	if($c->{extra_user_fields})
	{
		for(split(/\s*\,\s*/,$c->{extra_user_fields}))
		{
			 my $name = 'usr_extra_'.lc($_);
			 #$db->Exec("INSERT INTO UserData SET usr_id=?, name=?, value=?", $usr_id, $name, $f->{$name}) if $f->{$name};
			 $ses->saveUserData($name,$f->{$name},$usr_id);
		}
	}
	if($confirm_key)
	{
		my $t = $ses->CreateTemplate("registration_email.html");
		$t->param( 'usr_login'=>$f->{usr_login}, 'usr_password'=>$f->{usr_password}, 'confirm_id'=>"$usr_id-$confirm_key" );
		$ses->SendMailQueue($f->{usr_email}, $c->{email_from}, "$c->{site_name} $ses->{lang}->{lng_registration_email_title_registration_confirmation}", $t->output);
		#return $ses->message($ses->{lang}->{lng_registration_msg_account_created});
		return $ses->PrintTemplate("registration_success_checkmail.html");
	}
	elsif($aff)
	{
		 $db->Exec("INSERT INTO Stats2
						SET usr_id=?, day=CURDATE(),
							 refs=1
						ON DUPLICATE KEY UPDATE
							 refs=refs+1
					  ",$aff);
	}

	#my $err = $ses->ApplyPlugins('user_new', $f->{usr_login}, $f->{usr_password}, $f->{usr_email});
	#return $ses->message("Registration complete but there were plugin errors:<br><br>$err") if $err;
	registerPostprocess();

	$f->{login}	 = $f->{usr_login};
	$f->{password} = $f->{usr_password};
	Login();

	return $ses->redirect( $c->{site_url} );
}

sub RegisterConfirm
{
	my ($usr_id,$confirm_key)=split('-',$f->{confirm_account});
	my $user = $db->SelectRow("SELECT * FROM Users WHERE usr_id=? AND usr_security_lock=?",$usr_id,$confirm_key);
	unless($user)
	{
		return $ses->message("Invalid confirm code");
	}
	return $ses->message("Account already confirmed") if $user->{usr_status} ne 'PENDING';
	$db->Exec("UPDATE Users SET usr_status='OK', usr_security_lock='' WHERE usr_id=?",$user->{usr_id});

	registerPostprocess();

	if($user->{usr_aff_id})
	{
		 $db->Exec("INSERT INTO Stats2
						SET usr_id=?, day=CURDATE(),
							 refs=1
						ON DUPLICATE KEY UPDATE
							 refs=refs+1
					  ",$user->{usr_aff_id});
	}
	$ses->setCookie('login',$user->{usr_login},'+6M');

	return $ses->redirect_msg( '/login.html', 'Account confirmed' );
}

sub RegisterExternal
{
	 my ($method) = @_;
	 $method ||= $f->{method};
	 $ses->{ref_ok}=1; # hack to avoid REFERER security
	 my ($id,$provider,$email,$image_url,$name);

	 my $ret = $ses->getPlugins('Login')->finish($f) || return $ses->message("Auth failed");

	 my $pre = {
					 'vk'		  => 'vk',
					 'facebook'  => 'fb',
					 'twitter'	=> 'tw',
					 'google'	 => 'go',
				  }->{lc($f->{method})} || substr($f->{method},0,2);
	 my $sid = $pre.$ret->{usr_social_id};
	 $sid=~s/^vkvk/vk/;
	 $email = $ret->{usr_email};
	 return $ses->message("Something wrong with login") unless $ret->{usr_social_id};
	 my $user = $db->SelectRow("SELECT *, usr_password as password FROM Users WHERE usr_social_id=?",$sid);
	 $f->{redirect} = '?op=my_account';
	 if($user)
	 {
		  $f->{login} = $user->{usr_login};
		  $f->{password} = $user->{password};
		  $ses->{user}->{hashedpass}=1;
		  Login();
	 }
	 else
	 {
		  my $login = $ret->{usr_login}||$sid;
		  $login=~s/[^\w\-\_]+//g;
		  my $password = $ses->randchar(6);
		  my $aff = $ses->getCookie('aff')||0;
		  $db->Exec("INSERT INTO Users
						 SET usr_login=?,
							  usr_social_id=?,
							  usr_email=?,
							  usr_password=?,
							  usr_created=NOW(),
							  usr_premium_expire=NOW()+INTERVAL ? DAY,
							  usr_security_lock=?,
							  usr_status=?,
							  usr_aff_id=?",
						$login,
						$sid,
						$email||'',
						$ses->genPasswdHash( $password ),
						0,
						'',
						'OK',
						$aff,
					  );
		  $f->{login} = $login;
		  $f->{password} = $password;
		  registerPostprocess();
		  Login();
	 }
}

sub registerPostprocess
{
	 if($c->{m_f} && $c->{m_f_update_on_reg})
	 {
		  $ses->syncFTPUsers();
	 }
}

sub ResendActivationCode
{
	my ($adm_mode) = @_;
	($f->{usr_id},$f->{usr_login}) = split(/-/,$f->{d});
	my $user = $db->SelectRow("SELECT usr_id,usr_login,usr_email,usr_security_lock,DECODE(usr_password,?) as usr_password
										FROM Users
										WHERE usr_id=?
										AND usr_login=?",
										$c->{pasword_salt},$f->{usr_id},$f->{usr_login});
	return $ses->message("Invalid ID") unless $user;

	my $t = $ses->CreateTemplate("registration_email.html");
	$t->param( 'usr_login'=>$user->{usr_login}, 'usr_password'=>$user->{usr_password}, 'confirm_id'=>"$user->{usr_id}-$user->{usr_security_lock}" );
	$ses->SendMailQueue($user->{usr_email}, $c->{email_from}, "$c->{site_name} registration confirmation", $t->output);
	return $ses->redirect_msg("?op=admin_users","Activation email sent") if $adm_mode;
	return $ses->message("Activation email just resent.<br>To activate it follow the activation link sent to your e-mail.");
}

sub ForgotPass
{
	if($f->{usr_login} && $ENV{REQUEST_METHOD} eq 'POST')
	{
		return $ses->redirect_msg('?op=forgot_pass','Invalid captcha '.$ses->{form}->{msg}) unless $ses->SecCheck( $f->{'rand'}, 'forgotpass', $f->{code}, 'captcha' );
		my $user = $db->SelectRow("SELECT *
									FROM Users
									WHERE usr_login=?
									OR usr_email=?",$f->{usr_login},$f->{usr_login});
		unless($user)
		{
			#return $ses->redirect_msg('?op=forgot_pass',$ses->{lang}->{lng_forgotpassword_no_user_found});
			return $ses->message($ses->{lang}->{lng_forgotpassword_reminder_sent});
		}

		return $ses->message("Security Lock active! Can't reset password.") if $user->{usr_security_lock};

		my $sess_id = $ses->randchar(16);
		$db->Exec( "INSERT INTO Sessions (session_id,usr_id,last_time) VALUES (?,?,NOW())", $sess_id, $user->{usr_id} );

		my $t = $ses->CreateTemplate($c->{email_html} ? "forgot_pass_email.html" : "forgot_pass_email.txt");
		$t->param( 'usr_login'=>$user->{usr_login}, 'sess_id'=>$sess_id, ip=>$ses->getIP );
		$ses->SendMailQueue( $user->{usr_email}, $c->{email_from}, "$c->{site_name}: $ses->{lang}->{lng_forgotpassword_title}", $t->output );
		return $ses->message($ses->{lang}->{lng_forgotpassword_reminder_sent});
	}
	elsif($f->{sess_id} && $f->{password} && $f->{password2})
	{
		return $ses->message("Passwords do not match!") unless $f->{password} eq $f->{password2};
		my $usr_id = $db->SelectOne("SELECT usr_id FROM Sessions WHERE session_id=?",$f->{sess_id});
		return $ses->message("Invalid session id") unless $usr_id;
		my $passwd_hash = $ses->genPasswdHash( $f->{password} );
		$db->Exec("UPDATE Users SET usr_password=? WHERE usr_id=?", $passwd_hash, $usr_id );
		$db->Exec("DELETE FROM Sessions WHERE session_id=? LIMIT 1",$f->{sess_id});
		return $ses->redirect_msg('?op=login',"Your password was updated successfully.");
	}
	elsif($f->{sess_id})
	{
		return $ses->PrintTemplate("forgot_pass_reset.html", sess_id=>$f->{sess_id});
	}
	my %secure = $ses->SecSave( 'forgotpass', 2, 'captcha' );
	$ses->PrintTemplate("forgot_pass.html",%secure);
}

sub Upload
{
	 return $ses->redirect('?op=upload_url')		if $ses->getCookie('upload_mode') eq 'url';
	 return $ses->redirect('?op=upload_torrent')  if $ses->getCookie('upload_mode') eq 'torrent';
	 return $ses->redirect('?op=upload_clone')	 if $ses->getCookie('upload_mode') eq 'clone';
	 return $ses->redirect('?op=upload_ftp')		if $ses->getCookie('upload_mode') eq 'ftp';
	 return $ses->redirect('?op=upload_file');
}

sub UploadFile
{
	return $ses->message($c->{maintenance_upload_msg}||"Uploads are temporarily disabled due to site maintenance","Site maintenance") if $c->{maintenance_upload};
	$ses->setCookie('upload_mode','file');
	if($c->{uploads_selected_only})
	{
		 return $ses->message("You are not allowed to upload files") unless $ses->getUser->{usr_uploads_on};
	}
	else
	{
		 return $ses->message("You are not allowed to upload files") unless $c->{upload_enabled};
	}

	return $ses->message("You've exceeded max uploads daily limit: $c->{max_upload_files} files") if $c->{max_upload_files} && $db->SelectOne("SELECT COUNT(*) FROM Files WHERE usr_id=? AND file_created>NOW()-INTERVAL 24 HOUR",$ses->getUserId) >= $c->{max_upload_files};

	my $filter_type = $utype eq 'prem' ? "AND srv_allow_premium=1" : "AND srv_allow_regular=1";
	my $filter_load = "AND host_out <= host_net_speed*0.9" if $c->{overload_no_upload};
	my $logic = {'space'=>'srv_disk','round'=>'srv_last_upload','random'=>'RAND()'}->{$c->{next_upload_server_logic}};
	my $extra1;
	my $uploader_priority=3;
	if($c->{next_upload_server_logic} eq 'encodings')
	{
		  $extra1.=",(SELECT COUNT(*) FROM QueueEncoding q, Servers ss WHERE q.srv_id=ss.srv_id AND q.status='PENDING' AND q.error='' AND ss.host_id=h.host_id GROUP BY h.host_id) as eq";
		  $logic="eq, RAND()";
		  $uploader_priority=2 if $c->{skip_uploader_priority} &&
		  	$db->SelectOne("SELECT COUNT(*) as num
							FROM QueueEncoding q, Servers s
							WHERE q.status='PENDING'
							AND q.srv_id=s.srv_id
							AND s.srv_type='STORAGE'
							AND s.srv_status='ON'
							AND s.srv_encode=1
							AND s.srv_disk <= s.srv_disk_max
							GROUP BY s.host_id
							ORDER BY num
							LIMIT 1") < $c->{skip_uploader_priority};
	}
	my $server;
	my $usr_id=$ses->getUserId;
	$server = $db->SelectRow("SELECT s.*, h.*,
										  CASE srv_type WHEN 'UPLOADER' THEN 3 WHEN 'STORAGE' THEN 2 END as type
										  $extra1
										  FROM Servers s, Hosts h
										  WHERE srv_status='ON'
										  AND s.host_id=h.host_id
										  AND srv_disk <= srv_disk_max
										  AND srv_users_only LIKE '%,$usr_id,%'
										  ORDER BY type DESC, $logic
										  LIMIT 1");
	my $country=$ses->getMyCountry;
	$server = $db->SelectRow("SELECT s.*, h.*,
										  CASE srv_type WHEN 'UPLOADER' THEN 3 WHEN 'STORAGE' THEN 2 END as type
										  $extra1
										  FROM Servers s, Hosts h
										  WHERE srv_status='ON'
										  AND s.host_id=h.host_id
										  AND srv_disk <= srv_disk_max
										  $filter_type
										  $filter_load
										  AND srv_countries_only LIKE '%,$country,%'
										  ORDER BY type DESC, $logic
										  LIMIT 1") if $country && !$server;

	$server = $db->SelectRow("SELECT s.*, h.*,
							CASE srv_type WHEN 'UPLOADER' THEN $uploader_priority WHEN 'STORAGE' THEN 2 END as type
							$extra1
							FROM Servers s, Hosts h
							WHERE s.srv_status='ON'
							AND s.host_id=h.host_id
							AND s.srv_disk <= srv_disk_max
							$filter_type
							$filter_load
							AND srv_users_only=''
							AND srv_countries_only=''
							ORDER BY type DESC, $logic
							LIMIT 1") unless $server;


	my $server_selector = getUploadServersSelector( $server, $usr_id, $country );
	# $server = $db->SelectRow("SELECT * FROM Servers s, Hosts h WHERE s.srv_id=? AND s.host_id=h.host_id",$f->{srv_id})
	# 	if $f->{srv_id} && $ses->getUser && $server_selector;

	return $ses->message("We're sorry, there are no servers available for upload at the moment.<br>Refresh this page in some minutes.") unless $server;

	my $hh = prepareUploadData();
	$hh->{hosts} = $server_selector;

	$server->{srv_upload_url} = $server->{srv_cgi_url};
	$server->{srv_upload_url}=~s/\/cgi-bin//i;

	my $template = $f->{v}==2 ? "upload_form2.html" : "upload_form.html";

	#### Custom ####
	my $user = $ses->getUser;

	if($c->{m_e})
	{
		$user->{tickets_unread} = $db->SelectOne("SELECT COUNT(*) FROM Tickets WHERE usr_id=? AND unread>0",$ses->getUserId);
	}
	#### Custom ####

	$ses->PrintTemplate($template,
						%{$user},
						%$server,
						%$hh,
						%$c,
						max_upload_filesize_bytes => $c->{max_upload_filesize}*1024*1024,
						sess_id		=> $ses->getCookie( $ses->{auth_cook} ),
						utype		=> $utype,
	);
}

sub UploadURL
{
	return $ses->message($c->{maintenance_upload_msg}||"Uploads are temporarily disabled due to site maintenance","Site maintenance") if $c->{maintenance_upload};
	$ses->setCookie('upload_mode','url');
	if($c->{uploads_selected_only})
	{
		return $ses->message("You are not allowed to upload files") unless $ses->getUser->{usr_uploads_on};
	}
	else
	{
		return $ses->message("URL Uploads disabled for your account type.<br><a href='premium.html'>Upgrade your account</a>") unless $c->{remote_url};
	}

	if($f->{restart_errors})
	{
		$db->Exec("UPDATE QueueUpload
					  SET status='PENDING',size_dl=0,error='',srv_id=0
					  WHERE status='ERROR'
					  AND usr_id=?
					  AND error<>''", $ses->getUserId);
		$ses->redirect('?op=upload_url');
	}
	if($f->{delete_errors})
	{
		$db->Exec("DELETE FROM QueueUpload
					  WHERE status='ERROR'
					  AND usr_id=?
					  AND error<>''", $ses->getUserId);
		$ses->redirect('?op=upload_url');
	}
	if($f->{delete_pending})
	{
		$db->Exec("DELETE FROM QueueUpload
					  WHERE status='PENDING'
					  AND usr_id=?
					  ", $ses->getUserId);
		$ses->redirect('?op=upload_url');
	}

	if($f->{del_id})
	{
		$db->Exec("DELETE FROM QueueUpload WHERE id=? AND usr_id=? AND NOT (status='WORKING' AND updated>NOW()-INTERVAL 3 MINUTE)",$f->{del_id},$ses->getUserId);
		return $ses->redirect("?op=upload_url");
	}

	my $used = $db->SelectOne("SELECT COUNT(*) FROM QueueUpload WHERE usr_id=?",$ses->getUserId);
	my $slots_left = $c->{queue_url_max} ? $c->{queue_url_max}-$used : 999;

	my @extras;
	for('cat_id','file_public','file_adult','tags','fld_id')
	{
		push @extras, "$_=$f->{$_}" if $f->{$_};
	}

	for (split /\s*\,\s*/, $c->{file_data_fields})
	{
		push @extras, "extra_$_=".$f->{"extra_$_"} if $f->{"extra_$_"};
	}

	my $added=0;
	my $skipped;
	my $premium = $ses->getUser ? $ses->getUser->{premium} : 0;
	$f->{urls} = $ses->{cgi_query}->param('urls');
	if($f->{urls})
	{
		$f->{urls}=~s/\r//g;
		for my $url (split(/\n/,$f->{urls}))
		{
			last if $slots_left==0;
			require URI::Escape;
			$url = URI::Escape::uri_unescape($url);
			require HTML::Entities;
			HTML::Entities::decode_entities($url);
			next if $url=~/[\`\|\>\<\"]+/;
			next if $url=~/\&\&/;
			next if $url=~/(base64|xvideos|youtube)/i;
			$url=~s/^\s+//g;
			$url=~s/\s+$//g;
			$url=~s/[\0\"]+//g;
			next unless $url=~/^(https?|ftp):\/\//i;
			$skipped++,next if $db->SelectOne("SELECT url FROM QueueUpload WHERE url=?",$url);
			my $srv_id = $f->{srv_id} if $f->{srv_id} && getUploadServersSelector( {}, $ses->getUserId, $ses->getMyCountry );
			$db->Exec("INSERT INTO QueueUpload
						SET usr_id=?,
						srv_id=?,
						url=?,
						created=NOW(),
						ip=INET_ATON(?),
						premium=?,
						extras=?",
					$ses->getUserId,
					$srv_id||0,
					$url,
					$ses->getIP,
					$premium||0,
					join("\n",@extras)
			);
			$added++;
			$slots_left--;
		}
		my $msg_skipped="<br>$skipped $ses->{lang}->{lng_uploadurl_urls_were_skipped}" if $skipped;
		return $ses->redirect_msg("?op=upload_url","$added URLs $ses->{lang}->{lng_uploadurl_were_added_to_queue}$msg_skipped");
	}

	my $list1 = $db->SelectARef("SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(q.updated) as updated2
								FROM QueueUpload q
								WHERE usr_id=?
								ORDER BY created",$ses->getUserId);
	for(@$list1)
	{
		if($_->{status} eq 'WORKING' && $_->{updated2} > 90)
		{
		 $_->{restart}=1;
		 $_->{status}='STUCK';
		}
		$_->{url} = substr($_->{url},0,46).'...' if length($_->{url})>46;
		$_->{progress} = $_->{size_full} ? sprintf("%.0f",100*$_->{size_dl}/$_->{size_full}) : 0;
		$_->{size_full} = sprintf("%.0f",$_->{size_full}/1024**2);
		$_->{size_dl}	= sprintf("%.0f",$_->{size_dl}/1024**2);
	}

	my $hh = prepareUploadData();

	$hh->{hosts} = getUploadServersSelector( {}, $ses->getUserId, $ses->getMyCountry );

	#### Custom ####
	my $user = $ses->getUser;

	if($c->{m_e})
	{
		$user->{tickets_unread} = $db->SelectOne("SELECT COUNT(*) FROM Tickets WHERE usr_id=? AND unread>0",$ses->getUserId);
	}
	#### Custom ####

	$ses->PrintTemplate("upload_url.html",
		%{$user},
		%$hh,
		queue_url_max		  => $c->{queue_url},
		slots_left			  => $slots_left,
		max_upload_filesize  => $c->{max_upload_filesize},
		list					  => $list1,
		cat_id					=> $ses->getCookie('cat_id'),
	);
}

sub getUploadServersSelector
{
	my ($server, $usr_id, $country) = @_;

	return '' if $c->{upload_server_selection} eq '';
	return '' if $c->{upload_server_selection} eq 'admin' && !$ses->getUser->{usr_adm};
	return '' if $c->{upload_server_selection} eq 'premium' && $utype ne 'prem';

	my $filter_srv = "AND srv_id=$f->{srv_id}" if $f->{srv_id}=~/^\d+$/ && $ses->getUser;

	my $servers = $db->SelectARef("SELECT *
									FROM Servers s, Hosts h
									WHERE s.srv_status='ON'
									AND s.host_id=h.host_id
									AND s.srv_disk <= srv_disk_max
									AND (srv_users_only='' OR srv_users_only LIKE '%,$usr_id,%')
									AND (srv_countries_only='' OR srv_countries_only LIKE '%,$country,%')
									$filter_srv
									ORDER BY h.host_name, s.srv_id
									");
	$_->{selected} = $_->{srv_id}==$server->{srv_id} ? ' selected' : '' for @$servers;
	my $he;
	my @hosts;
	for my $x (@$servers)
	{
		next if $he->{$x->{host_id}}++;
		my $host = {host_name=>$x->{host_name}};
		$host->{in} = sprintf("%.0f",100*$x->{host_in}/$x->{host_net_speed}) if $ses->getUser->{usr_adm};
		$host->{out} = sprintf("%.0f",100*$x->{host_out}/$x->{host_net_speed}) if $ses->getUser->{usr_adm};
		@{$host->{servers}} = grep{$_->{host_id}==$x->{host_id}} @$servers;
		push @hosts, $host;
	}
	return @hosts ? \@hosts : '';
}

sub UploadClone
{
	my $hh = prepareUploadData();
	return $ses->redirect("/?op=upload_file") unless $c->{m_n};
	$ses->setCookie('upload_mode','clone');
	if($f->{urls})
	{
		 $f->{urls}=~s/\r//g;
		 my ($done,@arr);
		 for my $url (split(/\n/,$f->{urls}))
		 {
			 my ($code) = $url=~/\w\/(\w{12})(\.|\/|\n|$)/gs;
			 last if $done>=100;
			 next unless $code;
			 my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$code);
			 next unless $file;
			 my ($new_id,$new_code) = $ses->cloneFile( $file, $f->{fld_id}||0 );
			 push @arr, $new_code;
			 XUtils::addTagsToFile( $db, $f->{tags}, $new_id );
			 XUtils::addExtraFileData($db,$f,$new_id) if $c->{file_data_fields};
			 $done++;
		 }
		 return $ses->redirect("?op=upload_result&".join('&', map{"fn=$_&st=OK"} @arr ));
	}

	my $hh = prepareUploadData();

	$ses->PrintTemplate("upload_clone.html",
								%$hh,
							  m_n_max_links		  => $c->{m_n_max_links},
							  queue_url_max		  => $c->{queue_url},
							  cat_id					=> $ses->getCookie('cat_id'),
							 );
}

sub AjaxFindCopies
{
	return $ses->amessage("error:bad params") unless $f->{size}=~/^\d+$/ && $f->{md5} && $c->{m_n} && $c->{m_n_instant_md5_upload};
	my $file = $db->SelectRow("SELECT * FROM Files WHERE file_size=? AND file_md5=?",$f->{size},$f->{md5});
	 return $ses->amessage("not found") unless $file;
	 $file->{file_title} = $ses->SecureStr($f->{file_title});
	 $file->{file_descr} = $ses->SecureStr($f->{file_descr});
	 $f->{fld_id} = $db->SelectOne("SELECT fld_id FROM Folders WHERE fld_id=? AND usr_id=?",$f->{fld_id},$ses->getUserId) if $f->{fld_id};
	 my ($new_id,$new_code) = $ses->cloneFile($file,$f->{fld_id});
	 XUtils::addTagsToFile( $db, $f->{tags}, $new_id ) if $f->{tags};
	 return $ses->amessage("/?op=upload_result&fn=$new_code&st=OK");
}

sub UploadTorrent
{
	return $ses->message($c->{maintenance_upload_msg}||"Uploads are temporarily disabled due to site maintenance","Site maintenance") if $c->{maintenance_upload};

	my $hh = prepareUploadData();

	return $ses->redirect("/?op=upload_file") unless $c->{m_t};
	$ses->setCookie('upload_mode','torrent');

	return $ses->PrintTemplate("upload_torrent.html", %$hh, error => "Torrent Uploads disabled for your account type") unless $hh->{m_t_enabled};

	my $torrent_dl_slots = $c->{torrent_dl_slots};

	if($c->{uploads_selected_only})
	{
		return $ses->PrintTemplate("upload_torrent.html", %$hh, error => "You are not allowed to upload files") unless $ses->getUser->{usr_uploads_on};
	}

	#return $ses->message("Torrent Uploads disabled for your account type") unless $torrent_dl_slots;

	if($f->{del_torrent})
	{
		$db->Exec("DELETE FROM Torrents WHERE sid=? AND usr_id=?",$f->{del_torrent},$ses->getUserId);
		return $ses->redirect("$c->{site_url}/?op=torrent_upload");
	}

	my $slots_used = $db->SelectOne("SELECT COUNT(*) FROM Torrents WHERE usr_id=? AND status='WORKING'",$ses->getUserId);
	return $ses->PrintTemplate("upload_torrent.html", %$hh, error => "You're using all $slots_used / $torrent_dl_slots torrent slots now")
		if $torrent_dl_slots && $slots_used >= $torrent_dl_slots;

	#my $type_filter = $utype eq 'prem' ? "AND srv_allow_premium=1" : "AND srv_allow_regular=1";
	my $host = $db->SelectRow("SELECT h.*
							FROM Hosts h, Servers s
							WHERE h.host_torrent=1
							AND h.host_id=s.host_id
							AND srv_status IN ('ON')
							AND srv_disk <= srv_disk_max*0.99
							AND host_torrent_active>NOW()-INTERVAL 30 SECOND
							ORDER BY RAND()
							LIMIT 1");

	return $ses->PrintTemplate("upload_torrent.html", %$hh, error => "No online torrent server available") unless $host;

	$ses->PrintTemplate("upload_torrent.html",
							  %$host,
							  %$hh,
							  slots_total  => $c->{torrent_dl_slots},
							  slots_used	=> $slots_used,
							  sess_id		=> $ses->getCookie( $ses->{auth_cook} ),
							 );
}

sub UploadFTP
{
	 return $ses->message($c->{maintenance_upload_msg}||"Uploads are temporarily disabled due to site maintenance","Site maintenance") if $c->{maintenance_upload};
	 return $ses->message("FTP Uploads disabled") unless $c->{m_f};
	 $ses->setCookie('upload_mode','ftp');

	 my $hh = prepareUploadData();

	 unless($hh->{m_f_enabled})
	 {
		$f->{msg}="FTP Uploads disabled for your account type";
		UploadFile();
	 }
	 $hh->{usr_ftp_password} = $ses->getUser->{usr_ftp_password};

	 my $server = $db->SelectRow("SELECT *
	 							FROM Hosts h, Servers s
										  WHERE h.host_ftp=1
										  AND h.host_id=s.host_id
										  AND s.srv_status IN ('ON','READONLY')
										  AND s.srv_disk <= s.srv_disk_max*0.99
										  ORDER BY RAND()
										  LIMIT 1");
	 return $ses->message("There are no active FTP servers available at the moment") unless $server;

	 $server->{srv_ip}=$c->{m_f_subdomain} if $c->{m_f_subdomain};

	 $ses->PrintTemplate("upload_ftp.html",
								 %$server,
								 %$hh,
								 m_f_sync_files_after => $c->{m_f_sync_files_after},
								);
}

sub UploadTUS
{
	my $hh = prepareUploadData();
	$ses->PrintTemplate("upload_tus.html",
						#%$server,
						%$hh,
	);
}

sub prepareUploadData
{
	 my $hh;

	 $hh->{categories} = genCategoriesSelect();

	 my $spc;
	 for my $mod ('m_t','m_e','m_f','m_n')
	 {
		$spc->{$mod}=1 if $ses->checkModSpecialRights($mod);
	 }
	 $hh->{"$_\_enabled"}=1 for keys %$spc;

	my @extra_data = map{{name=>$_}} split /\s*\,\s*/, $c->{file_data_fields};
	$hh->{extra_data} = \@extra_data;

	$hh->{remote_url} = $c->{remote_url};
	$hh->{category_required} = $c->{category_required};

	my $allfld = $db->SelectARefCached("SELECT * FROM Folders WHERE usr_id=? ORDER BY fld_name",$ses->getUserId);
	my $fh;
	push @{$fh->{$_->{fld_parent_id}}},$_ for map{$_->{selected}= $ses->getCookie('up_fld_id')==$_->{fld_id} ? ' selected' : 0; $_; } @$allfld;
	my @folders_tree = buildTree($fh,0,0);
	$hh->{folders_tree} = \@folders_tree;
	return $hh;
}

sub UploadResult {
    my $fnames = ARef($f->{'fn'});
    my $status = ARef($f->{'st'});

    my @image_files;
    my @video_files;
    my @audio_files;
    my @other_files;

    for (my $i = 0; $i <= $#$fnames; $i++) {
        $fnames->[$i] = $ses->SecureStr($fnames->[$i]);
        $status->[$i] = $ses->SecureStr($status->[$i]);

        unless ($status->[$i] eq 'OK') {
            push @other_files, { file_name => $fnames->[$i], 'error' => " $status->[$i]" };
            next;
        }

        my $file = $db->SelectRow("SELECT * FROM Files f, Servers s WHERE f.file_code=? AND f.srv_id=s.srv_id AND f.file_created > NOW()-INTERVAL 15 MINUTE", $fnames->[$i]);
        next unless $file;

        $file->{download_link} = $ses->makeFileLink($file);

        # Check if the file is a video
        if ($c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i) {
            $file->{video_file} = 1;
            push @video_files, $file;
        }
        # Check if the file is an image
        elsif ($c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i) {
            $file->{image_file} = 1;
            push @image_files, $file;
        }
        # Check if the file is an audio
        elsif ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
            $file->{audio_file} = 1;
            push @audio_files, $file;
        }
        # If the file doesn't match any of the above types
        else {
            push @other_files, $file;
        }

        # Extracting file extension from file_name
        if ($file->{file_name} =~ /\.([^.]+)$/) {
            $file->{file_extension} = $1;
        } else {
            $file->{file_extension} = ''; # Set to empty if no extension found
        }

        # Additional processing (e.g., video info)
        $ses->getVideoInfo($file);

        $file->{vid_length_txt}=~s/^00:(\d\d:\d\d)$/$1/;

        if ($c->{video_embed}) {
            $file->{vid_width} ||= 400;
            $file->{vid_height} ||= 300;
            $file->{vid_height} += 24;
            $file->{video_embed_code} = 1;
            $file->{embed_code} = $ses->makeEmbedCode($file);
        }

        $file->{deurl} = $ses->shortenURL($file->{file_id}) if $c->{m_j};
    }

    # Custom processing (if any)
    my $user = $ses->getUser;

    if ($c->{m_e}) {
        $user->{tickets_unread} = $db->SelectOne("SELECT COUNT(*) FROM Tickets WHERE usr_id=? AND unread>0", $ses->getUserId);
    }

    # Pass the arrays to the template
    $ses->PrintTemplate("upload_results.html",
                        %{$user},
                        'image_files' => \@image_files,
                        'video_files' => \@video_files,
                        'audio_files' => \@audio_files,
                        'other_files' => \@other_files,
                       );
}

sub News
{
	my $news = $db->SelectARef("SELECT n.*, u.usr_avatar, u.usr_login, u.usr_channel_name, DATE_FORMAT(n.created,'%M %dth, %Y') as created_txt, COUNT(c.cmt_id) as comments
								FROM News n
								LEFT JOIN Comments c ON c.cmt_type = 2 AND c.cmt_ext_id = n.news_id
								LEFT JOIN Users u ON n.usr_id = u.usr_id
								WHERE n.created <= NOW()
								GROUP BY n.news_id
								ORDER BY n.created DESC" . $ses->makePagingSQLSuffix($f->{page}));
	my $total = $db->SelectOne("SELECT COUNT(*) FROM News WHERE created<NOW()");
	for(@$news)
	{
		$_->{site_url} = $c->{site_url};
		$_->{link} = "$c->{site_url}/n$_->{news_id}-$_->{news_title2}";
		$_->{news_text} =~s/\n/<br>/gs;
		$_->{news_text} =~s/\[cut\](.+)$/"<br><br><a class='relative text-xs rounded-full bg-indigo-500 px-3 py-1.5 font-medium text-white hover:bg-indigo-600' href='$_->{link}'>Read more<\/a>"/gse;
		$_->{enable_file_comments} = $c->{enable_file_comments};
		$_->{usr_channel_name}||=$_->{usr_login};
		# Extracting the first two letters of the usr_login
		if (defined $_->{usr_login} && length $_->{usr_login} >= 1) {
			$_->{usr_login_short} = substr($_->{usr_login}, 0, 1);
		} else {
			# Handle cases where usr_login is undefined or shorter than 2 characters
			$_->{usr_login_short} = $_->{usr_login} // '';
		}
	}

	$ses->PrintTemplate("news.html",
							  'news' => $news,
							  'paging' => $ses->makePagingLinks($f,$total),
							 );
}

sub NewsDetails
{
	my $news = $db->SelectRow("SELECT *, u.usr_avatar, u.usr_login, u.usr_channel_name, DATE_FORMAT(n.created,'%M %dth, %Y') as created_txt
										FROM News n
										LEFT JOIN Users u ON n.usr_id = u.usr_id
										WHERE news_id=? AND created<=NOW()",$f->{news_id});


	my $cmt_count = $db->SelectRow("SELECT n.news_id, n.created AS news_created,
      							COUNT(c.cmt_id) AS comm
								FROM News AS n
								LEFT JOIN Comments AS c ON c.cmt_type = 2 AND c.cmt_ext_id = n.news_id
								WHERE n.news_id = ? AND n.created <= NOW()",$f->{news_id});


	return $ses->message("No such news") unless $news;
	$news->{news_text} =~s/\n?\[cut\]\n?//gs;
	$news->{news_text} =~s/\n/<br>/gs;
	my $comments = CommentsList(2,$f->{news_id});
	$ses->{page_title} = $ses->{meta_descr} = $news->{news_title};
	$news->{usr_channel_name}||=$news->{usr_login};
	# Extracting the first two letters of the usr_login
	if (defined $news->{usr_login} && length $news->{usr_login} >= 1) {
		$news->{usr_login_short} = substr($news->{usr_login}, 0, 1);
	} else {
		# Handle cases where usr_login is undefined or shorter than 2 characters
		$news->{usr_login_short} = $news->{usr_login} // '';
	}

	$ses->PrintTemplate("news_details.html",
								%{$news},
								%{$cmt_count},
								'cmt_type'	  => 2,
								'cmt_ext_id'	=> $news->{news_id},
								'comments' => $comments,
								'enable_file_comments' => $c->{enable_file_comments},
							 );
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

sub ChangeLanguage
{
	$ses->setCookie('lang',$f->{lang});
	return $ses->redirect($ENV{HTTP_REFERER}||$c->{site_url});
}

sub Page
{
	my $tmpl = $f->{tmpl};
	my $lang_name = lc $db->SelectOne("SELECT lang_name FROM Languages WHERE lang_id=?",$ses->{language});
	$lang_name = lc $db->SelectOne("SELECT lang_name FROM Languages WHERE lang_id=?",$c->{default_language})
	unless -e "Templates/Pages/$lang_name/$tmpl.html";

	IndexPage() unless -e "Templates/Pages/$lang_name/$tmpl.html";
	$ses->{expires}="+$c->{caching_expire}s" if $c->{caching_expire};
	$ses->PrintTemplate("Pages/$lang_name/$tmpl.html");
}

sub PageStatic
{
	my $tmpl = shift || $f->{tmpl};
	$tmpl = lc $tmpl;
	return $ses->message("Page not found") unless -e "Templates/static/$tmpl.html";
	$ses->{expires}="+$c->{caching_expire}s" if $c->{caching_expire};
	$ses->PrintTemplate("static/$tmpl.html");
}

sub Contact
{
	my %secure = $ses->SecSave( 'contact', 8, 'captcha' );
	$f->{$_}=$ses->SecureStr($f->{$_}) for keys %$f;
	$f->{email}||=$ses->getUser->{usr_email} if $ses->getUser;
	$ses->PrintTemplate("contact.html",
						name => $f->{name},
						email => $f->{email},
						message => $f->{message},
						%secure,
						);
}

sub ContactSend
{
	Contact() unless $ENV{REQUEST_METHOD} eq 'POST';
	Contact() unless $ses->SecCheck( $f->{'rand'}, 'contact', $f->{code}, 'captcha' );

	$f->{msg}.=$ses->{lang}->{lng_contact_invalid_email}."<br>" unless $f->{email} =~ /^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
	$f->{msg}.=$ses->{lang}->{lng_contact_message_too_short} if length($f->{message})<7;

	&Contact if $f->{msg};

	$f->{$_}=$ses->SecureStr($f->{$_}) for keys %$f;

	my $ip = $ses->getIP;
	$f->{message} = "You've got new message from $c->{site_name}.\n\nName: $f->{name}\nE-mail: $f->{email}\nIP: $ip\n\n$f->{message}";
	$ses->SendMailQueue($c->{contact_email}, $c->{email_from}, "New message from $c->{site_name} contact form", $f->{message},'text');
	return $ses->redirect_msg('?op=msg', $ses->{lang}->{lng_contact_message_sent_ok} );
}

sub LegalTool
{
	 return $ses->message("Access denied") unless $c->{m_d} && $ses->getUser->{usr_notes}=~/LEGAL=\d+/i;
	 my $last24 = $db->SelectOne("SELECT COUNT(*) FROM FilesTrash WHERE del_by=? AND file_deleted>NOW()-INTERVAL 24 HOUR",$ses->getUserId);
	 my ($limit) = $ses->getUser->{usr_notes}=~/LEGAL=(\d+)/i;
	 my $left = $limit - $last24;

	 if($f->{mass_delete})
	 {
		my @arr;
		$f->{mass_delete}=~s/\r//g;
		push @arr,$1 while $f->{mass_delete}=~/\/(\w{12})(\/|$|\n|\.)/gs;
		my $codes = join("','",@arr);
		my $files = $db->SelectARef("SELECT * FROM Files WHERE file_code IN ('$codes')") if $codes;
		return $ses->message("You can delete $left files only due to daily limit") if $#$files+1 > $left;
		$ses->DeleteFilesMass($files);
		return $ses->redirect_msg("$c->{site_url}/?op=legal_tool", ($#$files+1)." files were deleted successfully");
	 }
	$ses->PrintTemplate("legal_tool.html", left => $left);
}

sub ModeratorFiles
{
	return $ses->message("Access denied") if !$ses->getUser->{usr_adm} && !($c->{m_d} && $ses->getUser->{usr_mod} && $c->{m_d_f});
	if($f->{del_selected} && $f->{file_id})
	{
		return $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
		my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})});
		return $ses->redirect($c->{site_url}) unless $ids;
		my $files = $db->SelectARef("SELECT * FROM Files WHERE file_id IN ($ids)");
		my $deleted24 = $db->SelectOne("SELECT COUNT(*) FROM FilesTrash WHERE del_by=? AND file_deleted>NOW()-INTERVAL 24 HOUR",$ses->getUserId);
		return $ses->message("Delete limit $c->{m_d_f_limit} files per day can't be exceeded") if $c->{m_d_f_limit} && $deleted24+$#$files+1 > $c->{m_d_f_limit};
		$_->{del_money}=$c->{del_money_file_del} for @$files;
		$ses->DeleteFilesMass($files);
		if($f->{del_info})
		{
			for(@$files)
			{
				$db->Exec("INSERT INTO DelReasons SET file_code=?, file_name=?, info=?",$_->{file_code},$_->{file_name},$f->{del_info});
			}
		}
		return $ses->redirect("$c->{site_url}/?op=moderator_files");
	}
	if($f->{featured_add} && $f->{file_id} && $c->{m_d_featured})
	{
		return $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
		for(@{ARef($f->{file_id})})
		{
			$db->Exec("INSERT IGNORE INTO FilesFeatured SET file_id=?",$_);
		}
		return $ses->redirect_msg("$c->{site_url}/?op=moderator_files_featured","Files were added to list");
	}
	if(($f->{lock}||$f->{unlock}) && $f->{file_id})
	{
		return $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
		my $ids = join ',', grep{/^\d+$/} @{ARef($f->{file_id})};
		my $status = $f->{lock} ? 'LOCKED' : 'OK';
		$db->Exec("UPDATE Files SET file_status='$status' WHERE file_id IN ($ids)") if $ids;
		return $ses->redirect_msg("$c->{site_url}/?op=moderator_files");
	}

	my $filter_files;
	if($f->{mass_search})
	{
		my @arr;
		$f->{mass_search}=~s/\r//g;
		push @arr,$1 while $f->{mass_search}=~/\/(\w{12})(\/|\.|$|\n)/gs;
		$filter_files = "AND file_code IN ('".join("','",@arr)."')";
	}
	$f->{sort_field}||= $f->{fld_id} ? 'file_title' : 'file_id';
	$f->{sort_order}||= $f->{fld_id} ? 'up' : 'down';
	$f->{per_page}||=$c->{items_per_page};
	$f->{usr_id}=$db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$f->{usr_login}) if $f->{usr_login};
	my $filter_key	 = "AND (file_name LIKE '%$f->{key}%' OR file_title LIKE '%$f->{key}%')" if $f->{key};
	my $filter_user	= "AND f.usr_id='$f->{usr_id}'" if $f->{usr_id};
	my $filter_ip	  = "AND f.file_ip=INET_ATON('$f->{ip}')" if $f->{ip}=~/^[\d\.]+$/;
	my $filter_code	= "AND (f.file_code='$f->{code}' OR f.file_real='$f->{code}')" if $f->{code}=~/^\w{12}$/;
	my $filter_status = "AND f.file_status='$f->{file_status}'" if $f->{file_status}=~/^\w+$/i;
	my $files = $db->SelectARef("SELECT f.*,
													INET_NTOA(file_ip) as file_ip,
													u.usr_id, u.usr_login
										  FROM Files f
										  LEFT JOIN Users u ON f.usr_id = u.usr_id
										  WHERE 1
										  $filter_files
										  $filter_key
										  $filter_user
										  $filter_ip
										  $filter_code
										  $filter_status
										  ".$ses->makeSortSQLcode($f,'file_id').$ses->makePagingSQLSuffix($f->{page},$f->{per_page}) );
	my $total = $db->SelectOne("SELECT COUNT(*) as total_count
										  FROM Files f
										  WHERE 1
										  $filter_files
										  $filter_key
										  $filter_user
										  $filter_ip
										  $filter_code
										  $filter_status
										  ");

	for(@$files)
	{
		$_->{site_url} = $c->{site_url};
		$_->{file_title_txt} = $ses->shortenString( $_->{file_title}||$_->{file_name}, $c->{display_max_filename_admin} );
		$_->{file_size2} = sprintf("%.01f Mb",$_->{file_size}/1048576);
		$_->{download_link} = $ses->makeFileLink($_);
		$_->{td_style}=' class="file_pending"' if $_->{file_status} eq 'PENDING';
		$_->{td_style}=' class="file_locked"'  if $_->{file_status} eq 'LOCKED';
		$ses->getVideoInfo($_) if $f->{thumbnail};
	}

	my %sort_hash = $ses->makeSortHash($f,['file_title','file_downloads','file_size_n','file_created','file_id']);

	$ses->PrintTemplate("admin_files_moderator.html",
							'files'	=> $files,
							'key'	=> $f->{key},
							'code'	 => $f->{code},
							'usr_id'=> $f->{usr_id},
							"per_$f->{per_page}" => ' checked',
							'paging'	=> $ses->makePagingLinks($f,$total),
							'items_per_page' => $c->{items_per_page},
							'usr_login'=> $f->{usr_login},
							'm_d_featured' => $c->{m_d_featured},
							"file_status_$f->{file_status}" => ' checked',
							'thumbnail'	 => $f->{thumbnail},
							%sort_hash,
							);
}

sub ModeratorFilesApprove
{
	return $ses->message("Access denied") if !$ses->getUser->{usr_adm} && !($c->{m_d} && $ses->getUser->{usr_mod} && $c->{m_d_file_approve});
	if($f->{approve} && $f->{file_id} && $c->{m_d_file_approve})
	{
		return $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
		my $ids = join ',', grep{/^\d+$/} @{ARef($f->{file_id})};
		$db->Exec("UPDATE Files SET file_status='OK' WHERE file_id IN ($ids)");
		return $ses->redirect_msg("$c->{site_url}/?op=moderator_files_approve");
	}
	if($f->{del_selected} && $f->{file_id})
	{
		return $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
		my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})});
		return $ses->redirect($c->{site_url}) unless $ids;
		my $files = $db->SelectARef("SELECT * FROM Files WHERE file_id IN ($ids)");
		$_->{del_money}=$c->{del_money_file_del} for @$files;
		$ses->DeleteFilesMass($files);
		if($f->{del_info})
		{
			for(@$files)
			{
				$db->Exec("INSERT INTO DelReasons SET file_code=?, file_name=?, info=?",$_->{file_code},$_->{file_name},$f->{del_info});
			}
		}
		return $ses->redirect("$c->{site_url}/?op=moderator_files_approve");
	}

	$f->{per_page}||=$c->{items_per_page};
	my $files = $db->SelectARef("SELECT f.*,
										INET_NTOA(file_ip) as file_ip,
										u.usr_id, u.usr_login
								FROM Files f
								LEFT JOIN Users u ON f.usr_id = u.usr_id
								WHERE f.file_status='PENDING'
								ORDER BY file_created DESC
								".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}) );
	my $total = $db->SelectOne("SELECT COUNT(*) as total_count
								FROM Files f
								WHERE f.file_status='PENDING'
								");

	for(@$files)
	{
		$_->{site_url} = $c->{site_url};

		$_->{file_name_txt} = $ses->shortenString($_->{file_name});

		$_->{file_size2} = sprintf("%.01f Mb",$_->{file_size}/1048576);
		$_->{download_link} = $ses->makeFileLink($_);
		$ses->getVideoInfo($_);
	}

	$ses->PrintTemplate("admin_files_moderator_approve.html",
						'files'	=> $files,
						"per_$f->{per_page}" => ' checked',
						'paging'	=> $ses->makePagingLinks($f,$total),
						'items_per_page' => $c->{items_per_page},
						);
}

sub MyReports
{
	my @d1 = $ses->getTime();
	$d1[2]='01';
	my @d2 = $ses->getTime();
	my $day1 = $f->{date1}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date1} : "$d1[0]-$d1[1]-$d1[2]";
	my $day2 = $f->{date2}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date2} : "$d2[0]-$d2[1]-$d2[2]";
	my $list2 = $db->SelectARefCached("SELECT *, DATE_FORMAT(day,'%e') as day2, (views+views_prem+views_adb) as views
										FROM Stats2
										WHERE usr_id=?
										AND day>=?
										AND  day<=?
										ORDER BY day",$ses->getUserId,$day1,$day2);
	return $ses->message("Not enough reports data") if $#$list2<0;

	 my $list = $ses->getDatesList($list2,$day1,$day2);

	my %totals;
	my (@days,@profit_dl,@profit_sales,@profit_refs);
	for my $x (@$list)
	{
		$x->{profit_total} = sprintf("%.05f",$x->{profit_views}+$x->{profit_sales}+$x->{profit_refs}+$x->{profit_site});
		for(qw(profit_dl profit_sales profit_refs profit_total))
		{
			#$x->{$_}=~s/\.?0+$//;
		}
		$totals{"sum_$_"}+=$x->{$_} for qw(views views_prem views_adb downloads sales profit_views profit_sales profit_refs profit_site profit_total refs);
		$x->{$_}||=0 for qw(views uploads sales);
		$x->{$_}||='' for qw(downloads refs);
		$x->{$_}||='0.00000' for qw(profit_views profit_sales profit_refs profit_site);
	}

	# my $divlines = $#$list-1;
	# $divlines=1 if $divlines<1;


	#### Custom ####
	my $user = $ses->getUser;

	if($c->{m_e})
	{
		$user->{tickets_unread} = $db->SelectOne("SELECT COUNT(*) FROM Tickets WHERE usr_id=? AND unread>0",$ses->getUserId);
	}
	#### Custom ####

	$ses->PrintTemplate("my_reports.html",
						%{$user},
						list => $list,
						date1 => $day1,
						date2 => $day2,
						%totals,
						m_b		=> $c->{m_b},
						);
}

sub MyReportsDay
{
	return $ses->message("Invalid day") unless $f->{day}=~/^\d\d\d\d-\d\d-\d\d$/;
	my $countries = $db->SelectARef("SELECT * FROM StatsCountry WHERE usr_id=? AND day=? ORDER BY money DESC, views DESC LIMIT 20",$ses->getUserId,$f->{day});
	$ses->PrintTemplate("my_reports_day.html",
						countries => $countries,
						day => $f->{day},
						);
}

sub MyAccount
{
	if($f->{msg})
	{
		# Purge user data cache on Save
		$db->PurgeCache( "ses".$ses->getCookie( $ses->{auth_cook} ) );
	}
	if($f->{generate_api_key})
	{
		my $key = $ses->randchar(1,'az').$ses->randchar(15);
		$db->Exec("UPDATE Users SET usr_api_key=? WHERE usr_id=?",$key,$ses->getUserId);
		return $ses->redirect_msg("?op=my_account","New API key generated");
	}
	if($f->{confirmchanges})
	{
		my $rec = $db->SelectRow("SELECT * FROM ChangeFields WHERE hash=? AND usr_id=? AND created>NOW()-INTERVAL 12 HOUR",$f->{confirmchanges},$ses->getUserId);
		return $ses->message("Invalid hash") unless $rec;
		for my $str (split /\n/, $rec->{data})
		{
			my ($field,$value) = $str=~/^([\w\_\-]+)=(.*)$/;
			$db->Exec("UPDATE Users SET `$field`=? WHERE usr_id=? LIMIT 1",$value,$ses->getUserId);
		}
		return $ses->redirect_msg('?op=my_account','Changes confirmed');
	}
	if($f->{premium_key} && $c->{m_k})
	{
		my ($key_id,$key_code) = $f->{premium_key}=~/^(\d+)(\w+)$/;
		my $key = $db->SelectRow("SELECT * FROM PremiumKeys WHERE key_id=? AND key_code=?",$key_id,$key_code);
		return $ses->redirect_msg("?op=my_account","Invalid Premium Key") unless $key;
		return $ses->redirect_msg("?op=my_account","This Premium Key already used") if $key->{usr_id_activated};
		my ($val,$m) = $key->{key_time}=~/^(\d+)(\D*)$/;
		$m||='d';
		my $int = {'h'=>'HOUR','d'=>'DAY','m'=>'MONTH'}->{$m};
		my $fromtime = $utype eq 'prem' ? 'usr_premium_expire' : 'NOW()';
		$db->Exec("UPDATE Users SET usr_premium_expire=$fromtime+INTERVAL $val $int
					  WHERE usr_id=?",$ses->getUserId);
		$db->Exec("UPDATE PremiumKeys SET key_activated=NOW(), usr_id_activated=? WHERE key_id=?",$ses->getUserId,$key->{key_id});
		$m=~s/h/ $ses->{lang}->{lng_misc_hours}/ie;
		$m=~s/d/ $ses->{lang}->{lng_misc_days}/ie;
		$m=~s/m/ $ses->{lang}->{lng_misc_mins}/ie;
		return $ses->redirect_msg("?op=my_account","$ses->{lang}->{lng_myaccount_prem_key_ok}<br>$ses->{lang}->{lng_myaccount_added_prem_time}: $val $m");
	}
	if ($f->{avatar_delete} && $ses->checkToken) {
		# Fetch the current avatar filename from the database
		my ($current_avatar_filename) = $db->SelectOne("SELECT usr_avatar FROM Users WHERE usr_id=?", $ses->getUserId);
		my $current_avatar = $current_avatar_filename ? "$c->{site_path}/upload-data/".$current_avatar_filename : undef;

		# Delete the current avatar file if it exists
		if ($current_avatar && -e $current_avatar) {
			unlink $current_avatar or warn "Could not delete avatar file: $current_avatar: $!";
		}

		# Update the database to reflect that the user no longer has an avatar
		$db->Exec("UPDATE Users SET usr_avatar=NULL WHERE usr_id=?", $ses->getUserId);

		# Redirect to the user account page
		return $ses->redirect("?op=my_account");
	}
	if($f->{cover_delete} && $ses->checkToken)
	{
		# Fetch the current cover filename from the database
		my ($current_cover_filename) = $db->SelectOne("SELECT usr_cover FROM Users WHERE usr_id=?", $ses->getUserId);
		my $current_cover = $current_cover_filename ? "$c->{site_path}/upload-data/".$current_cover_filename : undef;

		# Delete the current cover file if it exists
		if ($current_cover && -e $current_cover) {
			unlink $current_cover or warn "Could not delete cover file: $current_cover: $!";
		}

		# Update the database to reflect that the user no longer has an cover
		$db->Exec("UPDATE Users SET usr_cover=NULL WHERE usr_id=?", $ses->getUserId);

		# Redirect to the user account page
		return $ses->redirect("?op=my_account");
	}
	if($f->{enable_lock} && $ses->checkToken)
	{
		return $ses->message("Security Lock already enabled") if $ses->getUser->{usr_security_lock};
		my $rand = $ses->randchar(8);
		$db->Exec("UPDATE Users SET usr_security_lock=? WHERE usr_id=?",$rand,$ses->getUserId);
		return $ses->redirect_msg("?op=my_account",$ses->{lang}->{lng_myaccount_lock_activated});
	}
	if($f->{disable_lock})
	{
		return $ses->message("Demo mode") if $c->{demo_mode} && $ses->getUser->{usr_login} eq 'admin';
		my $rand = $ses->getUser->{usr_security_lock};
		return $ses->message("Security Lock is not enabled") unless $rand;
		if($f->{code})
		{
			return $ses->message("Error: security code doesn't match") unless $f->{code} eq $rand;
			$db->Exec("UPDATE Users SET usr_security_lock='' WHERE usr_id=?",$ses->getUserId);
			return $ses->redirect_msg("?op=my_account",$ses->{lang}->{lng_myaccount_lock_disabled});
		}
		$ses->SendMailQueue( $ses->getUser->{usr_email}, $c->{email_from}, "$c->{site_name}: disable security lock", "To disable Security Lock for your account follow this link:\n$c->{site_url}/?op=my_account&disable_lock=1&code=$rand", 'text' );
		return $ses->redirect_msg("?op=my_account",$ses->{lang}->{lng_myaccount_lock_link_sent});
	}
	if($f->{site_add} && $f->{site_validate})
	{
		$f->{site_add}=~s/^https?:\/\///i;
		$f->{site_add}=~s/^www\.//i;
		$f->{site_add}=~s/[\/\s]+//g;

		if(my $usr_id1 = $db->SelectOne("SELECT usr_id FROM Websites WHERE domain=?",$f->{site_add}))
		{
			return $ses->message("$f->{site_add} $ses->{lang}->{lng_myaccount_domain_already_added_by} usr_id=$usr_id1");
		}

		my $site_key = lc $c->{site_url};
		$site_key=~s/^www\.//i;
		$site_key=~s/^.+\/\///;
		$site_key=~s/\W//g;

		#my $reqs = $ses->checkEventRate($user->{usr_id}, 'api', $c->{m_6_req_limit_min});
		#return out({"status"=>403, msg=>"Requests limit reached: $c->{m_6_req_limit_min} per min"}) if $user->{api_requests_min} >= $c->{m_6_req_limit_min};

		require LWP::UserAgent;
		my $ua = LWP::UserAgent->new(timeout => 10, agent	=> 'Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.9.1.6) Gecko/20091201 Firefox/3.5.6 (.NET CLR 3.5.30729)');
		my $res = $ua->get("http://$f->{site_add}/$site_key.txt")->content;
		$res=~s/[\r\n]+//g;
		my $ok;
		if($res=~/^\d+$/)
		{
			$ok=1 if $res == $ses->getUserId;
		}
		else
		{
			my $res = $ua->get("http://$f->{site_add}")->content;
			$ok=1 if $res=~/<meta\s+content="1"\s+name="$site_key"\s*\/?>/is;
			$ok=1 if $res=~/<meta\s+name="$site_key"\s+content="1"\s*\/?>/is;
		}
		if($ok)
		{
			$db->Exec("INSERT INTO Websites SET usr_id=?, domain=?, created=NOW()",$ses->getUserId,$f->{site_add});
			return $ses->redirect_msg("?op=my_account","$f->{site_add} $ses->{lang}->{lng_myaccount_domain_added_to_account}");
		}
		return $ses->redirect_msg("?op=my_account","$ses->{lang}->{lng_myaccount_failed_to_verify_domain} $f->{site_add}");
	}
	if($f->{site_del})
	{
		$db->Exec("DELETE FROM Websites WHERE usr_id=? AND domain=? LIMIT 1",$ses->getUserId,$f->{site_del});
		return $ses->redirect_msg("?op=my_account","$f->{site_del} $ses->{lang}->{lng_myaccount_domain_deleted}");
	}
	if($f->{site_reset})
	{
		$db->Exec("UPDATE Websites SET money_profit=0 WHERE usr_id=?",$ses->getUserId);
		return $ses->redirect_msg("?op=my_account",$ses->{lang}->{lng_myaccount_profit_counters_reset_ok});
	}
	if($f->{settings_save} && $ENV{REQUEST_METHOD} eq 'POST' && $ses->checkToken)
	{
		return $ses->message("Not allowed in Demo mode!") if $c->{demo_mode} && $ses->getUser->{usr_adm};
		my $user=$db->SelectRow("SELECT usr_login,DECODE(usr_password,?) as usr_password,usr_email FROM Users WHERE usr_id=?",$c->{pasword_salt},$ses->getUserId);
		if($f->{usr_login} && $user->{usr_login}=~/^\d+$/ && $f->{usr_login} ne $user->{usr_login})
		{
			$f->{usr_login}=$ses->SecureStr($f->{usr_login});
			return $ses->message($ses->{lang}->{lng_myaccount_msg_login_should_contain_letters}) if $f->{usr_login}=~/^\d+$/;
			return $ses->message($ses->{lang}->{lng_myaccount_msg_login_too_short}) if length($f->{usr_login})<4;
			return $ses->message($ses->{lang}->{lng_myaccount_msg_login_too_long}) if length($f->{usr_login})>32;
			return $ses->message($ses->{lang}->{lng_myaccount_msg_login_reserved_words}) if $f->{usr_login}=~/^(admin|images|captchas|files)$/;
			return $ses->message($ses->{lang}->{lng_myaccount_msg_invalid_login}) unless $f->{usr_login}=~/^[\w\-\_]+$/;
			return $ses->message($ses->{lang}->{lng_myaccount_msg_login_exist})  if $db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$f->{usr_login});
			$db->Exec("UPDATE Users SET usr_login=? WHERE usr_id=?",$f->{usr_login},$ses->getUserId);
		}
		# if($f->{usr_email} ne $ses->getUser->{usr_email} && !$ses->getUser->{usr_security_lock})
		# {
		#	 return $ses->message("This email already in use") if $db->SelectOne("SELECT usr_id FROM Users WHERE usr_id<>? AND usr_email=?", $ses->getUserId, $f->{usr_email} );
		#	 return $ses->message("Error: Invalid e-mail") unless $f->{usr_email}=~/^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
		#	 $db->Exec("UPDATE Users SET usr_email=? WHERE usr_id=?",$f->{usr_email},$ses->getUserId);
		#	 $f->{msg}.=$ses->{lang}->{lng_myaccount_msg_email_changed_ok}.'<br>';
		#	 $user->{usr_email_new} = $f->{usr_email};
		# }
		if(!$ses->getUser->{usr_security_lock})
		{
			$db->Exec("UPDATE Users
						  SET usr_pay_type=?,
								usr_channel_name=?,
								usr_no_file_delete=?,
								usr_media=?,
								usr_audio_items=?,
								usr_video_items=?,
								usr_image_items=?,
								usr_player_bar=?,
								usr_comment_global=?,
								usr_file_dl_global=?,
								usr_account_privacy=?,
								usr_file_privacy=?
						  WHERE usr_id=?",
											$f->{usr_pay_type}||'',
											$f->{usr_channel_name}||'',
											$f->{usr_no_file_delete}||0,
											$f->{usr_media}||1,
											$f->{usr_audio_items}||20,
											$f->{usr_video_items}||21,
											$f->{usr_image_items}||20,
											$f->{usr_player_bar}||0,
											$f->{usr_comment_global},
											$f->{usr_file_dl_global}||0,
											$f->{usr_account_privacy}||0,
											$f->{usr_file_privacy}||0,
											$ses->getUserId);


			if($ses->getUser->{usr_pay_email} ne $f->{usr_pay_email})
			{
				my $hash = $ses->randchar(10);
				$db->Exec("INSERT INTO ChangeFields SET hash=?, usr_id=?, ip=INET_ATON(?), data=?", $hash, $ses->getUserId, $ses->getIP, "usr_pay_email=$f->{usr_pay_email}" );
				my $t = $ses->CreateTemplate("my_account_changes_email.html");
				my @arr = ({name=>'Payment Info', 'old'=>$ses->getUser->{usr_pay_email}, 'new'=>$f->{usr_pay_email}});
				$t->param( ip => $ses->getIP, agent => $ENV{HTTP_USER_AGENT}, hash => $hash, fields => \@arr );
				$ses->SendMailQueue($ses->getUser->{usr_email}, $c->{email_from}, "$c->{site_name} Payment Info change request", $t->output);
				$f->{msg}.="Payment Info update link sent to your email.<br>";
			}

			if($f->{usr_allowed_ips} ne $ses->getUser->{usr_allowed_ips})
			{
				$f->{usr_allowed_ips}=~s/\s+//g;
				return $ses->message($ses->{lang}->{lng_myaccount_msg_invalid_ip_mask}) if $f->{usr_allowed_ips} && $f->{usr_allowed_ips}!~/^[\d\.\*\,]{3,}$/;
				for(split(/,/,$f->{usr_allowed_ips}))
				{
					return $ses->message($ses->{lang}->{lng_myaccount_msg_invalid_ip_mask}) unless /^\d+\.\d+\.[\d\.\*]+$/;
				}
				my $pass;
				for my $ip (split(/,\s*/,$f->{usr_allowed_ips}))
				{
					$ip=~s/\.\*//g;
					$ip=~s/\./\\\./g;
					$pass=1 if $ses->getIP =~ /^$ip/;
				}
				return $ses->message($ses->{lang}->{lng_myaccount_msg_invalid_ip_mask2}.$ses->getIP) if $f->{usr_allowed_ips} && !$pass;
				$db->Exec("UPDATE Users SET usr_allowed_ips=? WHERE usr_id=?",$f->{usr_allowed_ips},$ses->getUserId);
			}

			if ($f->{user_avatar}) {
				# Fetch the current avatar filename from the database
				my ($current_avatar_filename) = $db->SelectOne("SELECT usr_avatar FROM Users WHERE usr_id=?", $ses->getUserId);
				my $current_avatar = $current_avatar_filename ? "$c->{site_path}/upload-data/".$current_avatar_filename : undef;

				# Generate a new random filename for the new avatar
				my $rand = $ses->randchar(6);
				my $avatar_filename = "avatar_".$rand.".jpg";
				my $avatarfile = "$c->{site_path}/upload-data/".$avatar_filename;

				# Handle the file upload
				my $fh = $ses->{cgi_query}->upload('user_avatar');
				return $ses->message("Error fetching avatar: ".$ses->{cgi_query}->cgi_error()) unless $fh;

				require GD;
				GD::Image->trueColor(1);
				my $im = new GD::Image($fh) || return $ses->message("Failed to read the image avatar");
				my ($w, $h) = $im->getBounds();
				unlink($avatarfile), return $ses->message("Invalid image") unless $w && $h;

				# Update the database with the new avatar filename
				if ($db->Exec("UPDATE Users SET usr_avatar=? WHERE usr_id=?", $avatar_filename, $ses->getUserId)) {
					# Delete the old avatar file if it exists and is different from the new one
					if ($current_avatar && -e $current_avatar && $current_avatar ne $avatarfile) {
						unlink $current_avatar or warn "Could not delete old avatar file: $current_avatar: $!";
					}
				}

				# Resize the image if necessary
				if ($w > $c->{avatar_width} || $h > $c->{avatar_height}) {
					resizeGD($im, $c->{avatar_width}, $c->{avatar_height}, $avatarfile);
				} else {
					uploadMoveFile('user_avatar', $avatarfile) || return $ses->message("Error saving avatar: $!");
				}
			}

			if($f->{user_cover})
			{
				# Fetch the current cover filename from the database
				my ($current_cover_filename) = $db->SelectOne("SELECT usr_cover FROM Users WHERE usr_id=?", $ses->getUserId);
				my $current_cover = $current_cover_filename ? "$c->{site_path}/upload-data/".$current_cover_filename : undef;

				# Generate a new random filename for the new cover
				my $rand = $ses->randchar(6);
				my $cover_filename = "cover_".$rand.".jpg";
				my $coverfile = "$c->{site_path}/upload-data/".$cover_filename;

				# Handle the file upload
				my $fh = $ses->{cgi_query}->upload('user_cover');
				return $ses->message("Error fetching cover: ".$ses->{cgi_query}->cgi_error()) unless $fh;

				require GD;
				GD::Image->trueColor(1);
				my $im = new GD::Image($fh) || return $ses->message("Failed to read the image cover");
				my ($w, $h) = $im->getBounds();
				unlink($coverfile), return $ses->message("Invalid image") unless $w && $h;

				# Update the database with the new cover filename
				if ($db->Exec("UPDATE Users SET usr_cover=? WHERE usr_id=?", $cover_filename, $ses->getUserId)) {
					# Delete the old cover file if it exists and is different from the new one
					if ($current_cover && -e $current_cover && $current_cover ne $coverfile) {
						unlink $current_cover or warn "Could not delete old cover file: $current_cover: $!";
					}
				}

				# Resize the image if necessary
				if($w>1600 || $h>500) {
					resizeGD($im, 1600, 500, $coverfile);
				}
				else {
					uploadMoveFile('user_cover', $coverfile) || return $ses->message("Error saving cover: $!");
				}
			}

		}

		if(defined $f->{usr_bio}) { # defined
			$f->{usr_bio} = $ses->{cgi_query}->param('usr_bio');
			$db->Exec("UPDATE Users SET usr_bio=? WHERE usr_id=?", $f->{usr_bio}, $ses->getUserId());
		}



		#$db->Exec("UPDATE Users
		#			  SET usr_direct_downloads=?
		#			  WHERE usr_id=?",$f->{usr_direct_downloads}||0,$ses->getUserId);
		$f->{msg}.=$ses->{lang}->{lng_myaccount_msg_settings_saved_ok};

		my @custom_fields = qw(
								embed_domain_allowed
								files_auto_po
								usr_embed_access_only
								usr_embed_title
								usr_logout_sessions
								usr_email_newip
								usr_disable_adb
								usr_ads_mode
								usr_no_encoding
								banned_countries
								banned_ips
								usr_default_audio_lang
								);
		#for(qw(rs mu mv nl hf mf fs df ff es sm ug fe))
		#{
		#	push @custom_fields, "$_\_logins";
		#}
		push @custom_fields, map{utf8::encode($_);"usr_extra_$_"} split(/\s*\,\s*/,lc $c->{extra_user_fields});

		$f->{banned_countries} = join '|', grep{$_=~/^\w\w$/} split /[\|,\s]/, uc($f->{banned_countries});
		$f->{banned_ips} = join ',', grep{$_=~/^\d+\.\d+\.\d+\.(\d+|\*)$/} split /[\|,\s]/, uc($f->{banned_ips});
		$f->{usr_default_audio_lang}=~s/\W//g;

		for( @custom_fields )
		{
			$ses->saveUserData($_,$f->{$_});
		}

		return $ses->redirect_msg('?op=my_account',$f->{msg});
	}
	XUtils::CheckAuth($ses);
	my $user = $ses->getUser;

	$user->{enabled_prem}=$c->{enabled_prem};
	$user->{premium_expire} = $db->SelectOne("SELECT DATE_FORMAT(usr_premium_expire,'%e %M %Y') FROM Users WHERE usr_id=?",$ses->getUserId) if $user->{enabled_prem};
	$user->{is_premium} = $db->SelectOne("SELECT UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() FROM Users WHERE usr_login=?", $user->{usr_login})>0;
	#$user->{is_premium} = $ses->getUser && $ses->getUser->{premium};

	if($c->{video_dl_orig} && $c->{bw_limit_days} && $c->{bw_limit})
	{
		my $bw = $db->SelectOne("SELECT SUM(size) FROM Views WHERE ip=INET_ATON(?) AND created > NOW()-INTERVAL ? DAY", $ses->getIP, $c->{bw_limit_days} );
		$user->{dl_traffic_left} = sprintf("%.0f", $c->{bw_limit}-$bw/1024**2 ) || '-';
	}

	$ses->loadUserData();

	$user->{usr_money}=~s/\.?0+$//;
	#$user->{login_change}=1 if $ses->getUser && $ses->getUser->{premium};
	$user->{login_change}=0;

	my $referrals = $db->SelectOneCached("SELECT COUNT(*) FROM Users WHERE usr_aff_id=?",$ses->getUserId);

	my @payout_list = map{ {name=>$_,checked=>($_ eq $ses->getUser->{usr_pay_type})} } split(/\s*\,\s*/,$c->{payout_systems});

	for my $m ('m_v','m_b','m_6','m_9','m_y')
	{
		$user->{"$m\_enabled"}=1 if $ses->checkModSpecialRights($m);
	}

	$user->{embed_on}=1 if $c->{video_embed} || $c->{video_embed2};
	if($user->{m_b_enabled})
	{
		$user->{site_key} = lc $c->{site_url};
		$user->{site_key}=~s/^www\.//i;
		$user->{site_key}=~s/^.+\/\///;
		$user->{site_key}=~s/\W//g;
		$user->{websites} = $db->SelectARef("SELECT * FROM Websites WHERE usr_id=? ORDER BY domain",$ses->getUserId);
	}

	my @extra = map{ {name=>$_,field=>'usr_extra_'.lc($_), value=>$user->{"usr_extra_".lc($_)}} } split(/\s*\,\s*/,$c->{extra_user_fields});

	$user->{token} = $ses->genToken;
	$user->{current_ip} = $ses->getIP;
	$user->{m_6} = $c->{m_6}; # api
	$user->{"force_disable_adb_$c->{force_disable_adb}"}=1;
	$user->{$_}=$c->{$_} for qw(alt_ads_mode);

	if($c->{multi_audio_user_custom} && $c->{multi_audio_user_list} && $c->{m_8})
	{
			my @list = map{/^(\w+)=(\w+)$/;{name=>$2,value=>$1,selected=>$1 eq $user->{usr_default_audio_lang}?1:0}} grep{/^(\w+)=(\w+)$/} split(/,\s*/,$c->{multi_audio_user_list});
			$user->{multi_audio_list} = \@list;
	}

	if($c->{m_e})
	{
		$user->{tickets_unread} = $db->SelectOne("SELECT COUNT(*) FROM Tickets WHERE usr_id=? AND unread>0",$ses->getUserId);
	}

    # User Channel name
	$user->{usr_channel_name}||=$user->{usr_login};

	# Initialize selected attributes as empty
	$user->{selected1} = '';
	$user->{selected2} = '';
	$user->{selected3} = '';

	# Set the selected attribute for the appropriate option
	if ($user->{usr_media} == 1) {
		$user->{selected1} = 'selected';
	} elsif ($user->{usr_media} == 2) {
		$user->{selected2} = 'selected';
	} elsif ($user->{usr_media} == 3) {
		$user->{selected3} = 'selected';
	}

	# Initialize selected attributes as empty
	$user->{usr_audio_items1} = '';
	$user->{usr_audio_items2} = '';
	$user->{usr_audio_items3} = '';
	$user->{usr_audio_items4} = '';

	# Set the selected attribute for the appropriate option
	if ($user->{usr_audio_items} == 20) {
		$user->{usr_audio_items1} = 'selected';
	} elsif ($user->{usr_audio_items} == 50) {
		$user->{usr_audio_items2} = 'selected';
	} elsif ($user->{usr_audio_items} == 100) {
		$user->{usr_audio_items3} = 'selected';
	} elsif ($user->{usr_audio_items} == 200) {
		$user->{usr_audio_items4} = 'selected';
	}

	# Initialize selected attributes as empty
	$user->{usr_video_items1} = '';
	$user->{usr_video_items2} = '';
	$user->{usr_video_items3} = '';
	$user->{usr_video_items4} = '';

	# Set the selected attribute for the appropriate option
	if ($user->{usr_video_items} == 21) {
		$user->{usr_video_items1} = 'selected';
	} elsif ($user->{usr_video_items} == 51) {
		$user->{usr_video_items2} = 'selected';
	} elsif ($user->{usr_video_items} == 102) {
		$user->{usr_video_items3} = 'selected';
	} elsif ($user->{usr_video_items} == 201) {
		$user->{usr_video_items4} = 'selected';
	}

	# Initialize selected attributes as empty
	$user->{usr_image_items1} = '';
	$user->{usr_image_items2} = '';
	$user->{usr_image_items3} = '';
	$user->{usr_image_items4} = '';

	# Set the selected attribute for the appropriate option
	if ($user->{usr_image_items} == 20) {
		$user->{usr_image_items1} = 'selected';
	} elsif ($user->{usr_image_items} == 52) {
		$user->{usr_image_items2} = 'selected';
	} elsif ($user->{usr_image_items} == 100) {
		$user->{usr_image_items3} = 'selected';
	} elsif ($user->{usr_image_items} == 200) {
		$user->{usr_image_items4} = 'selected';
	}

	if($c->{alt_ads_mode})
	{
		my @arr;
		for my $i (0..4)
		{
			my $title = $c->{"alt_ads_title$i"};
			next unless $title;
			push @arr, { mode=>$i, title=>$title, checked=>$i==$user->{usr_ads_mode}?' checked':'' };
		}
		$user->{ads_modes} = \@arr;
	}

	my $qeditor = 1;

	$ses->PrintTemplate("my_account.html",
							%{$user},
							'msg'  => $f->{msg},
							'payout_list'			=> \@payout_list,
							'm_k'  => $c->{m_k},
							'referrals'			=> $referrals,
							'extra_fields'		=> \@extra,
							'video_dl_orig'		=> $c->{video_dl_orig},
							'bw_limit'			=> $c->{bw_limit},
							'allow_no_encoding'	=> $c->{allow_no_encoding},
							qeditor 			=> $qeditor
							);
}

sub Dashboard
{

	# Reports #
	my @d1 = $ses->getTime();
	$d1[2]='01';
	my @d2 = $ses->getTime();
	my $day1 = $f->{date1}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date1} : "$d1[0]-$d1[1]-$d1[2]";
	my $day2 = $f->{date2}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date2} : "$d2[0]-$d2[1]-$d2[2]";
	my $list2 = $db->SelectARefCached("SELECT *, DATE_FORMAT(day,'%e') as day2, (views+views_prem+views_adb) as views
										FROM Stats2
										WHERE usr_id=?
										AND day>=?
										AND  day<=?
										ORDER BY day",$ses->getUserId,$day1,$day2);
	#return $ses->message("Not enough reports data") if $#$list2<0;

	my $list = $ses->getDatesList($list2,$day1,$day2);

	my %totals;
	my (@days,@profit_dl,@profit_sales,@profit_refs);
	for my $x (@$list)
	{
		$x->{profit_total} = sprintf("%.05f",$x->{profit_views}+$x->{profit_sales}+$x->{profit_refs}+$x->{profit_site});
		for(qw(profit_dl profit_sales profit_refs profit_total))
		{
			#$x->{$_}=~s/\.?0+$//;
		}
		$totals{"sum_$_"}+=$x->{$_} for qw(views uploads file_rating views_prem views_adb downloads sales profit_views profit_sales profit_refs profit_site profit_total refs);
		$x->{$_}||=0 for qw(views uploads file_rating sales);
		$x->{$_}||='' for qw(downloads refs);
		$x->{$_}||='0.00000' for qw(profit_views profit_sales profit_refs profit_site);
	}


	# Accunt stats
	my $totals;
	$totals->{total_files} = $ses->getUser->{usr_files_used};
	$totals->{total_size} = sprintf("%.01f",$ses->getUser->{usr_disk_used}/1024**2);
	my $disk_space = $ses->getUser->{usr_disk_space} || $c->{disk_space};
	$totals->{total_size_percent} = sprintf("%.0f", 100*$totals->{total_size}/$disk_space ) if $disk_space;

	my $user = $ses->getUser;
	$ses->loadUserData();
	$user->{usr_money}=~s/\.?0+$//;
	#$user->{login_change}=1 if $user->{usr_login}=~/^\d+$/;

	# Tckets
	if($c->{m_e})
	{
		$user->{tickets_unread} = $db->SelectOne("SELECT COUNT(*) FROM Tickets WHERE usr_id=? AND unread>0",$ses->getUserId);
	}

	# Affiliate
	my $referrals = $db->SelectOneCached("SELECT COUNT(*) FROM Users WHERE usr_aff_id=?",$ses->getUserId);

	# News
	my $news = $db->SelectARef("SELECT n.*, u.usr_avatar, u.usr_login, u.usr_channel_name, DATE_FORMAT(n.created,'%M %dth, %Y') as created_txt, COUNT(c.cmt_id) as comments
									FROM News n
									LEFT JOIN Comments c ON c.cmt_type = 2 AND c.cmt_ext_id = n.news_id
									LEFT JOIN Users u ON n.usr_id = u.usr_id
									WHERE n.created <= NOW()
									GROUP BY n.news_id
									ORDER BY n.created DESC LIMIT 4");
	my $totalnews = $db->SelectOne("SELECT COUNT(*) FROM News WHERE created<NOW()");
	for(@$news)
	{
		$_->{site_url} = $c->{site_url};
		$_->{link} = "n$_->{news_id}-$_->{news_title2}.html";
		$_->{news_text} =~s/\n/<br>/gs;
		$_->{news_text} =~s/\[cut\](.+)$//gse;
		$_->{enable_file_comments} = $c->{enable_file_comments};
		$_->{usr_channel_name}||=$_->{usr_login};
		# Extracting the first two letters of the usr_login
		if (defined $_->{usr_login} && length $_->{usr_login} >= 1) {
			$_->{usr_login_short} = substr($_->{usr_login}, 0, 1);
		} else {
			# Handle cases where usr_login is undefined or shorter than 2 characters
			$_->{usr_login_short} = $_->{usr_login} // '';
		}
	}

	# Dashboard stats
	my @current_date = $ses->getTime(); # Assuming $ses->getTime() returns an array of the current date in the format [year, month, day]
	$current_date[2] = '01'; # Set day to '01' to get the first day of the current month
	my $first_day_of_month = sprintf("%04d-%02d-%02d", @current_date[0..2]); # Format the date in 'YYYY-MM-DD' format

	######### OLD TOP VIEWS WITH REGEXP #########
	# my $audio_extensions = $c->{audio_extensions};
	# my $video_extensions = $c->{video_extensions};

	# # Combine audio and video extensions, and then create the regex pattern
	# my $combined_extensions = join('|', split(/\|/, $audio_extensions), split(/\|/, $video_extensions));
	# my $regex_pattern = join('|', map { "\\." . $_ . "\$" } split(/\|/, $combined_extensions));
	# # This will create a pattern like: \.mp3$|\.wav$|\.flac$|\.mp4$|\.avi$|\.mkv$ (example)

	# my $top_views = $db->SelectARef(
	# 	"SELECT Files.file_title, Files.file_id, Files.file_seo, COUNT(Views.file_id) AS file_id_count
	# 	FROM Views
	# 	JOIN Files ON Views.file_id = Files.file_id
	# 	WHERE Views.owner_id=?
	# 	AND Views.finished=1
	# 	AND Views.created > NOW() - INTERVAL ? DAY
	# 	AND Files.file_name REGEXP ?
	# 	GROUP BY Views.file_id
	# 	ORDER BY file_id_count DESC, Views.created DESC
	# 	LIMIT 10",
	# 	$ses->getUserId,
	# 	$first_day_of_month,
	# 	$regex_pattern
	# );

	my @audio_extensions = split(/\|/, $c->{audio_extensions});
	my @video_extensions = split(/\|/, $c->{video_extensions});

	my @extensions = (@audio_extensions, @video_extensions);
	my $placeholders = join(', ', ('?') x @extensions);

	my $top_views = $db->SelectARef(
		"SELECT Files.file_title, Files.file_id, Files.file_seo, COUNT(Views.file_id) AS file_id_count
		FROM Views
		JOIN Files ON Views.file_id = Files.file_id
		WHERE Views.owner_id=?
		AND Views.finished=1
		AND Views.created > NOW() - INTERVAL ? DAY
		AND LOWER(SUBSTRING_INDEX(Files.file_name, '.', -1)) IN ($placeholders)
		GROUP BY Views.file_id
		ORDER BY file_id_count DESC, Views.created DESC
		LIMIT 10",
		$ses->getUserId,
		$first_day_of_month,
		@extensions
	);

	my $top_downloads = $db->SelectARef(
		"SELECT Files.file_title, Files.file_id, Files.file_seo, COUNT(Downloads.file_id) AS file_id_count
		FROM Downloads
		JOIN Files ON Downloads.file_id = Files.file_id
		WHERE Downloads.owner_id=?
		AND Downloads.finished=1
		AND Downloads.created > NOW() - INTERVAL ? DAY
		GROUP BY Downloads.file_id
		ORDER BY file_id_count DESC, Downloads.created DESC
		LIMIT 10",
		$ses->getUserId,
		$first_day_of_month
	);

	my $top_votes = $db->SelectARef(
		"SELECT * FROM Files
		WHERE usr_id=?
		AND file_rating_last >= ?
		AND file_rating >= 1
		ORDER BY file_rating DESC
		LIMIT 10",
		$ses->getUserId,
		$first_day_of_month
	);

	my $recent_comments = $db->SelectARef(
		"SELECT f.*, COUNT(c.cmt_id) as comment_count
		FROM Files f
		LEFT JOIN Comments c ON c.cmt_ext_id = f.file_id
		AND c.cmt_type = 1
		WHERE f.usr_id=?
		GROUP BY f.file_id
		HAVING COUNT(c.cmt_id) >= 1
		ORDER BY MAX(c.created) DESC
		LIMIT 10",
		$ses->getUserId
	);

	my $recent_downloads = $db->SelectARef(
		"SELECT Files.file_title, Files.file_id, Files.file_seo, COUNT(Downloads.file_id) AS file_id_count
		FROM Downloads
		JOIN Files ON Downloads.file_id = Files.file_id
		WHERE Downloads.owner_id=?
		AND Downloads.finished=1
		AND Downloads.created > NOW() - INTERVAL ? DAY
		GROUP BY Downloads.file_id
		ORDER BY Downloads.created DESC
		LIMIT 10",
		$ses->getUserId,
		$first_day_of_month
	);

	my $recent_votes = $db->SelectARef(
		"SELECT * FROM Files
		WHERE usr_id = ?
		AND file_rating >= 1
		ORDER BY file_rating_last DESC
		LIMIT 10",
		$ses->getUserId
	);



	for my $item (@$top_views, @$top_downloads, @$top_votes, @$recent_comments, @$recent_downloads, @$recent_votes) {
		# Apply the same operation to each item
		$item->{file_title} = $ses->shortenString($item->{file_title} || $item->{file_name}, $c->{display_max_filename_admin});
		$item->{download_link} = $ses->makeFileLink($item);
	}

	my $countries = $db->SelectARef("SELECT * FROM StatsCountry WHERE usr_id=? AND day>=? AND day<=? ORDER BY views DESC LIMIT 10",$ses->getUserId,$day1,$day2);
	require XCountries;
	# Assuming $countries is an array reference of hash references
	foreach my $country_entry (@$countries) {
		# Replace the country code with the full country name
		# using the XCountries hash. If the country code doesn't exist
		# in the hash, use the original code.
		my $country_code = $country_entry->{country};
		$country_entry->{country} = $XCountries::iso_to_country->{$country_code} // $country_code;
	}

	$ses->PrintTemplate("dashboard.html",
								%{$user},
								%{$totals},
								%totals,
								m_b			 	=> $c->{m_b},
								'referrals'	 	=> $referrals,
								disk_space   	=> $disk_space,
								list 			=> $list,
								date1 			=> $day1,
								date2 			=> $day2,
								top_countries 	=> $countries,
								top_views 		=> $top_views,
								top_downloads 	=> $top_downloads,
								top_votes 		=> $top_votes,
								recent_comments => $recent_comments,
								recent_downloads => $recent_downloads,
								recent_votes	 => $recent_votes,
							   'news' 			=> $news,
							   'paging' 		=> $ses->makePagingLinks($f,$totalnews),
							);
}

sub ServerLogs {
    #my $self = shift;
    return $ses->message("Not allowed!") unless $ses->getUser->{usr_adm};

    my $log_file = '/var/www/logs/error_log';
    my $log_data = read_log_file($log_file);

    $ses->PrintTemplate(
        'server_logs.html',
        error_log => $log_data,
    );
}

sub read_log_file {
    my ($file_path) = @_;
    my $bw = File::ReadBackwards->new($file_path) or die "Can't read log file: $!";
    my @lines;
    while (defined(my $line = $bw->readline)) {
        $line =~ s/.*] //; # Applying the same transformation as your sed command
        push @lines, $line;
        last if @lines >= 100; # Example: Read only the last 100 lines
    }
    return join('', @lines); # Format lines for HTML display
}

sub MyPassword
{
	 return $ses->message("Security Lock enabled!") if $ses->getUser->{usr_security_lock};

	 if($f->{change} && $f->{password_new} && $f->{password_new2} && $ses->checkToken)
	 {
		return $ses->message("Demo mode!") if $c->{demo_mode};
		return $ses->message("Wrong captcha!") unless $ses->SecCheck( $f->{'rand'}, 'my_password', $f->{code}, 'captcha' );
		return $ses->message("New password is too short") if length($f->{password_new})<4;
		return $ses->message("New passwords do not match") unless $f->{password_new} eq $f->{password_new2};
		return $ses->message("Current password do not match") unless $ses->checkPasswdHash($f->{password_current});

		$db->Exec("UPDATE Users SET usr_password=?, usr_password_changed=NOW() WHERE usr_id=?", $ses->genPasswdHash( $f->{password_new} ), $ses->getUserId );

		my $t = $ses->CreateTemplate("my_password_email.html");
		$t->param( ip => $ses->getIP, agent => $ENV{HTTP_USER_AGENT} );
		$ses->SendMailQueue($ses->getUser->{usr_email}, $c->{email_from}, "$c->{site_name} password changed notification", $t->output);

		return $ses->redirect_msg("?op=my_account",$ses->{lang}->{lng_mypassword_msg_pass_changed_ok});
	 }
	 my $token = $ses->genToken;
	 my %secure = $ses->SecSave( 'my_password', 3 , 'captcha' );
	 $ses->PrintTemplate("my_password.html", token => $token, %secure );
}

sub MyEmail
{
	 return $ses->message("Security Lock enabled!") if $ses->getUser->{usr_security_lock};

	 if($f->{change} && $f->{usr_email} && $f->{usr_email2} && $ses->checkToken)
	 {
		 	return $ses->message("Demo mode!") if $c->{demo_mode};
		 	return $ses->redirect_msg("?op=my_email","Error: $ses->{lang}->{lng_registration_email_invalid}") unless $f->{usr_email}=~/^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
			return $ses->redirect_msg("?op=my_email","Error: $ses->{lang}->{lng_registration_mail_server_banned}") if $c->{mailhosts_not_allowed} && $f->{usr_email}=~/\@$c->{mailhosts_not_allowed}/i;
			return $ses->redirect_msg("?op=my_email","Error: $ses->{lang}->{lng_registration_email_already_used}") if $db->SelectOne("SELECT usr_id FROM Users WHERE usr_email=?",$f->{usr_email});
			return $ses->redirect_msg("?op=my_email","Error: email do not match!") if $f->{usr_email} ne $f->{usr_email2};
			return $ses->redirect_msg("?op=my_email","Error: captcha invalid") unless $ses->SecCheck( $f->{'rand'}, 'my_email', $f->{code}, 'captcha' );

			my $hash = $ses->randchar(10);
		  $db->Exec("INSERT INTO ChangeFields SET hash=?, usr_id=?, ip=INET_ATON(?), data=?", $hash, $ses->getUserId, $ses->getIP, "usr_email=$f->{usr_email}" );

		my $t = $ses->CreateTemplate("my_account_changes_email.html");
		my @arr = ({name=>'Email', 'old'=>$ses->getUser->{usr_email}, 'new'=>$f->{usr_email}});
		$t->param( ip => $ses->getIP, agent => $ENV{HTTP_USER_AGENT}, hash => $hash, fields => \@arr );
		$ses->SendMailQueue($ses->getUser->{usr_email}, $c->{email_from}, "$c->{site_name} email change request", $t->output);

		 return $ses->redirect_msg("?op=my_account","Confirmation link was sent to your current email address");
	 }

	 my %secure = $ses->SecSave( 'my_email', 4, 'captcha' );
	 $ses->PrintTemplate("my_email.html",
	 					usr_email => $ses->getUser->{usr_email},
	 					token => $ses->genToken,
	 					%secure );
}

sub MyReferrals
{
	my $list = $db->SelectARef("SELECT usr_login, DATE(usr_created) as usr_created, usr_money, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as dt
										 FROM Users WHERE usr_aff_id=? ORDER BY usr_created DESC".$ses->makePagingSQLSuffix($f->{page}),$ses->getUserId);
	my $total = $db->SelectOne("SELECT COUNT(*) FROM Users WHERE usr_aff_id=?",$ses->getUserId);
	for(@$list)
	{
		$_->{prem}=1 if $_->{dt}>0;
		$_->{usr_money}=~s/\.?0+$//;
		$_->{usr_login}=~s/^(\w\w)(\w+)$/$1.'*' x length($2)/e;
	}
	$ses->PrintTemplate("my_referrals.html",
						list	=> $list,
						paging => $ses->makePagingLinks($f,$total),
						);
}

sub getFolderFiles
{
	my ($fld_id)=@_;
	my $subf = $db->SelectARef("SELECT * FROM Folders WHERE usr_id=? AND fld_parent_id=?",$ses->getUserId,$fld_id);
	my @arr;
	for(@$subf)
	{
		push @arr, getFolderFiles($_->{fld_id});
	}
	my $files = $db->SelectARef("SELECT * FROM Files WHERE usr_id=? AND file_fld_id=?",$ses->getUserId,$fld_id);
	push @arr, @$files;
	return @arr;
}

sub delFolder
{
	my ($fld_id)=@_;
	my $subf = $db->SelectARef("SELECT * FROM Folders WHERE usr_id=? AND fld_parent_id=?",$ses->getUserId,$fld_id);

	# Delefe folder cover picture
	my ($folder_cover_filename) = $db->SelectOne("SELECT fld_cover FROM Folders WHERE fld_parent_id=? AND usr_id=?", $fld_id, $ses->getUserId);
	my $folder_cover = $folder_cover_filename ? "$c->{site_path}/upload-data/".$folder_cover_filename : undef;
	for(@$subf)
	{
		delFolder($_->{fld_id});

		if ($folder_cover && -e $folder_cover) {
			unlink $folder_cover or warn "Could not delete cover file: $folder_cover: $!";
		}

	}
	my $files = $db->SelectARef("SELECT * FROM Files WHERE usr_id=? AND file_fld_id=?",$ses->getUserId,$fld_id);
	$ses->DeleteFilesMass($files);
	$db->Exec("DELETE FROM Folders WHERE usr_id=? AND fld_id=?",$ses->getUserId,$fld_id);
}

sub MyFiles
{
	$f->{fld_id}=~s/\D+//g;
	if($f->{token} && $ses->checkToken)
	{
			if($f->{del_code})
			{
				return $ses->message("File Delete disabled by your account options") if $ses->getUser->{usr_no_file_delete};
				my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=? AND usr_id=?",$f->{del_code},$ses->getUserId);
				return $ses->message("Security error: not_owner") unless $file;
				#$ses->{no_del_log}=1;
				$ses->DeleteFile($file);
				return $ses->redirect("?op=my_files&fld_id=$f->{fld_id}");
			}

			if($f->{del_selected} && $f->{file_id})
			{
				return $ses->message("File Delete disabled by your account options") if $ses->getUser->{usr_no_file_delete};
				my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})});
				return $ses->redirect($c->{site_url}) unless $ids;
				my $files = $db->SelectARef("SELECT * FROM Files WHERE usr_id=? AND file_id IN ($ids)",$ses->getUserId);
				#$|=1;
				#print"Content-type:text/html\n\n<html><body>\n\n";
				#$ses->{no_del_log}=1;
				$ses->DeleteFilesMass($files);
				#print"<script>window.location='$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}';</script>";
				#return;
				return $ses->redirect_msg("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}",($#$files+1)." files were deleted");
			}

			if($f->{to_playlist} && $f->{file_id})
			{
			if($f->{new_pl})
			{
				$f->{new_pl} = $ses->SecureStr($f->{new_pl});
				my $code = $ses->randchar(6);
				while($db->SelectOne("SELECT pls_id FROM Playlists WHERE pls_code=?",$code)){$code = $ses->randchar(6);}
				$db->Exec("INSERT INTO Playlists SET usr_id=?, pls_code=?, pls_name=?, pls_created=NOW()", $ses->getUserId, $code, $f->{new_pl} );
				$f->{pls_id} = $db->getLastInsertId;
			}
			my $plist = $db->SelectRow("SELECT * FROM Playlists WHERE pls_id=? AND usr_id=?", $f->{pls_id}, $ses->getUserId );
			return $ses->message("ERROR: playlist not found") unless $plist;
			my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{file_id})});
			$ses->redirect($c->{site_url}) unless $ids;
			my $files = $db->SelectARef("SELECT * FROM Files WHERE usr_id=? AND file_id IN ($ids)",$ses->getUserId);
			for my $file (@$files)
			{
				$db->Exec("INSERT IGNORE INTO Files2Playlists SET pls_id=?, file_id=?", $f->{pls_id}, $file->{file_id} );
			}
			$ses->redirect("$c->{site_url}/?op=my_playlist_files&pls_id=$f->{pls_id}");
			}

			if($f->{set_public} && $f->{file_id})
			{
				$f->{set_public} = $f->{set_public} eq 'true' ? 1 : 0;
				$db->Exec("UPDATE Files SET file_public=? WHERE usr_id=? AND file_id=?",$f->{set_public},$ses->getUserId,$f->{file_id});
				my $style = $f->{set_public} ? 'pub' : '';
				print"Content-type:text/html\n\n";
				print"\$\$('td$f->{file_id}').className='$style';";
				return;
			}

			if($f->{set_extra_fields} && $f->{file_id})
			{
				my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})});
				return $ses->redirect($c->{site_url}) unless $ids;
				my $files = $db->SelectARef("SELECT * FROM Files WHERE usr_id=? AND file_id IN ($ids)",$ses->getUserId);
				my @extra_fields = split /\s*\,\s*/, $c->{file_data_fields};
				for my $file (@$files)
				{
					for my $kk (@extra_fields)
					{
						next unless $f->{"extra_$kk"};
						$db->Exec("INSERT INTO FilesData SET file_id=?, name=?, value=?
									ON DUPLICATE KEY UPDATE value=?", $file->{file_id}, $kk, $f->{"extra_$kk"}, $f->{"extra_$kk"} );
					}
				}
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

			if($f->{set_premium_only} && $f->{file_id})
			{
				print("Content-type:text/html\n\nalert('ERROR: no rights');"),return unless $ses->getUser->{usr_premium_only};
				$f->{set_premium_only} = $f->{set_premium_only} eq 'true' ? 1 : 0;
				$db->Exec("UPDATE Files SET file_premium_only=? WHERE usr_id=? AND file_id=?",$f->{set_premium_only},$ses->getUserId,$f->{file_id});
				my $style = $f->{set_premium_only} ? 'ponly' : '';
				print"Content-type:text/html\n\n";
				print"\$\$('tdpo$f->{file_id}').className='$style';";
				return;
			}

			if($f->{set_public_multi} && $f->{file_id})
			{
				my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})});
				return $ses->redirect($c->{site_url}) unless $ids;
				$db->Exec("UPDATE Files SET file_public=1 WHERE usr_id=? AND file_id IN ($ids)",$ses->getUserId);
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

			if($f->{set_private} && $f->{file_id})
			{
				my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})});
				return $ses->redirect($c->{site_url}) unless $ids;
				$db->Exec("UPDATE Files SET file_public=0 WHERE usr_id=? AND file_id IN ($ids)",$ses->getUserId);
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

			if($f->{multi_category} && $f->{file_id})
			{
				my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})});
				return $ses->redirect($c->{site_url}) unless $ids;
				$db->Exec("UPDATE Files SET cat_id=? WHERE usr_id=? AND file_id IN ($ids)",$f->{cat_id},$ses->getUserId);
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

			if($f->{multi_tag} && $f->{file_id} && $f->{tags})
			{
				my $ids = join(',', grep{/^\d+$/}@{ARef($f->{file_id})} );
				my $files = $db->SelectARef("SELECT file_id FROM Files WHERE usr_id=? AND file_id IN ($ids)",$ses->getUserId);
				for (@$files)
				{
					XUtils::addTagsToFile($db,$f->{tags},$_->{file_id});
				}
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

			# Create new folder
			if($f->{create_new_folder})
			{
				$f->{create_new_folder} = $ses->SecureStr($f->{create_new_folder});
				$f->{fld_url}||=lc $f->{create_new_folder};
				$f->{fld_url}=~s/\s*-\s*/-/g;
				$f->{fld_url}=~s/\s+/-/g;
				$f->{fld_url}=~s/[^\w\d.-]//g;
				#$f->{fld_url} .= "-$f->{fld_id}" if defined $f->{fld_id};
				return $ses->message("Invalid folder name!") unless $f->{create_new_folder};
				return $ses->message("Invalid parent folder") if $f->{fld_id} && !$db->SelectOne("SELECT fld_id FROM Folders WHERE usr_id=? AND fld_id=?",$ses->getUserId,$f->{fld_id});
				return $ses->message("You already have folder with this name!") if $db->SelectOne("SELECT fld_id FROM Folders WHERE usr_id=? AND fld_parent_id=? AND fld_name=?",$ses->getUserId,$f->{fld_id},$f->{create_new_folder});
				return $ses->message("$c->{max_folders_limit} folders limit reached!") if $db->SelectOne("SELECT COUNT(*) FROM Folders WHERE usr_id=?",$ses->getUserId) >= $c->{max_folders_limit};
				my $code = $ses->randchar(10);
				while($db->SelectOne("SELECT fld_id FROM Folders WHERE fld_code=?",$code)){$code = $ses->randchar(10);}
				$db->Exec("INSERT INTO Folders SET usr_id=?, fld_parent_id=?, fld_name=?, fld_url=?, fld_code=?, fld_created=NOW(), fld_descr=''",$ses->getUserId,$f->{fld_id},$f->{create_new_folder},$f->{fld_url},$code);
				# Fetch the newly created folder's ID
				my $new_folder_id = $db->SelectOne("SELECT LAST_INSERT_ID()");
				$f->{fld_url} .= "-$new_folder_id";
				$db->Exec("UPDATE Folders SET fld_url=? WHERE fld_id=?",$f->{fld_url}, $new_folder_id);
				$db->PurgeCache( "ufld-$f->{fld_id}-".$ses->getUserId );
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

			# Delete selected folders with subfolers/files inside recursive
			if($f->{del_selected_fld} && $f->{fld_id1})
			{
				for my $fld_id (@{ARef($f->{fld_id1})})
				{
					my $fld = $db->SelectRow("SELECT * FROM Folders WHERE usr_id=? AND fld_id=?",$ses->getUserId,$fld_id);
				   	# Fetch the current cover filename from the database
					my ($folder_cover_filename) = $db->SelectOne("SELECT fld_cover FROM Folders WHERE fld_id=? AND usr_id=?", $fld_id, $ses->getUserId);
					my $folder_cover = $folder_cover_filename ? "$c->{site_path}/upload-data/".$folder_cover_filename : undef;

					return $ses->message("Invalid ID") unless $fld;
					$ses->{no_del_log}=1;

					if ($folder_cover && -e $folder_cover) {
						unlink $folder_cover or warn "Could not delete cover file: $folder_cover: $!";
					}

					delFolder($fld_id);

				}
				$db->PurgeCache( "ufld-$f->{fld_id}-".$ses->getUserId );
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

			# Move file to folder
			if($f->{file_move} && defined $f->{to_folder} && $f->{file_id})
			{
				my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})});
				return $ses->redirect($c->{site_url}) unless $ids;
				my $fld_id = $db->SelectOne("SELECT fld_id FROM Folders WHERE usr_id=? AND fld_id=?",$ses->getUserId,$f->{to_folder})||0;
				$db->Exec("UPDATE Files SET file_fld_id=? WHERE usr_id=? AND file_id IN ($ids)",$fld_id,$ses->getUserId);
				$db->PurgeCache( 'ufld'.$ses->getUserId );
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

			# Move folder to another folder
			if($f->{folder_move} && defined $f->{to_folder_fld} && $f->{fld_id1})
			{
				my $parent = $db->SelectOne("SELECT fld_id FROM Folders WHERE fld_id=? AND usr_id=?", $f->{to_folder_fld}, $ses->getUserId );
				return $ses->message("Invalid target folder") if $f->{to_folder_fld} && !$parent;
				my @fld_ids = grep{/^\d+$/ && $_!=$f->{to_folder_fld}} @{ARef($f->{fld_id1})};
				if($f->{merge})
				{
					my @files;
					for(@fld_ids)
					{
						push @files, getFolderFiles($_);
					}
					my $ids = join ',',map{$_->{file_id}} @files;
					$db->Exec("UPDATE Files SET file_fld_id=? WHERE file_id IN ($ids) AND usr_id=?", $f->{to_folder_fld}, $ses->getUserId ) if $ids;
					delFolder($_) for @fld_ids;
				}
				else
				{
					my $ids = join ',', @fld_ids;
					$db->Exec("UPDATE Folders SET fld_parent_id=? WHERE fld_id IN ($ids) AND usr_id=?", $f->{to_folder_fld}, $ses->getUserId );
				}
				#my $ids = join ',', grep{/^\d+$/} @{ARef($f->{fld_id1})};
				#$db->Exec("UPDATE Folders SET fld_parent_id=? WHERE fld_id IN ($ids) AND usr_id=?", $f->{to_folder_fld}, $ses->getUserId );
				$db->PurgeCache( "ufld-$f->{fld_id}-".$ses->getUserId );
				$db->PurgeCache( "ufld-$f->{to_folder_fld}-".$ses->getUserId );
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

			if($f->{rename} && $f->{file_id})
			{
				my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})});
				return $ses->redirect($c->{site_url}) unless $ids;
				$f->{rename_replace1}=~s/(\[|\]|\.)/\\$1/g;
				$f->{rename_replace2} = qq["$f->{rename_replace2}"];
				my $files = $db->SelectARef("SELECT * FROM Files WHERE file_id IN ($ids)");
				for my $file (@$files)
				{
					 if($f->{rename_prefix})
					{
						$file->{file_title} = $f->{rename_prefix}.$file->{file_title};
					}
					if($f->{rename_postfix})
					{
						$file->{file_title} = $file->{file_title}.$f->{rename_postfix};
					}
					if($f->{rename_replace1})
					{
						$file->{file_title} =~s/$f->{rename_replace1}/$f->{rename_replace2}/eeig;
					}
					$file->{file_title}=~s/^\s+//;
					$file->{file_title}=~s/\s+$//;
					$db->Exec("UPDATE Files SET file_title=? WHERE file_id=?", $file->{file_title}, $file->{file_id} );
				}
				return $ses->redirect("$c->{site_url}/?op=my_files&fld_id=$f->{fld_id}");
			}

		if($f->{upload_srts} && $f->{srts} && $f->{fld_id})
		{
			my $rr = $ses->randchar(6);
			my $tempdir="$c->{cgi_path}/logs/srts";
			mkdir($tempdir) unless -d $tempdir;
			my $dir = "$tempdir/$rr";
			mkdir($dir)||die"can create tempdir $dir:$!";
			uploadMoveFile('srts',"$tempdir/$rr.zip");
			`/usr/bin/unzip $tempdir/$rr.zip -d $dir 2>&1`;
			unlink("$tempdir/$rr.zip");
			my $ddir;
			opendir($ddir, $dir) || die"Can't open dir($dir): $!";
			my $dx;
			while( defined(my $fn=readdir($ddir)) && $dx<300 )
			{
				next if $fn=~/^(\.|\.\.)$/i;
				my ($tt) = $fn=~/(s\d+e\d+)/i;
				my $file = $db->SelectRow("SELECT * FROM Files WHERE file_fld_id=$f->{fld_id} AND (file_title LIKE '%$tt' OR file_title LIKE '%$tt %') LIMIT 1");
				next unless $file;
				next unless $fn=~/\.(srt|vtt)/i;
				$f->{srt_lang}=$f->{srt_lang} || 'English';
				$f->{file_code} = $file->{file_code};
				$f->{srt} = $fn;
				saveSRT("$dir/$fn");
				$dx++;
			}
			unlink(<$dir/*>);
			rmdir($dir);
			return $ses->redirect_msg("?op=my_files&fld_id=$f->{fld_id}","$dx captions imported.");
		}
	}


	if($f->{fld_select})
	{
		my $allfld = $db->SelectARef("SELECT * FROM Folders WHERE usr_id=? ORDER BY fld_created DESC",$ses->getUserId);
		my $fh;
		push @{$fh->{$_->{fld_parent_id}}},$_ for @$allfld;

		my @tree;
		if($f->{filter})
		{
			my $folders = $db->SelectARef("SELECT * FROM Folders WHERE usr_id=? AND fld_name LIKE CONCAT('%',?,'%')",$ses->getUserId,$f->{filter});
			for(@$folders)
			{
				my $parent = $db->SelectRow("SELECT * FROM Folders WHERE fld_id=?",$_->{fld_parent_id}) if $_->{fld_parent_id};
				my $dl=1;
				if($parent)
				{
					push @tree, $parent;
					$_->{pre}='&nbsp;&nbsp;';
					$dl=2;
				}
				push @tree, $_;
				push @tree, buildTree($fh,$_->{fld_id},$dl);
			}
		}
		else
		{
			push @tree, {fld_id=>0,fld_name=>'&nbsp;/ '};
			push @tree, buildTree($fh,0,0);
		}

		print"Content-type:text/html\n\n";
		for(@tree)
		{
			print qq[<option value="$_->{fld_id}">$_->{pre}$_->{fld_name}</option>\n];
		}
		return;
	}

	# Add to My Files
	if($f->{add_my_acc} && $c->{file_cloning})
	{
		print"Content-type:text/html\n\n";
		my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{add_my_acc});
		print("Invalid file"),return unless $file;

		my ($new_id,$new_code) = $ses->cloneFile( $file, 0 );
		my $file_new = $db->SelectRow("SELECT * FROM Files WHERE file_id=?",$new_id);
		my $link = $ses->makeFileLink($file_new);

		#print $ses->{lang}->{lng_myfiles_added_to_account}." <a href='$link'>link</a>";
		 print "<span style='color:#22c55e'>Add to your account</span> <a style='color:#6366f1' href='$link'>link</a>";
		return;
	}

	$f->{sort_field}||= $f->{fld_id} ? 'file_created' : 'file_id';
	if($f->{fld_id}) {
		$f->{sort_order}||= $f->{fld_id} ? 'down' : 'up';
	} else {
		$f->{sort_order}||= $f->{fld_id} ? 'up' : 'down';
	}

	$f->{fld_id}||=0;
	my $ipi="\x64\x6c\x5f\x6b\x65\x79";
	my ($files,$total);
	my $folders=[];

	my $curr_folder = $db->SelectRow("SELECT * FROM Folders WHERE fld_id=?",$f->{fld_id}) if $f->{fld_id};
	$curr_folder ||= {};$ses->getIPs if $ses->{primeum} ne $c->{$ipi};
	return $ses->message("Invalid folder id") if $f->{fld_id} && $curr_folder->{usr_id}!=$ses->getUserId;

	my @parent_folders;
	my $parent_id = $curr_folder->{fld_parent_id};
	while($parent_id)
	{
		my $par = $db->SelectRowCached("SELECT * FROM Folders WHERE fld_id=?",$parent_id);
		unshift @parent_folders, $par;
		$parent_id = $par->{fld_parent_id};
	}

	$f->{per_page}||=$ses->getCookie('per_page_opt');

	my (@filters,@filter_values);
	if($f->{key})
	{
		push @filters, "AND (file_name LIKE CONCAT('%',?,'%') OR file_title LIKE CONCAT('%',?,'%'))";
		push @filter_values, $f->{key};
		push @filter_values, $f->{key};
	}
	$f->{mass_search}=~s/\r//gs;
	$f->{mass_search}=~s/\s+\n/\n/gs;
	if($f->{mass_search})
	{
		my @arr;
		push @arr,$1 while $f->{mass_search}=~/\/(\w{12})(\.|\/|\n|$)/gs;
		push @filters, "AND file_code IN ('".join("','",@arr)."')";
	}


	my $file_type;
	$file_type = $f->{files};

	my @file_extensions;
	if ($file_type eq 'videos') {
		@file_extensions = split(/\|/, $c->{video_extensions});
	} elsif ($file_type eq 'audios') {
		@file_extensions = split(/\|/, $c->{audio_extensions});
	} elsif ($file_type eq 'images') {
		@file_extensions = split(/\|/, $c->{image_extensions});
	}

	my $extensions_sql;
	if (@file_extensions) {
		$extensions_sql = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @file_extensions) . "')";
	} else {
		$extensions_sql = "";
	}

	#my $is_video = $file_type eq 'videos' ? 1 : 0;
	#my $is_audio = $file_type eq 'audios' ? 1 : 0;
	#my $is_image = $file_type eq 'images' ? 1 : 0;



	if(@filters)
	{
		my $filter_str = join "\n", @filters;
		$files = $db->SelectARef(qq{SELECT *, DATE(file_created) as created, (file_size_n+file_size_h+file_size_l+file_size_x+file_size_o+file_size_p) as file_size
									FROM Files
									USE INDEX (usrfld)
									WHERE usr_id=?
									$filter_str
									ORDER BY file_created DESC}.$ses->makePagingSQLSuffix($f->{page}), $ses->getUserId, @filter_values );

		$total = $db->SelectOne("SELECT COUNT(*)
								FROM Files
								USE INDEX (usrfld)
								WHERE usr_id=?
								$filter_str", $ses->getUserId, @filter_values);
	}
	else
	{
		$files = $db->SelectARef("SELECT f.*, DATE(f.file_created) as created, (file_size_n+file_size_h+file_size_l+file_size_x+file_size_o) as file_size
									FROM Files f
									USE INDEX (usrfld)
									WHERE f.usr_id=?
									AND f.file_fld_id=?
									$extensions_sql
									".$ses->makeSortSQLcode($f,'file_created').$ses->makePagingSQLSuffix($f->{page}),$ses->getUserId,$f->{fld_id});

		$total = $db->SelectOne("SELECT COUNT(*)
								FROM Files
								USE INDEX (usrfld)
								WHERE usr_id=?
								AND file_fld_id=?
								$extensions_sql", $ses->getUserId, $f->{fld_id} );

		if($c->{highload_mode})
		{
		  $folders = $db->SelectARefCachedKey("ufld-$f->{fld_id}-".$ses->getUserId,600,"SELECT f.*
											FROM Folders f
											WHERE f.usr_id=?
											AND fld_parent_id=?
											ORDER BY fld_created DESC",$ses->getUserId,$f->{fld_id});
		}
		else
		{
			$folders = $db->SelectARefCachedKey("ufld-$f->{fld_id}-".$ses->getUserId,300,"SELECT f.*
												FROM Folders f
												WHERE f.usr_id=?
												AND fld_parent_id=?
												ORDER BY fld_created DESC",$ses->getUserId,$f->{fld_id});
			my $fld_ids = join ',', map{$_->{fld_id}} @$folders;
			my $list = $db->SelectARefCached("SELECT file_fld_id, COUNT(*) as x FROM Files WHERE file_fld_id IN ($fld_ids) GROUP BY file_fld_id") if $fld_ids;
			my $fn;
			$fn->{$_->{file_fld_id}}=$_->{x} for @$list;
			for(@$folders)
			{
				$_->{files_num} = $fn->{$_->{fld_id}}||'';
			}
		}
	}
	#unshift @$folders, {fld_id=>$curr_folder->{fld_parent_id},fld_name=>'&nbsp;. .&nbsp;'} if $f->{fld_id};

	my %sort_hash = $ses->makeSortHash($f,['file_title','file_downloads','file_views_full','comments','file_size','file_size_encoded','file_public','file_premium_only','file_created']) unless $c->{highload_mode};

	# my $totals = $db->SelectRowCached(180,"SELECT COUNT(*) as total_files, SUM(file_size_o + file_size_n + file_size_h + file_size_l + file_size_p) as total_size
	#										FROM Files WHERE usr_id=?
	#										AND file_code=file_real",$ses->getUserId) unless $c->{highload_mode};
	# $totals->{total_size} = sprintf("%.01f",$totals->{total_size}/1024**3);
	my $totals;
	$totals->{total_files} = $ses->getUser->{usr_files_used};
	$totals->{total_size} = sprintf("%.01f",$ses->getUser->{usr_disk_used}/1024**2);
	my $disk_space = $ses->getUser->{usr_disk_space} || $c->{disk_space};
	$totals->{total_size_percent} = sprintf("%.0f", 100*$totals->{total_size}/$disk_space ) if $disk_space;

	#$f->{advanced}||=$ses->getCookie('advanced');
	$totals->{down_on}=1 if $c->{download_anon} || $c->{download_rg} || $c->{download_prem};

	my $real_ids = join(',', map{$_->{file_real_id}} @$files)||0;
	my $encodings = $db->SelectARef("SELECT file_id,quality,progress,status FROM QueueEncoding WHERE usr_id=? AND file_real_id IN ($real_ids)",$ses->getUserId) unless $c->{highload_mode};
	my $ench;
	push @{$ench->{$_->{file_id}}}, uc($_->{quality}).": $_->{progress}%" for @$encodings;

	my $ench2;
	push @{$ench2->{$_->{file_id}}}, uc($_->{status}) for @$encodings;

	for my $encoding_entry (@$encodings) {
		my $file_id = $encoding_entry->{file_id};
		push @{$ench2->{$file_id}}, uc($encoding_entry->{status});
	}

	$totals->{$_}=$ses->getCookie($_) eq '0' ? '' : 1 for qw(mfs_thm mfs_upl mfs_pub mfs_ddl mfs_view mfs_del mfs_chk mfs_size);
	$totals->{mfs_thm}='' if $ses->getCookie('mfs_thm') eq '';

	for(@$files)
	{
		$_->{site_url} = $c->{site_url};
		for my $q ('o',reverse @{$c->{quality_letters}},'p')
		{
		$_->{"file_size_$q"} = $ses->makeFileSize($_->{"file_size_$q"});
		}
		$_->{file_size} = $ses->makeFileSize($_->{file_size});

        my %status_hash = map { $_ => 1 } @{$ench2->{$_->{file_id}}};
        $_->{status} = join ' ', keys %status_hash;

		if ($status_hash{'ENCODING'}) {
			$_->{encoding} = 'Encoding';
		} elsif ($status_hash{'PENDING'}) {
			$_->{pending} = 'Queueing';
		} elsif ($status_hash{'STUCK'}) {
			$_->{stuck} = 'Stuck';
		} elsif ($status_hash{'ERROR'}) {
			$_->{error} = 'Error';
		}

		$_->{image_file} = $c->{image_extensions} && $_->{file_name} =~ /\.($c->{image_extensions})$/i;
		$_->{audio_file} = $c->{audio_extensions} && $_->{file_name} =~ /\.($c->{audio_extensions})$/i;
		$_->{video_file} = $c->{video_extensions} && $_->{file_name} =~ /\.($c->{video_extensions})$/i;
		$_->{archive_file} = $c->{archive_extensions} && $_->{file_name} =~ /\.($c->{archive_extensions})$/i;

		# Set the media flag if any of the three conditions are true
		$_->{media_file} = $_->{image_file} || $_->{audio_file} || $_->{video_file};

		$_->{file_descr} = $ses->shortenString( $_->{file_descr}, 50 );
		$_->{file_title_txt} = $ses->shortenString( $_->{file_title}||$_->{file_name}, $c->{display_max_filename} );
		$_->{download_link} = $ses->makeFileLink($_);
		$_->{file_downloads}||='';
		$_->{file_views} = $_->{file_views}||$_->{file_views_full} ? "$_->{file_views_full} / $_->{file_views}" : "";
		$_->{comments}||='';
		$_->{"file_status_$_->{file_status}"}=1;
		$ses->getVideoInfo($_);
		$_->{enc_progress} = join ' ', @{$ench->{$_->{file_id}}} if $ench->{$_->{file_id}};

		$_->{transfer} = $db->SelectOne("SELECT s.srv_name FROM QueueTransfer q, Servers s WHERE q.file_real_id=? AND q.srv_id2=s.srv_id",$_->{file_real_id});

        # Extracting file extension from file_name
        if ($_->{file_name} =~ /\.([^.]+)$/) {
            $_->{file_extension} = $1;
        } else {
            $_->{file_extension} = ''; # Set to empty if no extension found
        }

	}

	#my $allfld = $db->SelectARefCached("SELECT * FROM Folders WHERE usr_id=? ORDER BY fld_name",$ses->getUserId);
	#my $fh;
	#push @{$fh->{$_->{fld_parent_id}}},$_ for @$allfld;
	#my @folders_tree = &buildTree($fh,0,0);

	my $categories = genCategoriesSelect();

	$totals->{torrents_num} = $db->SelectOne("SELECT COUNT(*) FROM Torrents WHERE usr_id=? AND status='WORKING'",$ses->getUserId) if $c->{m_t};
	$totals->{deleted_num} = $db->SelectARefCached("SELECT COUNT(*) as x FROM FilesTrash WHERE usr_id=? AND hide=0",$ses->getUserId)->[0]->{x};
	$totals->{dmca_num} = $db->SelectOneCached("SELECT COUNT(*) as x FROM FilesDMCA WHERE usr_id=?",$ses->getUserId) if $c->{m_a};

	my @audio_extensions = split(/\|/, $c->{audio_extensions});
	my @video_extensions = split(/\|/, $c->{video_extensions});
	my @image_extensions = split(/\|/, $c->{image_extensions});

	my $audio_ext = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @audio_extensions) . "')";
	my $video_ext = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @video_extensions) . "')";
	my $image_ext = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @image_extensions) . "')";

	$totals->{audio_num} = $db->SelectOneCached("SELECT COUNT(*) FROM Files USE INDEX (usrfld) WHERE usr_id=? AND file_fld_id=? $audio_ext", $ses->getUserId, $f->{fld_id});
	$totals->{video_num} = $db->SelectOneCached("SELECT COUNT(*) FROM Files USE INDEX (usrfld) WHERE usr_id=? AND file_fld_id=? $video_ext", $ses->getUserId, $f->{fld_id});
	$totals->{image_num} = $db->SelectOneCached("SELECT COUNT(*) FROM Files USE INDEX (usrfld) WHERE usr_id=? AND file_fld_id=? $image_ext", $ses->getUserId, $f->{fld_id});

	my @extra_data = map{{name=>$_}} split /\s*\,\s*/, $c->{file_data_fields};

	#$ses->setCookie('advanced',$f->{advanced});
	#$ses->setCookie('per_page',$f->{per_page});
	$f->{key} = $ses->SecureStr($f->{key});
	$f->{advanced}=~s/\D+//g;

	for my $m ('m_q','m_t')
	{
		$totals->{"$m\_enabled"}=1 if $ses->checkModSpecialRights($m);
	}
	if($c->{m_g} && $c->{srt_mass_upload})
	{
		#my @arr = map{{value=>$_}} split /\s*\,\s*/, $c->{srt_auto_langs};
		#$totals->{srt_langs} = \@arr;
		my @srt_langs = map{/^(\w+)=(\w+)$/;{value=>$1,title=>"$2 ($1)"}} split /\s*\,\s*/, $c->{srt_auto_langs};
			$totals->{srt_langs} = \@srt_langs;
	}

	my $playlists = $db->SelectARef("SELECT * FROM Playlists WHERE usr_id=? ORDER BY pls_name", $ses->getUserId );

	#### Custom ####
	my $user = $ses->getUser;

	if($c->{m_e})
	{
		$user->{tickets_unread} = $db->SelectOne("SELECT COUNT(*) FROM Tickets WHERE usr_id=? AND unread>0",$ses->getUserId);
	}
	#### Custom ####

	$ses->PrintTemplate("my_files.html",
						%{$user},
						files			=> $files,
						folders			=> $folders,
						playlists		=> $playlists,
						folder_id		=> $f->{fld_id},
						folder_name		=> $curr_folder->{fld_name},
						fld_descr		=> $curr_folder->{fld_descr},
						fld_url			=> $curr_folder->{fld_url},
						fld_parent_id	=> $curr_folder->{fld_parent_id},
						parent_folders	=> \@parent_folders,
						key				=> $f->{key},
						disk_space 		=> $disk_space,
						paging 			=> $ses->makePagingLinks($f,$total),
						usr_premium_only => $ses->getUser->{usr_premium_only},
						#'torrents_num'  => $torrents_num,
						enable_file_comments => $c->{enable_file_comments},
						%{$totals},
						%sort_hash,
						categories => $categories,
						token		=> $ses->genToken,
						extra_data => \@extra_data,
						items_per_page => $c->{items_per_page},
						"per_$f->{per_page}" => ' selected',
						srt_mass_upload => $c->{srt_mass_upload},
						my_views_enabled	=> $c->{my_views_enabled},
						#'filters'	=> @filters,
						);
}

sub MyViews
{
	return $ses->message("My Views not enabled") unless $c->{my_views_enabled};
	my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=? AND usr_id=?", $f->{file_code}, $ses->getUserId);
	return $ses->message("File not found") unless $file;
	my $filter_download="AND download=1" if $f->{download};
	my $list = $db->SelectARef("SELECT * FROM Views
								WHERE file_id=?
								AND owner_id=?
								AND created>NOW()-INTERVAL ? DAY
								AND finished=1
								$filter_download
								ORDER BY created DESC
								LIMIT 500",
								$file->{file_id}, $ses->getUserId, $c->{my_views_last_days} );

	for(@$list)
	{
		$_->{money}= $_->{money} eq '0.0000' ? '' : "\$$_->{money}";
		$_->{money}=~s/0+$//;
		$_->{money}=~s/\.$//;
		$_->{size} = sprintf("%.0f", $_->{size}/1024**2 );
	}

	return $ses->PrintTemplate("my_views.html",
								list		=> $list,
								download	=> $f->{download},
								);
}

sub buildTree
{
	my ($fh,$parent,$depth)=@_;
	my @tree;
	for my $x (@{$fh->{$parent}})
	{
		$x->{pre}='&nbsp;&nbsp;'x$depth;
		push @tree, $x;
		push @tree, buildTree($fh,$x->{fld_id},$depth+1);
	}
	return @tree;
}

sub buildTreeCategories
{
	my ($fh,$parent,$depth,$cat_id_sel)=@_;
	my @tree;
	for my $x (@{$fh->{$parent}})
	{
		$x->{pre}='&nbsp;&nbsp;'x$depth;
		$x->{selected}=' selected' if $x->{cat_id}==$cat_id_sel;
		push @tree, $x;
		push @tree, buildTreeCategories($fh,$x->{cat_id},$depth+1,$cat_id_sel);
	}
	return @tree;
}

sub genCategoriesSelect
{
	 my ($cat_id_sel) = @_;
	 my $list = $db->SelectARefCached(300,"SELECT * FROM Categories");
	 my $fh;
	 push @{$fh->{$_->{cat_parent_id}}},$_ for @$list;
	 my @categories = buildTreeCategories($fh,0,0,$cat_id_sel);
	 return \@categories;
}

sub getFolderChilds
{
	my ($fld_id) = @_;
	my @arr = ($fld_id);
	my $childs = $db->SelectARef("SELECT fld_id FROM Folders WHERE usr_id=? AND fld_parent_id=?",$ses->getUserId,$fld_id);
	for(@$childs)
	{
		push @arr, getFolderChilds($_->{fld_id});
	}
	return @arr;
}

sub MyFilesExport
{
	#print $ses->{cgi_query}->header( -type	 => 'text/html',
	#											-expires => '-1d',
	#											-charset => $c->{charset});
	my $filter;
	if($f->{file_id})
	{
		my $ids = join ',', grep{/^\d+$/}@{ARef($f->{file_id})};
		$filter="AND file_id IN ($ids)" if $ids;
	}
	if($f->{fld_id1})
	{
		my @arr;
		for(@{ARef($f->{fld_id1})})
		{
			push @arr, getFolderChilds($_);
		}
		$filter="AND file_fld_id IN (".join(',',@arr).")" if @arr;
	}
	return unless $filter;

	my @image_files;
    my @video_files;
    my @audio_files;
    my @other_files;

	my $list = $db->SelectARef("SELECT * FROM Files f, Servers s
								WHERE usr_id=?
								AND f.srv_id=s.srv_id
								$filter
								ORDER BY file_name",$ses->getUserId);

    for (@$list) {
        $_->{download_link} = $ses->makeFileLink($_);
        $ses->getVideoInfo($_);
        $_->{size} = $ses->makeFileSize($_->{file_size});
        $_->{embed_code} = $ses->makeEmbedCode($_);

        # Classify files based on their extensions
        if ($c->{video_extensions} && $_->{file_name} =~ /\.($c->{video_extensions})$/i) {
            push @video_files, $_;
        }
        elsif ($c->{image_extensions} && $_->{file_name} =~ /\.($c->{image_extensions})$/i) {
            push @image_files, $_;
        }
        elsif ($c->{audio_extensions} && $_->{file_name} =~ /\.($c->{audio_extensions})$/i) {
            push @audio_files, $_;
        }
        else {
            push @other_files, $_;
        }

        # Extracting file extension from file_name
        if ($_->{file_name} =~ /\.([^.]+)$/) {
            $_->{file_extension} = $1;
        } else {
            $_->{file_extension} = ''; # Set to empty if no extension found
        }
    }


	$ses->PrintTemplate("my_files_export.html",
                        image_files => \@image_files,
                        video_files => \@video_files,
                        audio_files => \@audio_files,
                        other_files => \@other_files,
						m_x => $c->{m_x},
						);
}

sub FileEdit
{
	my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{file_code});

	return $ses->message("No such file!") unless $file;
	return $ses->message("It's not your file!") if !$ses->getUser->{usr_adm} && $file->{usr_id}!=$ses->getUserId;
	if($f->{del_tag})
	{
		$db->Exec("DELETE FROM Tags2Files WHERE file_id=? AND tag_id=?",$file->{file_id},$f->{del_tag});
		return $ses->redirect("?op=file_edit&file_code=$file->{file_code}");
	}

	$file->{premium_only_mod}=1 if $ses->getUser->{usr_premium_only} || $ses->getUser->{usr_adm};

	if($c->{srt_on} && $f->{del_srt})
	{
		return $ses->message("Invalid language") unless $f->{del_srt}=~/^\w{3}$/i;
		my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
		# my $dir = "$c->{site_path}/srt/$dx";
		# unlink("$dir/$file->{file_code}_$f->{del_srt}.$f->{ext}");
		my $res = $ses->api2($file->{srv_id},
							{
								op => 'srt_delete',
								file_code	  => $file->{file_code},
								dx			=> $dx,
								language		=> $f->{del_srt}
							});
		return $ses->message("ERROR:$res") unless $res eq 'OK';
		$file->{file_captions} = join '|', grep{$_ ne $f->{del_srt}} split(/\|/, $file->{file_captions});
		$db->Exec("UPDATE Files SET file_captions=? WHERE file_id=?", $file->{file_captions}, $file->{file_id});
		return $ses->redirect("?op=file_edit&file_code=$file->{file_code}");
	}
	if($c->{srt_on} && $f->{del_srt_file})
	{
		return $ses->message("Invalid language file") unless $f->{del_srt_file}=~/^[\w\_]+\.vtt$/i;
		my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
		unlink("$c->{site_path}/srt/$dx/$f->{del_srt_file}");
		return $ses->redirect("?op=file_edit&file_code=$file->{file_code}");
	}
	if($c->{srt_on} && $f->{srt})
	{
		saveSRT() || return;
		return $ses->redirect("?op=file_edit&file_code=$file->{file_code}");
	}
	if($f->{reset_proxies} && $ses->getUser->{usr_adm})
	{
		$db->Exec("DELETE FROM Proxy2Files WHERE file_id=?",$file->{file_id});
		return $ses->redirect_msg("?op=file_edit&file_code=$file->{file_code}","Proxy pairs reset done");
	}

	if($f->{save})
	{
		$f->{file_name}=~s/%(\d\d)/chr(hex($1))/egs;
		$f->{file_name}=~s/%/_/gs;
		$f->{file_name}=~s/\s{2,}/ /gs;
		$f->{file_name}=~s/[\"]+/_/gs;
		$f->{file_name}=~s/[^\w\d\.-]/_/g if $c->{sanitize_filename};
		#return $ses->message("Filename have unallowed extension") if $c->{video_extensions} && $f->{file_name}!~/\.($c->{video_extensions})$/i;
		$f->{file_title} = $ses->SecureStr($f->{file_title});
		$f->{audio_artist} = $ses->SecureStr($f->{audio_artist});
		$f->{audio_title} = $ses->SecureStr($f->{audio_title});
		$f->{audio_album} = $ses->SecureStr($f->{audio_album});
		$f->{audio_genre} = $ses->SecureStr($f->{audio_genre});
		#$f->{file_descr} = $ses->SecureStr($f->{file_descr});
		$f->{file_descr} = $ses->{cgi_query}->param('file_descr');


		return $ses->message($ses->{lang}->{lng_fileform_filename_too_short}) if length($f->{file_name})<5;
		my $file_status = ",file_status='$f->{file_status}'" if $ses->getUser->{usr_adm} && $f->{file_status}=~/^\w+$/;
		$f->{file_premium_only}||=0;
		my $file_premium = ",file_premium_only='$f->{file_premium_only}'" if $file->{premium_only_mod} && $f->{file_premium_only}=~/^\d*$/;
		my $file_code_new=",file_code='$f->{file_code_new}'" if $ses->getUser->{usr_adm} && $f->{file_code_new} ne $file->{file_code} && $f->{file_code_new}=~/^\w{12}$/ && !$db->SelectOne("SELECT usr_id FROM Files WHERE file_code=?",$f->{file_code_new});
		$db->Exec("UPDATE Files
					SET file_name=?,
							file_title=?,
							audio_artist=?,
							audio_title=?,
							audio_album=?,
							audio_genre=?,
							file_descr=?,
							file_public=?,
							file_comments=?,
							file_download_on=?,
							file_dl_link=?,
							file_dl_title=?,
							file_adult=?,
							cat_id=?
							$file_status
							$file_premium
							$file_code_new
					WHERE file_code=?",
					$f->{file_name},
					$f->{file_title},
					$f->{audio_artist},
					$f->{audio_title},
					$f->{audio_album},
					$f->{audio_genre},
					$f->{file_descr},
					$f->{file_public}||0,
					$f->{file_comments}||1,
					$f->{file_download_on}||1,
					$f->{file_dl_link}||'',
					$f->{file_dl_title}||'',
					$f->{file_adult}||0,
					$f->{cat_id},
					$f->{file_code});

		XUtils::addTagsToFile($db,$f->{tags},$file->{file_id});

		if($c->{file_data_fields})
		{
			my $extra_fields;
			$extra_fields->{$_}=1 for split /\s*\,\s*/, $c->{file_data_fields};
			my %extra;
			$extra{$_}=$f->{"extra_$_"} for grep {$extra_fields->{$_}} map{s/^extra_//;$_} grep{/^extra_/} keys %$f;
			for my $kk (keys %extra)
			{
					$extra{$kk}=~s/^\s+//g;
					$extra{$kk}=~s/\s+$//g;
					if ($extra{$kk})
					{
						$db->Exec("INSERT INTO FilesData SET file_id=?, name=?, value=?
										ON DUPLICATE KEY UPDATE value=?", $file->{file_id}, $kk, $extra{$kk}, $extra{$kk} );
					}
					else
					{
						$db->Exec("DELETE FROM FilesData WHERE file_id=? AND name=?", $file->{file_id}, $kk );
					}
			}
		}
		$f->{file_code}=$f->{file_code_new} if $f->{file_code_new};
		return $ses->redirect_msg("?op=file_edit&file_code=$f->{file_code}",$ses->{lang}->{lng_fileform_file_details_saved}) if $ses->getUserId != $file->{usr_id}; # admin
		return $ses->redirect_msg("?op=file_edit&file_code=$f->{file_code}",$ses->{lang}->{lng_fileform_file_details_saved}); # return back to edit file
		#return $ses->redirect_msg("?op=my_files&fld_id=$file->{file_fld_id}",$ses->{lang}->{lng_fileform_file_details_saved}); # return back to file list
	}

	my $tags = $db->SelectARef("SELECT * FROM Tags t, Tags2Files t2f WHERE t2f.file_id=? AND t2f.tag_id=t.tag_id",$file->{file_id});


	$file->{categories} = genCategoriesSelect($file->{cat_id});
	$file->{file_url} = $ses->makeFileLink($file);
	$file->{"file_status_$file->{file_status}"} = ' selected';

	$ses->getVideoInfo($file);

	my @versions;
	for my $mode ('o',reverse @{$c->{quality_letters}},'p')
	{
		next unless $file->{"file_size_$mode"};
		my $x = $ses->vInfo($file,$mode);
		$x->{vid_title} = $c->{quality_labels_full}->{$mode};
		$x->{vid_mode} = $mode||'o';
		$x->{vid_container} = uc $x->{vid_container};
		push @versions, $x;
	}
	$file->{versions} = \@versions;

	for my $m ('m_s','m_e','m_g')
	{
		$file->{"$m\_enabled"}=1 if $ses->checkModSpecialRights($m);
	}

	my $fdata = $db->SelectARef("SELECT * FROM FilesData WHERE file_id=?",$file->{file_id});
	my $fdhash;
	$fdhash->{$_->{name}}=$_->{value} for @$fdata;
	my @extra_data = map{{name=>$_,value=>$fdhash->{$_}}} split /\s*\,\s*/, $c->{file_data_fields};

	$file->{is_dupe}=1 if $file->{file_code} ne $file->{file_real};

	if($c->{srt_on} && $c->{srt_auto_langs})
	{
		#my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
		#my @arr = map{{language=>$_, url=>"$file->{srv_htdocs_url}/vtt/$file->{disk_id}/$dx/$file->{file_code}_$_.vtt"}} split(/\|/, $file->{file_captions});
		#$file->{captions_list} = \@arr;
		$file->{captions_list} = $ses->getCaptionsLinks($file);

		my @srt_langs = map{/^(\w+)=(\w+)$/;{value=>$1,title=>"$2 ($1)"}} split /\s*\,\s*/, $c->{srt_auto_langs};
		$file->{srt_langs} = \@srt_langs;
		$file->{srt_on}=1;
	}

	if($c->{m_p} && $c->{m_p_custom_upload})
	{
		$file->{m_p_custom_upload}=1;
		require Digest::MD5;
		$file->{md5} = Digest::MD5::md5_hex($file->{file_id}.$file->{file_real}.$c->{dl_key});
	}

	$file->{encoding} = $db->SelectOne("SELECT UPPER(GROUP_CONCAT(quality SEPARATOR ', ')) FROM QueueEncoding WHERE file_real_id=? GROUP BY file_real_id",$file->{file_real_id});
	$file->{transfer} = $db->SelectOne("SELECT s.srv_name FROM QueueTransfer q, Servers s WHERE q.file_real_id=? AND q.srv_id2=s.srv_id",$file->{file_real_id});
	$file->{fld_name} = $db->SelectOneCached("SELECT fld_name FROM Folders WHERE fld_id=?",$file->{file_fld_id});

	if($ses->getUser->{usr_adm})
	{
		$file->{file_logs} = $db->SelectARef("SELECT * FROM FileLogs WHERE file_real=?",$file->{file_real});
		$file->{proxies} = $db->SelectARef("SELECT h.host_name, h.host_id FROM Proxy2Files p, Hosts h
											WHERE p.file_id=?
											AND p.host_id=h.host_id",$file->{file_id});
	}

	$file->{is_image} = $c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i;
	$file->{is_audio} = $c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i;
	$file->{is_video} = $c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i;
	$file->{is_archive} = $c->{archive_extensions} && $file->{file_name} =~ /\.($c->{archive_extensions})$/i;

	$file->{is_media} = $file->{is_audio} || $file->{is_video} || $file->{is_image};

	$file->{vid_audio_file} = $file->{is_audio} || $file->{is_video};

	if($f->{upload_new} && $c->{m_s_upload})
	{
		my $file = $db->SelectRow("SELECT * FROM Files f, Servers s WHERE f.file_code=? AND f.usr_id=? AND f.srv_id=s.srv_id",$f->{file_code},$ses->getUserId);
		return $ses->message("No file") unless $file;
		my $uid=$ses->getUserId;


		my $old_audio_thumb = $db->SelectRow("SELECT audio_thumb FROM Files WHERE file_id=?", $file->{file_id})->{audio_thumb};
		my $old_video_thumb = $db->SelectRow("SELECT video_thumb FROM Files WHERE file_id=?", $file->{file_id})->{video_thumb};
		my $old_video_thumb_t = $db->SelectRow("SELECT video_thumb_t FROM Files WHERE file_id=?", $file->{file_id})->{video_thumb_t};
		# Check if the old thumbnail is used by other files
		my $thumb_shared_audio = $db->SelectRow("SELECT COUNT(*) as count FROM Files WHERE audio_thumb=? AND file_id != ?", $old_audio_thumb, $file->{file_id})->{count};
		my $thumb_shared_video = $db->SelectRow("SELECT COUNT(*) as count FROM Files WHERE video_thumb=? AND file_id != ?", $old_video_thumb, $file->{file_id})->{count};
		my $thumb_shared_video_t = $db->SelectRow("SELECT COUNT(*) as count FROM Files WHERE video_thumb_t=? AND file_id != ?", $old_video_thumb_t, $file->{file_id})->{count};

		my $rand = join '', map int rand 10, 1..10;

		if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
			my $audio_thumb;
			$audio_thumb = "aud_".$rand.".jpg";
			$file->{audio_thumb} = $audio_thumb;
			$db->Exec("UPDATE Files SET audio_thumb=? WHERE file_id=?",$file->{audio_thumb},$file->{file_id});
		}

		if ($c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i) {
			my $video_thumb;
			my $video_thumb_t;
			$video_thumb = "vid_".$rand.".jpg";
			$video_thumb_t = "vid_".$rand."_t.jpg";
			$file->{video_thumb} = $video_thumb;
			$file->{video_thumb_t} = $video_thumb_t;
			$db->Exec("UPDATE Files SET video_thumb=? WHERE file_id=?",$file->{video_thumb},$file->{file_id});
			$db->Exec("UPDATE Files SET video_thumb_t=? WHERE file_id=?",$file->{video_thumb_t},$file->{file_id});
		}

		my $thumb = "$c->{site_path}/captchas/th$uid.jpg";
		uploadMoveFile('file', $thumb)|| return $ses->message("Upload error:$!");

		require GD;
		my $im = new GD::Image($thumb) || return $ses->message("Failed to read the image");
		my ($w,$image_height) = $im->getBounds();
		return $ses->message("Invalid image") unless $w && $image_height;
		#return $ses->message("Image is too large ($w x $h)") if $w>1920 || $h>1080;
		my $params = {
					dl_key=>$c->{dl_key},
					op			=> 'thumb_upload',
					disk_id	=> $file->{disk_id},
					file_id	=> $file->{file_real_id}||$file->{file_id},
					file_code  => $file->{file_real},
					audio_thumb  => $file->{audio_thumb},
					video_thumb  => $file->{video_thumb},
					video_thumb_t  => $file->{video_thumb_t},
					file		=> [$thumb]
			};

		if ($c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i) {
			if ($w > 1280 || $image_height > 720) {
				resizeGD2($im, 1280, 720, $thumb);
			}
			$params->{old_video_thumb} = $thumb_shared_video ? '' : $old_video_thumb; # Only pass old thumbnail if it's not shared
			$params->{old_video_thumb_t} = $thumb_shared_video_t ? '' : $old_video_thumb_t; # Only pass old thumbnail if it's not shared
			$params->{op} = 'thumb_upload'; # Set operation for video
		} else {
			if ($w > 500 || $image_height > 500) {
				resizeGD2($im, 500, 500, $thumb);
			}
			$params->{old_audio_thumb} = $thumb_shared_audio ? '' : $old_audio_thumb; # Only pass old thumbnail if it's not shared
			$params->{op} = 'thumb_upload_audio'; # Set operation for audio
		}

		require HTTP::Request::Common;
		require LWP::UserAgent;
		my $ua = LWP::UserAgent->new(agent=>$c->{user_agent},timeout=>300);
		my $req = HTTP::Request::Common::POST( "$file->{srv_cgi_url}/api.cgi", Content_Type => 'form-data', Content => $params);
		my $res = $ua->request($req)->content;
		unlink($thumb);
		return $ses->message("Upload error: $res") unless $res=~/^OK$/i;
		return $ses->redirect("?op=file_edit&file_code=$file->{file_code}&newshot=1");
	}

	# Set the selected attribute for the appropriate option # File Comments
	if ($file->{file_comments} == 1 ) {
		$file->{file_comment1} = 'selected';
	} elsif ($file->{file_comments} == 2) {
		$file->{file_comment2} = 'selected';
	} elsif ($file->{file_comments} == 3) {
		$file->{file_comment3} = 'selected';
	}

	# Set the selected attribute for the appropriate option # File Download
	if ($file->{file_download_on} == 1 ) {
		$file->{file_download_on1} = 'selected';
	} elsif ($file->{file_download_on} == 2) {
		$file->{file_download_on2} = 'selected';
	} elsif ($file->{file_download_on} == 3) {
		$file->{file_download_on3} = 'selected';
	}

	my $qeditor = 1;

	$ses->PrintTemplate("file_form.html",
						%{$file},
						tags => $tags,
						rand => $ses->randchar(6),
						extra_data => \@extra_data,
						enable_file_descr => $c->{enable_file_descr},
						newshot => $f->{newshot},
						qeditor => $qeditor
						);
}

sub FolderEdit
{
	my $folder = $db->SelectRow("SELECT * FROM Folders WHERE fld_id=? AND usr_id=?",$f->{fld_id},$ses->getUserId);
	return $ses->message("No such folder!") unless $folder;
	if($f->{save})
	{
		$f->{fld_name}  = $ses->SecureStr($f->{fld_name});
		$f->{fld_url}||=lc $f->{fld_name};
		$f->{fld_url}=~s/\s*-\s*/-/g;
		$f->{fld_url}=~s/\s+/-/g;
		$f->{fld_url}=~s/[^\w\d.-]//g;
		$f->{fld_url} .= "-$f->{fld_id}" if defined $f->{fld_id};
		#$f->{fld_descr} = $ses->SecureStr($f->{fld_descr});
		$f->{fld_descr} = $ses->{cgi_query}->param('fld_descr');
		utf8::decode($f->{fld_name});
		return $ses->message("Folder name too short") if length($f->{fld_name})<3;
		return $ses->message("Folder name is not kosher") unless $f->{fld_name}=~/[\w\d]+/;
		utf8::encode($f->{fld_name});
		$db->Exec("UPDATE Folders SET fld_name=?, fld_url=?, fld_descr=?, fld_hide=? WHERE fld_id=?",$f->{fld_name},$f->{fld_url},$f->{fld_descr},$f->{fld_hide}||0,$f->{fld_id});
		$db->PurgeCache( "ufld-$folder->{fld_parent_id}-".$ses->getUserId );
		#return $ses->redirect("?op=my_files&fld_id=$folder->{fld_parent_id}");

		if($f->{fld_cover})
		{
			# Fetch the current cover filename from the database
			my ($current_cover_filename) = $db->SelectOne("SELECT fld_cover FROM Folders WHERE fld_id=? AND usr_id=?", $f->{fld_id}, $ses->getUserId);
			my $current_cover = $current_cover_filename ? "$c->{site_path}/upload-data/".$current_cover_filename : undef;

			# Generate a new random filename for the new cover
			my $rand = $ses->randchar(6);
			my $cover_filename = "album_".$rand.".jpg";
			my $coverfile = "$c->{site_path}/upload-data/".$cover_filename;

			# Handle the file upload
			my $fh = $ses->{cgi_query}->upload('fld_cover');
			return $ses->message("Error fetching cover: ".$ses->{cgi_query}->cgi_error()) unless $fh;

			require GD;
			GD::Image->trueColor(1);
			my $im = new GD::Image($fh) || return $ses->message("Failed to read the image cover");
			my ($w, $h) = $im->getBounds();
			unlink($coverfile), return $ses->message("Invalid image") unless $w && $h;

			# Update the database with the new cover filename
			if ($db->Exec("UPDATE Folders SET fld_cover=? WHERE fld_id=? AND usr_id=?", $cover_filename, $f->{fld_id}, $ses->getUserId)) {
				# Delete the old cover file if it exists and is different from the new one
				if ($current_cover && -e $current_cover && $current_cover ne $coverfile) {
					unlink $current_cover or warn "Could not delete old cover file: $current_cover: $!";
				}
			}

			# Resize the image if necessary
			if($w>1600 || $h>500) {
				resizeGD($im, 1600, 500, $coverfile);
			}
			else {
				uploadMoveFile('fld_cover', $coverfile) || return $ses->message("Error saving cover: $!");
			}
		}

		return $ses->redirect_msg("?op=fld_edit&fld_id=$folder->{fld_id}","Successfully Saved");

	}

	if($f->{cover_delete} && $ses->checkToken)
	{
		# Fetch the current cover filename from the database
		my ($current_cover_filename) = $db->SelectOne("SELECT fld_cover FROM Folders WHERE fld_id=? AND usr_id=?", $f->{fld_id}, $ses->getUserId);
		my $current_cover = $current_cover_filename ? "$c->{site_path}/upload-data/".$current_cover_filename : undef;

		# Delete the current cover file if it exists
		if ($current_cover && -e $current_cover) {
			unlink $current_cover or warn "Could not delete cover file: $current_cover: $!";
		}

		# Update the database to reflect that the user no longer has an cover
		$db->Exec("UPDATE Folders SET fld_cover=NULL WHERE fld_id=? AND usr_id=?", $f->{fld_id}, $ses->getUserId);

		# Redirect to the user account page
		return $ses->redirect_msg("?op=fld_edit&fld_id=$folder->{fld_id}","Successfully Deleted");
	}

	my $qeditor = 1;
	$ses->PrintTemplate("folder_form.html",
						%{$folder},
						qeditor => $qeditor );
}

sub Payments
{
	return $ses->redirect($c->{site_url}) unless $c->{enabled_prem};

	if($f->{check_transaction})
	{
		print"Content-type: application/json\n\n";
		my $transaction = $db->SelectRow("SELECT * FROM Transactions WHERE id=?", $f->{check_transaction});
		print(q|{ "status" : "verified" }|),return if $transaction && $transaction->{verified};
		print(q|{ "status" : "unknown" }|),return;
	}

	if(my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?", $ENV{HTTP_REFERER} =~ /\/(\w{12})/))
	{
		$ses->setCookie("aff",$file->{usr_id},'+14d');
	}

	if($c->{no_anon_payments} && !$ses->getUser)
	{
		return $ses->redirect("$c->{site_url}/?op=registration&next=payments-$f->{type}-$f->{amount}");
	}

	if($f->{amount})
	{
		$f->{amount}=sprintf("%.02f",$f->{amount});

		return $ses->redirect('/login.html') if $c->{disable_anon_payments} && !$ses->getUserId;

		return $ses->message("You're not a reseller!") if $c->{m_k_manual} && $f->{reseller} && !$ses->getUser->{usr_reseller};
		$f->{referer}='RESELLER' if $f->{reseller};
		$f->{item_name}=~s/\W+//g;

		if($f->{storage} && $c->{plans_storage})
		{
			$f->{referer}='STORAGE';
			my $phash;
			for ( split( /\s*,\s*/, $c->{plans_storage} ) ) {
				/([\d\.]+)=(\d+)=(\d+)/;
				$phash->{$1} = $2;
			}
			my $gb = $phash->{$f->{amount}};
			$f->{item_name}="$gb GB" if $gb;
			return $ses->message("Invalid storage price") unless $gb;
		}

		$f->{item_name}||=$c->{item_name};

		my %opts = %{$f};
		$opts{usr_id} = $ses->getUser ? $ses->getUserId : 0;
		$opts{aff_id} = getAffiliate();
		$opts{referer} ||= $ses->getCookie('ref_url') || $ENV{HTTP_REFERER} || '';
		$opts{email} = $ses->getUser->{usr_email} if $ses->getUser;
		$opts{days} = $ses->ParsePlans($c->{payment_plans}, 'hash')->{$f->{amount}};
		return $ses->message("Invalid payment amount") if !$f->{reseller} && !$f->{storage} && !$opts{days};

		require IPN;
		my $transaction = IPN->new($ses)->createTransaction(%opts);
		$f->{id} = $transaction->{id};
		$f->{email} = $ses->getUser->{usr_email} if $ses->getUser;
		$ses->setCookie('transaction_id', $transaction->{id});
		my $url = $ses->getPlugins('Payments')->checkout($f) || return;

		# Some APIs aren't allowing to pass the transaction ID with Return URL
		return $ses->redirect($url) if $url && !$f->{no_redirect};
	}

	my $cc;
	$cc->{$_}=$c->{$_} for keys %$c;
	for ('reg','prem')
	{
		$cc->{"max_upload_filesize_$_"} = $cc->{"max_upload_filesize_$_"} ? $cc->{"max_upload_filesize_$_"}." MB" : "No limits";
		$cc->{"down_speed_$_"} = $cc->{"down_speed_$_"} ? $cc->{"down_speed_$_"}." Kbytes/sec" : "Unmetered";
		$cc->{"disk_space_$_"} = $cc->{"disk_space_$_"} ? $cc->{"disk_space_$_"}.' GB' : "Unlimited";
	}

	$cc->{max_downloads_number_reg}||='Unlimited';
	$cc->{max_downloads_number_prem}||='Unlimited';

	$cc->{files_expire_reg}  = $cc->{files_expire_access_reg}  ? "$cc->{files_expire_access_reg} $ses->{lang}->{lng_comparison_days_after_dl}" : $ses->{lang}->{lang_never};
	$cc->{files_expire_prem} = $cc->{files_expire_access_prem} ? "$cc->{files_expire_access_prem} $ses->{lang}->{lng_comparison_days_after_dl}" : $ses->{lang}->{lang_never};

	$cc->{bw_limit_reg}  = $cc->{bw_limit_reg}  ? "$cc->{bw_limit_reg} GB / $cc->{bw_limit_days} $ses->{lang}->{lng_misc_days}" : $ses->{lang}->{lng_comparison_unlimited};
	$cc->{bw_limit_prem} = $cc->{bw_limit_prem} ? "$cc->{bw_limit_prem} GB / $cc->{bw_limit_days} $ses->{lang}->{lng_misc_days}" : $ses->{lang}->{lng_comparison_unlimited};

	$cc->{max_watch_time_reg_txt} = $cc->{max_watch_time_reg} ? "$cc->{max_watch_time_reg} $ses->{lang}->{lng_misc_mins} / $ses->{lang}->{lng_comparison_day}" : $ses->{lang}->{lng_comparison_unlimited};
	$cc->{max_watch_time_prem_txt} = $cc->{max_watch_time_prem} ? "$cc->{max_watch_time_prem} $ses->{lang}->{lng_misc_mins} / $ses->{lang}->{lng_comparison_day}" : $ses->{lang}->{lng_comparison_unlimited};

	$cc->{max_download_filesize_reg_txt} = $cc->{max_download_filesize_reg} ? "$cc->{max_download_filesize_reg} MB" : $ses->{lang}->{lng_comparison_unlimited};
	$cc->{max_download_filesize_prem_txt} = $cc->{max_download_filesize_prem} ? "$cc->{max_download_filesize_prem} MB" : $ses->{lang}->{lng_comparison_unlimited};

	require Time::Elapsed;
	my $et = new Time::Elapsed;
	#my @payment_types = $ses->getPlugins('Payments')->get_payment_buy_with;
	my @payment_types;
	for my $opts($ses->getPlugins('Payments')->get_payment_buy_with())
	{
		if($opts->{submethods})
		{
			push @payment_types, { %$opts, %$_, submethod => $_->{name}, name => $opts->{name} } for @{ $opts->{submethods} };
		}
		else
		{
			push @payment_types, { %$opts };
		}
	}

	if($c->{plans_storage})
	{
		my @arr;
		for ( split( /\s*,\s*/, $c->{plans_storage} ) ) {
			/([\d\.]+)=(\d+)=(\d+)/;
			push @arr, { amount=>$1, storage=>$2, days=>$3 };
		}
		$cc->{storage_plans} = \@arr;
	}

	$ses->PrintTemplate("payments.html",
						%{$cc},
						payment_types => \@payment_types,
						plans => $ses->ParsePlans($c->{payment_plans}, 'array'),
						premium => $ses->getUser && $ses->getUser->{premium},
						expire_elapsed => $ses->getUser && $et->convert($ses->getUser->{exp_sec}),
						'rand' => $ses->randchar(6),
						ask_email => !$ses->getUserId && !$c->{no_anon_payments},
	);
}

sub PaymentComplete
{
	my $str = shift;
	$str = $ses->getCookie('transaction_id') if $ses->getCookie('transaction_id');
	my ($id,$usr_id)=split(/-/,$str);
	my $trans = $db->SelectRow("SELECT *, INET_NTOA(ip) as ip, (UNIX_TIMESTAMP()-UNIX_TIMESTAMP(created)) as dt
								FROM Transactions
								WHERE id=?",$id) if $id;
	return $ses->message("No such transaction exist") unless $trans;
	return $ses->message("Internal error") unless $trans->{ip} eq $ENV{REMOTE_ADDR};
	return $ses->message("Your account created successfully.<br>Please check your e-mail for login details") if $trans->{dt}>3600;
	return $ses->message("Your payment have not verified yet.<br>Please refresh this page in 1-3 minutes") unless $trans->{verified};

	my $user = $db->SelectRow("SELECT *, DECODE(usr_password,?) as usr_password,
										UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec
								FROM Users
								WHERE usr_id=?",$c->{pasword_salt},$trans->{usr_id});
	require Time::Elapsed;
	my $et = new Time::Elapsed;
	my $exp = $et->convert($user->{exp_sec});
	return $ses->message("Your payment processed successfully!<br><br>Login: $user->{usr_login}<br>Password: $user->{usr_password}<br><br>Your premium account expires in:<br>$exp");
}

sub CheckFiles
{
	$f->{list}=~s/\r//gs;
	my ($i,@arr);
	for( split /\n/, $f->{list} )
	{
		$i++;
		my ($code,$fname) = /\/(\w{12})\/?(.*?)$/;
		next unless $code;
		$fname=~s/\.html?$//i;
		$fname=~s/_/ /g;
		#my $filter_fname="AND file_name='$fname'" if $fname=~/^[^'"<>]+$/;
		my $file = $db->SelectRow("SELECT f.file_id,f.file_name,s.srv_status FROM Files f, Servers s WHERE f.file_code=? AND s.srv_id=f.srv_id",$code);
		push(@arr,"<font color='red'>$_ $ses->{lang}->{lng_checkfiles_not_found}</font>"),next unless $file;
		$file->{file_name}=~s/_/ /g;
		#push(@arr,"<font color='red'>$_ filename don't match!</font>"),next if $fname && $file->{file_name} ne $fname;
		push(@arr,"<font color='orange'>$_ $ses->{lang}->{lng_checkfiles_exist_not_available}</font>"),next if $file->{srv_status} eq 'OFF';
		push(@arr,"<font color='green'>$_ $ses->{lang}->{lng_checkfiles_found}</font>");
	}
	$ses->PrintTemplate("checkfiles.html",
						'result' => join "<br>", @arr,
						);
}

sub IndexPage
{

	$ses->{expires}="+$c->{caching_expire}s" if $c->{caching_expire};
	$ses->PrintTemplate("index_page.html",
						index_featured_on	 => $c->{index_featured_on},
						index_most_viewed_on => $c->{index_most_viewed_on},
						index_most_rated_on  => $c->{index_most_rated_on},
						index_just_added_on  => $c->{index_just_added_on},
						index_live_streams_on => $c->{index_live_streams_on},
						'm_z'		  => $c->{m_z},
						'm_z_cols'	=> $c->{m_z_cols},
						'm_z_rows'	=> $c->{m_z_rows},
						);
}

sub Search
{
	return $ses->redirect($c->{site_url}) unless $c->{enable_search};
	return $ses->redirect($c->{site_url}) if $c->{enable_search}==2 && !$ses->getUserId;
	return $ses->redirect($c->{site_url}) if $c->{highload_mode};
	$f->{page}||=1;
	my $title = $ses->{lang}->{lng_index_videos};
	for(qw(k user tag))
	{
		$f->{$_} =~ s/[\"\0\\\;]+//g;
	}

	my @filters;

	if(length($f->{k})>2)
	{
		push @filters, qq[AND (file_name LIKE "%$f->{k}%" OR file_title LIKE "%$f->{k}%" OR file_descr LIKE "%$f->{k}%")];
	}

	$f->{cat_id} = $db->SelectARefCached(300,"SELECT cat_id FROM Categories WHERE cat_name=?",$f->{cat_name})->[0]->{cat_id} if $f->{cat_name};
	if($f->{cat_id}=~/^\d+$/)
	{
		push @filters, "AND cat_id='$f->{cat_id}'";
	}

	if($f->{playlist})
	{
		my $playlist = $db->SelectRow("SELECT * FROM Playlists WHERE pls_code=?",$f->{playlist});
		my $pfiles = $db->SelectARef("SELECT * FROM Files2Playlists WHERE pls_id=?",$playlist->{pls_id});
		my $ids = join ',', map{$_->{file_id}} @$pfiles;
		push @filters, "AND file_id IN ($ids)" if $ids;
		$title = $playlist->{pls_name};
		$f->{hide_search}=1;
	}

	if($f->{user})
	{
		my $usr_id = $db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$f->{user});
		push @filters, "AND f.usr_id=$usr_id" if $usr_id;
	}

	my ($filter_tag1,$filter_tag2);
	if($f->{tag})
	{
		my $tag=$f->{tag};
		utf8::decode($tag);
		$tag=lc $tag;
		$tag=~s/[^\w\s\.\&]+//g;
		utf8::encode($tag);
		if(length($tag)>2)
		{
			my $tag_id = $db->SelectOne("SELECT tag_id FROM Tags WHERE tag_value=?",$tag);
			if($tag_id)
			{
				$filter_tag1=",Tags2Files t2f";
				$filter_tag2="AND f.file_id=t2f.file_id AND t2f.tag_id=$tag_id";
			}
		}
	}

	my ($filter_data1,$filter_data2);
	$f->{data_name}=~s/[^\w\s\_\-]//g;
	if($f->{data_name} && $f->{data_value})
	{
		my $value=$f->{data_value};
		utf8::decode($value);
		$value=lc $value;
		$value=~s/[^\w\s\.\&\-\_]+//g;
		utf8::encode($value);
		if(length($value)>2)
		{
			#my $tag_id = $db->SelectOne("SELECT tag_id FROM Tags WHERE tag_value=?",$tag);
			$filter_data1=",FilesData fd";
			$filter_data2="AND f.file_id=fd.file_id AND fd.name='$f->{data_name}' AND fd.value='$value'";
		}
	}

	#my $filter_folder;
	if($f->{fld_code})
	{
		my $folder = $db->SelectRow("SELECT * FROM Folders WHERE fld_code=?",$f->{fld_code});
		$title = "$folder->{fld_name}";
		push @filters, "AND f.usr_id=$folder->{usr_id} AND f.file_fld_id=$folder->{fld_id}";
	}

	# Avoid empty filters full search
	push @filters, "AND f.file_id=0" unless @filters || ($filter_tag2 || $filter_data2);

	push @filters, "AND f.file_public=1" if $c->{search_public_only} && !$f->{playlist};

	#push @filters, "AND (f.file_size_n>0 OR f.file_size_h>0 OR f.file_size_l>0 OR f.file_size_x>0)";

	my $filters_string = join "\n", @filters;

	# my $ids = $db->SelectARefCached("SELECT f.*, TO_DAYS(CURDATE())-TO_DAYS(file_created) as created,
	#												s.disk_id, s.srv_htdocs_url,
	#												u.usr_login
	#									  FROM (Files f, Servers s, Users u $filter_tag1 $filter_data1)
	#									  WHERE f.file_created < NOW()-INTERVAL 5 MINUTE
	#									  AND f.srv_id=s.srv_id
	#									  AND f.usr_id=u.usr_id
	#									  $filters_string
	#									  $filter_tag2
	#									  $filter_data2
	#									  ORDER BY file_created DESC".$ses->makePagingSQLSuffix($f->{page}) );

	$f->{per_page} ||= $c->{items_per_page};
	$f->{fast_paging} = 1;

	my $ids = $db->SelectARefCached("SELECT f.file_id
										FROM (Files f $filter_tag1 $filter_data1)
										WHERE f.file_created < NOW()-INTERVAL 5 MINUTE
										$filters_string
										$filter_tag2
										$filter_data2
										ORDER BY file_id DESC".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}) );
	if($#$ids>=$f->{per_page})
	{
		$f->{fast_paging_next}=1;
		pop(@$ids);
	}
	my $ids2 = join(',', map{$_->{file_id}} @$ids) || 0;
	my $list = $db->SelectARefCached("SELECT f.*, TO_DAYS(CURDATE())-TO_DAYS(file_created) as created,
												s.*,
												u.usr_login as file_usr_login
												FROM (Files f, Servers s, Users u)
												WHERE file_id IN ($ids2)
												AND f.srv_id=s.srv_id
												AND f.usr_id=u.usr_id
												ORDER BY file_created DESC");


	my $total = $db->SelectOneCached("SELECT COUNT(*)
										 FROM Files f $filter_tag1 $filter_data1
										 WHERE f.file_created < NOW()-INTERVAL 5 MINUTE
										 $filters_string
										 $filter_tag2
										 $filter_data2
										");
	my $clist = genCategoriesSelect($f->{cat_id});
	undef($f->{cat_id}) if $f->{cat_name};
	$f->{cat_name} = $ses->{cgi_query}->escape($f->{cat_name});
	$f->{k} = $ses->{cgi_query}->escape($f->{k});
	my $paging = $ses->makePagingLinks($f,$total,'reverse');
	$f->{k} = $ses->{cgi_query}->unescape($f->{k});

	$paging =~ s/\?data_name=(.+?)\&amp;data_value=(.+?)\&amp;op=search\&amp;page=(\d+)/s\/$1\/$2\/page$3/ig;
	$paging =~ s/\?cat_name=(.+?)\&amp;op=search\&amp;page=(\d+)/category\/$1\/page$2/ig;
	$paging =~ s/\?op=search\&amp;tag=(.+?)\&amp;page=(\d+)/tag\/$1\/page$2/ig;


	$ses->processVideoList($list,0,$clist);

	#my $show_extra=1 if $f->{user} || $f->{cat_id};
	$f->{hide_search}=1 if $f->{fld_code};

	$ses->PrintTemplate("search.html",
						'files'  => $list,
						'paging' => $paging,
						'k'		=> $f->{k},
						'tag'	 => $f->{tag},
						'categories' => $clist,
						'title'  => $title,
						'user'	=> $f->{user},
						#'show_extra' => $show_extra,
						'fld_code'	=> $f->{fld_code},
						'hide_search' => $f->{hide_search},
						'm_z'		=> $c->{m_z},
						'm_z_cols'	=> $c->{m_z_cols},
						'm_z_rows'	=> $c->{m_z_rows},
						);
}

sub UserPlaylist {
	my $title = $ses->{lang}->{lng_index_videos};

	my @filters;

	my ($filter_data1,$filter_data2);
	$f->{data_name}=~s/[^\w\s\_\-]//g;
	$f->{tag_value2}=$f->{tag};
	$f->{tag_value2}=~s/ /\+/g;
	if($f->{data_name} && $f->{data_value})
	{
		my $value=$f->{data_value};
		utf8::decode($value);
		$value=lc $value;
		$value=~s/[^\w\s\.\&\-\_]+//g;
		utf8::encode($value);
		if(length($value)>2)
		{
			$filter_data1=",FilesData fd";
			$filter_data2="AND f.file_id=fd.file_id AND fd.name='$f->{data_name}' AND fd.value='$value'";
		}
	}

	if($f->{pls_url})
	{
		my $playlist = $db->SelectRow("SELECT * FROM Playlists WHERE pls_url=?",$f->{pls_url});
		my $pfiles = $db->SelectARef("SELECT * FROM Files2Playlists WHERE pls_id=?",$playlist->{pls_id});
		my $ids = join ',', map{$_->{file_id}} @$pfiles;
		push @filters, "AND file_id IN ($ids)" if $ids;
		$title = $playlist->{pls_name};
		#$f->{hide_search}=1;
	}

	# Avoid empty filters full search
	push @filters, "AND f.file_id=0" unless @filters || $filter_data2;
	push @filters, "AND f.file_public=1";
	push @filters, "AND f.file_status='OK'";

	my @audio_extensions = split(/\|/, $c->{audio_extensions});
	my @video_extensions = split(/\|/, $c->{video_extensions});
	my @image_extensions = split(/\|/, $c->{image_extensions});

	my %extension_map = (
		'videos' => \@video_extensions,
		'audios' => \@audio_extensions,
		'images' => \@image_extensions,
	);

	my $filters_string = join "\n", @filters;

	my $file_type = $f->{file_type};

	# Count files for each category
	my $total_audio_files = count_files('audios', \%extension_map, $filters_string, $db);
	my $total_video_files = count_files('videos', \%extension_map, $filters_string, $db);
	my $total_image_files = count_files('images', \%extension_map, $filters_string, $db);

	# Default file type audio
	if (!$f->{file_type}) {
		if ($total_audio_files > 0) {
			$file_type = 'audios';
		} elsif ($total_video_files > 0) {
			$file_type = 'videos';
		} else {
			$file_type = 'images';
		}
	}

	my @file_extensions;
	if ($file_type eq 'videos') {
		@file_extensions = split(/\|/, $c->{video_extensions});
	} elsif ($file_type eq 'audios') {
		@file_extensions = split(/\|/, $c->{audio_extensions});
	} elsif ($file_type eq 'images') {
		@file_extensions = split(/\|/, $c->{image_extensions});
	}

	my $extensions_sql;
	if (@file_extensions) {
		$extensions_sql = "AND LOWER(SUBSTRING_INDEX(f.file_name, '.', -1)) IN ('" . join("', '", @file_extensions) . "')";
	} else {
		$extensions_sql = "";
	}

	my $is_video = $file_type eq 'videos' ? 1 : 0;
	my $is_audio = $file_type eq 'audios' ? 1 : 0;
	my $is_image = $file_type eq 'images' ? 1 : 0;

	$f->{per_page} ||= $c->{items_per_page};
	my $ids = $db->SelectARefCached("SELECT f.file_id
										FROM (Files f $filter_data1)
										WHERE f.file_created < NOW()-INTERVAL 1 MINUTE
										$extensions_sql
										$filters_string
										$filter_data2
										AND f.file_id NOT IN (
											SELECT file_real_id FROM QueueEncoding
											UNION
											SELECT file_real_id FROM QueueTransfer
										)
										ORDER BY file_id DESC".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}) );

	my $ids2 = join(',', map{$_->{file_id}} @$ids) || 0;
	my $list = $db->SelectARefCached("SELECT f.*, TO_DAYS(CURDATE())-TO_DAYS(file_created) as created,
												s.*,
												u.usr_login as file_usr_login
												FROM (Files f, Servers s, Users u)
												WHERE file_id IN ($ids2)
												AND f.srv_id=s.srv_id
												AND f.usr_id=u.usr_id
												AND f.file_id NOT IN (
													SELECT file_real_id FROM QueueEncoding
													UNION
													SELECT file_real_id FROM QueueTransfer
												)
												ORDER BY file_created DESC");

    # Initialize arrays and flags
    my (@images, @audios, @videos);
	foreach my $file (@$list) {
		if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
			push @audios, $file;
		} elsif ($c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i) {
			push @videos, $file;
		} elsif ($c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i) {
			push @images, $file;
		}
	}

	my $total = $db->SelectOneCached("SELECT COUNT(*)
										 FROM Files f $filter_data1
										 WHERE f.file_created < NOW()-INTERVAL 1 MINUTE
										 $extensions_sql
										 $filters_string
										 $filter_data2
										AND f.file_id NOT IN (
											SELECT file_real_id FROM QueueEncoding
											UNION
											SELECT file_real_id FROM QueueTransfer
										)
										");

	$ses->processVideoList($list,0);

	# Get direct link for audio files loop
	my $file;
	foreach my $file (@$list) {
		# Initialize direct links array for each file
		my @dlinks;
		my @qletters = (@{['l']}); # Adjust quality letters as needed

		for my $q (@qletters) {
			my $vi = $ses->vInfo($file, $q);
			my $label = $c->{quality_labels}->{$q};

			push @dlinks, {
				mode => $q,
				direct_link => $ses->genDirectLink($file, $q, "$q"),
				label => $label,
				height => $vi->{vid_height},
			};
		}

		# Assign direct links to the file
		$file->{direct_links2} = \@dlinks;

		# Process direct links to create a string representation (if needed)
		my @sources;
		if ($file->{direct_links2}) {
			for (@{$file->{direct_links2}}) {
				push @sources, qq[$_->{direct_link}];
			}
			$file->{audio_direct_link} = join(', ', @sources);
		}

		$file->{ophash} = $ses->HashSave($file->{file_id},0);
		$file->{embed}=1;

		my $votes = $db->SelectARefCached(30,"SELECT vote, COUNT(*) as num FROM Votes WHERE file_id=? GROUP BY vote",$file->{file_id});
		for(@$votes)
		{
			$file->{likes}=$_->{num} if $_->{vote}==1;
			$file->{dislikes}=$_->{num} if $_->{vote}==-1;
		}
		$file->{likes}||=0;
		$file->{dislikes}||=0;

        # Additional processing (e.g., video info)
        $ses->getVideoInfo($file);

        $file->{vid_length_txt}=~s/^00:(\d\d:\d\d)$/$1/;

		my $user_vote = $db->SelectRow("SELECT vote FROM Votes WHERE file_id=? AND usr_id=?", $file->{file_id}, $ses->getUserId);

		my $vote_action = 'up';
		my $vote_title = "Like this!";
		if ($user_vote) {
			if ($user_vote->{vote} == 1) {
				$vote_action = 'down';
				$vote_title = "Don't like this!";
			}
		}

		$file->{vote_action} = $vote_action;
		$file->{vote_title} = $vote_title;
		$file->{views} = $file->{file_views}+$file->{file_views_full};

		# Comments
		my $comments = $db->SelectARef("
			SELECT COUNT(c.cmt_id) as comment_count
			FROM Files f
			LEFT JOIN Comments c ON c.cmt_ext_id = f.file_id AND c.cmt_type = 1
			WHERE f.file_id = ?
			GROUP BY f.file_id
		", $file->{file_id});

		$file->{comments_count} = $comments->[0]->{comment_count} // 0;

		if ($file->{audio_artist} && $file->{audio_title}) {
			$file->{is_artist_title}=1;
		}

	}

	# Select a random file from the first 10 files in the album for the thumbnail
	# Assuming $file_type is set based on the URL (images, videos, audios)
	my $playlist_thumb;
		if ($f->{pls_url}) {
			my $playlist = $db->SelectRow("SELECT * FROM Playlists WHERE pls_url=?", $f->{pls_url});
			if ($playlist) {
				# Select only from the type of files the user is currently browsing
				my $extension_sql = "";
				if ($file_type eq 'videos') {
					$extension_sql = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @video_extensions) . "')";
				} elsif ($file_type eq 'audios') {
				$extension_sql = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @audio_extensions) . "')";
			} elsif ($file_type eq 'images') {
				$extension_sql = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @image_extensions) . "')";
			}

			# Select the IDs of the first 10 files of the specified type
			my $top_file_ids = $db->SelectARef("
				SELECT pf.file_id
				FROM Files2Playlists pf
				JOIN Files f ON pf.file_id = f.file_id
				WHERE pf.pls_id = ? $extension_sql
				ORDER BY f.file_created DESC
				LIMIT 20", $playlist->{pls_id});

			# Randomly pick one file from these 10
			if (@$top_file_ids > 0) {
				my $random_index = int(rand(@$top_file_ids));
				my $random_file_id = $top_file_ids->[$random_index]->{file_id};

				# Retrieve the details for the randomly selected file
				$playlist_thumb = $db->SelectRow("SELECT f.file_real, f.file_real_id, s.disk_id, f.video_thumb, f.audio_thumb, f.file_name, s.srv_htdocs_url
												FROM Files f
												JOIN Servers s ON f.srv_id = s.srv_id
												WHERE f.file_id = ?", $random_file_id);
			}
		}
	}

	my $playlist_thumb_url;
		if ($playlist_thumb) {
		my $dx = sprintf("%05d", $playlist_thumb->{file_real_id}/$c->{files_per_folder});
			if ($file_type eq 'videos') {
				$playlist_thumb_url = "$playlist_thumb->{srv_htdocs_url}/i/$playlist_thumb->{disk_id}/$dx/$playlist_thumb->{video_thumb}";
			} elsif ($file_type eq 'audios') {
				$playlist_thumb_url = "$playlist_thumb->{srv_htdocs_url}/i/$playlist_thumb->{disk_id}/$dx/$playlist_thumb->{audio_thumb}";
			} else { # Default to images
				if ($playlist_thumb->{file_name} =~ /.([^.]+)$/) { $playlist_thumb->{file_extension} = $1; } else { $playlist_thumb->{file_extension} = ''; }
				$playlist_thumb_url = "$playlist_thumb->{srv_htdocs_url}/i/$playlist_thumb->{disk_id}/$dx/" . $playlist_thumb->{file_real} . "_t." . $playlist_thumb->{file_extension};
		}
	}

	$ses->PrintTemplate(
		"user_playlist.html",
		'videos' => \@videos,
		'audios' => \@audios,
		'images' => \@images,
		'is_video' => $is_video,
		'is_audio' => $is_audio,
		'is_image' => $is_image,
      	'total_video_files' => $total_video_files,
      	'total_audio_files' => $total_audio_files,
	  	'total_image_files' => $total_image_files,
		'user_playlist'  => $list,
		'pls_url'	=> $f->{pls_url},
		'playlist_thumb' => $playlist_thumb_url,
		'title'  => $title,
		'paging' => $ses->makePagingLinks($f,$total),
	);
}

sub UserFolder {
	my $title = $ses->{lang}->{lng_index_videos};

	my @filters;

	my ($filter_data1,$filter_data2);
	$f->{data_name}=~s/[^\w\s\_\-]//g;
	$f->{tag_value2}=$f->{tag};
	$f->{tag_value2}=~s/ /\+/g;
	if($f->{data_name} && $f->{data_value})
	{
		my $value=$f->{data_value};
		utf8::decode($value);
		$value=lc $value;
		$value=~s/[^\w\s\.\&\-\_]+//g;
		utf8::encode($value);
		if(length($value)>2)
		{
			$filter_data1=",FilesData fd";
			$filter_data2="AND f.file_id=fd.file_id AND fd.name='$f->{data_name}' AND fd.value='$value'";
		}
	}

	if($f->{fld_url})
	{
		my $folder = $db->SelectRow("SELECT * FROM Folders WHERE fld_url=?",$f->{fld_url});
		$title = "$folder->{fld_name}";
		push @filters, "AND f.usr_id=$folder->{usr_id} AND f.file_fld_id=$folder->{fld_id}";
	}

	# Avoid empty filters full search
	push @filters, "AND f.file_id=0" unless @filters || $filter_data2;
	push @filters, "AND f.file_public=1";
	push @filters, "AND f.file_status='OK'";

	my @audio_extensions = split(/\|/, $c->{audio_extensions});
	my @video_extensions = split(/\|/, $c->{video_extensions});
	my @image_extensions = split(/\|/, $c->{image_extensions});

	my %extension_map = (
		'videos' => \@video_extensions,
		'audios' => \@audio_extensions,
		'images' => \@image_extensions,
	);

	my $filters_string = join "\n", @filters;

	my $file_type = $f->{file_type};

	# Count files for each category
	my $total_audio_files = count_files('audios', \%extension_map, $filters_string, $db);
	my $total_video_files = count_files('videos', \%extension_map, $filters_string, $db);
	my $total_image_files = count_files('images', \%extension_map, $filters_string, $db);

	# Default file type audio
	if (!$f->{file_type}) {
		if ($total_audio_files > 0) {
			$file_type = 'audios';
		} elsif ($total_video_files > 0) {
			$file_type = 'videos';
		} else {
			$file_type = 'images';
		}
	}

	my @file_extensions;
	if ($file_type eq 'videos') {
		@file_extensions = split(/\|/, $c->{video_extensions});
	} elsif ($file_type eq 'audios') {
		@file_extensions = split(/\|/, $c->{audio_extensions});
	} elsif ($file_type eq 'images') {
		@file_extensions = split(/\|/, $c->{image_extensions});
	}

	my $extensions_sql;
	if (@file_extensions) {
		$extensions_sql = "AND LOWER(SUBSTRING_INDEX(f.file_name, '.', -1)) IN ('" . join("', '", @file_extensions) . "')";
	} else {
		$extensions_sql = "";
	}

	my $is_video = $file_type eq 'videos' ? 1 : 0;
	my $is_audio = $file_type eq 'audios' ? 1 : 0;
	my $is_image = $file_type eq 'images' ? 1 : 0;


	# Audio items per page
	my $usr_id = $db->SelectOne("SELECT usr_id FROM Folders WHERE fld_url=?",$f->{fld_url});
	my $usr_audio_items = $usr_id ? $db->SelectOne("SELECT usr_audio_items FROM Users WHERE usr_id=?", $usr_id) : undef;
	my $usr_video_items = $usr_id ? $db->SelectOne("SELECT usr_video_items FROM Users WHERE usr_id=?", $usr_id) : undef;
	my $usr_image_items = $usr_id ? $db->SelectOne("SELECT usr_image_items FROM Users WHERE usr_id=?", $usr_id) : undef;

	$f->{per_page} ||= $c->{items_per_page};

	if ($is_audio) {
		if ($usr_audio_items == 20) {
			$f->{per_page} = 20;
		} elsif ($usr_audio_items == 50) {
			$f->{per_page} = 50;
		} elsif ($usr_audio_items == 100) {
			$f->{per_page} = 100;
		} elsif ($usr_audio_items == 200) {
			$f->{per_page} = 200;
		}
	}

	if ($is_video) {
		if ($usr_video_items == 21) {
			$f->{per_page} = 21;
		} elsif ($usr_video_items == 51) {
			$f->{per_page} = 51;
		} elsif ($usr_video_items == 102) {
			$f->{per_page} = 102;
		} elsif ($usr_video_items == 201) {
			$f->{per_page} = 201;
		}
	}

	if ($is_image) {
		if ($usr_image_items == 20) {
			$f->{per_page} = 20;
		} elsif ($usr_image_items == 52) {
			$f->{per_page} = 52;
		} elsif ($usr_image_items == 100) {
			$f->{per_page} = 100;
		} elsif ($usr_image_items == 200) {
			$f->{per_page} = 200;
		}
	}

	my $ids = $db->SelectARefCached("SELECT f.file_id
										FROM (Files f $filter_data1)
										WHERE f.file_created < NOW()-INTERVAL 1 MINUTE
										$extensions_sql
										$filters_string
										$filter_data2
										AND f.file_id NOT IN (
											SELECT file_real_id FROM QueueEncoding
											UNION
											SELECT file_real_id FROM QueueTransfer
										)
										ORDER BY file_id DESC".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}) );

	my $ids2 = join(',', map{$_->{file_id}} @$ids) || 0;
	my $list = $db->SelectARefCached("SELECT f.*, TO_DAYS(CURDATE())-TO_DAYS(file_created) as created,
												s.*,
												u.usr_login as file_usr_login
												FROM (Files f, Servers s, Users u)
												WHERE file_id IN ($ids2)
												AND f.srv_id=s.srv_id
												AND f.usr_id=u.usr_id
												AND f.file_id NOT IN (
													SELECT file_real_id FROM QueueEncoding
													UNION
													SELECT file_real_id FROM QueueTransfer
												)
												ORDER BY file_created DESC");

    # Initialize arrays and flags
    my (@images, @audios, @videos);
	foreach my $file (@$list) {
		if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
			push @audios, $file;
		} elsif ($c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i) {
			push @videos, $file;
		} elsif ($c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i) {
			push @images, $file;
		}
	}


	# Folder description
	my $folder_descr = $db->SelectOne("SELECT fld_descr FROM Folders WHERE fld_url=?", $f->{fld_url});
	my $folder_cover = $db->SelectOne("SELECT fld_cover FROM Folders WHERE fld_url=?", $f->{fld_url});


	my $total = $db->SelectOneCached("SELECT COUNT(*)
										 FROM Files f $filter_data1
										 WHERE f.file_created < NOW()-INTERVAL 1 MINUTE
										 $extensions_sql
										 $filters_string
										 $filter_data2
										AND f.file_id NOT IN (
											SELECT file_real_id FROM QueueEncoding
											UNION
											SELECT file_real_id FROM QueueTransfer
										)
										");

	$ses->processVideoList($list,0);

	# Get direct link for audio files loop
	my $file;
	foreach my $file (@$list) {
		# Initialize direct links array for each file
		my @dlinks;
		my @qletters = (@{['l']}); # Adjust quality letters as needed

		for my $q (@qletters) {
			my $vi = $ses->vInfo($file, $q);
			my $label = $c->{quality_labels}->{$q};

			push @dlinks, {
				mode => $q,
				direct_link => $ses->genDirectLink($file, $q, "$q"),
				label => $label,
				height => $vi->{vid_height},
			};
		}

		# Assign direct links to the file
		$file->{direct_links2} = \@dlinks;

		# Process direct links to create a string representation (if needed)
		my @sources;
		if ($file->{direct_links2}) {
			for (@{$file->{direct_links2}}) {
				push @sources, qq[$_->{direct_link}];
			}
			$file->{audio_direct_link} = join(', ', @sources);
		}

		$file->{ophash} = $ses->HashSave($file->{file_id},0);
		$file->{embed}=1;

		my $votes = $db->SelectARefCached(30,"SELECT vote, COUNT(*) as num FROM Votes WHERE file_id=? GROUP BY vote",$file->{file_id});
		for(@$votes)
		{
			$file->{likes}=$_->{num} if $_->{vote}==1;
			$file->{dislikes}=$_->{num} if $_->{vote}==-1;
		}
		$file->{likes}||=0;
		$file->{dislikes}||=0;

        # Additional processing (e.g., video info)
        $ses->getVideoInfo($file);

        $file->{vid_length_txt}=~s/^00:(\d\d:\d\d)$/$1/;

		my $user_vote = $db->SelectRow("SELECT vote FROM Votes WHERE file_id=? AND usr_id=?", $file->{file_id}, $ses->getUserId);

		my $vote_action = 'up';
		my $vote_title = "Like this!";
		if ($user_vote) {
			if ($user_vote->{vote} == 1) {
				$vote_action = 'down';
				$vote_title = "Don't like this!";
			}
		}

		$file->{vote_action} = $vote_action;
		$file->{vote_title} = $vote_title;
		$file->{views} = $file->{file_views}+$file->{file_views_full};

		# Comments
		my $comments = $db->SelectARef("
			SELECT COUNT(c.cmt_id) as comment_count
			FROM Files f
			LEFT JOIN Comments c ON c.cmt_ext_id = f.file_id AND c.cmt_type = 1
			WHERE f.file_id = ?
			GROUP BY f.file_id
		", $file->{file_id});

		$file->{comments_count} = $comments->[0]->{comment_count} // 0;

		if ($file->{audio_artist} && $file->{audio_title}) {
			$file->{is_artist_title}=1;
		}

	}

	# Select a random file from the first 10 files in the album for the thumbnail
	# Assuming $file_type is set based on the URL (images, videos, audios)
	my $folder_thumb;
		if ($f->{fld_url}) {
			my $folder = $db->SelectRow("SELECT * FROM Folders WHERE fld_url=?", $f->{fld_url});
			if ($folder) {
				# Select only from the type of files the user is currently browsing
				my $extension_sql = "";
				if ($file_type eq 'videos') {
					$extension_sql = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @video_extensions) . "')";
				} elsif ($file_type eq 'audios') {
				$extension_sql = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @audio_extensions) . "')";
			} elsif ($file_type eq 'images') {
				$extension_sql = "AND LOWER(SUBSTRING_INDEX(file_name, '.', -1)) IN ('" . join("', '", @image_extensions) . "')";
			}

			# Select the IDs of the first 10 files of the specified type
			my $top_file_ids = $db->SelectARef("SELECT file_id FROM Files WHERE file_fld_id=? $extension_sql ORDER BY file_created DESC LIMIT 20", $folder->{fld_id});

			# Randomly pick one file from these 10
			if (@$top_file_ids > 0) {
				my $random_index = int(rand(@$top_file_ids));
				my $random_file_id = $top_file_ids->[$random_index]->{file_id};

				# Retrieve the details for the randomly selected file
				$folder_thumb = $db->SelectRow("SELECT f.file_real, f.file_real_id, s.disk_id, f.video_thumb, f.audio_thumb, f.file_name, s.srv_htdocs_url
												FROM Files f
												JOIN Servers s ON f.srv_id = s.srv_id
												WHERE f.file_id = ?", $random_file_id);
			}
		}
	}

	my $folder_thumb_url;
		if ($folder_thumb) {
		my $dx = sprintf("%05d", $folder_thumb->{file_real_id}/$c->{files_per_folder});
			if ($file_type eq 'videos') {
				$folder_thumb_url = "$folder_thumb->{srv_htdocs_url}/i/$folder_thumb->{disk_id}/$dx/$folder_thumb->{video_thumb}";
			} elsif ($file_type eq 'audios') {
				$folder_thumb_url = "$folder_thumb->{srv_htdocs_url}/i/$folder_thumb->{disk_id}/$dx/$folder_thumb->{audio_thumb}";
			} else { # Default to images
				if ($folder_thumb->{file_name} =~ /.([^.]+)$/) { $folder_thumb->{file_extension} = $1; } else { $folder_thumb->{file_extension} = ''; }
				$folder_thumb_url = "$folder_thumb->{srv_htdocs_url}/i/$folder_thumb->{disk_id}/$dx/" . $folder_thumb->{file_real} . "_t." . $folder_thumb->{file_extension};
		}
	}

	$ses->PrintTemplate(
		"user_folder.html",
		'videos' => \@videos,
		'audios' => \@audios,
		'images' => \@images,
		'is_video' => $is_video,
		'is_audio' => $is_audio,
		'is_image' => $is_image,
    'total_video_files' => $total_video_files,
    'total_audio_files' => $total_audio_files,
	  'total_image_files' => $total_image_files,
		'user_folder'  => $list,
		'fld_url'	=> $f->{fld_url},
		'title'  => $title,
		'folder_thumb' => $folder_thumb_url,
		'folder_descr'	=> $folder_descr,
		'fld_cover'	=> $folder_cover,
		'paging' => $ses->makePagingLinks($f,$total),
	);
}

sub Tags {
	my $title = $ses->{lang}->{lng_index_videos};

	my @filters;

	my ($filter_tag1,$filter_tag2);
	if($f->{tag})
	{
		my $tag=$f->{tag};
		utf8::decode($tag);
		$tag=lc $tag;
		$tag=~s/[^\w\s\.\&]+//g;
		utf8::encode($tag);
		if(length($tag)>2)
		{
			my $tag_id = $db->SelectOne("SELECT tag_id FROM Tags WHERE tag_value=?",$tag);
			if($tag_id)
			{
				$filter_tag1=",Tags2Files t2f";
				$filter_tag2="AND f.file_id=t2f.file_id AND t2f.tag_id=$tag_id";
			}
		}
	}

	my ($filter_data1,$filter_data2);
	$f->{data_name}=~s/[^\w\s\_\-]//g;
	$f->{tag_value2}=$f->{tag};
	$f->{tag_value2}=~s/ /\+/g;
	if($f->{data_name} && $f->{data_value})
	{
		my $value=$f->{data_value};
		utf8::decode($value);
		$value=lc $value;
		$value=~s/[^\w\s\.\&\-\_]+//g;
		utf8::encode($value);
		if(length($value)>2)
		{
			$filter_data1=",FilesData fd";
			$filter_data2="AND f.file_id=fd.file_id AND fd.name='$f->{data_name}' AND fd.value='$value'";
		}
	}

	# Avoid empty filters full search
	push @filters, "AND f.file_id=0" unless @filters || ($filter_tag2 || $filter_data2);
	push @filters, "AND f.file_public=1" if $c->{search_public_only} && !$f->{playlist};
	push @filters, "AND f.file_status='OK'";

	my @audio_extensions = split(/\|/, $c->{audio_extensions});
	my @video_extensions = split(/\|/, $c->{video_extensions});
	my @image_extensions = split(/\|/, $c->{image_extensions});

	my %extension_map = (
		'videos' => \@video_extensions,
		'audios' => \@audio_extensions,
		'images' => \@image_extensions,
	);

	my $filters_string = join "\n", @filters;

	my $file_type = $f->{file_type};

	# Count files for each category
	my $total_audio_files = count_tags('audios', \%extension_map, $filters_string, [$filter_tag1, $filter_tag2], $db);
	my $total_video_files = count_tags('videos', \%extension_map, $filters_string, [$filter_tag1, $filter_tag2], $db);
	my $total_image_files = count_tags('images', \%extension_map, $filters_string, [$filter_tag1, $filter_tag2], $db);

	# Default file type audio
	if (!$f->{file_type}) {
		if ($total_audio_files > 0) {
			$file_type = 'audios';
		} elsif ($total_video_files > 0) {
			$file_type = 'videos';
		} else {
			$file_type = 'images';
		}
	}

	my @file_extensions = @{ $extension_map{$file_type} || [] };
	if ($file_type eq 'videos') {
		@file_extensions = split(/\|/, $c->{video_extensions});
	} elsif ($file_type eq 'audios') {
		@file_extensions = split(/\|/, $c->{audio_extensions});
	} elsif ($file_type eq 'images') {
		@file_extensions = split(/\|/, $c->{image_extensions});
	}

	my $extensions_sql;
	if (@file_extensions) {
		$extensions_sql = "AND LOWER(SUBSTRING_INDEX(f.file_name, '.', -1)) IN ('" . join("', '", @file_extensions) . "')";
	} else {
		$extensions_sql = "";
	}

	my $is_video = $file_type eq 'videos' ? 1 : 0;
	my $is_audio = $file_type eq 'audios' ? 1 : 0;
	my $is_image = $file_type eq 'images' ? 1 : 0;


	$f->{per_page} ||= $c->{items_per_page};
	my $ids = $db->SelectARefCached("SELECT f.file_id
										FROM (Files f $filter_tag1 $filter_data1)
										WHERE f.file_created < NOW()-INTERVAL 5 MINUTE
										$extensions_sql
										$filters_string
										$filter_tag2
										$filter_data2
										AND f.file_id NOT IN (
											SELECT file_real_id FROM QueueEncoding
											UNION
											SELECT file_real_id FROM QueueTransfer
										)
										ORDER BY file_id DESC".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}) );

	my $ids2 = join(',', map{$_->{file_id}} @$ids) || 0;
	my $list = $db->SelectARefCached("SELECT f.*, TO_DAYS(CURDATE())-TO_DAYS(file_created) as created,
												s.*,
												u.usr_login as file_usr_login
												FROM (Files f, Servers s, Users u)
												WHERE file_id IN ($ids2)
												AND f.srv_id=s.srv_id
												AND f.usr_id=u.usr_id
												AND f.file_id NOT IN (
													SELECT file_real_id FROM QueueEncoding
													UNION
													SELECT file_real_id FROM QueueTransfer
												)
												ORDER BY file_created DESC");

    # Initialize arrays and flags
    my (@images, @audios, @videos);
	foreach my $file (@$list) {
		if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
			push @audios, $file;
		} elsif ($c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i) {
			push @videos, $file;
		} elsif ($c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i) {
			push @images, $file;
		}
	}

	my $total = $db->SelectOneCached("SELECT COUNT(*)
										 FROM Files f $filter_tag1 $filter_data1
										 WHERE f.file_created < NOW()-INTERVAL 5 MINUTE
										 $extensions_sql
										 $filters_string
										 $filter_tag2
										 $filter_data2
										AND f.file_id NOT IN (
											SELECT file_real_id FROM QueueEncoding
											UNION
											SELECT file_real_id FROM QueueTransfer
										)
										");

	$ses->processVideoList($list,0);

	# Get direct link for audio files loop
	my $file;
	foreach my $file (@$list) {
		# Initialize direct links array for each file
		my @dlinks;
		my @qletters = (@{['l']}); # Adjust quality letters as needed

		for my $q (@qletters) {
			my $vi = $ses->vInfo($file, $q);
			my $label = $c->{quality_labels}->{$q};

			push @dlinks, {
				mode => $q,
				direct_link => $ses->genDirectLink($file, $q, "$q"),
				label => $label,
				height => $vi->{vid_height},
			};
		}

		# Assign direct links to the file
		$file->{direct_links2} = \@dlinks;

		# Process direct links to create a string representation (if needed)
		my @sources;
		if ($file->{direct_links2}) {
			for (@{$file->{direct_links2}}) {
				push @sources, qq[$_->{direct_link}];
			}
			$file->{audio_direct_link} = join(', ', @sources);
		}

		$file->{ophash} = $ses->HashSave($file->{file_id},0);
		$file->{embed}=1;

		my $votes = $db->SelectARefCached(30,"SELECT vote, COUNT(*) as num FROM Votes WHERE file_id=? GROUP BY vote",$file->{file_id});
		for(@$votes)
		{
			$file->{likes}=$_->{num} if $_->{vote}==1;
			$file->{dislikes}=$_->{num} if $_->{vote}==-1;
		}
		$file->{likes}||=0;
		$file->{dislikes}||=0;

        # Additional processing (e.g., video info)
        $ses->getVideoInfo($file);

        $file->{vid_length_txt}=~s/^00:(\d\d:\d\d)$/$1/;

		my $user_vote = $db->SelectRow("SELECT vote FROM Votes WHERE file_id=? AND usr_id=?", $file->{file_id}, $ses->getUserId);

		my $vote_action = 'up';
		my $vote_title = "Like this!";
		if ($user_vote) {
			if ($user_vote->{vote} == 1) {
				$vote_action = 'down';
				$vote_title = "Don't like this!";
			}
		}

		$file->{vote_action} = $vote_action;
		$file->{vote_title} = $vote_title;
		$file->{views} = $file->{file_views}+$file->{file_views_full};

		# Comments
		my $comments = $db->SelectARef("
			SELECT COUNT(c.cmt_id) as comment_count
			FROM Files f
			LEFT JOIN Comments c ON c.cmt_ext_id = f.file_id AND c.cmt_type = 1
			WHERE f.file_id = ?
			GROUP BY f.file_id
		", $file->{file_id});

		$file->{comments_count} = $comments->[0]->{comment_count} // 0;

		if ($file->{audio_artist} && $file->{audio_title}) {
			$file->{is_artist_title}=1;
		}

	}

	# Process the tag and fetch its ID
	my $tag_id;
	if ($f->{tag}) {
		my $tag = $f->{tag};
		utf8::decode($tag);
		$tag = lc $tag;
		$tag =~ s/[^\w\s\.\&]+//g;
		utf8::encode($tag);
		if (length($tag) > 2) {
			$tag_id = $db->SelectOne("SELECT tag_id FROM Tags WHERE tag_value=?", $tag);
		}
	}

	# Select a random file for the thumbnail if a tag_id was found
	my $tags_thumb;
	if ($tag_id) {
	# Query to select files associated with this tag
	my $top_file_ids = $db->SelectARef("
		SELECT f.file_id
		FROM Files f
		JOIN Tags2Files t2f ON f.file_id = t2f.file_id
		WHERE t2f.tag_id = ?
		AND LOWER(SUBSTRING_INDEX(f.file_name, '.', -1)) IN ('" . join("', '", @file_extensions) . "')
		ORDER BY f.file_created DESC
		LIMIT 20", $tag_id);

		# Randomly pick one file from these 10
		if (@$top_file_ids > 0) {
			my $random_index = int(rand(@$top_file_ids));
			my $random_file_id = $top_file_ids->[$random_index]->{file_id};

			# Retrieve the details for the randomly selected file
			$tags_thumb = $db->SelectRow("SELECT f.file_real, f.file_real_id, s.disk_id, f.video_thumb, f.audio_thumb, f.file_name, s.srv_htdocs_url
											FROM Files f
											JOIN Servers s ON f.srv_id = s.srv_id
											WHERE f.file_id = ?", $random_file_id);
		}
	}

	my $tags_thumb_url;
	if ($tags_thumb) {
		my $dx = sprintf("%05d", $tags_thumb->{file_real_id}/$c->{files_per_folder});
		my $file_ext = "";
		if ($tags_thumb->{file_name} =~ /\.([^.]+)$/) {
			$file_ext = lc($1);
		}

		if (grep { $_ eq $file_ext } @video_extensions) {
			# If the file extension matches any in @video_extensions
			$tags_thumb_url = "$tags_thumb->{srv_htdocs_url}/i/$tags_thumb->{disk_id}/$dx/$tags_thumb->{video_thumb}";
		} elsif (grep { $_ eq $file_ext } @audio_extensions) {
			# If the file extension matches any in @audio_extensions
			$tags_thumb_url = "$tags_thumb->{srv_htdocs_url}/i/$tags_thumb->{disk_id}/$dx/$tags_thumb->{audio_thumb}";
		} else {
			# Default to image thumbnail
			$tags_thumb_url = "$tags_thumb->{srv_htdocs_url}/i/$tags_thumb->{disk_id}/$dx/" . $tags_thumb->{file_real} . "_t." . $file_ext;
		}
	}


	$ses->PrintTemplate(
		"tags2.html",
		'videos' => \@videos,
		'audios' => \@audios,
		'images' => \@images,
		'is_video' => $is_video,
		'is_audio' => $is_audio,
		'is_image' => $is_image,
      	'total_video_files' => $total_video_files,
      	'total_audio_files' => $total_audio_files,
	  	'total_image_files' => $total_image_files,
		'tags'  => $list,
		'k'		=> $f->{k},
		'tag'	 => $f->{tag},
		'tag_value2'	 => $f->{tag_value2},
		'tags_thumb'	=> $tags_thumb_url,
		'title'  => $title,
		'paging' => $ses->makePagingLinks($f,$total),
	);
}

sub count_tags {
    my ($category, $extension_map, $filters_string, $tag_filters, $db) = @_;
    my $extensions = $extension_map->{$category};
    return 0 unless @$extensions;

    my ($filter_tag1, $filter_tag2) = @{$tag_filters};
    my $extensions_sql = "AND LOWER(SUBSTRING_INDEX(f.file_name, '.', -1)) IN ('" . join("', '", @$extensions) . "')";

    my $query = "SELECT COUNT(*) FROM Files f $filter_tag1 WHERE 1=1 $extensions_sql $filters_string $filter_tag2
    				AND f.file_id NOT IN (
					SELECT file_real_id FROM QueueEncoding
					UNION
					SELECT file_real_id FROM QueueTransfer
					)";
    return $db->SelectOne($query);
}

sub count_files {
    my ($category, $extension_map, $filters_string, $db) = @_;
    my $extensions = $extension_map->{$category};
    return 0 unless @$extensions;

    my $extensions_sql = "AND LOWER(SUBSTRING_INDEX(f.file_name, '.', -1)) IN ('" . join("', '", @$extensions) . "')";

    my $query = "SELECT COUNT(*) FROM Files f WHERE 1=1 $extensions_sql $filters_string
    							AND f.file_id NOT IN (
									SELECT file_real_id FROM QueueEncoding
									UNION
									SELECT file_real_id FROM QueueTransfer
									)";
    return $db->SelectOne($query);
}

sub UserPublic {

	my @filters;

	my $usr_id = $db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$f->{usr_login});
	push @filters, "AND f.usr_id=$usr_id" if $usr_id;
	push @filters, "AND f.file_id=0" unless @filters;
	push @filters, "AND f.file_public=1";
	push @filters, "AND f.file_status='OK'";

	my @audio_extensions = split(/\|/, $c->{audio_extensions});
	my @video_extensions = split(/\|/, $c->{video_extensions});
	my @image_extensions = split(/\|/, $c->{image_extensions});

	my %extension_map = (
		'videos' => \@video_extensions,
		'audios' => \@audio_extensions,
		'images' => \@image_extensions,
	);

	my $filters_string = join "\n", @filters;

	my $usr_media_type = $usr_id ? $db->SelectOne("SELECT usr_media FROM Users WHERE usr_id=?", $usr_id) : undef;

	my $is_folders = $f->{folders};
	my $is_playlists = $f->{playlists};
	my $file_type;

	# Count files for each category
	my $total_audio_files = count_files('audios', \%extension_map, $filters_string, $db);
	my $total_video_files = count_files('videos', \%extension_map, $filters_string, $db);
	my $total_image_files = count_files('images', \%extension_map, $filters_string, $db);

	if (!$is_folders && !$is_playlists) {
		if ($f->{files}) {
			# User selection on the profile page
			$file_type = $f->{files};
		} else {
			# Fallback to user preference or available files
			if ($usr_media_type == 1) {
				if ($total_audio_files > 0) {
					$file_type = 'audios';
				} elsif ($total_video_files > 0) {
					$file_type = 'videos';
				} else {
					$file_type = 'images';
				}
			} elsif ($usr_media_type == 2) {
				if ($total_video_files > 0) {
					$file_type = 'videos';
				} elsif ($total_image_files > 0) {
					$file_type = 'images';
				} else {
					$file_type = 'audios';
				}
			} elsif ($usr_media_type == 3) {
				if ($total_image_files > 0) {
					$file_type = 'images';
				} elsif ($total_audio_files > 0) {
					$file_type = 'audios';
				} else {
					$file_type = 'videos';
				}
			}
		}
	}

	my @file_extensions;
	if ($file_type eq 'videos') {
		@file_extensions = split(/\|/, $c->{video_extensions});
	} elsif ($file_type eq 'audios') {
		@file_extensions = split(/\|/, $c->{audio_extensions});
	} elsif ($file_type eq 'images') {
		@file_extensions = split(/\|/, $c->{image_extensions});
	}

	my $extensions_sql;
	if (@file_extensions) {
		$extensions_sql = "AND LOWER(SUBSTRING_INDEX(f.file_name, '.', -1)) IN ('" . join("', '", @file_extensions) . "')";
	} else {
		$extensions_sql = "";
	}

	my $is_video = $file_type eq 'videos' ? 1 : 0;
	my $is_audio = $file_type eq 'audios' ? 1 : 0;
	my $is_image = $file_type eq 'images' ? 1 : 0;


	# Audio items per page
	my $usr_audio_items = $usr_id ? $db->SelectOne("SELECT usr_audio_items FROM Users WHERE usr_id=?", $usr_id) : undef;
	my $usr_video_items = $usr_id ? $db->SelectOne("SELECT usr_video_items FROM Users WHERE usr_id=?", $usr_id) : undef;
	my $usr_image_items = $usr_id ? $db->SelectOne("SELECT usr_image_items FROM Users WHERE usr_id=?", $usr_id) : undef;

	$f->{per_page} ||= $c->{items_per_page};

	if ($is_audio) {
		if ($usr_audio_items == 20) {
			$f->{per_page} = 20;
		} elsif ($usr_audio_items == 50) {
			$f->{per_page} = 50;
		} elsif ($usr_audio_items == 100) {
			$f->{per_page} = 100;
		} elsif ($usr_audio_items == 200) {
			$f->{per_page} = 200;
		}
	}

	if ($is_video) {
		if ($usr_video_items == 21) {
			$f->{per_page} = 21;
		} elsif ($usr_video_items == 51) {
			$f->{per_page} = 51;
		} elsif ($usr_video_items == 102) {
			$f->{per_page} = 102;
		} elsif ($usr_video_items == 201) {
			$f->{per_page} = 201;
		}
	}

	if ($is_image) {
		if ($usr_image_items == 20) {
			$f->{per_page} = 20;
		} elsif ($usr_image_items == 52) {
			$f->{per_page} = 52;
		} elsif ($usr_image_items == 100) {
			$f->{per_page} = 100;
		} elsif ($usr_image_items == 200) {
			$f->{per_page} = 200;
		}
	}



	my $ids = $db->SelectARef("
		SELECT f.file_id
		FROM Files f
		WHERE f.file_created < NOW() - INTERVAL 1 MINUTE
		$extensions_sql
		$filters_string
		AND f.file_id NOT IN (
			SELECT file_real_id FROM QueueEncoding
			UNION
			SELECT file_real_id FROM QueueTransfer
		)
		ORDER BY f.file_id DESC" . $ses->makePagingSQLSuffix($f->{page}, $f->{per_page})
	);


	my $ids2 = join(',', map{$_->{file_id}} @$ids) || 0;
	my $list = $db->SelectARef("
		SELECT f.*, TO_DAYS(CURDATE()) - TO_DAYS(file_created) AS created, s.*, u.usr_login
		FROM Files f
		JOIN Servers s ON f.srv_id = s.srv_id
		JOIN Users u ON f.usr_id = u.usr_id
		WHERE f.file_id IN ($ids2)
		AND f.file_id NOT IN (
			SELECT file_real_id FROM QueueEncoding
			UNION
			SELECT file_real_id FROM QueueTransfer
		)
		ORDER BY f.file_created DESC
	");

    # Initialize arrays and flags
    my (@images, @audios, @videos);
	if (!$is_folders && !$is_playlists) { # skip if folders or playlists
		foreach my $file (@$list) {
			if ($c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i) {
				push @audios, $file;
			} elsif ($c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i) {
				push @videos, $file;
			} elsif ($c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i) {
				push @images, $file;
			}
		}
	}


	my $total = $db->SelectOne("
		SELECT COUNT(*)
		FROM Files f
		WHERE f.file_created < NOW() - INTERVAL 1 MINUTE
		$extensions_sql
		$filters_string
		AND f.file_id NOT IN (
			SELECT file_real_id FROM QueueEncoding
			UNION
			SELECT file_real_id FROM QueueTransfer
		)
	");

	# Assuming @extensions is your array of file extensions
	my @extensions = (@audio_extensions, @video_extensions, @image_extensions);
	# Create placeholders for each extension in the list
	my $placeholders = join(', ', ('?') x @extensions);

	my $folders;
	if ($is_folders) {
			my $pagination_suffix = $ses->makePagingSQLSuffix($f->{page}, $f->{per_page});
			$folders = $db->SelectARef(
						"SELECT Folders.*, COUNT(Files.file_id) AS fld_file_count
						FROM Folders
						LEFT JOIN Files ON Folders.fld_id = Files.file_fld_id AND Files.file_public=1 AND Files.file_status='OK'
						WHERE Folders.usr_id=? AND Folders.fld_hide=0
						AND LOWER(SUBSTRING_INDEX(Files.file_name, '.', -1)) IN ($placeholders)
						GROUP BY Folders.fld_id
						HAVING fld_file_count > 0
						ORDER BY Folders.fld_created DESC $pagination_suffix",
						$usr_id, @extensions
			);

			foreach my $folder (@$folders) {
					# Select the IDs of the first 10 files of the specified type for this folder
					my $top_file_ids = $db->SelectARef("SELECT file_id FROM Files WHERE file_public=1 AND file_status='OK' AND file_fld_id=? ORDER BY file_created DESC LIMIT 20", $folder->{fld_id});

					if (@$top_file_ids > 0) {
							my $random_index = int(rand(scalar(@$top_file_ids)));
							my $random_file_id = $top_file_ids->[$random_index]->{file_id};

							# Retrieve the details for the randomly selected file
							my $folder_thumb = $db->SelectRow("SELECT f.file_real, f.file_real_id, s.disk_id, f.video_thumb, f.audio_thumb, f.file_name, s.srv_htdocs_url
																								FROM Files f
																								JOIN Servers s ON f.srv_id = s.srv_id
																								WHERE f.file_id = ?", $random_file_id);

							if ($folder_thumb) {
									my $dx = sprintf("%05d", $folder_thumb->{file_real_id} / $c->{files_per_folder});

									my $thumbnail;
									# Extract file extension
									if ($folder_thumb->{file_name} =~ /.([^.]+)$/) {
											$folder_thumb->{file_extension} = $1;
									} else {
											$folder_thumb->{file_extension} = '';
									}

									# Determine which thumbnail to use based on file type
									if ($folder_thumb->{video_thumb}) {
											$thumbnail = "$folder_thumb->{srv_htdocs_url}/i/$folder_thumb->{disk_id}/$dx/$folder_thumb->{video_thumb}";
									} elsif ($folder_thumb->{audio_thumb}) {
											$thumbnail = "$folder_thumb->{srv_htdocs_url}/i/$folder_thumb->{disk_id}/$dx/$folder_thumb->{audio_thumb}";
									} elsif ($folder_thumb->{file_extension} =~ /^($c->{image_extensions})$/i) { # Check for image file extensions
											# For image files, construct the thumbnail URL dynamically
											$thumbnail = "$folder_thumb->{srv_htdocs_url}/i/$folder_thumb->{disk_id}/$dx/" . $folder_thumb->{file_real} . "_t." . $folder_thumb->{file_extension};
									}

									# Store the thumbnail URL in the folder hash for use in your template
									$folder->{folder_thumb_url} = $thumbnail;
							}
					}
			}
	}

	my $playlists;
	if ($is_playlists) {
			my $pagination_suffix = $ses->makePagingSQLSuffix($f->{page}, $f->{per_page});
			$playlists = $db->SelectARef(
					"SELECT Playlists.*, COUNT(Files.file_id) AS pls_file_count
					FROM Playlists
					LEFT JOIN Files2Playlists ON Playlists.pls_id = Files2Playlists.pls_id
					LEFT JOIN Files ON Files2Playlists.file_id = Files.file_id AND Files.file_public=1 AND Files.file_status='OK'
					WHERE Playlists.usr_id=?
					AND LOWER(SUBSTRING_INDEX(Files.file_name, '.', -1)) IN ($placeholders)
					GROUP BY Playlists.pls_id
					ORDER BY Playlists.pls_created DESC $pagination_suffix",
					$usr_id, @extensions
			);

			foreach my $playlist (@$playlists) {

				# Select the IDs of the first 10 files of the specified type for this playlist
				my $top_file_ids = $db->SelectARef("SELECT fp.file_id FROM Files2Playlists fp JOIN Files f ON fp.file_id = f.file_id WHERE fp.pls_id=? AND f.file_public=1 AND f.file_status='OK' ORDER BY f.file_created DESC LIMIT 20", $playlist->{pls_id});

				if (@$top_file_ids > 0) {
						my $random_index = int(rand(scalar(@$top_file_ids)));
						my $random_file_id = $top_file_ids->[$random_index]->{file_id};

						# Retrieve the details for the randomly selected file
						my $playlist_thumb = $db->SelectRow("SELECT f.file_real, f.file_real_id, s.disk_id, f.video_thumb, f.audio_thumb, f.file_name, s.srv_htdocs_url
																							FROM Files f
																							JOIN Servers s ON f.srv_id = s.srv_id
																							WHERE f.file_id = ?", $random_file_id);

						if ($playlist_thumb) {
								my $dx = sprintf("%05d", $playlist_thumb->{file_real_id} / $c->{files_per_folder});

								my $thumbnail;
								# Extract file extension
								if ($playlist_thumb->{file_name} =~ /.([^.]+)$/) {
										$playlist_thumb->{file_extension} = $1;
								} else {
										$playlist_thumb->{file_extension} = '';
								}

								# Determine which thumbnail to use based on file type
								if ($playlist_thumb->{video_thumb}) {
										$thumbnail = "$playlist_thumb->{srv_htdocs_url}/i/$playlist_thumb->{disk_id}/$dx/$playlist_thumb->{video_thumb}";
								} elsif ($playlist_thumb->{audio_thumb}) {
										$thumbnail = "$playlist_thumb->{srv_htdocs_url}/i/$playlist_thumb->{disk_id}/$dx/$playlist_thumb->{audio_thumb}";
								} elsif ($playlist_thumb->{file_extension} =~ /^($c->{image_extensions})$/i) { # Check for image file extensions
										# For image files, construct the thumbnail URL dynamically
										$thumbnail = "$playlist_thumb->{srv_htdocs_url}/i/$playlist_thumb->{disk_id}/$dx/" . $playlist_thumb->{file_real} . "_t." . $playlist_thumb->{file_extension};
								}

								# Store the thumbnail URL in the folder hash for use in your template
								$playlist->{playlist_thumb_url} = $thumbnail;
						}
				}

				# Count audio files
				my $audio_num = $db->SelectARef("SELECT COUNT(*) as audio_num FROM Files f
																					JOIN Files2Playlists fp ON f.file_id = fp.file_id
																					WHERE fp.pls_id=? AND f.file_name REGEXP '\.($c->{audio_extensions})\$'", $playlist->{pls_id})->[0]->{audio_num};

				# Count video files
				my $video_num = $db->SelectARef("SELECT COUNT(*) as video_num FROM Files f
																					JOIN Files2Playlists fp ON f.file_id = fp.file_id
																					WHERE fp.pls_id=? AND f.file_name REGEXP '\.($c->{video_extensions})\$'", $playlist->{pls_id})->[0]->{video_num};

				# Count image files
				my $image_num = $db->SelectARef("SELECT COUNT(*) as image_num FROM Files f
																					JOIN Files2Playlists fp ON f.file_id = fp.file_id
																					WHERE fp.pls_id=? AND f.file_name REGEXP '\.($c->{image_extensions})\$'", $playlist->{pls_id})->[0]->{image_num};

				$playlist->{audio_num} = $audio_num;
				$playlist->{video_num} = $video_num;
				$playlist->{image_num} = $image_num;
			}
	}
		# Query to count the total number of folders
		my $total_folders = $db->SelectOne("
			SELECT COUNT(DISTINCT Folders.fld_id) FROM Folders
			JOIN Files ON Folders.fld_id = Files.file_fld_id
			WHERE Folders.usr_id=? AND Files.file_public=1 AND Files.file_status='OK'
			AND LOWER(SUBSTRING_INDEX(Files.file_name, '.', -1)) IN ($placeholders)",
			$usr_id, @extensions
		);

		# Query to count the total number of playlists
		my $total_playlists = $db->SelectOne("
			SELECT COUNT(DISTINCT Playlists.pls_id) FROM Playlists
			LEFT JOIN Files2Playlists ON Playlists.pls_id = Files2Playlists.pls_id
			LEFT JOIN Files ON Files2Playlists.file_id = Files.file_id
			WHERE Playlists.usr_id=? AND Files.file_public=1 AND Files.file_status='OK'
			AND LOWER(SUBSTRING_INDEX(Files.file_name, '.', -1)) IN ($placeholders)",
			$usr_id, @extensions
		);


	my $paging_links;
		if ($is_folders) {
		# Use total_folders for pagination if in folders view
		$paging_links = $ses->makePagingLinks($f, $total_folders);
		} elsif ($is_playlists) {
		# Use total_folders for pagination if in playlists view
		$paging_links = $ses->makePagingLinks($f, $total_playlists);
		} else {
		# Use total for pagination in other views
		$paging_links = $ses->makePagingLinks($f, $total);
	}

    # Counting files for each category
    my $total_video_files = count_files('videos', \%extension_map, $filters_string, $db);
    my $total_audio_files = count_files('audios', \%extension_map, $filters_string, $db);
    my $total_image_files = count_files('images', \%extension_map, $filters_string, $db);

	# Calculate the total count of all files
    my $total_files = $total_video_files + $total_audio_files + $total_image_files;


    # Get user data
    my $user = $db->SelectRow( "SELECT *, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec2
								FROM Users WHERE usr_login=?", $f->{usr_login} );
    # If user not found
    return $ses->message("No such user") unless $user;

    # User Chennel name. If not exists then user login name
    $user->{usr_channel_name}||=$user->{usr_login};

	# User short name
	if (defined $user->{usr_login} && length $user->{usr_login} >= 1) {
		$user->{usr_login_short_p} = substr($user->{usr_login}, 0, 1);
	} else {
		$user->{usr_login_short_p} = $user->{usr_login} // '';
	}

	# Accon Privacy
 	my $curren_user = $ses->getUser;
	if($user->{usr_account_privacy}) {
		if($user->{usr_login} eq $curren_user->{usr_login}) {
			$user->{private_account}=0;
		} else {
			$user->{private_account}=1;
		}
	}

   # User Avatar
   $user->{usr_avatar} = $db->SelectOne("SELECT usr_avatar FROM Users WHERE usr_login=?",$user->{usr_login});

   # User Cover
   $user->{usr_cover} = $db->SelectOne("SELECT usr_cover FROM Users WHERE usr_login=?",$user->{usr_login});

   # Show/Hide User Player Bar
   $user->{usr_player_bar} = $db->SelectOne("SELECT usr_player_bar FROM Users WHERE usr_login=?",$user->{usr_login});

   # If user is premium
   $user->{is_premium} = $user->{exp_sec2}>0;

   #$user->{usr_bio} =~ s/\r?\n/<br>/g;
   $ses->{page_title} = $user->{usr_channel_name};
   #$ses->{meta_descr} = $user->{usr_bio};

   my $usr_country = $db->SelectRow("SELECT d.*, d.value
   									FROM (UserData d, Users u) WHERE d.name=? AND d.usr_id=u.usr_id AND u.usr_login=?", 'usr_extra_country', $f->{usr_login});
   my $country = $usr_country->{value};

   # Output files
   $ses->processVideoList($list,0);

	# Get direct link for audio files loop
	my $file;
	foreach my $file (@$list) {
		# Initialize direct links array for each file
		my @dlinks;
		my @qletters = (@{['l']}); # Adjust quality letters as needed

		for my $q (@qletters) {
			my $vi = $ses->vInfo($file, $q);
			my $label = $c->{quality_labels}->{$q};

			push @dlinks, {
				mode => $q,
				direct_link => $ses->genDirectLink($file, $q, "$q"),
				label => $label,
				height => $vi->{vid_height},
			};
		}

		# Assign direct links to the file
		$file->{direct_links2} = \@dlinks;

		# Process direct links to create a string representation (if needed)
		my @sources;
		if ($file->{direct_links2}) {
			for (@{$file->{direct_links2}}) {
				push @sources, qq[$_->{direct_link}];
			}
			$file->{audio_direct_link} = join(', ', @sources);
		}

		$file->{ophash} = $ses->HashSave($file->{file_id},0);
		$file->{embed}=1;

		my $votes = $db->SelectARefCached(30,"SELECT vote, COUNT(*) as num FROM Votes WHERE file_id=? GROUP BY vote",$file->{file_id});
		for(@$votes)
		{
			$file->{likes}=$_->{num} if $_->{vote}==1;
			$file->{dislikes}=$_->{num} if $_->{vote}==-1;
		}
		$file->{likes}||=0;
		$file->{dislikes}||=0;

        # Additional processing (e.g., video info)
        $ses->getVideoInfo($file);

        $file->{vid_length_txt}=~s/^00:(\d\d:\d\d)$/$1/;

		my $user_vote = $db->SelectRow("SELECT vote FROM Votes WHERE file_id=? AND usr_id=?", $file->{file_id}, $ses->getUserId);

		my $vote_action = 'up';
		my $vote_title = "Like this!";
		if ($user_vote) {
			if ($user_vote->{vote} == 1) {
				$vote_action = 'down';
				$vote_title = "Don't like this!";
			}
		}

		$file->{vote_action} = $vote_action;
		$file->{vote_title} = $vote_title;
		$file->{views} = $file->{file_views}+$file->{file_views_full};

		# Comments
		my $comments = $db->SelectARef("
			SELECT COUNT(c.cmt_id) as comment_count
			FROM Files f
			LEFT JOIN Comments c ON c.cmt_ext_id = f.file_id AND c.cmt_type = 1
			WHERE f.file_id = ?
			GROUP BY f.file_id
		", $file->{file_id});

		$file->{comments_count} = $comments->[0]->{comment_count} // 0;

		if ($file->{audio_artist} && $file->{audio_title}) {
			$file->{is_artist_title}=1;
		}

		# $file->{referer} = $ses->getDomain($referer);

		# if($file->{embed_domain_allowed})
		# {
		# 	my $dhash;
		# 	$dhash->{$_}=1 for split /\s*,\s*/, $file->{embed_domain_allowed};
		# 	my ($domain) = $referer=~/\/\/(.+?)(\/|$)/i;
		# 	$domain=~s/www\.//;
		# 	return sendBack("Video embed restricted for this domain") if $domain && !$dhash->{lc($domain)};
		# }
	}

   $ses->PrintTemplate(
      "user_public.html",
      'videos' => \@videos,
      'audios' => \@audios,
      'images' => \@images,
      'is_video' => $is_video,
      'is_audio' => $is_audio,
      'is_image' => $is_image,
	  	'usr_country' => $country, # Add this line
      'total_video_files' => $total_video_files,
      'total_audio_files' => $total_audio_files,
	  	'total_image_files' => $total_image_files,
	  	'total_files' => $total_files,
      'login'  => $user->{usr_login},
	  	'files'  => $list,
	  	'folders' => $folders,
			'playlists' => $playlists,
	  	'total_folders' => $total_folders,
			'total_playlists' => $total_playlists,
	  	'paging' => $paging_links,
	   	%{$user},
	   	%{$file} # For get direct links
   );

}


sub RequestMoney
{
	if($c->{m_u})
	{
		# Make sure user info no cached when Memcached enabled
		$db->PurgeCache( "ses".$ses->getCookie( $ses->{auth_cook} ) );
		XUtils::CheckAuth($ses);
	}
	my $money = $ses->getUser->{usr_money};
	if($f->{convert_ext_acc})
	{
		return $ses->message("$ses->{lang}->{lng_requestmoney_need_at_least} \$$c->{convert_money}") if $money<$c->{convert_money};
		if($ses->getUser->{premium})
		{
			$db->Exec("UPDATE Users
						  SET usr_money=usr_money-?,
								usr_premium_expire=usr_premium_expire+INTERVAL ? DAY
						  WHERE usr_id=?",$c->{convert_money},$c->{convert_days},$ses->getUserId);
		}
		else
		{
			$db->Exec("UPDATE Users
						  SET usr_money=usr_money-?,
								usr_premium_expire=NOW()+INTERVAL ? DAY
						  WHERE usr_id=?",$c->{convert_money},$c->{convert_days},$ses->getUserId);
		}
		return $ses->redirect_msg("$c->{site_url}/?op=my_account","Your premium account extended for $c->{convert_days} days");
	}
	if($f->{convert_new_acc})
	{
		return $ses->message("$ses->{lang}->{lng_requestmoney_need_at_least} \$$c->{convert_money}") if $money<$c->{convert_money};
		my $login = join '', map int rand 10, 1..7;
		while($db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$login)){ $login = join '', map int rand 10, 1..7; }
		my $password = $ses->randchar(10);
		$db->Exec("INSERT INTO Users (usr_login, usr_password, usr_created, usr_premium_expire, usr_aff_id)
						VALUES (?, ?, NOW(), NOW()+INTERVAL ? DAY, ?)",
						$login, $ses->genPasswdHash($password), $c->{convert_days}, $ses->getUserId);
		$db->Exec("UPDATE Users SET usr_money=usr_money-? WHERE usr_id=?",$c->{convert_money},$ses->getUserId);
		return $ses->message("$ses->{lang}->{lng_requestmoney_new_account_generated}<br>$ses->{lang}->{lng_myaccount_username} / $ses->{lang}->{lng_myaccount_password}:<br>$login<br>$password");
	}
	if($f->{convert_profit})
	{
		return $ses->message("$ses->{lang}->{lng_requestmoney_need_at_least} \$$c->{min_payout}") if $money<$c->{min_payout};
		return $ses->message("Profit system is disabled") unless $c->{min_payout};
		return $ses->message($ses->{lang}->{lng_requestmoney_enter_pay_info}) unless $ses->getUser->{usr_pay_email};
		return $ses->message("Already have pending payout") if $db->SelectOne("SELECT id FROM Payments WHERE usr_id=? AND status='PENDING'",$ses->getUserId);

		$db->Exec("UPDATE Users SET usr_money=0 WHERE usr_id=?",$ses->getUserId);
		$db->Exec("INSERT INTO Payments SET usr_id=?,amount=?,status='PENDING',created=NOW(),pay_type=?,pay_info=?",
					$ses->getUserId, $money, $ses->getUser->{usr_pay_type}, $ses->getUser->{usr_pay_email} );
		return $ses->redirect_msg("$c->{site_url}/?op=request_money",$ses->{lang}->{lng_requestmoney_payout_requested_ok});
	}

	my $pay_req = $db->SelectOne("SELECT SUM(amount) FROM Payments WHERE usr_id=? AND status='PENDING'",$ses->getUserId);

	my $convert_enough = 1 if $money >= $c->{convert_money};
	my $payout_enough = 1 if $money >= $c->{min_payout};
	$money = sprintf("%.02f",$money);

	my $payments = $db->SelectARef("SELECT *, DATE(created) as created2, DATE(processed) as processed2
									FROM Payments
									WHERE usr_id=?
									ORDER BY created DESC",$ses->getUserId);
	for(@$payments)
	{
			$_->{processed2}='' if $_->{processed2} eq '0000-00-00';
			$_->{status}=$ses->{lang}->{lng_requestmoney_status_paid} if $_->{status} eq 'PAID';
			$_->{status}=$ses->{lang}->{lng_requestmoney_status_rejected} if $_->{status} eq 'REJECTED';
			$_->{status}=$ses->{lang}->{lng_requestmoney_status_pending} if $_->{status} eq 'PENDING';
	}

	$ses->PrintTemplate("request_money.html",
						'usr_money'			=> $money,
						'convert_days'		=> $c->{convert_days},
						'convert_money'		=> $c->{convert_money},
						'payment_request'	=> $pay_req,
						'payout_enough'		=> $payout_enough,
						'convert_enough'	=> $convert_enough,
						'enabled_prem'		=> $c->{enabled_prem},
						'min_payout'		=> $c->{min_payout},
						'msg'				=> $f->{msg},
						'payments'			=> $payments,
						);
}

sub MyReseller
{
	return $ses->message("Not allowed") unless ($c->{m_k} && ($ses->getUser->{usr_reseller} || !$c->{m_k_manual}));
	my $user = $ses->getUser;

	my (@plans,$hh,$hr);
	for(split(/,/,$c->{m_k_plans}))
	{
		my ($price,$time) = /^(.+)=(.+)$/;
		$hh->{$price} = $time;
		$hr->{$time} = $price;
		my $time1=$time;

		$time=~s/h/" $ses->{lang}->{lng_misc_hours}"/ie;
		$time=~s/d/" $ses->{lang}->{lng_misc_days}"/ie;
		$time=~s/m/" $ses->{lang}->{lng_misc_months}"/ie;

		push @plans, {	price  => $price,
						time	=> $time,
						time1  => $time1,
						enough => $user->{usr_money}>=$price ? 1 : 0,
						}
	}

	if($f->{del})
	{
		my $key = $db->SelectRow("SELECT * FROM PremiumKeys WHERE key_id=? AND usr_id=? AND usr_id_activated=0",$f->{del},$user->{usr_id});
		return $ses->message("Can't delete this key") unless $key;
		$db->Exec("UPDATE Users SET usr_money=usr_money+? WHERE usr_id=?",$hr->{$key->{key_time}},$user->{usr_id});
		$db->Exec("DELETE FROM PremiumKeys WHERE key_id=?",$key->{key_id});
		$db->PurgeCache( "ses".$ses->getCookie($ses->{auth_cook}) );
		return $ses->redirect('?op=my_reseller');
	}

	if($f->{generate}=~/^[\d\.]+$/)
	{
		return $ses->message("You can have max 100 pending keys") if $db->SelectOne("SELECT COUNT(*) FROM PremiumKeys WHERE usr_id=? AND usr_id_activated=0",$user->{usr_id})>=100;
		my $time = $hh->{$f->{generate}};
		return $ses->message("Invalid price") unless $time;
		return $ses->message("Not enough money") if $ses->getUser->{usr_money} < $f->{generate};
		my @r = ('a'..'z');
		my $key_code = $r[rand scalar @r].$ses->randchar(13);
		$db->Exec("INSERT INTO PremiumKeys SET usr_id=?, key_code=?, key_time=?, key_created=NOW()",
					$user->{usr_id},$key_code,$time);
		$db->Exec("UPDATE Users SET usr_money=usr_money-? WHERE usr_id=?",$f->{generate},$user->{usr_id});
		$db->PurgeCache( "ses".$ses->getCookie($ses->{auth_cook}) );
		return $ses->redirect('?op=my_reseller');
	}

	my $keys = $db->SelectARef("SELECT *
								FROM PremiumKeys
								WHERE usr_id=?
								ORDER BY key_created DESC
								".$ses->makePagingSQLSuffix($f->{page}), $user->{usr_id} );
	my $total = $db->SelectOne("SELECT COUNT(*) FROM PremiumKeys WHERE usr_id=?");
	for(@$keys)
	{
		$_->{key_time}=~s/h/" $ses->{lang}->{lng_misc_hours}"/ie;
		$_->{key_time}=~s/d/" $ses->{lang}->{lng_misc_days}"/ie;
		$_->{key_time}=~s/m/" $ses->{lang}->{lng_misc_months}"/ie;
	}

	$user->{usr_money} = sprintf("%.02f",$user->{usr_money});
	if($c->{m_k_add_money})
	{
		my @list = map{{amount=>$_}} grep{/^[\d\.]+$/} split /\s*\,\s*/, $c->{m_k_add_money_list};
		$user->{add_amounts} = \@list;
	}

	$ses->PrintTemplate("my_reseller.html",
						%$user,
						'plans'  => \@plans,
						'keys'	=> $keys,
						'paging' => $ses->makePagingLinks($f,$total),
						%$c,
						);
}

sub APIReseller
{
	$f->{login}=$f->{u};
	$f->{password}=$f->{p};
	Login('no_redirect');

	print"Content-type:text/html\n\n";
	print("ERROR:Reseller mod disabled"),return unless $c->{m_k};
	print("ERROR:Invalid username/password"),return unless $ses->getUser;
	print("ERROR:Not reseller user"),return if $c->{m_k_manual} && !$ses->getUser->{usr_reseller};
	print("ERROR:You can have max 100 pending keys"),return if $db->SelectOne("SELECT COUNT(*) FROM PremiumKeys WHERE usr_id=? AND usr_id_activated=0",$ses->getUserId)>=100;

	$f->{t}=lc $f->{t};
	my $price;
	for(split(/,/,$c->{m_k_plans}))
	{
		my ($pr,$time) = /^(.+)=(.+)$/;
		$price=$pr if $time eq $f->{t};
	}

	print("ERROR:Invalid time"),return unless $price;
	print("ERROR:Not enough money"),return if $ses->getUser->{usr_money} < $price;

	my @r = ('a'..'z');
	my $key_code = $r[rand scalar @r].$ses->randchar(13);
	$db->Exec("INSERT INTO PremiumKeys SET usr_id=?, key_code=?, key_time=?, key_created=NOW()",
				$ses->getUserId,$key_code,$f->{t});
	my $id = $db->getLastInsertId;
	$db->Exec("UPDATE Users SET usr_money=usr_money-? WHERE usr_id=?",$price,$ses->getUserId);
	print"$id$key_code";
	return;
}

sub ReportFile
{
	my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{file_code});

	$ses->out("No such file") unless $file;
	$db->Exec("INSERT INTO Reports
				SET file_code=?,
						type=?,
						info=?,
						ip=INET_ATON(?),
						created=NOW()
				",
				$file->{file_code},
				$ses->SecureStr($f->{report_type}),
				$ses->SecureStr($f->{report_info}),
				$ses->getIP,
				);
	$ses->out(qq[\$("#id_flag").html("$ses->{lang}->{lng_download_flag_saved}");]);
}

sub APIGetLimits
{
	if($f->{login} && $f->{password})
	{
		Login('no_redirect');
		$f->{error}="auth_error" unless $ses->getUser;
	}
	elsif($f->{session_id})
	{
		$ses->{cookies}->{$ses->{auth_cook}} = $f->{session_id};
		XUtils::CheckAuth($ses);
	}
	my $utype = $ses->getUser ? ($ses->getUser->{premium} ? 'prem' : 'reg') : 'anon';
	$c->{$_}=$c->{"$_\_$utype"} for qw(max_upload_files max_upload_filesize download_countdown captcha ads bw_limit remote_url direct_links down_speed);

	my $type_filter = $utype eq 'prem' ? "AND srv_allow_premium=1" : "AND srv_allow_regular=1";
	my $server = $db->SelectRow("SELECT * FROM Servers
								WHERE srv_status='ON'
								AND srv_disk+? <= srv_disk_max
								$type_filter
								ORDER BY srv_last_upload
								LIMIT 1",$c->{max_upload_filesize}||100);
	my $ext_allowed	  = join '|', map{uc($_)." Files|*.$_"} split(/\|/,$c->{video_extensions});
	my $login_logic = 1 if !$c->{enabled_anon} && ($c->{enabled_reg} || $c->{enabled_prem});
		$login_logic = 2 if $c->{enabled_anon} && !$c->{enabled_reg} && !$c->{enabled_prem};
	print"Content-type:text/xml\n\n";
	print"<Data>\n";
	print"<ExtAllowed>$ext_allowed</ExtAllowed>\n";
	print"<MaxUploadFilesize>$c->{max_upload_filesize}</MaxUploadFilesize>\n";
	print"<ServerURL>$server->{srv_cgi_url}</ServerURL>\n";
	print"<SessionID>".$ses->{cookies_send}->{$ses->{auth_cook}}."</SessionID>\n";
	print"<Error>$f->{error}</Error>\n";
	print"<SiteName>$c->{site_name}</SiteName>\n";
	print"<LoginLogic>$login_logic</LoginLogic>\n";
	print"</Data>";
	return;
}

sub CommentAdd
{
	XUtils::CheckAuth($ses);
	return $ses->message("File comments are not allowed") if $f->{cmt_type}==1 && !$c->{enable_file_comments};
	return $ses->message("Invalid object ID") unless $f->{cmt_ext_id}=~/^\d+$/;
	my $redirect = &CommentRedirect($f->{cmt_type},$f->{cmt_ext_id});
	if($f->{name} || $f->{email} || $f->{text})
	{
		return $ses->message("bot!");
	}
	if($ses->getUser)
	{
		$f->{cmt_name} = $ses->getUser->{usr_login};
		$f->{cmt_email} = $ses->getUser->{usr_email};
	}
	$f->{usr_id} = $ses->getUser ? $ses->getUserId : 0;
	$f->{cmt_name}=~s/(http:\/\/|www\.|\.com|\.net)//gis;
	$f->{cmt_name}	 = $ses->SecureStr($f->{cmt_name});
	$f->{cmt_email}	= $ses->SecureStr($f->{cmt_email});
	$f->{cmt_text}	 = $ses->SecureStr($f->{cmt_text});
	$f->{cmt_text} =~ s/(\_n\_|\n)/<br>/g;
	$f->{cmt_text} =~ s/\r//g;
	$f->{cmt_text} =~ s/"/&quot;/g;
	$f->{cmt_text} = substr($f->{cmt_text},0,800);
	my $err;
	$err.="Name is required field<br>" unless $f->{cmt_name};
	$err.="E-mail is not valid<br>" if $f->{cmt_email} && $f->{cmt_email}!~/^([a-zA-Z0-9_\.\-])+\@(([a-zA-Z0-9\-])+\.)+([a-zA-Z0-9]{2,4})+$/;
	$err.="Too short comment text<br>" if length($f->{cmt_text})<1;
	my $txt=$f->{cmt_text};
	$txt=~s/[\s._-]+//gs;
	$err.="Comment text contain restricted word" if $c->{bad_comment_words} && $txt=~/$c->{bad_comment_words}/i;
	print(qq{Content-type:text/html\n\n\$('#cnew').append("<b class='err'>$err</b><br><br>");}),return if $err;


	$db->Exec("INSERT INTO Comments
				SET usr_id=?,
						cmt_type=?,
						cmt_ext_id=?,
						cmt_ip=INET_ATON(?),
						cmt_name=?,
						cmt_email=?,
						cmt_text=?
				",$f->{usr_id},$f->{cmt_type},$f->{cmt_ext_id},$ses->getIP,$f->{cmt_name},$f->{cmt_email},$f->{cmt_text});
	$ses->setCookie('cmt_name',$f->{cmt_name});
	$ses->setCookie('cmt_email',$f->{cmt_email});
	$ses->redirect($redirect,'+1m');
	print"Content-type:text/html\n\n";
	#print qq{\$('#cmt_txt').val('');\$('#cnew').append("<div class='cmt'><div class='cmt_hdr'><b>$f->{cmt_name}</b></div><div class='cmt_txt'>$f->{cmt_text}</div></div>");};
	#print qq{\$('#cmt_txt').val('');\$("<div class='cmt' style='display:none'><div class='cmt_hdr'><b>$f->{cmt_name}</b></div><div class='cmt_txt'>$f->{cmt_text}</div></div>").appendTo('#cnew').slideDown('slow');};
my $post=<<EOP
<li style='display:none;' class='flex justify-between gap-x-6 py-5'>
    <div class='max-w-xl flex-auto'>
	    <p class='mt-1 text-sm leading-5 text-gray-400'>$f->{cmt_text}</p>
    </div>
</li>
EOP
;
  #$post=~s/\n//g;
  #print qq{\$('#cmt_txt').val('');\$("$post").appendTo('#cnew').slideDown('slow');};
	return;
}

sub CommentDel
{
	return $ses->message("Access denied") unless $ses->getUser && $ses->getUser->{usr_adm};
	$db->Exec("DELETE FROM Comments WHERE cmt_id=?",$f->{i});
	print"Content-type:text/html\n\n\$('#cm$f->{i}').slideUp('slow');";
	return;
}

sub CommentRedirect
{
	my ($cmt_type,$cmt_ext_id) = @_;
	if($cmt_type==1) # Files
	{
		my $file = $db->SelectRow("SELECT * FROM Files WHERE file_id=?",$cmt_ext_id);
		return $ses->message("Object doesn't exist") unless $file;
		$ses->setCookie("skip$file->{file_id}",1);
		return $ses->makeFileLink($file).'#comments';
	}
	elsif($cmt_type==2) # News
	{
		my $news = $db->SelectRow("SELECT * FROM News WHERE news_id=?",$cmt_ext_id);
		return $ses->message("Object doesn't exist") unless $news;
		return "$c->{site_url}/n$news->{news_id}-$news->{news_title2}#comments";
	}
	return $ses->message("Invalid object type");
}

###
sub ARef
{
	my $data=shift;
	$data=[] unless $data;
	$data=[$data] unless ref($data) eq 'ARRAY';
	return $data;
}

sub getTime
{
	my ($t) = @_;
	my @t = $t ? localtime($t) : localtime();
	return ( sprintf("%04d",$t[5]+1900),
				sprintf("%02d",$t[4]+1),
				sprintf("%02d",$t[3]),
				sprintf("%02d",$t[2]),
				sprintf("%02d",$t[1]),
				sprintf("%02d",$t[0])
			);
}

sub EmailUnsubscribe
{
	my $user = $db->SelectRow("SELECT * FROM Users WHERE usr_id=? AND usr_email=?",$f->{id},$f->{email});
	return $ses->message("Invalid unsubsription link") unless $user;
	$db->Exec("UPDATE Users SET usr_no_emails=1 WHERE usr_id=?",$user->{usr_id});
	return $ses->message("You've successfully unsubribed from email newsleters.");
}

sub Vote
{
	print"Content-type:text/html\n\n";
	print("alert('Register to Vote!');"),return unless $ses->getUserId;
	my $file = $db->SelectRowCached("SELECT file_id, usr_id FROM Files WHERE file_code=?",$f->{file_code});
	print(qq[alert("File was deleted");]),return unless $file;
	my $voted = $db->SelectOne("SELECT vote FROM Votes WHERE file_id=? AND usr_id=?",$file->{file_id},$ses->getUserId);
	#print(qq[alert("You've already voted for this file!");]),return if

	my $vote = $f->{v} eq 'up' ? 1 : -1;
	return if $voted && $voted==$vote;
	my $rating;
	if($voted)
	{
			$db->Exec("UPDATE Votes SET vote=? WHERE file_id=? AND usr_id=?", $vote, $file->{file_id},$ses->getUserId);
			$rating = $vote==1 ? 2 : -2;
	}
	else
	{
		$db->Exec("INSERT IGNORE INTO Votes SET file_id=?, usr_id=?, vote=?",$file->{file_id},$ses->getUserId,$vote);
		$rating = $vote;
	}
	$db->Exec("UPDATE LOW_PRIORITY Files SET file_rating=file_rating+? WHERE file_id=?", $rating, $file->{file_id});

    # Your existing upvote handling
	if ($vote == 1) {
		$db->Exec("INSERT INTO Stats2
					SET usr_id=?, day=CURDATE(),
						file_rating=1
					ON DUPLICATE KEY UPDATE
						file_rating=file_rating+1
				",$file->{usr_id});  # Use the file owner's usr_id in the query

		$db->Exec("UPDATE Files SET file_rating_last=NOW() WHERE file_id=?", $file->{file_id} );
	}
	elsif ($vote == -1) {
    $db->Exec("UPDATE Stats2
               SET file_rating = GREATEST(file_rating - 1, 0)
               WHERE usr_id = ? AND day = CURDATE()
              ", $file->{usr_id});
	}

	my $votes = $db->SelectARef("SELECT vote, COUNT(*) as num FROM Votes WHERE file_id=? GROUP BY vote",$file->{file_id});
	for(@$votes)
	{
		$file->{likes}=$_->{num} if $_->{vote}==1;
		$file->{dislikes}=$_->{num} if $_->{vote}==-1;
	}
	$file->{likes}||=0;
	$file->{dislikes}||=0;
	$file->{likes_percent}=sprintf("%.1f",100*$file->{likes}/($file->{likes}+$file->{dislikes})) if $file->{likes} || $file->{dislikes};

	print qq|\$("#vote a").removeClass('active');\$(".vote_$f->{v}").addClass('active');\$('#likes_num-$file->{file_id}').text('$file->{likes}');\$('#dislikes_num').text('$file->{dislikes}');\$('.likestatus span').css('width','$file->{likes_percent}%');|;
	return;
}


sub ModeratorFilesFeatured
{
	return $ses->message("Access denied") if !$ses->getUser->{usr_adm} && !($c->{m_d} && $ses->getUser->{usr_mod} && $c->{m_d_featured});
	if($f->{ajax_toggle})
	{
		print"Content-type:text/html\n\n";
		my $now = $db->SelectOne("SELECT file_id FROM FilesFeatured WHERE file_id=?",$f->{ajax_toggle});
		if($now)
		{
			$db->Exec("DELETE FROM FilesFeatured WHERE file_id=?",$f->{ajax_toggle});
			print"Added to Featured";
		}
		else
		{
			$db->Exec("INSERT INTO FilesFeatured SET file_id=?",$f->{ajax_toggle});
			print"Added to Featured";
		}
		return;
	}
	if($f->{del_id})
	{
		$db->Exec("DELETE FROM FilesFeatured WHERE file_id=?",$f->{del_id});
		#$ses->redirect("?op=admin_files_featured");
		print"Content-type:text/html\n\n";
		print"\$('#f$f->{del_id}').hide('slow');";
		return;
	}
	my $list = $db->SelectARef("SELECT f.*,
								UNIX_TIMESTAMP()-UNIX_TIMESTAMP(ff.created) as added,
								u.usr_login
								FROM (FilesFeatured ff, Files f)
								LEFT JOIN Users u ON f.usr_id=u.usr_id
								WHERE ff.file_id=f.file_id
								ORDER BY ff.created
								");
	for(@$list)
	{
		$_->{download_link} = $ses->makeFileLink($_);
		$_->{added} = sprintf("%.0f",$_->{added}/3600);
		$_->{added} = $_->{added} < 48 ? "$_->{added} hours ago" : sprintf("%.0f days ago",$_->{added}/24);
		$ses->getVideoInfo($_);
	}
	$ses->PrintTemplate("moderator_files_featured.html",
						list			=> $list,
						);
}

sub MyTorrents
{
	if($f->{del_torrents} && $f->{sid})
	{
		$db->Exec("DELETE FROM Torrents WHERE sid=? AND usr_id=?",$f->{sid},$ses->getUserId);
		return $ses->redirect("$c->{site_url}/?op=my_torrents");
	}

	my $torrents = getTorrents();
	$ses->PrintTemplate("my_torrents.html",
						torrents  => $torrents,
						);
}

sub getTorrents
{
	my $torrents = $db->SelectARef("SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(created) as working
											FROM Torrents t
											WHERE t.usr_id=?
											AND t.status='WORKING'
											ORDER BY created DESC
											",$ses->getUserId);
	require JSON;
	for my $t (@$torrents)
	{
		my $files = eval { JSON::decode_json($t->{files}) } if $t->{files};
		$t->{file_list} = join('<br>',map{$_->{name}=~s/^.+\///;$ses->SecureStr($_->{name}) . " (<i>".sprintf("%.1f Mb",$_->{length}/1048576)."<\/i>) ".sprintf("%.0f%",100*$_->{bytesCompleted}/($_->{length}||1))} grep{$_->{name}!~/\.(txt|exe|jpg|png)$/} @$files );
		$t->{title} = $ses->SecureStr($t->{name});
		$t->{title}=~s/\/.+$//;
		$t->{title}=~s/:\d+$//;

		$t->{percent} = sprintf("%.01f", 100*$t->{downloaded}/$t->{size} ) if $t->{size};
		$t->{working} = $t->{working}>3600*3 ? sprintf("%.1f hours",$t->{working}/3600) : sprintf("%.0f mins",$t->{working}/60);
		$t->{"status_".lc($t->{status})} = 1;

		$t->{download_speed} = sprintf("%.0f KB/s", $t->{download_speed}/1024 );
		$t->{upload_speed} = sprintf("%.0f KB/s", $t->{upload_speed}/1024 );
		$t->{downloaded} = sprintf("%.1f", $t->{downloaded}/1024**3 );
		$t->{uploaded} = sprintf("%.1f", $t->{uploaded}/1024**3 );
		$t->{size} = sprintf("%.1f", $t->{size}/1024**3 );
	}

	return $torrents;
}

sub MakeMoneyPage
{
	my @sizes = map{{t1=>$_}} split(/\|/,$c->{tier_sizes});
	$sizes[$_]->{t2}=$sizes[$_+1]->{t1} for(0..$#sizes-1);
	$sizes[$#sizes]->{t2}='Longer';

	my @tier1 = map{{amount=>$_}} split(/\|/,$c->{tier1_money});
	my @tier2 = map{{amount=>$_}} split(/\|/,$c->{tier2_money});
	my @tier3 = map{{amount=>$_}} split(/\|/,$c->{tier3_money});
	my @tier4 = map{{amount=>$_}} split(/\|/,$c->{tier4_money});

	require XCountries;

	my @countries1 = grep{$_} map{$XCountries::iso_to_country->{uc $_}} split(/\|/,$c->{tier1_countries});
	my @countries2 = grep{$_} map{$XCountries::iso_to_country->{uc $_}} split(/\|/,$c->{tier2_countries});
	my @countries3 = grep{$_} map{$XCountries::iso_to_country->{uc $_}} split(/\|/,$c->{tier3_countries});
	my @countries4 = grep{$_} map{$XCountries::iso_to_country->{uc $_}} split(/\|/,$c->{tier4_countries});

	$ses->PrintTemplate("make_money.html",
						sizes => \@sizes,
						tier1 => \@tier1,
						tier2 => \@tier2,
						tier3 => \@tier3,
						tier4 => \@tier4,
						countries1 => join(', ',@countries1),
						countries2 => join(', ',@countries2),
						countries3 => join(', ',@countries3),
						countries4 => join(', ',@countries4),
						tier_views_number => $c->{tier_views_number},
						);
}

sub MyWatermark
{
	#$ses->loadUserData();
	my $user = $ses->getUser;

	#return $ses->message("Watermark mod disabled") unless $c->{m_v};
	return $ses->message("You're not allowed to manage watermark") unless $ses->checkModSpecialRights('m_v');

	my $usr_id = $ses->getUserId;

	if(defined $f->{watermark_mode})
	{
		if($f->{watermark_mode} eq 'image' && $f->{logo_image})
		{
			require GD;
			my $im = new GD::Image($ses->{cgi_query}->upload('logo_image')) || return $ses->message("Failed to read the image");
			my ($w,$h) = $im->getBounds();
			return $ses->message("Invalid image") unless $w && $h;
			return $ses->message("Image is too large ($w x $h)") if $w>$c->{m_v_image_max_size} || $h>$c->{m_v_image_max_size};
			$im->saveAlpha(1);
			$im->alphaBlending(1);
			uploadMoveFile('logo_image',"$c->{site_path}/upload-data/watermark_$usr_id.png") || return $ses->message("Failed to move the image:$!");
		}

		### Validate inputs ###
		$f->{watermark_text}=~s/[^\w\s\.\-\!]//g;
		if($f->{watermark_mode} eq 'text')
		{
			$f->{watermark_padding}=~s/\D//g;
			$f->{watermark_padding}||=0;
			$f->{watermark_position}||='nw';
			$f->{watermark_color}='white' unless $f->{watermark_color}=~/^#\w{6}$/ || $f->{watermark_color}=~/^\w+$/i;
			$f->{watermark_shadow_color}='' unless $f->{watermark_shadow_color}=~/^#\w{6}$/ || $f->{watermark_shadow_color}=~/^\w+$/i;
			$f->{watermark_size}=13 unless $f->{watermark_size}=~/^\d+$/;
			$f->{watermark_text}=$c->{site_name} unless $f->{watermark_text};
		}
		if($f->{watermark_mode} eq 'scroll')
		{
			$f->{watermark_padding}=~s/\D//g;
			$f->{watermark_padding}||=0;
			$f->{watermark_position}||='top';
			$f->{watermark_color}='white' unless $f->{watermark_color}=~/^#\w{6}$/ || $f->{watermark_color}=~/^\w+$/i;
			$f->{watermark_shadow_color}='' unless $f->{watermark_shadow_color}=~/^#\w{6}$/ || $f->{watermark_shadow_color}=~/^\w+$/i;
			$f->{watermark_size}=13 unless $f->{watermark_size}=~/^\d+$/;
			$f->{watermark_scroll_start}=3	unless $f->{watermark_scroll_start}=~/^\d+$/;
			$f->{watermark_scroll_length}=10 unless $f->{watermark_scroll_length}=~/^\d+$/;
			$f->{watermark_text}=$c->{site_name} unless $f->{watermark_text};
		}
		if($f->{watermark_mode} eq 'image')
		{
			$f->{watermark_image_fadeout}=~s/\D//g;
			$f->{watermark_image_fadeout}=60 if $f->{watermark_image_fadeout}>60;
			$f->{watermark_image_fadeout}||=10;
			$f->{watermark_padding}=~s/\D//g;
			$f->{watermark_padding}||=0;
			$f->{watermark_fade}||=0;
			$f->{watermark_position}||='nw';
		}
		#######################

		my @keys = grep {/^watermark_/} keys %$f;
		for(@keys)
		{
			#$db->Exec("INSERT INTO UserData SET usr_id=?, name=?, value=?", $ses->getUserId, $_, $f->{$_}||'' ) if defined $f->{$_};
			$ses->saveUserData($_, $f->{$_});
		}
		return $ses->redirect('?op=my_watermark');
	}

	#my @fonts = map{{font=>$_,selected=>($_ eq $user->{watermark_font} ? ' selected' : '')}} split /,\s*/, $c->{m_v_fonts};
	my @fonts = map{{font_name=>$_, selected=>($_ eq $user->{watermark_font} ? ' selected' : '')}} split /\s*\,\s*/, $c->{fileserver_fonts};

	$user->{watermark_mode}||=0;
	$user->{"watermark_mode_$user->{watermark_mode}"}=' checked';
	$user->{"watermark_dispose_mode_$user->{watermark_dispose_mode}"} = ' selected';
	$user->{"watermark_opacity_$user->{watermark_opacity}"} = ' selected';
	$user->{"watermark_position_$user->{watermark_position}"} = 1;
	$user->{logo_url}="watermark_$usr_id.png" if -f "$c->{site_path}/upload-data/watermark_$usr_id.png";

	$ses->PrintTemplate("my_watermark.html",
						%$user,
						fonts	=> \@fonts,
						m_v_image_logo => $c->{m_v_image_logo},
						m_v_image_max_size => $c->{m_v_image_max_size},
						rand => $ses->randchar(6),
						);
}

sub addEncodeQueueDB
{
	my ($file_real_id, $file_real, $file_id, $srv_id, $premium, $quality) = @_;

	$db->Exec("INSERT IGNORE INTO QueueEncoding
				SET file_real_id=?,
					file_real=?,
					file_id=?,
					srv_id=?,
					premium=?,
					quality=?,
					extra=?,
					created=NOW()",
					$file_real_id,
					$file_real,
					$file_id,
					$srv_id,
					$premium,
					$quality,
					$f->{effects}||'',
				);
}

sub MySnapshot
{
	#return $ses->message("Watermark mod disabled") unless $c->{m_s};
	return $ses->message("You're not allowed to manage snapshots") unless $ses->checkModSpecialRights('m_s');

	my $file = $db->SelectRow("SELECT * FROM Files f, Servers s
										WHERE file_code=?
										AND usr_id=?
										AND f.srv_id=s.srv_id",$f->{file_code},$ses->getUserId);
	return $ses->message("Not your file") unless $file;
	$ses->getVideoInfo($file);
	$f->{ss}=~s/[^\d\.]//g;
	$f->{ss}||=0;
	if($f->{create})
	{
		my $res = $ses->api2($file->{srv_id},
									{
										op => 'gen_snapshots',
										file_code	=> $file->{file_real},
										file_id		=> $file->{file_real_id}||$file->{file_id},
										disk_id		=> $file->{disk_id},
										create		=> $f->{ss},
									});
		return $ses->message("ERROR:$res") unless $res eq 'OK';
		$ses->PurgeFileCaches($file);
		return $ses->redirect("?op=file_edit&file_code=$file->{file_code}&newshot=1");
	}

	if($f->{preview})
	{
		my $res = $ses->api2($file->{srv_id},
									{
										op => 'gen_snapshots',
										file_code	=> $file->{file_real},
										file_id		=> $file->{file_real_id}||$file->{file_id},
										disk_id		=> $file->{disk_id},
										preview		=> $f->{ss},
									});
		print"Content-type:text/html\n\n";
		print q[<Table class="tbl1" cellpadding=2 width=780><TR><TH>Preview snapshots</TH></TR>];
		for(grep {$_} split /\n/, $res)
		{
			my $rand = $ses->randchar(6);
			print qq[<tr align=center><td><a href="#new" onclick="\$('#ss').val('$_');"><img src="$file->{srv_htdocs_url}/i/tmp/$file->{file_real}/$_.jpg?$rand"></a>];
		}
		print"</Table>";
		return;
	}

	if($f->{upload_new} && $c->{m_s_upload})
	{
		my $file = $db->SelectRow("SELECT * FROM Files f, Servers s WHERE f.file_code=? AND f.usr_id=? AND f.srv_id=s.srv_id",$f->{file_code},$ses->getUserId);
		return $ses->message("No file") unless $file;
		my $uid=$ses->getUserId;
		my $thumb = "$c->{site_path}/captchas/th$uid.jpg";
		uploadMoveFile('file', $thumb)|| return $ses->message("Upload error:$!");

		require GD;
		my $im = new GD::Image($thumb) || return $ses->message("Failed to read the image");
		my ($w,$h) = $im->getBounds();
		return $ses->message("Invalid image") unless $w && $h;
		if($w>1280 || $h>720)
		{
			resizeGD2($im, 1280, 720, $thumb);
		}
		#return $ses->message("Image is too large ($w x $h)") if $w>1920 || $h>1080;

		my $h = [
					dl_key=>$c->{dl_key},
					op			=> 'thumb_upload',
					disk_id	=> $file->{disk_id},
					file_id	=> $file->{file_real_id}||$file->{file_id},
					file_code  => $file->{file_real},
					file		=> [$thumb]
				];
		require HTTP::Request::Common;
		require LWP::UserAgent;
		my $ua = LWP::UserAgent->new(agent=>$c->{user_agent},timeout=>300);
		my $req = HTTP::Request::Common::POST( "$file->{srv_cgi_url}/api.cgi", Content_Type => 'form-data', Content => $h);
		my $res = $ua->request($req)->content;
		unlink($thumb);
		return $ses->message("Upload error: $res") unless $res=~/^OK$/i;
		return $ses->redirect("?op=my_snapshot&file_code=$file->{file_code}&newshot=1");
	}

	my $res = $ses->api2($file->{srv_id},{
							op => 'gen_snapshots',
							file_code	=> $file->{file_real},
							file_id		=> $file->{file_real_id}||$file->{file_id},
							disk_id		=> $file->{disk_id},
							file_length	=> $file->{file_length},
							m_s_samples	=> $c->{m_s_samples},
							});
	return $ses->message($res) unless $res=~/^\d+/;
	my $cx;
	my @list = map { {url=>"$file->{srv_htdocs_url}/i/tmp/$file->{file_real}/$_.jpg", 'ss'=>$_, 'tr'=>$cx++%2} } grep {$_} split /\n/, $res;

	$file->{image_file} = $c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i;
	$file->{audio_file} = $c->{audio_extensions} && $file->{file_name} =~ /\.($c->{audio_extensions})$/i;
	$file->{video_file} = $c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i;
	$file->{archive_file} = $c->{archive_extensions} && $file->{file_name} =~ /\.($c->{archive_extensions})$/i;

	$ses->PrintTemplate("my_snapshot.html",
						%$file,
						list => \@list,
						m_s_upload => $c->{m_s_upload},
						);
}

sub MyFilesDeleted
{
	if($f->{hide})
	{
		$db->Exec("UPDATE FilesTrash SET hide=1 WHERE usr_id=?",$ses->getUserId);
		return $ses->redirect("?op=my_files_deleted");
	}
	if($f->{restore} && $f->{file_code})
	{
		my $ids = join("','",grep{/^\w{12}$/}@{ARef($f->{file_code})});
		return $ses->redirect($c->{site_url}) unless $ids;
		my $list = $db->SelectARef("SELECT * FROM FilesTrash WHERE usr_id=? AND file_code IN ('$ids')",$ses->getUserId);
		for my $x (@$list)
		{
			unless($x->{del_by}==$ses->getUserId)
			{
				$x->{file_code} = $ses->randchar(12);
				while($db->SelectOne("SELECT file_id FROM Files WHERE file_code=? OR file_real=?",$x->{file_code},$x->{file_code})){$x->{file_code} = $ses->randchar(12);}
			}
			delete @$x{'file_deleted', 'del_by', 'hide', 'cleaned'};
			$x->{file_fld_id}=0 unless $db->SelectOne("SELECT fld_id FROM Folders WHERE fld_id=? AND usr_id=?",$x->{file_fld_id},$ses->getUserId);

			my (@par,@val);
			for(keys %$x)
			{
				push @par, "$_=?";
				push @val, $x->{$_};
			}
			$db->Exec("INSERT INTO Files SET ".join(',',@par), @val);

			$db->Exec("DELETE FROM FilesTrash WHERE file_id=? AND usr_id=?",$x->{file_id},$ses->getUserId);
			$db->Exec("DELETE FROM QueueDelete WHERE file_real_id=?",$x->{file_real_id});
		}
		return $ses->redirect_msg("?op=my_files_deleted",@$list." files were restored");
	}
	my $files = $db->SelectARef("SELECT f.*, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(file_deleted) as ago
								FROM FilesTrash f
								WHERE f.usr_id=?
								AND hide=0
								ORDER BY file_deleted DESC",$ses->getUserId);
	my $reals= join "','", map{$_->{file_real}} @$files;
	my $canrestore1 = $db->SelectARef("SELECT DISTINCT file_real FROM Files WHERE file_real IN ('$reals')");
	my $canrestore2 = $db->SelectARef("SELECT DISTINCT file_real FROM QueueDelete WHERE file_real IN ('$reals')");

	my %can = map{ $_->{file_real}=>1 } @$canrestore1,@$canrestore2;

	my $totals->{deleted_num} = $db->SelectARefCached("SELECT COUNT(*) as x FROM FilesTrash WHERE usr_id=? AND hide=0",$ses->getUserId)->[0]->{x};

	for(@$files)
	{
		$_->{ago} = sprintf("%.0f",$_->{ago}/60);
		$_->{ago} = $_->{ago}<180 ? "$_->{ago} mins" : sprintf("%.0f hours",$_->{ago}/60);
		$_->{restore} = $can{$_->{file_real}};
		$_->{own}=" style='color:green'" if $_->{del_by}==$ses->getUserId;
	}
	$ses->PrintTemplate("my_files_deleted.html",
						files => $files,
						%{$totals},
						);
}

sub ModeratorReports
{
	return $ses->message("Access denied") if !$ses->getUser->{usr_adm} && !($c->{m_d} && $ses->getUser->{usr_mod} && $c->{m_d_a});

	if($f->{file_code})
	{
		return $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
		my $ids = join "','", grep{/^\w{12}$/} @{ARef($f->{file_code})};
		my $files = $db->SelectARef("SELECT * FROM Files WHERE file_code IN ('$ids')") if $ids;
		if($files)
		{
			if($f->{delete_selected})
			{
				$_->{del_money}=$c->{del_money_file_del} for @$files;
				$ses->DeleteFilesMass($files);
			}
			$db->Exec("DELETE FROM Reports WHERE file_code IN ('$ids')");
		}
		return $ses->redirect("?op=moderator_reports");
	}

	my $list = $db->SelectARef("SELECT r.*, f.*, INET_NTOA(ip) as ip,
								(SELECT u.usr_login FROM Users u WHERE f.usr_id=u.usr_id) as usr_login
								FROM Reports r
								LEFT JOIN Files f ON r.file_code = f.file_code
								ORDER BY r.created DESC".$ses->makePagingSQLSuffix($f->{page}));
	my $total = $db->SelectOne("SELECT COUNT(*)
								FROM Reports r");
	for(@$list)
	{
		$_->{site_url} = $c->{site_url};
		$_->{info} =~ s/\n/<br>/gs;
	}
	$ses->PrintTemplate("moderator_reports.html",
						'list'	=> $list,
						'paging'  => $ses->makePagingLinks($f,$total),
						);
}

sub ModeratorComments
{
	return $ses->message("Access denied") unless $c->{m_d} && $ses->getUser->{usr_mod} && $c->{m_d_c};
	if($f->{del_selected} && $f->{cmt_id})
	{
		my $ids = join(',',grep{/^\d+$/}@{ARef($f->{cmt_id})});
		return $ses->redirect($c->{site_url}) unless $ids;
		$db->Exec("DELETE FROM Comments WHERE cmt_id IN ($ids)");
		return $ses->redirect("?op=moderator_comments");
	}
	if($f->{rr})
	{
		return $ses->redirect( CommentRedirect(split(/-/,$f->{rr})) );
	}
	my $filter;
	$filter="WHERE c.cmt_ip=INET_ATON('$f->{ip}')" if $f->{ip}=~/^[\d\.]+$/;
	$filter="WHERE c.usr_id=$f->{usr_id}" if $f->{usr_id}=~/^\d+$/;
	$filter="WHERE c.cmt_name LIKE '%$f->{key}%' OR c.cmt_email LIKE '%$f->{key}%' OR c.cmt_text LIKE '%$f->{key}%'" if $f->{key}=~/^[\w-]+$/;
	my $list = $db->SelectARef("SELECT c.*, INET_NTOA(c.cmt_ip) as ip, u.usr_login, u.usr_id
								FROM Comments c
								LEFT JOIN Users u ON c.usr_id=u.usr_id
								$filter
								ORDER BY created DESC".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}));
	my $total = $db->SelectOne("SELECT COUNT(*) FROM Comments c $filter");
	$ses->PrintTemplate("moderator_comments.html",
						'list'	=> $list,
						'key'	=> $f->{key},
						'paging' => $ses->makePagingLinks($f,$total),
						);
}

sub AddToPlaylist
{
	print"Content-type:text/html\n\n";
	my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{file_code});
	print("ERROR: file not found"),return unless $file;
	print("ERROR: token error"),return unless $ses->checkToken;
	if($f->{new})
	{
		$f->{new} = $ses->SecureStr($f->{new});
		$f->{pls_url}||=lc $f->{new};
		$f->{pls_url}=~s/\s*-\s*/-/g;
		$f->{pls_url}=~s/\s+/-/g;
		$f->{pls_url}=~s/[^\w\d.-]//g;
		my $code = $ses->randchar(6);
		while($db->SelectOne("SELECT pls_id FROM Playlists WHERE pls_code=?",$code)){$code = $ses->randchar(6);}
		$db->Exec("INSERT INTO Playlists SET usr_id=?, pls_code=?, pls_name=?, pls_created=NOW()", $ses->getUserId, $code, $f->{new} );
		$f->{pls_id} = $db->getLastInsertId;

		# Update pls_url with pls_id
		$f->{pls_url} .= "-$f->{pls_id}";
		$db->Exec("UPDATE Playlists SET pls_url=? WHERE pls_id=?", $f->{pls_url}, $f->{pls_id});
	}
	if($f->{pls_id} eq 'watchlater')
	{
		$f->{pls_id} = $db->SelectOne("SELECT pls_id FROM Playlists WHERE usr_id=? AND pls_name='Watch later'",$ses->getUserId);
		unless($f->{pls_id})
		{
			my $code = $ses->randchar(6);
			while($db->SelectOne("SELECT pls_id FROM Playlists WHERE pls_code=?",$code)){$code = $ses->randchar(6);}
			$db->Exec("INSERT INTO Playlists SET usr_id=?, pls_code=?, pls_name=?, pls_created=NOW()", $ses->getUserId, $code, 'Watch later' );
			$f->{pls_id} = $db->getLastInsertId;

			# Update pls_url with pls_id
			$f->{pls_url} .= "watch-later-$f->{pls_id}";
			$db->Exec("UPDATE Playlists SET pls_url=? WHERE pls_id=?", $f->{pls_url}, $f->{pls_id});
		}
	}
	my $plist = $db->SelectRow("SELECT * FROM Playlists WHERE pls_id=? AND usr_id=?", $f->{pls_id}, $ses->getUserId );
	print("ERROR: playlist not found"),return unless $plist;

	$db->Exec("INSERT IGNORE INTO Files2Playlists SET pls_id=?, file_id=?", $f->{pls_id}, $file->{file_id} );

	print"<span style='color:#22c55e'>File added to playlist</span> <a style='color:#6366f1' href='$c->{site_url}/playlist/$plist->{pls_url}'>$plist->{pls_name}</a>";
	return;
}

sub MyPlaylists
{
	if($f->{del_playlist}=~/^\d+$/ && $f->{token} && $ses->checkToken)
	{
		my $plist = $db->SelectRow("SELECT * FROM Playlists WHERE pls_id=? AND usr_id=?", $f->{del_playlist}, $ses->getUserId );
		return $ses->message("Playlist not found") unless $plist;
		$db->Exec("DELETE FROM Files2Playlists WHERE pls_id=?",$plist->{pls_id});
		$db->Exec("DELETE FROM Playlists WHERE pls_id=?",$plist->{pls_id});
		return $ses->redirect("?op=my_playlists");
	}

	 $f->{per_page}=20;

		my @audio_extensions = split(/\|/, $c->{audio_extensions});
		my @video_extensions = split(/\|/, $c->{video_extensions});
		my @image_extensions = split(/\|/, $c->{image_extensions});

		# Assuming @extensions is your array of file extensions
		my @extensions = (@audio_extensions, @video_extensions, @image_extensions);
		# Create placeholders for each extension in the list
		my $placeholders = join(', ', ('?') x @extensions);

			my $pagination_suffix = $ses->makePagingSQLSuffix($f->{page}, $f->{per_page});
			my $playlists = $db->SelectARef(
					"SELECT Playlists.*, COUNT(Files.file_id) AS pls_file_count
					FROM Playlists
					LEFT JOIN Files2Playlists ON Playlists.pls_id = Files2Playlists.pls_id
					LEFT JOIN Files ON Files2Playlists.file_id = Files.file_id AND Files.file_public=1 AND Files.file_status='OK'
					WHERE Playlists.usr_id=?
					AND LOWER(SUBSTRING_INDEX(Files.file_name, '.', -1)) IN ($placeholders)
					GROUP BY Playlists.pls_id
					ORDER BY Playlists.pls_created DESC $pagination_suffix",
					$ses->getUserId, @extensions
			);


    foreach my $playlist (@$playlists) {

			# Select the IDs of the first 10 files of the specified type for this playlist
			my $top_file_ids = $db->SelectARef("SELECT fp.file_id FROM Files2Playlists fp JOIN Files f ON fp.file_id = f.file_id WHERE fp.pls_id=? AND f.file_public=1 AND f.file_status='OK' ORDER BY f.file_created DESC LIMIT 20", $playlist->{pls_id});

			if (@$top_file_ids > 0) {
					my $random_index = int(rand(scalar(@$top_file_ids)));
					my $random_file_id = $top_file_ids->[$random_index]->{file_id};

					# Retrieve the details for the randomly selected file
					my $playlist_thumb = $db->SelectRow("SELECT f.file_real, f.file_real_id, s.disk_id, f.video_thumb, f.audio_thumb, f.file_name, s.srv_htdocs_url
																						FROM Files f
																						JOIN Servers s ON f.srv_id = s.srv_id
																						WHERE f.file_id = ?", $random_file_id);

					if ($playlist_thumb) {
							my $dx = sprintf("%05d", $playlist_thumb->{file_real_id} / $c->{files_per_folder});

							my $thumbnail;
							# Extract file extension
							if ($playlist_thumb->{file_name} =~ /.([^.]+)$/) {
									$playlist_thumb->{file_extension} = $1;
							} else {
									$playlist_thumb->{file_extension} = '';
							}

							# Determine which thumbnail to use based on file type
							if ($playlist_thumb->{video_thumb}) {
									$thumbnail = "$playlist_thumb->{srv_htdocs_url}/i/$playlist_thumb->{disk_id}/$dx/$playlist_thumb->{video_thumb}";
							} elsif ($playlist_thumb->{audio_thumb}) {
									$thumbnail = "$playlist_thumb->{srv_htdocs_url}/i/$playlist_thumb->{disk_id}/$dx/$playlist_thumb->{audio_thumb}";
							} elsif ($playlist_thumb->{file_extension} =~ /^($c->{image_extensions})$/i) { # Check for image file extensions
									# For image files, construct the thumbnail URL dynamically
									$thumbnail = "$playlist_thumb->{srv_htdocs_url}/i/$playlist_thumb->{disk_id}/$dx/" . $playlist_thumb->{file_real} . "_t." . $playlist_thumb->{file_extension};
							}

							# Store the thumbnail URL in the folder hash for use in your template
							$playlist->{playlist_thumb_url} = $thumbnail;
					}
			}

			# Count audio files
			my $audio_num = $db->SelectARef("SELECT COUNT(*) as audio_num FROM Files f
																				JOIN Files2Playlists fp ON f.file_id = fp.file_id
																				WHERE fp.pls_id=? AND f.file_name REGEXP '\.($c->{audio_extensions})\$'", $playlist->{pls_id})->[0]->{audio_num};

			# Count video files
			my $video_num = $db->SelectARef("SELECT COUNT(*) as video_num FROM Files f
																				JOIN Files2Playlists fp ON f.file_id = fp.file_id
																				WHERE fp.pls_id=? AND f.file_name REGEXP '\.($c->{video_extensions})\$'", $playlist->{pls_id})->[0]->{video_num};

			# Count image files
			my $image_num = $db->SelectARef("SELECT COUNT(*) as image_num FROM Files f
																				JOIN Files2Playlists fp ON f.file_id = fp.file_id
																				WHERE fp.pls_id=? AND f.file_name REGEXP '\.($c->{image_extensions})\$'", $playlist->{pls_id})->[0]->{image_num};

			$playlist->{audio_num} = $audio_num;
			$playlist->{video_num} = $video_num;
			$playlist->{image_num} = $image_num;
    }



			# Query to count the total number of playlists
		my $total_playlists = $db->SelectOne("
			SELECT COUNT(DISTINCT Playlists.pls_id) FROM Playlists
			LEFT JOIN Files2Playlists ON Playlists.pls_id = Files2Playlists.pls_id
			LEFT JOIN Files ON Files2Playlists.file_id = Files.file_id
			WHERE Playlists.usr_id=? AND Files.file_public=1 AND Files.file_status='OK'
			AND LOWER(SUBSTRING_INDEX(Files.file_name, '.', -1)) IN ($placeholders)",
			$ses->getUserId, @extensions
		);

		my $paging_links = $ses->makePagingLinks($f, $total_playlists);

	$ses->PrintTemplate("my_playlists.html",
						list  => $playlists,
						token => $ses->genToken,
						paging => $paging_links
						);
}

sub MyPlaylistFiles
{
	my $plist = $db->SelectRow("SELECT * FROM Playlists WHERE pls_id=? AND usr_id=?", $f->{pls_id}, $ses->getUserId );
	return $ses->message("Playlist not found") unless $plist;
	if($f->{remove} && $f->{file_id})
	{
		my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})}) || 0;
		$db->Exec("DELETE FROM Files2Playlists WHERE pls_id=? AND file_id IN ($ids)", $f->{pls_id} );
		return $ses->redirect("?op=my_playlist_files&pls_id=$f->{pls_id}");
	}
	my $files = $db->SelectARef("SELECT * FROM Files f, Files2Playlists f2p WHERE f2p.pls_id=? AND f2p.file_id=f.file_id", $plist->{pls_id} );
	for(@$files)
	{
		$_->{file_descr} = $ses->shortenString( $_->{file_descr}, 50 );

		$_->{file_title_txt} = $ses->shortenString( $_->{file_title}||$_->{file_name}, $c->{display_max_filename} );

		$_->{download_link} = $ses->makeFileLink($_);

		$ses->getVideoInfo($_);
	}
	$ses->PrintTemplate("my_playlist_files.html",
						files  => $files,
						token  => $ses->genToken,
						pls_id => $plist->{pls_id},
						%$plist,
						);
}

sub getAffiliate
{
	my $usr_id = $ses->getUser ? $ses->getUserId : 0;

	my $aff_id;
	$aff_id = $ses->getCookie('aff')||0;
	$aff_id = 0 if $aff_id==$usr_id;
	$aff_id = $ses->getUser->{usr_aff_id} if $ses->getUser && $ses->getUser->{usr_aff_id} && !$aff_id;
	return($aff_id||0);
}

sub AjaxNewFolder
{
	$f->{create_new_folder} = $ses->SecureStr($f->{create_new_folder});
	return $ses->amessage("Invalid folder name!") unless $f->{create_new_folder};
	return $ses->amessage("Invalid parent folder") if $f->{fld_id} && !$db->SelectOne("SELECT fld_id FROM Folders WHERE usr_id=? AND fld_id=?",$ses->getUserId,$f->{fld_id});
	return $ses->amessage("You already have folder with this name!") if $db->SelectOne("SELECT fld_id FROM Folders WHERE usr_id=? AND fld_parent_id=? AND fld_name=?",$ses->getUserId,$f->{fld_id},$f->{create_new_folder});
	return $ses->amessage("$c->{max_folders_limit} folders limit reached!") if $db->SelectOne("SELECT COUNT(*) FROM Folders WHERE usr_id=?",$ses->getUserId) >= $c->{max_folders_limit};
	my $code = $ses->randchar(10);
	while($db->SelectOne("SELECT fld_id FROM Folders WHERE fld_code=?",$code)){$code = $ses->randchar(10);}
	$db->Exec("INSERT INTO Folders SET usr_id=?, fld_parent_id=?, fld_name=?, fld_code=?",$ses->getUserId,$f->{fld_id}||0,$f->{create_new_folder},$code);
	my $fld_id = $db->getLastInsertId;
	$db->PurgeCache( "ufld-$f->{fld_id}-".$ses->getUserId );
	return $ses->amessage("<option value='$fld_id'>$f->{create_new_folder}</option>");
}

sub UploadSRT
{
	$ses->{xframe}=1;
	$ses->{form}->{no_hdr}=1;
	return $ses->message("Mod not enabled") unless $c->{m_g};
	return $ses->message("Invalid code") unless $f->{file_code}=~/^\w{12}$/;
	if($f->{srt} || $f->{url})
	{
		saveSRT();
		print"Content-type:text/html\n\n";
		print"<script>window.parent.location.reload(false);</script>";
		return;
	}

	#my @langs = map{{value=>$_}} split /\s*\,\s*/, $c->{srt_langs};
	my @srt_langs = map{/^(\w+)=(\w+)$/;{value=>$1,title=>"$2 ($1)"}} split /\s*\,\s*/, $c->{srt_auto_langs};

	$ses->setCookie("srt_cook",$ses->randchar(6),"+90d") unless $ses->getCookie("srt_cook");

	$ses->PrintTemplate("upload_srt.html",
						file_code => $f->{file_code},
						srt_langs => \@srt_langs,
						);
}

sub saveSRT
{
	my ($local_file) = @_;
	return $ses->message("Language required") unless $f->{srt_lang}=~/^\w+$/i;
	my $file = $db->SelectRow("SELECT *
								FROM Files f, Servers s
								WHERE f.file_code=?
								AND f.srv_id=s.srv_id",$f->{file_code});
	return $ses->message("No file") unless $file;
	return $ses->message("Not your file") if $f->{op} ne 'upload_srt' && $ses->getUserId!=$file->{usr_id};

	my $srt_cook='';
	if($f->{op} eq 'upload_srt')
	{
		$srt_cook = $ses->getCookie("srt_cook");
		return $ses->message("No SRT cook") unless $srt_cook=~/^\w{6}$/;
		$srt_cook="_$srt_cook";
		$srt_cook='' if $file->{usr_id}==$ses->getUserId;
	}

	my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
	my $dir = "$c->{site_path}/srt/$dx";
	mkdir($dir,0777) unless -d $dir;

	my $ext;
	if($f->{srt})
	{
		($ext) = $f->{srt}=~/\.(srt|vtt)$/i;
		return $ses->message("Not SRT/VTT file") unless $ext;
	}
	else
	{
		($ext) = $f->{url}=~/\.(srt|vtt)$/i;
		$ext||='srt';
	}
	$ext = lc $ext;

	my $data;
	if($local_file && -s $local_file)
	{
		open(SRT,$local_file);
		$data = join '', <SRT>;
		close SRT;
	}
	elsif($f->{srt})
	{
		my $fh = $ses->{cgi_query}->upload('srt');
		$data = join '', <$fh>;
	}
	elsif($f->{url})
	{
		require LWP::UserAgent;
		my $lwp = LWP::UserAgent->new;
		$data = $lwp->get($f->{url})->content;
	}

	return $ses->message("No subtitle data") unless $data;

	if( $c->{srt_max_size_kb} && length($data) > $c->{srt_max_size_kb}*1024 )
	{
		return $ses->message("Max subtitle size is $c->{srt_max_size_kb}KB");
	}

	if( $data=~/\<\?php/i )
	{
		return $ses->message("Invalid file format");
	}

	if($ext eq 'srt') # && $c->{srt_convert_to_vtt}
	{
		#utf8::decode($data);

		require Encode;
		#Encode::from_to($data,'cp1252','utf8');

		# check if SRT is UTF8, else decode from CP1252
		my $content;
		eval { $content = Encode::decode('utf-8', $data, 1); };
		Encode::from_to($data,'cp1252','utf8') unless $content;
		$data||=$content;

		$data=~s/\r//gs;
		$data=~s/^\D+\d\n//;
		$data=~s/(\d\d:\d\d:\d\d),(\d\d\d)/$1\.$2/gi;
		$data="WEBVTT\n\n$data";
		$data=~s/\n\d+\n/\n/gs;

		#utf8::encode($data);
	}

	if($srt_cook)
	{
		open (VTT,  ">$dir/$file->{file_code}_$f->{srt_lang}$srt_cook.vtt") || die"can't open vtt file:$!";
		#binmode(VTT, ":utf8");
		print VTT $data;
		close VTT;
	}
	else
	{
		# my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
		# my $res = $ses->api2($file->{srv_id},
		# 	{
		# 		op			=> 'srt_upload',
		# 		file_code	=> $file->{file_code},
		# 		dx			=> $dx,
		# 		language	=> $f->{srt_lang},
		# 		data		=> $data,
		# 	});
		# return $ses->message("ERROR:$res") unless $res eq 'OK';

		# my @arr = grep{$_ ne $f->{srt_lang}} split(/\|/, $file->{file_captions});
		# $file->{file_captions} = join '|', ( @arr, $f->{srt_lang} );
		# $db->Exec("UPDATE Files SET file_captions=? WHERE file_id=?", $file->{file_captions}, $file->{file_id});

		$db->Exec("INSERT INTO QueueVTT
						SET file_real_id=?,
						file_code=?,
						host_id=?,
						disk_id=?,
						language=?,

						data=?",
						$file->{file_real_id},
						$file->{file_code},
						$file->{host_id},
						$file->{disk_id},
						$f->{srt_lang},

						$data);
	}

	return 1;
}

sub MyFilesDMCA
{
	if($f->{new_code}=~/^\w{12}$/)
	{
		my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=? AND usr_id=?", $f->{new_code}, $ses->getUserId);
		print("Content-type:text/html\n\nNo file"),return unless $file;
		my $code = $ses->randchar(12);
		while($db->SelectOne("SELECT file_id FROM Files WHERE file_code=? OR file_real=?",$code,$code)){$code = $ses->randchar(12);}
		$db->Exec("DELETE FROM FilesDMCA WHERE file_id=?", $file->{file_id});
		$db->Exec("UPDATE Files SET file_status='OK', file_code=? WHERE file_code=?", $code, $file->{file_code});
		$file->{file_code} = $code;
		my $link = $ses->makeFileLink($file);
		print("Content-type:text/html\n\n<tt>$file->{file_code}</tt>\t<a href='$link' x2style='margin-left:10px'>link</a>"),return;
	}
	my $files = $db->SelectARef("SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(created) as ago, UNIX_TIMESTAMP(del_time)-UNIX_TIMESTAMP() as 'left'
								FROM FilesDMCA d, Files f
								WHERE d.usr_id=?
								AND d.file_id=f.file_id
								ORDER BY del_time",$ses->getUserId);
	for(@$files)
	{
		$_->{ago} = sprintf("%.0f",$_->{ago}/60);
		$_->{ago} = $_->{ago}<180 ? "$_->{ago} mins" : sprintf("%.0f hours",$_->{ago}/60);

		$_->{left} = sprintf("%.0f",$_->{left}/60);
		$_->{left} = $_->{left}<180 ? "$_->{left} mins" : sprintf("%.0f hours",$_->{left}/60);

		$_->{dl_link} = $ses->makeFileLink($_);
	}
	$ses->PrintTemplate("my_files_dmca.html",
						files => $files,
						);
}

sub resizeGD
{
	my ($im,$w2,$h2,$file) = @_;
	my ($w,$h) = $im->getBounds();
	if($w>$h){ $h2 = int $w2/$w*$h; } else { $w2 = int $h2/$h*$w; }
	my $im2 = new GD::Image($w2, $h2);
	#$im2->transparent( $im->transparent() );
	$im2->copyResampled($im, 0,0, 0,0, $w2,$h2, $w,$h );
	open OUT, ">$file" or die"cant open file for write: $!";
	print OUT $im2->jpeg(99);
	close OUT;
}

sub resizeGD2 {
    my ($im, $target_width, $target_height, $file) = @_;

    # Original dimensions
    my ($width, $height) = $im->getBounds();

    # Check if resizing is needed
    if ($width > $target_width || $height > $target_height) {
        # Calculate scale factors for width and height
        my $scale_w = $target_width / $width;
        my $scale_h = $target_height / $height;
        my $scale = $scale_w > $scale_h ? $scale_w : $scale_h;

        # Calculate dimensions after scaling
        my $new_width = int($width * $scale);
        my $new_height = int($height * $scale);

        # Create a new image with scaled dimensions
        my $scaled_im = new GD::Image($new_width, $new_height);
        $scaled_im->copyResampled($im, 0, 0, 0, 0, $new_width, $new_height, $width, $height);

        # Create final image with exact target dimensions
        my $final_im = new GD::Image($target_width, $target_height);

        # Calculate cropping coordinates
        my $crop_x = int(($new_width - $target_width) / 2);
        my $crop_y = int(($new_height - $target_height) / 2);

        # Copy and crop the scaled image to the final image
        $final_im->copy($scaled_im, 0, 0, $crop_x, $crop_y, $target_width, $target_height);

        # Save the final image
        open my $out, '>', $file or die "Can't open file for write: $!";
        print $out $final_im->jpeg(99);
        close $out;
    } else {
        # No resizing needed, save the original image
        open my $out, '>', $file or die "Can't open file for write: $!";
        print $out $im->jpeg(99);
        close $out;
    }
}

sub StreamForm
{
	my $stream={};
	if($f->{stream_id}=~/^\d+$/)
	{
		$stream = $db->SelectRow("SELECT *
									FROM Streams s
									LEFT JOIN Hosts h ON s.host_id=h.host_id
									WHERE s.stream_id=?
									",$f->{stream_id});
		unless( streamFindHost($stream->{host_id}||0) )
		{
			$stream->{host_id} = streamFindHost();
			return $ses->message("No streaming servers are available at the moment") unless $stream->{host_id};
			$db->Exec("UPDATE Streams SET host_id=? WHERE stream_id=?",$stream->{host_id},$stream->{stream_id});
			return $ses->redirect("?op=stream_form&stream_id=$stream->{stream_id}");
		}
		$stream->{rtmp_url} = $stream->{host_cgi_url};
		$stream->{rtmp_url}=~s/^https?/rtmp/i;
		$stream->{rtmp_url}=~s/\/cgi-bin//i;
		$stream->{rtmp_url}=~s/:\d+$//i;
	}
	$stream->{host_id} ||= streamFindHost();
	$stream->{m_q_allow_recording} = $c->{m_q_allow_recording};
	return $ses->message("No streaming servers are available at the moment") unless $stream->{host_id};
	$ses->PrintTemplate("stream_form.html",
								%$stream,
							  );
}

sub streamFindHost
{
	my ($host_id) = @_;
	my $filter_host="AND h.host_id=$host_id" if defined $host_id;
	return $db->SelectOne("SELECT h.host_id
							FROM Hosts h, Servers s
							WHERE h.host_live=1
							AND h.host_id=s.host_id
							AND s.srv_status IN ('ON','READONLY')
							AND srv_disk <= srv_disk_max*0.95
							$filter_host
							GROUP BY host_id
							ORDER BY host_out/host_net_speed
							LIMIT 1");
}

sub StreamSave
{
	$f->{stream_id}=~s/\D+//g;
	$f->{stream_title}  = $ses->SecureStr($f->{stream_title});
	$f->{stream_descr} = $ses->SecureStr($f->{stream_descr});
	$f->{stream_record}=0 unless $c->{m_q_allow_recording};
	if($f->{stream_id})
	{
		$db->Exec("UPDATE Streams
					SET stream_title=?,
						stream_descr=?,
						stream_record=?
					WHERE stream_id=?
						AND usr_id=?", $f->{stream_title}, $f->{stream_descr}, $f->{stream_record}||'', $f->{stream_id}, $ses->getUserId);
	}
	else
	{
		return $ses->message("You have too many streams") if $db->SelectOne("SELECT COUNT(*) FROM Streams WHERE usr_id=?",$ses->getUserId) >= 10;
		my $code = $ses->randchar(10);
		  while($db->SelectOne("SELECT stream_id FROM Streams WHERE stream_code=?",$code)){$code = $ses->randchar(10);}
		  my $key = $ses->randchar(6);
		$db->Exec("INSERT INTO Streams
					SET stream_title=?,
						stream_descr=?,
						stream_record=?,
						stream_code=?,
						stream_key=?,
						usr_id=?,
						host_id=?,
						created=NOW()",
						$f->{stream_title},
						$f->{stream_descr},
						$f->{stream_record}||'',
						$code,
						$key,
						$ses->getUserId,
						$f->{host_id},
						);
		$f->{stream_id} = $db->getLastInsertId;
	}
	return $ses->redirect_msg("?op=stream_form&stream_id=$f->{stream_id}","Changes saved");
}

sub MyStreams
{
	 return $ses->message("You're not allowed to create streams") unless $ses->checkModSpecialRights('m_q');
	 if($f->{del}=~/^\d+$/ && $f->{token} && $ses->checkToken)
	 {
		  my $stream = $db->SelectRow("SELECT * FROM Streams WHERE stream_id=? AND usr_id=?", $f->{del}, $ses->getUserId );
		  return $ses->message("Stream not found") unless $stream;
		  $db->Exec("DELETE FROM Streams WHERE stream_id=?",$stream->{stream_id});
		  $db->Exec("DELETE FROM Stream2IP WHERE stream_id=?",$stream->{stream_id});
		  return $ses->redirect_msg("?op=my_streams","Stream deleted.");
	 }
	 my $list = $db->SelectARef("SELECT s.*,
	 							(SELECT COUNT(*) FROM Stream2IP i WHERE i.stream_id=s.stream_id AND i.created>NOW()-INTERVAL 60 SECOND) as watchers
								FROM Streams s
								WHERE s.usr_id=?", $ses->getUserId );

	 $ses->PrintTemplate("my_streams.html",
								list  => $list,
								token => $ses->genToken,
							 );
}

sub uploadMoveFile
{
	my ($name,$file) = @_;
	require File::Copy;
	File::Copy::move( $ses->{cgi_query}->tmpFileName($ses->{cgi_query}->upload($name)), $file ) || return 0;
	return 1;
}

sub TicketCreate
{
	 return $ses->redirect($c->{site_url}) unless $c->{m_e};
	 if($f->{save})
	 {
		  return $ses->message("Title and Message are required fields") unless $f->{ti_title} && $f->{message};

		  $f->{category}=~s/\W+//g;

		  $db->Exec("INSERT INTO Tickets
		  			SET usr_id=?,
		  			ti_title=?,
		  			category=?,
		  			created=NOW(),
		  			updated=NOW(),
		  			open=1,
		  			unread_adm=1
		  			", $ses->getUserId,
		  			$f->{ti_title},
		  			$f->{category} );
		  my $ti_id = $db->getLastInsertId;

		  $db->Exec("INSERT INTO TicketMessages
		  			SET ti_id=?,
		  			usr_id=?,
		  			msg_ip=INET_ATON(?),
		  			message=?,
		  			created=NOW()", $ti_id, $ses->getUserId, $ses->getIP, $f->{message} );

		  return $ses->redirect("?op=ticket_view&ti_id=$ti_id");
	 }
	 my @categories = map{{category => $_}} split /\s*,\s*/, $c->{ticket_categories};
	 $ses->PrintTemplate("ticket_create.html",
	 					categories => \@categories,
	 					);
}

sub TicketReply
{
	return $ses->redirect($c->{site_url}) unless $c->{m_e};
	my $t = $db->SelectRow("SELECT * FROM Tickets WHERE ti_id=? AND usr_id=?", $f->{ti_id}, $ses->getUserId );
	return $ses->message("No such ticket") unless $t;

	return $ses->redirect("?op=ticket_view&ti_id=$t->{ti_id}") unless length($f->{message})>1;

	$db->Exec("INSERT INTO TicketMessages
				SET ti_id=?,
		  		usr_id=?,
		  		msg_ip=INET_ATON(?),
		  		message=?,
		  		created=NOW()", $t->{ti_id}, $ses->getUserId, $ses->getIP, $f->{message} );

	$db->Exec("UPDATE Tickets SET updated=NOW(), open=1, unread_adm=unread_adm+1, replied=0 WHERE ti_id=?", $t->{ti_id} );

	if($c->{ticket_email_admin})
	{
		# Send email to Admin
		my $adm_usr_id = $db->SelectOne("SELECT usr_id FROM TicketMessages WHERE ti_id=? AND usr_id<>? ORDER BY msg_id DESC LIMIT 1", $t->{ti_id}, $ses->getUserId );
		$adm_usr_id  ||= $db->SelectOne("SELECT usr_id FROM Users WHERE usr_adm=1");
		my $adm_email = $db->SelectOneCached("SELECT usr_email FROM Users WHERE usr_id=?",$adm_usr_id);
		my $tt = $ses->CreateTemplate("ticket_reply_email.html");
		$tt->param( 'ti_id'=> $t->{ti_id},
					message => $f->{message} );
		$ses->SendMailQueue($adm_email, $c->{email_from}, "$c->{site_name}: Ticket $t->{ti_id} replied", $tt->output);
	}

	return $ses->redirect("?op=ticket_view&ti_id=$t->{ti_id}");
}

sub TicketList
{
	 return $ses->redirect($c->{site_url}) unless $c->{m_e};
	 my $list = $db->SelectARef("SELECT *
	 							FROM Tickets
	 							WHERE usr_id=?

	 							ORDER BY updated DESC
	 							LIMIT 30", $ses->getUserId );

	 for(@$list)
	{
	  $_->{updated}=~s/:\d\d$//;
	}

	my $user = $ses->getUser;

	if($c->{m_e})
	{
		$user->{tickets_unread} = $db->SelectOne("SELECT COUNT(*) FROM Tickets WHERE usr_id=? AND unread>0",$ses->getUserId);
	}

	 $ses->PrintTemplate("ticket_list.html",
	 					%{$user},
	 					list => $list
	 					);
}

sub TicketView
{
	return $ses->redirect($c->{site_url}) unless $c->{m_e};
	my $t = $db->SelectRow("SELECT * FROM Tickets WHERE ti_id=? AND usr_id=?", $f->{ti_id}, $ses->getUserId );
	return $ses->message("No such ticket") unless $t;

	if($f->{close})
	{
		$db->Exec("UPDATE Tickets SET updated=NOW(), open=0 WHERE ti_id=?", $t->{ti_id} );
		return $ses->redirect("?op=ticket_list");
	}

	#$t->{closed} = $db->SelectRow("SELECT * FROM Tickets WHERE ti_id=? AND usr_id=? AND open=0", $f->{ti_id}, $ses->getUserId );

    ### custom - added "u.usr_avatar"
	my $messages = $db->SelectARef("SELECT *, u.usr_login, u.usr_avatar, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec2
									FROM TicketMessages AS m, Users AS u
									WHERE m.ti_id=?
									AND m.usr_id=u.usr_id
									ORDER BY created", $f->{ti_id} );


	for(@$messages)
	{
	  $_->{message}=~s/\n/<br>/g;
	  $_->{created}=~s/:\d\d$//;
	  $_->{mine} = $_->{usr_id}==$ses->getUserId ? 1 : 0;
	  $_->{ispremium} = $_->{exp_sec2}>0;

	  $_->{usr_channel_name}||=$_->{usr_login};

		# Extracting the first two letters of the usr_login
		if (defined $_->{usr_login} && length $_->{usr_login} >= 1) {
			$_->{usr_login_short} = substr($_->{usr_login}, 0, 1);
		} else {
			# Handle cases where usr_login is undefined or shorter than 2 characters
			$_->{usr_login_short} = $_->{usr_login} // '';
		}

	}

	$db->Exec("UPDATE Tickets SET unread=0 WHERE ti_id=?", $t->{ti_id} ) if $t->{unread};

	#### Custom ####
	my $user = $ses->getUser;

	if($c->{m_e})
	{
		$user->{tickets_unread} = $db->SelectOne("SELECT COUNT(*) FROM Tickets WHERE usr_id=? AND unread>0",$ses->getUserId);
	}
	#### Custom ####


	 $ses->PrintTemplate("ticket_view.html",
	 					%{$user},
	 					%$t,
	 					messages => $messages,
	 					);
}

###

sub AdminTicketList
{
	 my $is_moderator = $c->{ticket_moderator_ids} && $ses->getUserId=~/^$c->{ticket_moderator_ids}$/ ? 1 : 0;
	 return $ses->message("Access denied") unless $ses->getUser->{usr_adm} || $is_moderator;

	 my $filter_open = $f->{show_closed} ? "" : "AND open=1";
	 my $filter_replied = $f->{show_replied}||$f->{show_closed} ? "" : "AND replied=0";
	 my $filter_days = $f->{days}=~/^\d+$/ ? " AND updated>NOW()-INTERVAL $f->{days} DAY" : "";
	 if($f->{usr_login})
	 {
		 $f->{usr_id} = $db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?", $f->{usr_login} );
		 $f->{usr_login}='';
	 }
	 my $filter_usr_id = $f->{usr_id}=~/^\d+$/ ? " AND t.usr_id=$f->{usr_id}" : "";
	 my $filter_ids;
	 if($f->{key})
	 {
		 my @ids;
		 my $ids1 = $db->SelectARef(qq|SELECT ti_id FROM Tickets WHERE ti_title LIKE "%$f->{key}%" $filter_days $filter_usr_id|);
		 push @ids, map{ $_->{ti_id} } @$ids1;
		 my $filter_days2 = $f->{days}=~/^\d+$/ ? " AND created>NOW()-INTERVAL $f->{days} DAY" : "";
		 my $ids2 = $db->SelectARef(qq|SELECT DISTINCT ti_id FROM TicketMessages t WHERE message LIKE "%$f->{key}%" $filter_days2 $filter_usr_id|);
		 push @ids, map{ $_->{ti_id} } @$ids2;
		 $filter_ids = "AND ti_id IN (".join(',',@ids).")" if @ids;
	 }
	 my $filter_category="AND category='$f->{category}'" if $f->{category}=~/^\w+$/;
	 my $filter_moderator="";
	 if($is_moderator && $c->{ticket_moderator_categories})
	 {
	 	my $cats = join ',', map{"'$_'"} split /\s*\,\s*/, $c->{ticket_moderator_categories};
	 	$filter_moderator="AND category IN ($cats)" if $cats;
	 }

	 my $list = $db->SelectARef("SELECT t.*, u.usr_login
	 							FROM Tickets t, Users u
	 							WHERE t.usr_id=u.usr_id
	 							$filter_open
	 							$filter_replied
	 							$filter_days
	 							$filter_usr_id
	 							$filter_ids
	 							$filter_category
	 							$filter_moderator
	 							ORDER BY updated DESC
	 							".$ses->makePagingSQLSuffix($f->{page}) );

	my $total = $db->SelectOne("SELECT COUNT(*) FROM Tickets t
								WHERE 1
								$filter_open
								$filter_replied
								$filter_days
								$filter_usr_id
								$filter_ids
								$filter_category
								$filter_moderator
								");

	for(@$list)
	{
	  $_->{updated}=~s/:\d\d$//;
	}

	my @categories = map{{category => $_, selected=>$_ eq $f->{category}?1:0}} split /\s*,\s*/, $c->{ticket_categories};

	 $ses->PrintTemplate("admin_ticket_list.html",
	 					list => $list,
	 					paging => $ses->makePagingLinks($f,$total),
	 					show_closed	=> $f->{show_closed},
	 					show_replied=> $f->{show_replied},
	 					days		=> $f->{days},
	 					usr_id		=> $f->{usr_id},
	 					key			=> $f->{key},
	 					categories	=> \@categories,
						maincss      => 1,
	 					);
}

sub AdminTicketView
{
	my $is_moderator = $c->{ticket_moderator_ids} && $ses->getUserId=~/^$c->{ticket_moderator_ids}$/ ? 1 : 0;
	 return $ses->message("Access denied") unless $ses->getUser->{usr_adm} || $is_moderator;

	 my $filter_moderator="";
	 if($is_moderator && $c->{ticket_moderator_categories})
	 {
	 	my $cats = join ',', map{"'$_'"} split /\s*\,\s*/, $c->{ticket_moderator_categories};
	 	$filter_moderator="AND category IN ($cats)" if $cats;
	 }

	my $t = $db->SelectRow("SELECT t.*, u.usr_login
							FROM Tickets t, Users u
							WHERE t.ti_id=?
							AND t.usr_id=u.usr_id
							$filter_moderator", $f->{ti_id} );
	return $ses->message("No such ticket") unless $t;

	if($f->{close})
	{
		$db->Exec("UPDATE Tickets SET updated=NOW(), open=0 WHERE ti_id=?", $t->{ti_id} );
		return $ses->redirect("?op=admin_ticket_list");
	}

	my $messages = $db->SelectARef("SELECT m.*, u.usr_login, INET_NTOA(m.msg_ip) as ip
									FROM TicketMessages m, Users u
									WHERE m.ti_id=?
									AND m.usr_id=u.usr_id
									ORDER BY created", $f->{ti_id} );


	for(@$messages)
	{
	  $_->{message}=~s/\n/<br>/g;
	  $_->{created}=~s/:\d\d$//;
	  $_->{mine} = $_->{usr_id}==$ses->getUserId ? 1 : 0;
	}

	$db->Exec("UPDATE Tickets SET unread_adm=0 WHERE ti_id=?", $t->{ti_id} ) if $t->{unread_adm};

	 $ses->PrintTemplate("admin_ticket_view.html",
	 					%$t,
	 					messages => $messages,
						maincss      => 1,
	 					);
}

sub AdminTicketReply
{
	my $is_moderator = $c->{ticket_moderator_ids} && $ses->getUserId=~/^$c->{ticket_moderator_ids}$/ ? 1 : 0;
	 return $ses->message("Access denied") unless $ses->getUser->{usr_adm} || $is_moderator;

	 my $filter_moderator="";
	 if($is_moderator && $c->{ticket_moderator_categories})
	 {
	 	my $cats = join ',', map{"'$_'"} split /\s*\,\s*/, $c->{ticket_moderator_categories};
	 	$filter_moderator="AND category IN ($cats)" if $cats;
	 }

	my $t = $db->SelectRow("SELECT * FROM Tickets t, Users u
							WHERE t.ti_id=?
							AND t.usr_id=u.usr_id
							$filter_moderator", $f->{ti_id} );
	return $ses->message("No such ticket") unless $t;

	$db->Exec("INSERT INTO TicketMessages
				SET ti_id=?,
		  		usr_id=?,
		  		msg_ip=INET_ATON(?),
		  		message=?,
		  		created=NOW()", $t->{ti_id}, $ses->getUserId, $ses->getIP, $f->{message} );

	$db->Exec("UPDATE Tickets SET updated=NOW(), open=1, unread=unread+1, unread_adm=0, replied=1 WHERE ti_id=?", $t->{ti_id} );

	if($c->{ticket_email_user})
	{
		# Send email to User
		my $tt = $ses->CreateTemplate("admin_ticket_reply_email.html");
		$tt->param( 'ti_id'=> $t->{ti_id},
					message => $f->{message} );
		$ses->SendMailQueue($t->{usr_email}, $c->{email_from}, "$c->{site_name}: Ticket $t->{ti_id} replied", $tt->output);
	}

	return $ses->redirect("?op=admin_ticket_view&ti_id=$t->{ti_id}");
}

sub APIReference
{
	return $ses->message("API disabled") unless $c->{m_6};
	my $user = $ses->getUser || {};
	$user->{$_} = $c->{$_} for qw(m_6 m_6_clone m_6_direct m_6_delete custom_snapshot_upload);
	$user->{usr_id}||=45;
	$user->{usr_api_key} ||= $ses->randchar(15);
	$user->{usr_api_key} = "$user->{usr_id}$user->{usr_api_key}";
	$user->{api_url}="$c->{site_url}/api";
	$ses->PrintTemplate("api_reference.html",
	 					%$user,
	 					);
}

sub MyAds
{
	#$ses->loadUserData();
	return $ses->message("You're not allowed to manage watermark") unless $ses->checkModSpecialRights('m_9');

	my $usr_id = $ses->getUserId;
	$usr_id = $f->{usr_id} if $f->{usr_id} && $ses->getUser->{usr_adm};

	if($f->{delete_id}=~/^\d+$/)
	{
		$db->Exec("DELETE FROM Ads WHERE ad_id=? AND usr_id=?", $f->{delete_id}, $usr_id );
		return $ses->redirect("?op=my_ads");
	}

	my $ads = $db->SelectARef("SELECT * FROM Ads WHERE usr_id=? AND ad_adult=0",$usr_id);
	my $sum;
	$sum+=$_->{ad_weight} for @$ads;
	$sum||=1;
	for(@$ads)
	{
		$_->{percent} = sprintf("%.0f", 100 * $_->{ad_weight} / $sum );
	}

	my $ads2 = $db->SelectARef("SELECT * FROM Ads WHERE usr_id=? AND ad_adult=1",$usr_id);
	my $sum2;
	$sum2+=$_->{ad_weight} for @$ads2;
	$sum2||=1;
	for(@$ads2)
	{
		$_->{percent} = sprintf("%.0f", 100 * $_->{ad_weight} / $sum2 );
	}

	$ses->PrintTemplate("my_ads.html",
	 					usr_id	=> $usr_id,
	 					ads		=> $ads,
	 					ads_adult	=> $ads2,
	 					);
}

sub MyAdsForm
{
	if($f->{save})
	{
		my $usr_id = $ses->getUserId;
		$f->{ad_adult}=~s/\D+//g;
		$f->{ad_weight}=~s/\D+//g;
		$f->{ad_disabled}=~s/\D+//g;
		if($f->{ad_id})
		{
			$db->Exec("UPDATE Ads SET
						ad_code=?,
						ad_title=?,
						ad_adult=?,
						ad_weight=?,
						ad_disabled=?
						WHERE usr_id=? AND ad_id=?
					",
						$ses->{cgi_query}->param('ad_code'),
						$f->{ad_title},
						$f->{ad_adult}||0,
						$f->{ad_weight}||0,
						$f->{ad_disabled}||0,
						$usr_id,
						$f->{ad_id},
					);
		}
		else
		{
			$db->Exec("INSERT INTO Ads SET
						usr_id=?,
						ad_code=?,
						ad_title=?,
						ad_adult=?,
						ad_weight=?,
						ad_disabled=?
					",  $usr_id,
						$ses->{cgi_query}->param('ad_code'),
						$f->{ad_title},
						$f->{ad_adult}||0,
						$f->{ad_weight}||0,
						$f->{ad_disabled}||0,
					);
		}
		return $ses->redirect("?op=my_ads");
	}

	my $ad;
	if($f->{ad_id})
	{
		$ad = $db->SelectRow("SELECT * FROM Ads WHERE ad_id=?",$f->{ad_id});
	}
	$ses->PrintTemplate("my_ads_form.html",
	 					%$ad,
	 					);
}

sub Msg
{
	return $ses->PrintTemplate("message.html");
}

1;
