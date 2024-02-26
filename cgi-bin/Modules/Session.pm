package Session;

use strict;
use HTML::Template::Pro;
use CGI::Carp qw(fatalsToBrowser set_message);
use CGI;
use XFileConfig;
use DataBase;

sub new {
  my ($class,$query,$db) = @_;
	  $class = ref( $class ) || $class;
  my $self = {} ;
  bless $self, $class;
  
  $self->{query} = $query;
  $self->{user} = undef;
  $self->{cookies} = undef;
  $self->{form}	= undef;
  $self->{db} = $db;
  $self->{auth_cook}='xfsts';
  
  return $self;
}

sub DESTROY{
}

sub db
{
  my $self = shift;
  return $self->{db} if defined($self->{db});
  $self->{db} = DataBase->new();
  return $self->{db};
}

sub initCGI
{
  my ($self,$query)= @_;

  if($query && $query->{'psgi.input'})
  {
  	return $self->initPSGI($query);
  }

  my $in = $query ? $query : new CGI();
  $self->{form}={};
  $self->{cookies}={};
  $self->{cgi_query} = $in;

  for( $in->param() )
  {
	my @val = defined( &CGI::multi_param ) ? $in->multi_param($_) : $in->param($_);
	unless($self->{no_escape}){ for(@val){s/</&lt;/gs;s/>/&gt;/gs;s/"/&quot;/gs;s/\(/&#40;/gs;s/\)/&#41;/gs;s/\'/&#39;/gs;} };
	$self->{form}->{$_} = @val>1 ? \@val : $val[0];
  }
  $self->{cookies}->{$_}=$self->SecureStr($in->cookie($_)) for $in->cookie();
  $self->{domain}=$c->{domain} || $ENV{HTTP_HOST};
  $self->{domain}=~s/^(www|main|srt)\.//;
  $self->{domain}=~s/:.*$//;
  $c->{cdn_url}||=$c->{site_url};

  $ENV{HTTP_REFERER} = $self->SecureStr($ENV{HTTP_REFERER});

  if($self->{cookies}->{msg})
  {
	$self->{form}->{msg}=$self->{cookies}->{msg};
	$self->setCookie('msg','');
  }
  my $ea=0;
  $ea=1 if $self->{form}->{cj}&&$self->{form}->{cl};
  $self->{form}->{msg}=$self->SecureStr($self->{form}->{msg}) if $self->{form}->{msg};
  $ea=1 if $ENV{REQUEST_URI}=~/ipn\.cgi/i;
  require SecTetx;
  SecTetx::params($self,$c,$ea);
  
  my $cpath = $c->{cgi_path}||'.';
  unless($self->{cookies}->{lang})
  {
	my $blang=$ENV{HTTP_ACCEPT_LANGUAGE};
	$blang=~s/,.+$//;
	for(keys %{$c->{language_codes}})
	{
		if($blang=~/^$_$/i && !$c->{no_lng_sql})
		{
			my $language = $self->db->SelectARefCached(120,"SELECT * FROM Languages WHERE lang_name=?",$c->{language_codes}->{$_})->[0];
			$self->setCookie('lang',$language->{lang_id}) if $language;
		}
	}
  }

	$self->{language} = $self->{cookies}->{lang} if $self->{cookies}->{lang}=~/^\d+$/;
	$self->{language}||=$c->{default_language}||1;

	if(!$c->{no_lng_sql} && $c->{db_login})
	{
		my $list = $self->db->SelectARefCached(120,"SELECT * FROM Translations WHERE lang_id=?",$self->{language});
		$self->{lang}->{$_->{trans_name}} = $_->{trans_value} for @$list;
	}
}

sub initPSGI
{
	my ($self,$env)= @_;

	$self->{env} = $env;

	my $req = Plack::Request->new($env);
	$self->{psgi_req} = $req;

	for( $req->param() )
	{
		my @val = $req->param($_);
		unless($self->{no_escape}){ for(@val){s/</&lt;/gs;s/>/&gt;/gs;s/"/&quot;/gs;s/\(/&#40;/gs;s/\)/&#41;/gs;s/\'/&#39;/gs;} };
		$self->{form}->{$_} = @val>1 ? \@val : $val[0];
	}
	$self->{cookies}->{$_} = $self->SecureStr($req->cookies->{$_}) for keys %{$req->cookies};
	$self->{domain}=$c->{domain} || $self->{env}->{HTTP_HOST};
	$self->{domain}=~s/^(www|main|srt)\.//;
	$self->{domain}=~s/:.*$//;
	$c->{cdn_url}||=$c->{site_url};

	if($self->{cookies}->{msg})
	{
		$self->{form}->{msg}=$self->{cookies}->{msg};
		$self->setCookie('msg','');
	}
	my $ea=0;
	$ea=1 if $self->{form}->{cj}&&$self->{form}->{cl};
	$self->{form}->{msg}=$self->SecureStr($self->{form}->{msg}) if $self->{form}->{msg};
	$ea=1 if $self->{env}->{REQUEST_URI}=~/ipn\.cgi/i;
	require SecTetx;
	SecTetx::params($self,$c,$ea);
	
	my $cpath = $c->{cgi_path}||'.';
	unless($self->{cookies}->{lang})
	{
		my $blang=$ENV{HTTP_ACCEPT_LANGUAGE};
		$blang=~s/,.+$//;
		for(keys %{$c->{language_codes}})
		{
			if($blang=~/^$_$/i && !$c->{no_lng_sql})
			{
				my $language = $self->db->SelectARefCached(120,"SELECT * FROM Languages WHERE lang_name=?",$c->{language_codes}->{$_})->[0];
				$self->setCookie('lang',$language->{lang_id}) if $language;
			}
		}
	}

	$self->{language} = $self->{cookies}->{lang} if $self->{cookies}->{lang}=~/^\d+$/;
	$self->{language}||=$c->{default_language}||1;

	if(!$c->{no_lng_sql} && $c->{db_login})
	{
		my $list = $self->db->SelectARefCached(120,"SELECT * FROM Translations WHERE lang_id=?",$self->{language});
		$self->{lang}->{$_->{trans_name}} = $_->{trans_value} for @$list;
	}
}

sub f
{
	my ($self)=@_;
	$self->initCGI($self->{query}) unless $self->{form};
	return $self->{form};
}

sub iPlg
{
	my ($self,$x)=@_;
	require SecTetx;
	return SecTetx::plg($self,$x);
}

sub Logout
{
	my $self = shift;
	my $sess_id = $self->getCookie( $self->{auth_cook} );
	$self->db->PurgeCache( "ses$sess_id" );
	$self->db->Exec("DELETE FROM Sessions WHERE usr_id=?",$self->getUserId);
	$self->setCookie($self->{auth_cook},"");
	delete $self->{user};
	$self->redirect( $c->{site_url} );
}

sub getUser
{
	my $self = shift;
	return $self->{user};
}

sub getUserId
{
	my $self = shift;
	return 0 unless $self->{user};
	return $self->{user}->{usr_id};
}

sub getCookie
{
	my ($self,$name) = @_;
	return $self->{cookies}->{ $name };
}

sub setCookie
{
	my ($self,$name,$value,$expire) = @_;
	utf8::decode($value);
	$self->{cookies}->{ $name } = $value;
	$self->{cookies_send}->{ $name } = $value;
	$self->{cookies_exp}->{ $name } = $expire;
}

sub CreateTemplate
{
	my ($self,$filename)=@_;
	my $design = $self->getCookie('design')||'';
	$design=~s/\D//g;
	$filename=~s/[^\w\_\-\.\/]+//g;
	$c->{cgi_path}||='.';
	die("Template not found: $filename") unless -f "$c->{cgi_path}/Templates$design/$filename";
	my $t=HTML::Template->new( filename => "$c->{cgi_path}/Templates$design/$filename", die_on_bad_params => 0, global_vars => 1, loop_context_vars => 1, utf8 => 1,);

	my $enable_search = $c->{enable_search}==1 || ($c->{enable_search}==2 && $self->getUserId);
	$enable_search=0 if $c->{highload_mode};
	my $hh;
	if( $c->{m_5} && !$self->{adm} )
	{
		$hh->{devtools_mode} = $c->{m_5_devtools_mode};
		$hh->{devtools_mode} = 0 if $c->{m_5_devtools_no_admin} && $self->getUser && $self->getUser->{usr_adm};
		$hh->{"devtools_mode_$c->{m_5_devtools_mode}"} = 1;
		$hh->{adb_mode} = $c->{m_5_adb_mode};
		$hh->{adb_mode} = 0 if $c->{m_5_adb_no_prem} && $self->{user} && $self->{user}->{premium};
		$hh->{"adb_mode_$c->{m_5_adb_mode}"} = 1;
		$hh->{adb_delay} = $c->{m_5_adb_delay} ? $c->{m_5_adb_delay}*1000 : 50;
		$hh->{$_} = $c->{$_} for qw(m_5_adb_script m_5_disable_right_click m_5_disable_shortcuts);
	}
	$hh->{rnd} = int(rand 1000000);
	$t->param( 'site_name'		=> $c->{site_name},
				'site_url'		=> $c->{site_url},
				'static_url'	=> $c->{cdn_url},
				'cdn_url'		=> $c->{cdn_url},
				'site_cgi'		=> $c->{site_cgi},
				'msg'			=> $self->f->{msg},
				'enabled_reg'	=> $c->{enabled_reg},
				'enabled_prem'	=> $c->{enabled_prem},
				'ads'			=> $c->{ads},
				'enable_search'	=> $enable_search,
				'header_extra'	=> $self->{header_extra},
				'm_t'			=> $c->{m_t},
				'm_f'			=> $c->{m_f},
				'm_e'			=> $c->{m_e},
				%$hh,
				'news_enabled'	=> $c->{news_enabled},
				"op_".$self->f->{op} => 1,
				'cdn_version_num'	=> $c->{cdn_version_num},
				%{$self->{lang}},
				);
	print"X\n" if $self->{form}->{id}&&$c->{site_url}!~/\/\/(www\.|)$self->{dc}/i;
	if($self->getUser)
	{

    # Extract the first two letters of usr_login
    my $usr_login_short = '';
    if (defined $self->{user}->{usr_login} && length $self->{user}->{usr_login} >= 1) {
        $usr_login_short = substr($self->{user}->{usr_login}, 0, 1);
    }

		$c->{upload_enabled} = $self->getUser->{usr_uploads_on} if $c->{uploads_selected_only};
		my $token = $self->genToken;
		$t->param( 'admin_panel' => 1 ) if $self->{adm} || $filename=~/^admin_/;
		$t->param( 'my_login'			=> $self->{user}->{usr_login},
          'usr_login_short'    => $usr_login_short, # Add this line
					'admin'				=> $self->{user}->{usr_adm},
					'usr_moderator'		=> $self->{user}->{usr_mod},
					'premium'			=> $self->{user}->{premium},
          'avatar'			=> $self->{user}->{usr_avatar},
          'user_id'			=> $self->{user}->{usr_id},
					'upload_enabled'	=> $c->{upload_enabled},
					'reseller'			=> $c->{m_k} && (!$c->{m_k_manual} || $self->getUser->{usr_reseller}),
					'token'				=> $token,
					'token_str'			=> "\&amp;token=$token",
					'legal_tool'		=> $self->{user}->{usr_notes}=~/LEGAL=\d+/i ? 1 : 0,
					'tickets_moderator'	=> $c->{m_e} && $c->{ticket_moderator_ids} && $self->{user}->{usr_id}=~/^$c->{ticket_moderator_ids}$/,
					);
	}

	return $t;
}


sub PrintTemplate
{
	my ($self,$template,%par) = @_;

	delete $par{quality_letters};
	delete $par{quality_labels};
	delete $par{quality_labels_full};
	delete $par{db_slaves};

	my $t2=$self->CreateTemplate( $template );
	$t2->param(%par);

	my @Cookies;
	foreach my $name (keys %{ $self->{cookies_send} })
	{
		my $c =  $self->{cgi_query}->cookie(-name    => $name,
											-value   => $self->{cookies_send}->{$name},
											-domain  => ".$self->{domain}",
											-expires => $self->{cookies_exp}->{$name},
											-httponly => 1
											);
		push(@Cookies, $c);
	}
	my %hhh;
	$hhh{'-X_FRAME_OPTIONS'} = 'DENY' unless $c->{xframe_allow_frames} || $self->{xframe};
	print $self->{cgi_query}->header(	-cookie  => [@Cookies] ,
										-type    => 'text/html',
										-expires => $self->{expires}||'-1d',
										-charset => $c->{charset},
										%hhh,
										);
	if($self->{form}->{no_hdr})
	{
		print $t2->output;
	}
	else
	{
		my $t=$self->CreateTemplate( $self->{main_template} || "main.html" );
		$t->param(%par);
		$t->param( 'tmpl' => $t2->output );
		$self->{page_title} = $self->{lang}->{"lng_title_$self->{form}->{op}$self->{form}->{tmpl}"} || $self->{page_title};
		$t->param( 'page_title' => $self->{page_title} ) if $self->{page_title};
		$t->param( 'meta_descr' => $self->{meta_descr} ) if $self->{meta_descr};
		$t->param( 'meta_keywords' => $self->{meta_keywords} ) if $self->{meta_keywords};
		$t->param( 'sql_exec' => $self->{db}->{'exec'}, 'sql_select' => $self->{db}->{'select'}, 'memcached_hit' => $self->{db}->{'memcached_hit'} ) if $self->{db};

		my $ll = $self->db->SelectARefCached(60,"SELECT * FROM Languages WHERE lang_active=1 ORDER BY lang_order") if $self->{db};
		my @ll2;
		for(@$ll)
		{
			if($_->{lang_id}==$self->{language})
			{
				$t->param('language2' => $_->{lang_name},'language_lc' => lc $_->{lang_name});
			}
			else
			{
				$_->{lang_name_lc} = lc $_->{lang_name};
				push @ll2, $_;
			}
		}
		$t->param(languages => \@ll2);

		print $t->output;
	}
	exit unless $self->{fast_cgi};
}

sub PrintTemplatePSGI
{
  my ($self,$template,%par) = @_;

  my $t2=$self->CreateTemplate( $template );
  $t2->param(%par);

  my $res = $self->{psgi_req}->new_response(200);
  
  foreach my $name (keys %{ $self->{cookies_send} })
  {
    $res->cookies->{$name} = {
                             	value   => $self->{cookies_send}->{$name},
                                domain  => ".$self->{domain}",
                                expires => $self->normalizeDate($self->{cookies_exp}->{$name}),
                            };
  }
  $res->header("Content-Type" => "text/html; charset=utf-8");

  if($self->{form}->{no_hdr})
  {
     $res->body($t2->output);
  }
  else
  {
     my $t=$self->CreateTemplate( $self->{main_template} || "main.html" );
     $t->param(%par);
     $t->param( 'tmpl' => $t2->output );
     $self->{page_title} = $self->{lang}->{"lng_title_$self->{form}->{op}$self->{form}->{tmpl}"} || $self->{page_title};
     $t->param( 'page_title' => $self->{page_title} ) if $self->{page_title};
     $t->param( 'meta_descr' => $self->{meta_descr} ) if $self->{meta_descr};
     $t->param( 'meta_keywords' => $self->{meta_keywords} ) if $self->{meta_keywords};
     $t->param( 'sql_exec' => $self->{db}->{'exec'}, 'sql_select' => $self->{db}->{'select'}, 'memcached_hit' => $self->{db}->{'memcached_hit'} ) if $self->{db};

     my $ll = $self->db->SelectARefCached(60,"SELECT * FROM Languages WHERE lang_active=1 ORDER BY lang_order") if $self->{db};
     my @ll2;
     for(@$ll)
     {
        if($_->{lang_id}==$self->{language})
        {
            $t->param('language2' => $_->{lang_name},'language_lc' => lc $_->{lang_name});
        }
        else
        {
            $_->{lang_name_lc} = lc $_->{lang_name};
            push @ll2, $_;
        }
     }
     $t->param(languages => \@ll2);
     
     $res->body($t->output);
  }

  return $res->finalize();
}

sub out
{
    my ($self,$out) = @_;
    my @Cookies;
    foreach my $name (keys %{ $self->{cookies_send} })
    {
      my $c =  $self->{cgi_query}->cookie( -name    => $name,
                                           -value   => $self->{cookies_send}->{$name},
                                           -domain  => ".$self->{domain}",
                                           -expires => $self->{cookies_exp}->{$name},
                                           -httponly => 1
                                         );
      push(@Cookies, $c);
    }
    my %hhh;
    $hhh{'-X_FRAME_OPTIONS'}='DENY' unless $c->{xframe_allow_frames} || $self->{xframe};
    print $self->{cgi_query}->header( -cookie  => [@Cookies] ,
                                      -type    => 'text/html',
                                      -expires => $self->{expires}||'-1d',
                                      -charset => $c->{charset},
                                      %hhh,
                                    );
    print $out;
    exit unless $self->{fast_cgi};
}

sub message
{
    my ($self,$err) = @_;
    return unless $err;
    my $tmpl = $self->{form}->{no_hdr} ? "message_embed.html" : "message.html";
    $self->PrintTemplate($tmpl, 'err'=>$err );
    return 0;
}

sub redirect
{
   my ($self,$url,$exp) = @_;

   if($self->{adm} && $self->isAdmin && $url!~/token=/i && $url=~/\?/)
   {
     my ($ah)=$1 if $url=~s/(\#\w+)$//;
     $url.="&token=".$self->genToken.$ah;
   }

   my @Cookies;
   foreach my $k (keys %{ $self->{cookies_send} })
   {
     push @Cookies, $self->{cgi_query}->cookie( -name    => $k, 
                                                -value   => $self->{cookies_send}->{$k}, 
                                                -domain  => ".$self->{domain}",
                                                -expires => $self->{cookies_exp}->{$k}||$exp,
                                              );
   }

   print $self->{cgi_query}->redirect( -uri    => $url, 
                                       -cookie => [@Cookies],
                                     );
   exit unless $self->{fast_cgi};
}

sub redirect_msg
{
   my ($self,$url,$msg) = @_;
   utf8::encode($msg);
   $self->setCookie('msg',$msg);
   $self->redirect($url);
}

sub isAdmin
{
  my ($self) = @_;
  return 1 if $self->{user} && $self->{user}->{usr_adm};
  return 0;
}

sub getBrowser
{
	my ($self) = @_;
	my ($browser) = $ENV{HTTP_USER_AGENT}=~/((?:Chrome|Firefox)\/[\d\.]+)/i;
	return $browser || $ENV{HTTP_USER_AGENT};
}

sub getIP
{
 my ($self) = @_;
 my $ip = '';
 $ip = $ENV{HTTP_CF_CONNECTING_IP} if $c->{use_cloudflare_ip_header};
 $ip ||= $ENV{HTTP_X_FORWARDED_FOR} || $ENV{HTTP_X_REAL_IP} || $ENV{REMOTE_ADDR};
 $ip = $ENV{HTTP_X_FORWARDED_FOR} if $ENV{HTTP_X_FORWARDED_FOR} && $ENV{HTTP_SAVE_DATA};
 $ip=(split(/[\,\s]+/,$ip))[0] if $ip=~/\,/;
 $ip ||= $ENV{REMOTE_ADDR};
 $self->{ipv6}=$ip if $ip=~/:/;
 $ip = $self->convertIP6toIP4($ip) if $ip=~/:/;
 $ip=~s/[^\d\.]+//g;
 $ip||='0.0.0.0';
 return $ip;
}

sub convertIP6toIP4
{
	my ($self,$ip6) = @_;
	return inet_ntoa( ipv6to4( ipv6_aton($ip6) ) );
}

sub ipv6to4 {
  my $naddr = shift;
  @_ = unpack('L3H8',$naddr);
  return pack('H8',@{_}[3..10]);
}
sub ipv6_aton {
  my($ipv6) = @_;
  return undef unless $ipv6;
  local($1,$2,$3,$4,$5);
  if ($ipv6 =~ /^(.*:)(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/) {
    return undef if $2 > 255 || $3 > 255 || $4 > 255 || $5 > 255;
    $ipv6 = sprintf("%s%X%02X:%X%02X",$1,$2,$3,$4,$5);
  }
  my $c;
  return undef if
  $ipv6 =~ /[^:0-9a-fA-F]/ ||
  (($c = $ipv6) =~ s/::/x/ && $c =~ /(?:x|:):/) ||
  $ipv6 =~ /[0-9a-fA-F]{5,}/;
  $c = $ipv6 =~ tr/:/:/;
  return undef if $c < 7 && $ipv6 !~ /::/;
  if ($c > 7) {
    return undef unless
  $ipv6 =~ s/^::/:/ ||
  $ipv6 =~ s/::$/:/;
    return undef if --$c > 7;
  }
  while ($c++ < 7) {
    $ipv6 =~ s/::/:::/;
  }
  $ipv6 .= 0 if $ipv6 =~ /:$/;
  my @hex = split(/:/,$ipv6);
  foreach(0..$#hex) {
    $hex[$_] = hex($hex[$_] || 0);
  }
  pack("n8",@hex);
}
sub inet_ntoa {
  my @hex = (unpack("n2",$_[0]));
  $hex[3] = $hex[1] & 0xff;
  $hex[2] = $hex[1] >> 8;
  $hex[1] = $hex[0] & 0xff;
  $hex[0] >>= 8;
  return sprintf("%d.%d.%d.%d",@hex);
}

sub getMyCountry
{
	my ($self) = @_;
	return $self->{country} if $self->{country};

	$self->{country} = $c->{use_cloudflare_ip_header} && $ENV{HTTP_CF_IPCOUNTRY} ? $ENV{HTTP_CF_IPCOUNTRY} : $self->getCountryCode($self->getIP);

    return uc($self->{country}) || 'LV';
}

sub getCountryCode
{
	my ($self,$ip) = @_;
	return '' unless $ip;
	require Geo::IP2;
    my $geo = $self->{db} && $self->{db}->{geoip} ? $self->{db}->{geoip} : Geo::IP2->new("$c->{cgi_path}/GeoLite2-Country.mmdb");
    my $country = $geo->country_code_by_addr($ip);
    $self->{db}->{geoip} ||= $geo if $self->{db};
    return uc($country) || 'LV';
}

sub logg
{
	my ($self,$name,$msg) = @_;
	my $date = sprintf("%04d-%02d-%02d %02d:%02d:%02d",$self->getDate);
	$name||='misc';
	open LOGG, ">>$c->{cgi_path}/logs/$name.txt";
	print LOGG "[$date] $msg\n";
	close LOGG;
}

sub randchar
{ 
   my ($self,$num,$az) = @_;
   my @range = $az ? ('a'..'z') : ('0'..'9','a'..'z');
   my $x = int scalar @range;
   join '', map $range[rand $x], 1..$num||1;
}

sub api
{
   my ($self,$srv_cgi_url,$data) = @_;
   unless($self->{ua})
   {
	   require LWP::UserAgent;
	   $self->{ua} = LWP::UserAgent->new(agent => $c->{user_agent}, timeout => $data->{api_timeout}||120);
   }
   return $self->{ua}->post("$srv_cgi_url/api.cgi", $data)->content;
}

sub api2
{
   my ($self,$srv_id,$data) = @_;
   my $srv = $self->db->SelectRowCached("SELECT * FROM Servers WHERE srv_id=?",$srv_id);
   return 'noserver' unless $srv;
   return 'off' if $srv->{srv_status} eq 'OFF';
   return $self->api($srv->{srv_cgi_url}, { dl_key => $c->{dl_key}, disk_id => $srv->{disk_id}, %{$data}, } );
}

sub api_host
{
   my ($self,$host_id,$data) = @_;
   my $host = $self->db->SelectRowCached("SELECT * FROM Hosts WHERE host_id=?",$host_id);
   return 'noserver' unless $host;
   return $self->api($host->{host_cgi_url}, { dl_key => $c->{dl_key}, %{$data}, } );
}

sub hook_url
{
  my ($buffer) = @_;
  print"$buffer\n";
}

sub AdminLog
{
   my ($self,$msg) = @_;
   return unless $c->{admin_log} && $msg;
   open(FILE,">>$c->{cgi_path}/logs/$c->{admin_log}")||return;
   my @dt = $self->getTime();
   print FILE "$dt[0]:$dt[1]:$dt[2] $dt[3]-$dt[4]-$dt[5] $msg\n";
   close FILE;
}

sub getTime
{
    my ($self,$time) = @_;
    my @t = $time ? localtime( $time ) : localtime();
    return ( sprintf("%04d",$t[5]+1900),
             sprintf("%02d",$t[4]+1), 
             sprintf("%02d",$t[3]), 
             sprintf("%02d",$t[2]), 
             sprintf("%02d",$t[1]), 
             sprintf("%02d",$t[0]) 
           );
}

sub getDate
{
    my ($self,$time) = @_;
    my @tt = $self->getTime($time);
    return splice( @tt, 0, 3);
}

sub DeleteFile
{
	my ($self,$file) = @_;
	$self->DeleteFilesMass([$file]);
}

sub DeleteFilesMass
{
	my ($self,$files) = @_;
	for my $file (@$files)
	{
		if($self->db->SelectOne("SELECT COUNT(*) FROM Files WHERE file_real=?",$file->{file_real}) <= 1)
		{
			$file->{lastone}=1;
			if($self->f->{now})
			{
				$self->DeleteFileDisk($file);
			}
			else
			{
				$self->db->Exec("INSERT INTO QueueDelete SET file_real_id=?,file_real=?,srv_id=?,del_by=?,del_time=NOW()+INTERVAL ? HOUR, audio_thumb=?,video_thumb=?,video_thumb_t=?", $file->{file_real_id}||$file->{file_id},$file->{file_real},$file->{srv_id},$self->getUserId||0, $self->{delete_disk_time}||$c->{delete_disk_time}||0,$file->{audio_thumb},$file->{video_thumb},$file->{video_thumb_t});
			}

			my $size=0;
			$size+=$file->{"file_size_$_"} for ('o',reverse @{$c->{quality_letters}},'p');
			$self->db->Exec("UPDATE Users SET usr_disk_used=usr_disk_used-? WHERE usr_id=?",int $size/1024,$file->{usr_id});
		}

		$self->DeleteFileDB($file);
	}
}

sub DeleteFileDB
{
	my ($self,$file) = @_;

	$self->db->Exec("INSERT IGNORE INTO FilesTrash SELECT *, NOW() as file_deleted, ? as del_by, 0 as hide, 0 as cleaned FROM Files WHERE file_id=?", $self->getUserId||0, $file->{file_id});

	$self->db->Exec("DELETE FROM Files WHERE file_id=?",$file->{file_id});

	if($file->{lastone})
	{
		$self->db->Exec("DELETE FROM QueueEncoding WHERE file_real_id=?",$file->{file_real_id}||$file->{file_id});
		$self->db->Exec("DELETE FROM QueueTransfer WHERE file_real_id=?",$file->{file_real_id}||$file->{file_id});
	}
	else
	{
		my $file_id_ok = $self->db->SelectOne("SELECT file_id FROM Files WHERE file_real=? LIMIT 1",$file->{file_real});
		$self->db->Exec("UPDATE QueueEncoding SET file_id=? WHERE file_real_id=?", $file_id_ok, $file->{file_real_id} );
		$self->db->Exec("UPDATE QueueTransfer SET file_id=? WHERE file_real_id=?", $file_id_ok, $file->{file_real_id} );
	}

	if($file->{del_money} && $file->{usr_id})
	{
		$self->db->Exec("UPDATE Users SET usr_money=usr_money-? WHERE usr_id=?", $file->{file_money}, $file->{usr_id} );
		$self->db->Exec("UPDATE Users SET usr_money=usr_money-? WHERE usr_id=?", sprintf("%.04f",$file->{file_money}*$c->{referral_aff_percent}/100), $file->{usr_aff_id} ) if $file->{usr_aff_id} && $c->{referral_aff_percent}>0;
	}

}

sub DeleteFileQuality
{
	my ($self,$file,$quality,$priority) = @_;
	$self->db->Exec("INSERT INTO QueueDelete SET file_real_id=?,file_real=?,srv_id=?,del_by=?,del_time=NOW(),quality=?,priority=?",$file->{file_real_id},$file->{file_real},$file->{srv_id},$self->getUserId||0,$quality||0,$priority||0 );
}

sub DeleteUserDB
{
	my ($self,$usr_id) = @_;
	$self->db->Exec("DELETE FROM Users WHERE usr_id=?",$usr_id);
	$self->db->Exec("DELETE FROM UserData WHERE usr_id=?",$usr_id);
	$self->db->Exec("DELETE FROM Sessions WHERE usr_id=?",$usr_id);
	$self->db->Exec("DELETE FROM Payments WHERE usr_id=?",$usr_id);
	$self->db->Exec("DELETE FROM Transactions WHERE usr_id=?",$usr_id);
	$self->db->Exec("DELETE FROM Folders WHERE usr_id=?",$usr_id);
	$self->db->Exec("DELETE FROM Streams WHERE usr_id=?",$usr_id);
}

sub DeleteFileDisk
{
	my ($self,$file) = @_;
	my $res = $self->api2( $file->{srv_id}, { op => 'del_files', list => "$file->{file_real_id}-$file->{file_real}-$file->{audio_thumb}-$file->{video_thumb}-$file->{video_thumb_t}"});
	$self->db->Exec("DELETE FROM QueueDelete WHERE file_real_id=?",$file->{file_real_id});
	if($res=~/OK$/s || $res eq 'noserver' || $res eq 'off')
	{
		$self->PurgeFileCaches($file) unless $self->f->{no_cache_purges};
	}
	else
	{
		$self->AdminLog("Error deleting file from disk. $file->{file_real_id}-$file->{file_real}, srv_id=$file->{srv_id}.\n$res\n");
	}
}

sub PurgeFileCaches
{
	my ($self,$file) = @_;

	$self->db->PurgeCache("filedl$file->{file_code}");
	$self->db->PurgeCache("enc$file->{file_real_id}");

	if($c->{m_i})
	{
		require LWP::UserAgent;
		my $ua = LWP::UserAgent->new(timeout => 5, agent => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36");
		for(@{$self->genThumbURLs($file,{purge=>1})})
		{
   			my $res = $ua->get("$_")->content;
		}
		my $res = $self->PurgeCloudflareCache( $self->genThumbURLs($file) );
	}
}

sub PurgeCloudflareCache
{
	my ($self,$urls) = @_;
	return '' unless $urls || $#$urls==-1;
	return unless $c->{m_i_cf_zone_id} && $c->{m_i_cf_token};
	my $list = join '","', @$urls;
	require HTTP::Request;
	require LWP::UserAgent;
	my $req = HTTP::Request->new( 'DELETE', "https://api.cloudflare.com/client/v4/zones/$c->{m_i_cf_zone_id}/purge_cache" );
	$req->header( 'Content-Type' => 'application/json' );
	$req->header( 'Authorization' => "Bearer $c->{m_i_cf_token}" );
	$req->content( qq|{"files":["$list"]}| );
	my $lwp = LWP::UserAgent->new(timeout => 10, agent => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36");
	return $lwp->request( $req )->content;
}

sub SecureStr
{
	my ($self,$str)=@_;
	$str=~s/</&lt;/gs;
	$str=~s/>/&gt;/gs;
	$str=~s/"/&quot;/gs;
	$str=~s/\(/&#40;/gs;
	$str=~s/\)/&#41;/gs;
	$str=~s/&lt;br&gt;/<br>/gs;
	$str=~s/\0//gs;
	$str=~s/\\/\\\\/gs;
	$str=~s/\.\./&#46;&#46;/gs;
	return $str;
}

sub SendMailQueue
{
	my ($self, $mail_to, $mail_from, $subject, $body, $txt, $priority) = @_;
	$self->db->Exec("INSERT INTO QueueEmail SET email_to=?, email_from=?, subject=?, body=?, priority=?, txt=?", $mail_to, $mail_from, $subject, $body, $priority||5, $txt?1:0);
}

sub SendMail
{
   my ($self,$mail_to, $mail_from, $subject, $body, $txt) = @_;

   if($c->{smtp_auth} eq 'mailgun')
   {
      return $self->SendMailMailgun($mail_to, $mail_from, $subject, $body, $txt);
   }
   elsif($c->{smtp_auth} eq 'tls')
   {
      return $self->SendMailTLS($mail_to, $mail_from, $subject, $body, $txt);
   }
   elsif($c->{smtp_auth} eq 'tls2')
   {
      return $self->SendMailTLS2($mail_to, $mail_from, $subject, $body, $txt);
   }
   elsif($c->{smtp_auth} eq 'tls3')
   {
      return $self->SendMailTLS3($mail_to, $mail_from, $subject, $body, $txt);
   }

   my $content_type = $c->{email_html} ? 'text/html' : 'text/plain';
      $content_type = 'text/plain' if $txt;
      $content_type = 'text/html'  if $txt eq 'html';
   require MIME::Lite;
   my $msg = MIME::Lite->new(
        From    => $mail_from,
        To      => $mail_to,
        Subject => $subject,
        Data    => $body
    );
    $msg->attr("content-type"         => $content_type);
    $msg->attr("content-type.charset" => "UTF8");
    $msg->add("Return-Path", $mail_from );
    $msg->add("Reply-To", $mail_from );

	if($c->{smtp_server} && $c->{smtp_user} && $c->{smtp_pass})
	{
	  $msg->send('smtp',$c->{smtp_server}, AuthUser=>$c->{smtp_user}, AuthPass=>$c->{smtp_pass} );
	}
	else
	{
	  $msg->send('sendmail', SetSender=>1);
	}
}

sub SendMailMultipart
{
   my ($self,$mail_to, $mail_from, $subject, $body, $body_text) = @_;

   if($c->{smtp_auth} eq 'mailgun')
   {
      return $self->SendMailMailgun($mail_to, $mail_from, $subject, $body);
   }
   elsif($c->{smtp_auth} eq 'tls')
   {
      return $self->SendMailTLS($mail_to, $mail_from, $subject, $body);
   }

   require MIME::Lite;
   my $msg = MIME::Lite->new(
        From    => $mail_from,
        To      => $mail_to,
        Type    => 'multipart/alternative',
        Subject => $subject,
    );
    $msg->add("Return-Path", $mail_from );
    $msg->add("Reply-To", $mail_from );

    my $att_text = MIME::Lite->new(
   		Type     => 'text',
   		Data     => $body_text,
   		Encoding => 'quoted-printable',
 	);
 	$att_text->attr('content-type' => 'text/plain; charset=UTF-8');
	$msg->attach($att_text); 


	my $att_html = MIME::Lite->new(  
  		Type     => 'text',
  		Data     => $body,  
  		Encoding => 'quoted-printable', 
 	);  
 	$att_html->attr('content-type' => 'text/html; charset=UTF-8');  
 	$msg->attach($att_html);  

    $msg->send('sendmail', SetSender=>1);
}

sub SendMailTLS
{
   require Net::SMTP::TLS;
   my ($self, $mail_to, $mail_from, $subject, $body) = @_;
   my $content_type = $c->{email_html} ? 'text/html' : 'text/plain';
      $content_type = 'text/plain' if $c->{email_text};
   my $msg = new Net::SMTP::TLS($c->{smtp_server}, User    => $c->{smtp_user}, Password=> $c->{smtp_pass}, Timeout => 30);

   $msg->mail($mail_from);
   $msg->recipient($mail_to);

   $msg->data();
   $msg->datasend("To: $mail_to\n");
   $msg->datasend("From: $mail_from\n");
   $msg->datasend("Content-Type: $content_type\n");
   $msg->datasend("Subject: $subject\n\n");
   $msg->datasend($body);
   $msg->dataend();

   $msg->quit;
}

sub SendMailTLS2
{
   require Net::SMTPS;
   my ($self, $mail_to, $mail_from, $subject, $body) = @_;
   my $content_type = $c->{email_html} ? 'text/html' : 'text/plain';
   my $msg = new Net::SMTPS($c->{smtp_server}, Hello => $self->{domain},  doSSL => 'starttls', Port => 587);

   $msg->auth($c->{smtp_user},$c->{smtp_pass});
   $msg->mail($mail_from);
   $msg->recipient($mail_to);

   $msg->data();
   $msg->datasend("To: $mail_to\n");
   $msg->datasend("From: $mail_from\n");
   $msg->datasend("Content-Type: $content_type\n");
   $msg->datasend("Subject: $subject\n\n");
   $msg->datasend($body);
   $msg->dataend();

   $msg->quit;
}

sub SendMailTLS3
{
   require Net::SMTP;
   my ($self, $mail_to, $mail_from, $subject, $body) = @_;
   my $content_type = $c->{email_text} ? 'text/plain' : 'text/html';
   my $msg = new Net::SMTP($c->{smtp_server}, Hello => $self->{domain}, SSL => 1,);

   $msg->auth($c->{smtp_user},$c->{smtp_pass});
   $msg->mail($mail_from);
   $msg->recipient($mail_to);

   $msg->data();
   $msg->datasend("To: $mail_to\n");
   $msg->datasend("From: $mail_from\n");
   $msg->datasend("Content-Type: $content_type\n");
   $msg->datasend("Subject: $subject\n\n");
   $msg->datasend($body);
   $msg->dataend();

   $msg->quit;
}

sub decode_base64
{
    my ($self,$str) = @_;
    use integer;
    $str =~ tr|A-Za-z0-9+=/||cd;
    die("Length of base64 data not a multiple of 4") if length($str) % 4;
    $str =~ s/=+$//;
    $str =~ tr|A-Za-z0-9+/| -_|;
    return "" unless length $str;
    my $uustr = '';
    my ($i, $l);
    $l = length($str) - 60;
    for ($i = 0; $i <= $l; $i += 60) {
	$uustr .= "M" . substr($str, $i, 60);
    }
    $str = substr($str, $i);
    if ($str ne "") {
	$uustr .= chr(32 + length($str)*3/4) . $str;
    }
    return unpack ("u", $uustr);
}

sub shortenURL
{
    my ($self,$file_id) = @_;
    my $idd = $self->encode_base36( $file_id );
    $c->{m_j_domain}=~s/http:\/\///;
    return $c->{m_j_domain} ? "http://$c->{m_j_domain}/$idd" : "$c->{site_url}/u/$idd";
}

sub decode_base36
{
    my ($self,$base36) = @_;
    $base36 = uc( $base36 );
    return 0 if $base36 =~ m{[^0-9A-Z]};

    my ( $result, $digit ) = ( 0, 0 );
    for my $char ( split( //, reverse $base36 ) ) {
        my $value = $char =~ m{\d} ? $char : ord( $char ) - 55;
        $result += $value * ( 36**$digit++ );
    }

    return $result;
}

sub encode_base36
{
    my ( $self, $number ) = @_;

    return ''  if $number    =~ m{\D};
    return 0 if $number == 0;

    my $result = '';
    while ( $number ) {
        my $remainder = $number % 36;
        $result .= $remainder <= 9 ? $remainder : chr( 55 + $remainder );
        $number = int $number / 36;
    }

    return reverse( $result );
}

# sub makeFileLink
# {
#    my ($self,$file) = @_;
#    my $fname = $file->{file_title};
#     # Remove spaces around dashes
#     $fname =~ s/\s*-\s*/-/g;
#     # Replace remaining spaces with hyphens
#     $fname =~ s/\s+/-/g; 
#     # Remove characters that are not word, digit, dot, or hyphen
#     $fname =~ s/[^\w\d.-]//g;
#     # Convert all alphabetic characters to lowercase
#     $fname = lc $fname;    
#    my $code = $c->{link_format_uppercase} ? uc $file->{file_id} : lc $file->{file_id};
#    return "$c->{site_url}/$code".
#             {0 => "/$fname.html",
#              1 => "/$fname.htm",
#              2 => "/$fname",
#              3 => ".html",
#              4 => ".htm"}->{$c->{link_format}};
# }

sub makeFileLink
{
   my ($self,$file) = @_;
   my $file_seo = "$c->{site_url}/$file->{file_seo}-$file->{file_id}";
}

sub makeDownloadLink
{
   my ($self,$file,$quality) = @_;
   return '' unless $file->{"file_size_$quality"};
   my $code = $c->{link_format_uppercase} ? uc $file->{file_code} : $file->{file_code};
   return "$c->{site_url}/d/$code\_$quality";
}

sub makeFileSize
{
   my ($self,$size)=@_;
   return '' unless $size;
   return "$size B" if $size<=1024;
   return sprintf("%.0f KB",$size/1024) if $size<=1024*1024;
   return sprintf("%.01f MB",$size/1048576) if $size<=1024*1024*1024;
   return sprintf("%.01f GB",$size/1073741824);
}

sub makeEmbedCode
{
    my ($self,$file,$simple) = @_;
    my $ew = $self->getCookie("embed_width") || $c->{embed_width};
    $ew=600 unless $ew=~/^\d+$/;
    my $eh = $self->getCookie("embed_height") || $c->{embed_height};
    $eh=360 unless $eh=~/^\d+$/;
    my $site_url = $c->{embed_alt_domain} || $c->{site_url};
    my $embed_url = "$site_url/e/$file->{file_code}";
    if($c->{embed_static})
    {
        $self->genThumbURLs($file) unless $file->{video_img_url};
        my $timg = $file->{video_img_url};
        $timg=~s/^https?:\/\///i;
        $timg=~s/\.jpg$//i;
        $embed_url = "$site_url/e/$file->{file_code}";
        $embed_url.="?$timg" unless $file->{iproxy};
    }
    return qq[<iframe width="640" height="360" src="$embed_url" scrolling="no" frameborder="0" allowfullscreen="true"></iframe>] if $simple || !$c->{embed_responsive};
    return qq[<div style="position:relative;padding-bottom:56%;padding-top:20px;height:0;"><IFRAME SRC="$embed_url" FRAMEBORDER=0 MARGINWIDTH=0 MARGINHEIGHT=0 SCROLLING=NO WIDTH=$ew HEIGHT=$eh allowfullscreen style="position:absolute;top:0;left:0;width:100%;height:100%;"></IFRAME></div>];
}
sub makePagingLinks
{ 
 my ($self,$f,$total_items,$reverse) = @_;
 my $range = 1;
 my $items_per_page = $f->{per_page} || $c->{items_per_page} || 5;
 return '' if $items_per_page eq 'all';

  my $current_page = $f->{page}||1;
  $current_page = 1 if $f->{page} eq 'all';
  my @pp;
  foreach my $key(sort keys %{$f})
  {
    my $val = $f->{$key};
    push @pp,"$key=$val" if $val ne '' && (ref $val ne "ARRAY" && $key !~/^(page|fast_paging|fast_paging_next)$/);
    map{push @pp,"$key=$_"}@$val if ref $val eq 'ARRAY';
  }
  my $par = join '&amp;',@pp;
  my $adm='adm' if $self->{adm};

  my $t='<nav class="isolate inline-flex -space-x-px rounded-md shadow-sm" aria-label="Pagination">';
  if($self->f->{fast_paging})
  {
    $t.="<a class='relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-800 focus:outline-offset-0' href='$c->{site_url}/$adm?$par&amp;page=".($current_page-1)."'><span class='sr-only'>Previous</span>
      <svg class='h-5 w-5' viewBox='0 0 20 20' fill='currentColor' aria-hidden='true'>
        <path fill-rule='evenodd' d='M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z' clip-rule='evenodd' />
      </svg></a>" if $current_page>1;
    $t.="<span aria-current='page' class='relative z-10 inline-flex items-center bg-gray-100/10 px-4 py-2 text-sm font-semibold text-white'>$current_page</span>";
    $t.="<a class='relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-800 focus:outline-offset-0' href='$c->{site_url}/$adm?$par&amp;page=".($current_page+1)."'><span class='sr-only'>Next</span>
      <svg class='h-5 w-5' viewBox='0 0 20 20' fill='currentColor' aria-hidden='true'>
        <path fill-rule='evenodd' d='M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z' clip-rule='evenodd' />
      </svg></a>" if $self->f->{fast_paging_next};
    $t.="</nav>";
    return $t;
  }

   #$t.="<div class='hidden sm:flex sm:flex-1 sm:items-center sm:justify-between'><small>($total_items $self->{lang}->{lng_paging_total})</small></div>";

 my $total_pages = int(0.999+$total_items/$items_per_page);
    
    return '' if $total_pages<2;

 my $i1 = $current_page - $range;
 my $i2 = $current_page + $range;
 if ($i2 > $total_pages)
 {
    $i1 -= ($i2-$total_pages);
    $i2 = $total_pages;
 }
 
 $t.="<a class='relative inline-flex items-center rounded-l-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-800 focus:outline-offset-0' href='$c->{site_url}/$adm?$par&amp;page=".($current_page-1)."'>
      <span class='sr-only'>Previous</span>
      <svg class='h-5 w-5' viewBox='0 0 20 20' fill='currentColor' aria-hidden='true'>
        <path fill-rule='evenodd' d='M12.79 5.23a.75.75 0 01-.02 1.06L8.832 10l3.938 3.71a.75.75 0 11-1.04 1.08l-4.5-4.25a.75.75 0 010-1.08l4.5-4.25a.75.75 0 011.06.02z' clip-rule='evenodd' />
      </svg>
      </a>" if $current_page>1;
 $t.="<a class='relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-900 focus:outline-offset-0' href='$c->{site_url}/$adm?$par&amp;page=1'>1</a>" if $i1>1;
 $t.="<a class='relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-900 focus:outline-offset-0' href='$c->{site_url}/$adm?$par&amp;page=2'>2</a>" if $i1>2;
 #$t.="<span class='relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-900 focus:outline-offset-0'>...</span>" if $i1>3;

 my $i = $i1;
 while( $i <= $i2 )
 {
    if( $i > 0 )
    {
       $t .= $i==$current_page ?
       "<span aria-current='page' class='relative z-10 inline-flex items-center bg-gray-100/10 px-4 py-2 text-sm font-semibold text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600'>$i</span>" : "<a class='relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-800  focus:outline-offset-0' href='$c->{site_url}/$adm?$par&amp;page=$i'>$i</a>";
    }
    else
    {
       $i2++ if $i2 < $total_pages;
    }
    $i++;
 }

 #$t.="<span class='relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-900 focus:outline-offset-0'>...</span>" if $i2<$total_pages-2;
 #$t.="<a class='relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-800 focus:outline-offset-0' href='$c->{site_url}/$adm?$par&amp;page=".($total_pages-1)."'>".($total_pages-1)."</a>" if $i2<$total_pages-1;
 #$t.="<a class='relative inline-flex items-center px-4 py-2 text-sm font-semibold text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-800  focus:outline-offset-0' href='$c->{site_url}/$adm?$par&amp;page=$total_pages'>$total_pages</a>" if $i2<$total_pages;
 $t.="<a class='relative inline-flex items-center rounded-r-md px-2 py-2 text-gray-400 ring-1 ring-inset ring-gray-800 hover:bg-gray-800 focus:outline-offset-0' href='$c->{site_url}/$adm?$par&amp;page=".($current_page+1)."'>
       <span class='sr-only'>Previous</span>
      <svg class='h-5 w-5' viewBox='0 0 20 20' fill='currentColor' aria-hidden='true'>
        <path fill-rule='evenodd' d='M7.21 14.77a.75.75 0 01.02-1.06L11.168 10 7.23 6.29a.75.75 0 111.04-1.08l4.5 4.25a.75.75 0 010 1.08l-4.5 4.25a.75.75 0 01-1.06-.02z' clip-rule='evenodd' />
      </svg>
      </a>" if $current_page<$total_pages;



 return  $t; 
}

sub makePagingSQLSuffix
{
    my ($self,$current_page,$per_page)  = @_;
    
    my $items_per_page = $per_page || $self->f->{per_page} || $c->{items_per_page} || 15;
    return " " if $items_per_page eq "all";
    my $end = $current_page*$items_per_page;
    my $start = $end - $items_per_page; 
       $start = $start>0 ? $start:0;
    $start=~s/\D+//g;
    $items_per_page=~s/\D+//g;
    $items_per_page++ if $self->f->{fast_paging};

    return " LIMIT $start, $items_per_page";
}

sub encode32
{			
    my $self=shift;
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

sub decode32
{
   my $self=shift;
   $_ = shift;
   my $l;
   tr|a-z2-7|\0-\37|;
   $_=unpack('B*',$_);
   s/000(.....)/$1/g;
   $l=length;
   $_=substr($_,0,$l & ~7) if $l & 7;
   $_=pack('B*',$_);
}

sub HashSave
{
   my ($self,$file_id,$dt) = @_;
   $dt||=0;
   $file_id||=0;
   my ($i1,$i2,$i3,$i4) = split(/\./,$self->getIP);
   my $str = "$file_id-$i1-$i2-".(time+$dt);
   require Digest::MD5;
   my $md5 = Digest::MD5::md5_hex($str.$c->{license_key});
   return "$str-$md5";
}
sub HashCheck
{
   my ($self,$hash) = @_;
   my ($file_id,$i1,$i2,$tmin,$md5) = split(/-/,$hash);
   unless($tmin && $md5){ $self->{form}->{msg}="Invalid hash";return 0; }
   my $str = "$file_id-$i1-$i2-$tmin";
   require Digest::MD5;
   my $md5corr = Digest::MD5::md5_hex($str.$c->{license_key});
   unless($md5 eq $md5corr){ $self->{form}->{msg}="Invalid md5";return 0; }

   if($tmin>time){$self->{form}->{msg}="Skipped countdown";return 0;}
   if($tmin<time-900){$self->{form}->{msg}="Expired download session";return 0;}
   if($self->getIP!~/^$i1\.$i2\./){$self->{form}->{msg}="Wrong IP address";return 0;}

   return 1;
}

sub SecSave
{
   my ($self, $type, $dt, $captcha_on) = @_;
   $dt||=0;
   my $number = $captcha_on && $c->{captcha_mode}=~/^(1|2)$/ ? int(rand(9)+1).join('', map int rand(10), 1..3) : '';
   my ($i1,$i2) = split(/\./,$self->getIP);
   my $tmin = time + $dt - 1607500000;
   require Digest::MD5;
   my $hash = Digest::MD5::md5_hex($type.$number.$i1.$i2.$tmin.$c->{license_key});

   my %captcha = $self->GenerateCaptcha($number,$hash) if $captcha_on;
   $captcha{rand} = "$tmin-$hash";
   return %captcha;
}

sub SecCheck
{
   my ($self, $hash, $type, $number, $captcha_on) = @_;
   $number||='';
   my ($tmin,$md5) = $hash=~/^(\d+)-(.+)$/;
   my ($i1,$i2) = split(/\./,$self->getIP);

   require Digest::MD5;
   my $hashmd5 = Digest::MD5::md5_hex($type.$number.$i1.$i2.$tmin.$c->{license_key});
   if($hashmd5 ne $md5){$self->{form}->{msg}="Invalid hash";return 0;}

   if($captcha_on && $c->{captcha_mode}==3)
   {
      if( $self->checkRecaptcha ) {return 1;} else {$self->{form}->{msg}="Wrong captcha";return 0;}
   }
   if($captcha_on && $c->{captcha_mode}==1)
   {
      unless(-e "$c->{site_path}/captchas/$md5.jpg"){$self->{form}->{msg}="Expired session";return 0;}
      unlink("$c->{site_path}/captchas/$md5.jpg");
   }
   
   if($tmin > time-1607500000){$self->{form}->{msg}="Skipped countdown";return 0;}
   if($tmin<time-1607500000-900){$self->{form}->{msg}="Expired download session";return 0;}

   return 1;
}

sub GenerateCaptcha
{
   my ($self,$number,$fname) = @_;

   if($c->{captcha_mode}==1)
   {
      eval {require SecImage;};
      my $iurl = SecImage::GenerateImage($number,$fname) unless $@;
      return ('captcha_on'=>1, 'iurl' => $iurl, 'number' => $number);
   }
   elsif($c->{captcha_mode}==2)
   {
      require SecImage;
      my $itext = SecImage::GenerateText($number);
      return ('captcha_on'=>1, 'itext' => $itext, 'number' => $number);
   }
   elsif($c->{captcha_mode}==3 && $c->{recaptcha_pub_key} && $c->{recaptcha_pri_key})
   {
      my $html = $self->genRecaptcha;
      return ('captcha_on'=>1, 'ihtml'=>$html);
   }
   return ('captcha_on'=>0);
}

sub genRecaptcha
{
  my ($self,$onclick) = @_;
  my $auto=qq|data-callback="imNotARobot"| if $onclick;
  return qq[<script src="https://www.google.com/recaptcha/api.js" async defer></script><div class="g-recaptcha" data-sitekey="$c->{recaptcha_pub_key}" $auto></div>];
}
sub checkRecaptcha
{
  my ($self) = @_;
  return 0 unless $self->f->{'g-recaptcha-response'};
  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new(timeout => 15);
  my $res = $ua->get( "https://www.google.com/recaptcha/api/siteverify?secret=$c->{recaptcha_pri_key}&response=".$self->f->{'g-recaptcha-response'}."&remoteip=".$self->getIP )->content;
  return $res=~/"success": true/i ? 1 : 0;
}
sub checkRecaptcha3
{
  my ($self) = @_;
  return 0 unless $self->f->{'g-recaptcha-response'};
  require LWP::UserAgent;
  my $ua = LWP::UserAgent->new(timeout => 15);
  my $res = $ua->get( "https://www.google.com/recaptcha/api/siteverify?secret=$c->{recaptcha3_pri_key}&response=".$self->f->{'g-recaptcha-response'}."&remoteip=".$self->getIP )->content;
  my ($score) = $res=~/score": ([\d\.]+)/;
  return $res=~/"success": true/i ? $score*100 : 0;
}

sub vInfo
{
    my ($self,$file,$mode) = @_;
    require XUtils;
    return XUtils::vInfo($file,$mode);
}

sub getVideoInfo
{
    my ($self,$file,$mode) = @_;
    $mode||='o' if $file->{file_size_o};
    $mode||='n' if $file->{file_size_n};
    $mode||='h' if $file->{file_size_h};
    $mode||='x' if $file->{file_size_x};
    my $x = $self->vInfo($file,$mode);
    $file->{$_}=$x->{$_} for keys %$x;

    $self->genThumbURLs($file);

    $file->{download_link} = $self->makeFileLink($file);

}

sub isMobile
{
    my ($self) = @_;
    return 1 if $ENV{HTTP_USER_AGENT}=~/(blackberry|webos|iphone|ipod|ipad|android)/i;
    return $ENV{'HTTP_USER_AGENT'} =~ m/android.+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|meego.+mobile|midp|mmp|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i 
           || substr($ENV{'HTTP_USER_AGENT'}, 0, 4) =~ m/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(di|rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-/i;
}

sub shortenString
{
    my ($self,$str,$max_length) = @_;
    $max_length ||= $c->{display_max_filename};
    $str = length($str)>$max_length ? substr($str,0,$max_length).'&#133;' : $str;
    return $str;
}

sub writeLog
{
   my ( $self, $ipn_id, $message, $isExit ) = @_;

   if($message)
   {
       open  LOG, ">>$c->{cgi_path}/ipn_log.txt";
       print LOG localtime()." : $message\n";
       close LOG;
   }

   unless($ipn_id)
   {
      $self->db->Exec("INSERT INTO IPNLogs SET created=NOW(), info=?", $message );
      $ipn_id = $self->db->getLastInsertId;
   }
   else
   {
      $self->db->Exec("UPDATE IPNLogs SET info=CONCAT(info,?) WHERE ipn_id=?", "\n$message", $ipn_id );
   }

   print("Content-type:text/html\n\n"),exit if $isExit;

   return $ipn_id;
}

sub processAff
{
    my ($self, $ipn_id, $transaction, $f) = @_;
    return unless $transaction->{aff_id}=~/^\d+$/;
    my $aff = $self->db->SelectRow("SELECT * FROM Users WHERE usr_id=?", $transaction->{aff_id} );
    return unless $aff;
    return unless $c->{sale_aff_percent};
    my $owner = $self->db->SelectRow("SELECT * FROM Users WHERE usr_id=?",$transaction->{aff_id});
    my $usr_sales_rate = $owner->{usr_sales_rate} ? $owner->{usr_sales_rate} : $c->{sale_aff_percent};
    my $money = $transaction->{amount}*$usr_sales_rate/100;
    $self->db->Exec("UPDATE Users SET usr_money=usr_money+? WHERE usr_id=?", $money, $transaction->{aff_id});
    $self->writeLog($ipn_id, "Affiliate profit: \$$money to usr_id=$transaction->{aff_id}");

    my $refs = $transaction->{new} ? 1 : 0;
    $self->db->Exec("INSERT INTO Stats2 SET usr_id=?, day=CURDATE(),sales=1, profit_sales=?, refs=$refs ON DUPLICATE KEY UPDATE sales=sales+1, profit_sales=profit_sales+?, refs=refs+$refs",$transaction->{aff_id},$money,$money);

    my $aff_id = $owner->{usr_aff_id};
    my $money_ref = sprintf("%.05f",$money*$c->{referral_aff_percent}/100);
    if($aff_id && $money_ref>0)
    {
      $self->db->Exec("UPDATE Users SET usr_money=usr_money+? WHERE usr_id=?", $money_ref, $aff_id);
      $self->writeLog($ipn_id, "Affiliate2 profit: \$$money_ref to usr_id=$aff_id");
      $self->db->Exec("INSERT INTO Stats2 SET usr_id=?, day=CURDATE(),profit_refs=? ON DUPLICATE KEY UPDATE profit_refs=profit_refs+?",$aff_id,$money_ref,$money_ref);
    }    
}

sub processWebsite
{
    my ($self, $ipn_id, $transaction) = @_;

    $self->writeLog("Referer: $transaction->{ref_url}");
    my $domain = $transaction->{ref_url};
    $domain=~s/^https?:\/\///i;
    $domain=~s/^www\.//i;
    $domain=~s/\/.+$//;
    $domain=~s/[\/\s]+//g;
    $self->writeLog($ipn_id, "Domain: $domain");
    my $usr_id = $self->db->SelectOne("SELECT usr_id FROM Websites WHERE domain=?",$domain);

    if($usr_id)
    {
      my $rate = $self->db->SelectOne("SELECT usr_website_rate FROM Users WHERE usr_id=?",$usr_id) || $c->{m_b_rate};
      my $money = sprintf("%.05f", $transaction->{amount}*$rate/100 );
      $self->writeLog($ipn_id, "Webmaster usr_id=$usr_id earned \$$money (Rate=$rate\%)");
      $self->db->Exec("UPDATE Users SET usr_money=usr_money+? WHERE usr_id=?", $money, $usr_id);

      $self->db->Exec("INSERT INTO Stats2 SET usr_id=?, day=CURDATE(),profit_site=? ON DUPLICATE KEY UPDATE profit_site=profit_site+?",$usr_id,$money,$money) if $c->{m_s};

      $self->db->Exec("UPDATE Websites SET money_sales=money_sales+?, money_profit=money_profit+? WHERE usr_id=? AND domain=?", $transaction->{amount}, $money, $usr_id, $domain);
    }
}

sub genToken
{
    my ($self) = @_;
    return '' unless $self->{user} && $self->{user}->{session_id};
    require Digest::MD5;
    my $x = Digest::MD5::md5_hex( $self->{user}->{session_id}.$c->{dl_key}.$c->{pasword_salt}.join('',$self->getDate) );
    return $x;
}

sub checkToken
{
    my ($self) = @_;
    return 0 unless $self->{user} && $self->{user}->{session_id};
    my $md5 = $self->genToken;
    unless($self->f->{token} eq $md5)
    {
        return 0;
    }
    return 1;
}

sub makeSortSQLcode
{
  my ($self,$f,$default_field) = @_;
  
  $f->{sort_field}=~s/[^a-z0-9\_]+//g;
  my $sort_field = $f->{sort_field} || $default_field;
  my $sort_order = $f->{sort_order} eq 'down' ? 'DESC' : '';

  return " ORDER BY $sort_field $sort_order ";
}

sub makeSortHash
{
   my ($self,$f,$fields) = @_;
   my @par;
   foreach my $key (keys %{$f})
   {
    next if $key=~/^(sort_field|sort_order)$/i;
    my $val = $f->{$key};
    push @par, (ref($val) eq 'ARRAY' ? map({"$key=$_"}@$val) : "$key=$val");
   }
   my $params = join('&amp;',@par);
   my $sort_field = $f->{sort_field};
   my $sort_order = $f->{sort_order};
   $sort_field ||= $fields->[0];
   my $sort_order2 = $sort_order eq 'down' ? 'up' : 'down';   
   my %hash = ('sort_'.$sort_field         => 1,
               'sort_order_'.$sort_order2  => 1,
               'params'                    => $params,
              );
   for my $fld (@$fields)
   {
      if($fld eq $sort_field)
      {
         $hash{"s_$fld"}  = "<a class='flex items-center px-3 py-1 text-sm gap-x-1 text-sm font-medium leading-6 text-gray-300 hover:text-indigo-300' href='?$params&amp;sort_field=$fld&amp;sort_order=$sort_order2'>";
         $hash{"s2_$fld"} = "&nbsp;<img src='$c->{site_url}/images/sort_$sort_order.png'>"
      }
      else
      {
         $hash{"s_$fld"}  = "<a class='flex items-center px-3 py-1 text-sm gap-x-1 text-sm font-medium leading-6 text-gray-300 hover:text-indigo-300' href='?$params&amp;sort_field=$fld&amp;sort_order=down'>";
         $hash{"s2_$fld"} = "&nbsp;<img src='$c->{site_url}/images/sort_both.png'>"
      }
      $hash{"s2_$fld"}.= "</a>";
   }

   return %hash;
}

sub getPlugins
{
  my ($self, $type) = @_;

  require SecTetx;
  my $ret = SecTetx::out($self,$c,$type);

  return @$ret if wantarray();
  return Session::PluginsList->new($ret);
}

sub syncFTPUsers
{
    my ($self,$verbose) = @_;
    return unless $c->{m_f};
    my $filter;
    if($c->{m_f_users} eq 'premium')
    {
        $filter = "AND usr_premium_expire>NOW()";
    }
    elsif($c->{m_f_users} eq 'special')
    {
        my $ids = $self->db->SelectARef("SELECT usr_id FROM UserData WHERE name='usr_ftp' AND value='1'");
        my $idstr = join ',', map{$_->{usr_id}} @$ids;
        $filter = "AND usr_id IN ($idstr)" if $idstr;
    }

    my $users = $self->db->SelectARef("SELECT usr_login, usr_ftp_password FROM Users WHERE usr_status='OK' AND (usr_lastlogin > NOW()-INTERVAL 14 DAY OR usr_created>NOW()-INTERVAL 1 DAY) $filter");
    for(@$users)
    {
    	unless($_->{usr_ftp_password})
    	{
    		$_->{usr_ftp_password} = $self->randchar(10);
    		$self->db->Exec("UPDATE Users SET usr_ftp_password=? WHERE usr_login=?", $_->{usr_ftp_password}, $_->{usr_login} )
    	}
    }
    
    my $list = join("\n", map{"$_->{usr_login}:$_->{usr_ftp_password}"}@$users );

    my $hosts = $self->db->SelectARef("SELECT * FROM Hosts WHERE host_ftp=1");
    for my $s (@$hosts)
    {
        my $res = $self->api_host($s->{host_id}, { op => 'add_ftp_users', list => $list, });
        print"FTP server $s->{host_name} : ($res)<br>\n" if $verbose;
    }
    return $#$users+1;
}

sub ParsePlans
{
  my ($ses, $str, $ref) = @_;
  $ref ||= 'array';
  my ($ref_array, $ref_hash, $ref_hash_reverse) = ([], {}, {});
  for ( split( /,/, $str ) ) {
    /([\d\.]+)=(.*)/;
    my $per_day = sprintf('%.02f',$1/$2) if $2 > 0;
    my $obj = { amount => $1, days => $2, value => $2, site_url => $c->{site_url}, per_day=>$per_day };
    push @$ref_array, $obj;
  }
  foreach(@$ref_array) {
    my $amount = sprintf("%.02f",$_->{amount});
    $ref_hash->{$amount} = $_->{value};
    $ref_hash_reverse->{$_->{value}} = $amount;
  }
  return($ref_array) if $ref eq 'array';
  return($ref_hash) if $ref eq 'hash';
  return($ref_hash_reverse) if $ref eq 'hash_reverse';
}

sub getIPs
{
 my $ip = $ENV{HTTP_X_FORWARDED_FOR} || $ENV{HTTP_X_REAL_IP} || $ENV{REMOTE_ADDR};
 $ip=(split(/[\,\s]+/,$ip))[0] if $ip=~/\,/;
 $ip ||= $ENV{REMOTE_ADDR};
 exit && return $ip;
}

sub days_in_month {
    my ( $self, $y, $m ) = @_;
    sub leap_year {
      my $y = shift;
      return ( ( $y % 4 == 0 ) and ( $y % 400 == 0 or $y % 100 != 0 ) ) || 0;
    }

    my @days_in_month = (
        [ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ],
        [ 0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ],
    );
    return $days_in_month[ leap_year($y) ][$m];
}

sub getDatesList
{
    my ($self,$list2,$day1,$day2) = @_;
    my ($y1,$m1,$d1) = $day1=~/^(\d\d\d\d)-(\d\d)-(\d\d)$/;
    my ($y2,$m2,$d2) = $day2=~/^(\d\d\d\d)-(\d\d)-(\d\d)$/;
    my @list;
    for(my $y=$y1;$y<=$y2;$y++)
    {
      my $m_max = $y<$y2 ? 12 : $m2;
      my $m_min = $y==$y1 ? $m1 : 1;
      for(my $m=$m_min;$m<=$m_max;$m++)
      {
          my $d_max = ($y*12+$m)<($y2*12+$m2) ? $self->days_in_month($y,$m) : $d2;
          my $d_min = $y==$y1 && $m==$m1 ? $d1 : 1;
          for(my $d=$d_min;$d<=$d_max;$d++)
          {
              push @list, { day=>sprintf("%04d-%02d-%02d",$y,$m,$d), x=>"$d/$m" };
          }
      }
    }

    my $hh;
    $hh->{$_->{day}} = $_ for @$list2;

    require POSIX;
    for my $x (@list)
    {
      $x = $hh->{$x->{day}} if $hh->{$x->{day}};
      my ($y,$m,$d) = split(/-/,$x->{day});
      $x->{time} = POSIX::mktime(0,0,0,$d,$m-1,$y-1900).'000';
    }

    return \@list;
}

sub processVideoList
{
    my ($self,$list,$per_row,$clist) = @_;
    my $f = $self->{form};
    my $cath;
    $clist ||= $self->db->SelectARefCached(300,"SELECT * FROM Categories");
    for my $x (@$clist)
    {
        $x->{cat_name2} = $x->{cat_name};
        $x->{cat_name2}=~s/\s+/\+/g;
        $cath->{$x->{cat_id}} = {cat_name=>$x->{cat_name}, cat_name2=>$x->{cat_name2}};
    }

    my $cx;
    for(@$list)
    {
       $cx++;
       $_->{site_url} = $c->{site_url};
       $_->{file_descr} = substr($_->{file_descr},0,256).'&#133;' if length($_->{file_descr})>256;
       $_->{download_link} = $self->makeFileLink($_);
       $_->{download_link} .= "?list=$f->{playlist}" if $f->{playlist};
       $_->{file_name}=~s/_/ /g;
       my ($ext) = $_->{file_name}=~/\.(\w+)$/i;
       $_->{file_descr}=~s/\n/<br>/g;

       my $file_title = $_->{file_title}||$_->{file_name};
       $_->{file_title_txt} = $self->shortenString( $_->{file_title}||$_->{file_name} );

       $_->{file_length2} = sprintf("%02d:%02d:%02d",int($_->{file_length}/3600),int(($_->{file_length}%3600)/60),$_->{file_length}%60);
       $_->{file_length2}=~s/^00:(\d\d:\d\d)$/$1/;

       $_->{add_to_account}=1 if $self->getUser && $_->{usr_id}!=$self->getUserId;
       
       $_->{clear}=1 if $per_row && $cx%$per_row==0;

       $_->{cat_name}=$cath->{$_->{cat_id}}->{cat_name};
       $_->{cat_name2}=$cath->{$_->{cat_id}}->{cat_name2};

       $self->genThumbURLs($_);
    }
}

sub genThumbURLs
{
	my ($self,$file,$opt) = @_;

    my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
    unless($file->{srv_htdocs_url})
    {
        $self->{servers}->{$file->{srv_id}} ||= $self->db->SelectRow("SELECT * FROM Servers WHERE srv_id=?",$file->{srv_id});
        $file->{$_}=$self->{servers}->{$file->{srv_id}}->{$_} for qw(srv_htdocs_url srv_cgi_url disk_id host_id);
    }

    $file->{real} = $file->{file_real};
    $file->{thumb_audio} = db->SelectOne("SELECT audio_thumb FROM Files WHERE file_id=?",$file->{file_id});
    $file->{thumb_video} = db->SelectOne("SELECT video_thumb FROM Files WHERE file_id=?",$file->{file_id});
    $file->{thumb_video_t} = db->SelectOne("SELECT video_thumb_t FROM Files WHERE file_id=?",$file->{file_id});

    
    if($c->{m_i} && $c->{m_i_server} && !$opt->{noproxy})
    {
      $file->{iproxy}=1;
      $file->{video_img_folder}="$c->{m_i_server}";
      $file->{video_img_folder}.='/xpurge' if $opt->{purge};
      $file->{real} = $file->{file_code};
    }
    else
    {
      $file->{video_img_folder}="$file->{srv_htdocs_url}/i/$file->{disk_id}/$dx";
    }

    my @list;
    
    my ($ext) = $file->{file_name} =~ /\.([^.]+)$/;

    if($c->{image_extensions} && $file->{file_name} =~ /\.($c->{image_extensions})$/i) {
      $file->{video_thumb_url}="$file->{video_img_folder}/$file->{real}_t.$ext";
    } elsif ($c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i) {
      $file->{video_thumb_url}="$file->{video_img_folder}/$file->{thumb_video}";
    } else {
      $file->{video_thumb_url}="$file->{video_img_folder}/$file->{thumb_audio}";
    }

    $file->{spectrogram_url}="$file->{video_img_folder}/$file->{real}_sp.png";

    $file->{wave1_url}="$file->{video_img_folder}/$file->{real}_w1.png";
    $file->{wave2_url}="$file->{video_img_folder}/$file->{real}_w2.png";

    $file->{video_img_url}="$file->{video_img_folder}/$file->{thumb_video}";
    
    #$file->{image_thumb_url}="$file->{video_img_folder}/$file->{real}_t.$ext";
    #$file->{video_preview_url}="$file->{video_img_folder}/$file->{real}_p.mp4";
    
    $file->{image_file_url}="$file->{video_img_folder}/$file->{real}.$ext";
    push @list, $file->{video_img_url}, $file->{video_thumb_url}, $file->{spectrogram_url}, $file->{wave1_url};
    if($c->{m_x} && $file->{file_screenlist})
    {
		$file->{img_screenlist}       = "$file->{video_img_folder}/$file->{real}_x.jpg";
		$file->{img_screenlist_thumb} = "$file->{video_img_folder}/$file->{real}_xt.jpg";
		push @list, $file->{img_screenlist}, $file->{img_screenlist_thumb};
    }
    if($c->{m_z})
    {
    	$file->{img_timeslide_url} = "$file->{video_img_folder}/$file->{real}0000.jpg";
    	push @list, $file->{img_timeslide_url};
    }

    $file->{player_img} = $file->{video_img_url};
    $file->{player_img} = $file->{img_screenlist_thumb} if $file->{img_screenlist_thumb} && $c->{player_image} eq 'screenlist';
    $file->{player_img} = $file->{img_timeslide_url} if $file->{img_timeslide_url} && $c->{player_image} eq 'timeslider';

    return \@list;
}

sub saveUserData
{
  my ($self,$name,$value,$usr_id) = @_;
  $usr_id||=$self->getUserId;
  if($value eq '' || !defined($value))
  {
   $self->db->Exec("DELETE FROM UserData WHERE usr_id=? AND name=? LIMIT 1", $usr_id, $name);
  }
  else
  {
   utf8::decode($value);
   $value=~s/[^\w\-\+\^\$\&\*\!\?\'\_\+\~\,\.\:\%\#\s\|]//g;
   utf8::encode($value);
   $value||='';
   $self->db->Exec("INSERT INTO UserData SET usr_id=?,name=?,value=? ON DUPLICATE KEY UPDATE value=?", $usr_id, $name, $value, $value);
  }
}

sub getDomain
{
   my ($self, $str) = @_;
   $str=~s/^https?:\/\///i;
   $str=~s/^www\.//i;
   $str=~s/\/.+$//;
   $str=~s/[\/\s]+//g;
   return($str);
}

sub amessage
{
    my ($self,$err) = @_;
    return unless $err;
    print"Content-type:text/html\n\n$err";
    return 0;
}

sub SendMailMailgun
{
   my ($self, $mail_to, $mail_from, $subject, $body) = @_;
   require HTTP::Request::Common;
   require LWP::UserAgent;
   my $ua = LWP::UserAgent->new(timeout => 15);
   my ($body_text,$body_html)=('','');
   if ($c->{email_html}){$body_html=$body;} else {$body_text=$body;}
   my $req = HTTP::Request::Common::POST( $c->{mailgun_api_url},
	[	"from" => $mail_from, 
		"to" => $mail_to, 
		"subject" => $subject, 
		"text" => $body_text,
		"html" => $body_html ]);
	$req->authorization_basic('api', $c->{mailgun_api_key});
	my $res = $ua->request($req)->content;
    print STDERR "Mail ERROR: $res" unless $res=~/Queued\./i;
}

sub genPasswdHash
{
   require PBKDF2::Tiny;
   require MIME::Base64;

   my ($self,$pass) = @_;
   my $turns = 1000;
   my $salt = join('', map { chr( rand(256) ) } (1..24));
   my $data = PBKDF2::Tiny::derive('SHA-256', $pass, $salt, $turns);
   my $hash = sprintf("sha256:%d:%s:%s",
      $turns,
      MIME::Base64::encode_base64($salt, ''),
      MIME::Base64::encode_base64($data, ''));

   return $hash;
}

sub checkPasswdHash
{
	my ($self, $password) = @_;
	if($self->{user}->{usr_password} =~ /^sha256:/)
	{
	  require MIME::Base64;
	  require PBKDF2::Tiny;
	  my ($algo, $turns, $salt, $data) = split(/:/, $self->{user}->{usr_password});
	  return 0 unless PBKDF2::Tiny::verify( MIME::Base64::decode_base64($data), 'SHA-256', $password, MIME::Base64::decode_base64($salt), $turns );
	}
	else
	{
	  my $check_pass = $self->db->SelectOne("SELECT DECODE(usr_password, ?) FROM Users WHERE usr_id=?", $c->{pasword_salt}, $self->{user}->{usr_id});
	  return 0 unless $check_pass eq $password;
	}
	return 1;
}

sub normalizeDate
{
	my ($self,$expires) = @_;
	my @MON  = qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
	my @WDAY = qw( Sun Mon Tue Wed Thu Fri Sat );
	 
	my %term = (
	    's' => 1,
	    'm' => 60,
	    'h' => 3600,
	    'd' => 86400,
	    'M' => 86400 * 30,
	    'y' => 86400 * 365,
	);

    my $expires_at;
    if ($expires =~ /^\d+$/) {
        $expires_at = $expires;
    }
    elsif ( $expires =~ /^([-+]?(?:\d+|\d*\.\d*))([smhdMy]?)/ ) {
        no warnings;
        my $offset = ($term{$2} || 1) * $1;
        $expires_at = time + $offset;
    }
    elsif ( $expires  eq 'now' ) {
        $expires_at = time;
    }
    else {
        return $expires;
    }
    my($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime($expires_at);
    $year += 1900;
    return sprintf("%s, %02d-%s-%04d %02d:%02d:%02d GMT",
                   $WDAY[$wday], $mday, $MON[$mon], $year, $hour, $min, $sec);

}

sub getCaptionsLinks
{
	my ($self,$file) = @_;
	my $lnghash;
    for(split /\s*\,\s*/, $c->{srt_auto_langs})
    {
    	/(\w+)=(\w+)/;
    	$lnghash->{$1}=$2;
    }
	my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
	
	my @arr = map{{language=>$_, title=>$lnghash->{$_}, url=>"$file->{srv_htdocs_url}/vtt/$file->{disk_id}/$dx/$file->{file_code}_$_.vtt"}} split(/\|/, $file->{file_captions});

	if($c->{srt_allow_anon_upload})
	{
		my $dir = "$c->{site_path}/srt/$dx";
		my $srt_cook = $self->getCookie("srt_cook");
		for(keys %$lnghash)
		{
			push @arr, { url => "/srt/$dx/$file->{file_code}_$_.vtt", language=>$_, main => "$file->{file_code}_$_.vtt", title => "$lnghash->{$_}" } 
				if -f "$dir/$file->{file_code}_$_.vtt";
			push @arr, { url => "/srt/$dx/$file->{file_code}_$_.srt", language=>$_, main => "$file->{file_code}_$_.srt", title => "$lnghash->{$_}" } 
				if -f "$dir/$file->{file_code}_$_.srt";
			push @arr, { url => "/srt/$dx/$file->{file_code}_$_\_$srt_cook.vtt", language=>$_, main => "$file->{file_code}_$_\_$srt_cook.vtt", title => "My: $lnghash->{$_}" } 
				if -f "$dir/$file->{file_code}_$_\_$srt_cook.vtt";
		}
	}

	while($ENV{REQUEST_URI}=~/c(\d)_file=(.+?)[$\&]/ig)
	{
		my ($x,$srt)=($1,$2);
		my ($srtname)=$ENV{REQUEST_URI}=~/c$x\_label=(\w+)/i;
		$srtname||='English';
		$srt=~s/https:\/\//$c->{site_url}\/proxy\//;
		push @arr, { url => $srt, language=>'eng', title => $srtname }
	}

	return \@arr;
}

sub loadUserData
{
	my ($self,$user) = @_;
	$user||=$self->{user};
	my $data = $self->db->SelectARef("SELECT * FROM UserData WHERE usr_id=?",$user->{usr_id});
	$user->{$_->{name}}=$_->{value} for @$data;
	$user->{data_loaded} = 1;
}

sub checkModSpecialRights
{
	my ($self,$mod,$user) = @_;
	return 0 unless $c->{$mod};
	$user ||= $self->getUser;
	my $user_field = {
		'm_b' => 'usr_website',
		'm_e' => 'usr_effects',
		'm_f' => 'usr_ftp',
		'm_n' => 'usr_clone',
		'm_q' => 'usr_streams',
		'm_s' => 'usr_snapshot',
		'm_t' => 'usr_torrent',
		'm_v' => 'usr_watermark',
		'm_6' => 'usr_api',
		'm_9' => 'usr_ads',
		'm_y' => 'usr_domains',
	}->{$mod};
	return 1 if $c->{"$mod\_users"} eq 'admin' && $user->{usr_adm};
    return 1 if $c->{"$mod\_users"} eq 'special' && ( $user->{data_loaded} ? $user->{$user_field} : $self->db->SelectOne("SELECT value FROM UserData WHERE usr_id=? AND name=?",$user->{usr_id},$user_field) );
    return 1 if $c->{"$mod\_users"} eq 'premium' && $user->{premium};
    return 1 if $c->{"$mod\_users"} eq 'registered' && $user->{usr_id};
    return 1 if $c->{"$mod\_users"} eq 'all';
    return 0;
}

sub genIPLogic
{
	my ($self,$ip) = @_;

	$ip ||= $self->getIP;
		
	if($self->{ipv6})
	{
		$ip = $self->{ipv6};
		$ip=~s/^(\w+)\:(\w+)\:(\w+)\:(\w+)\:.+$/$1:$2:$3:$4/;
	}
	else
	{
		$ip=~s/^(\d+)\.(\d+)\..+$/$1.$2/;
	}

	my $nocheck=1 if $c->{ip_check_logic} eq '';
	$nocheck=1 if $c->{no_ipcheck_countries} && $self->getMyCountry=~/^($c->{no_ipcheck_countries})$/;
	$nocheck=1 if $self->{no_ip_check};
	my $ip1 = $ip;
	if($nocheck)
	{
		$ip1=$ip='0.0';
	}
	elsif($c->{ip_check_logic} eq 'no_mobiles' && $self->isMobile)
	{
		$ip1=$ip='0.1';
	}
	elsif($c->{ip_check_logic} eq 'no_ipv6' && $self->{ipv6})
	{
		$ip1=$ip='0.2';
	}
	elsif($c->{ip_check_logic} eq 'agent')
	{
		$ip='0.3';
		$ip1="$ENV{HTTP_ACCEPT_LANGUAGE}|$ENV{HTTP_USER_AGENT}";
	}
	elsif($c->{ip_check_logic} eq 'asn')
	{
		$ip='0.4';
		$ip1="$ENV{HTTP_X_ASN}";
	}

	return ($ip1, $ip);
}

sub genDirectLink
{
	my ( $self, $file, $quality, $fname ) = @_;

	my $dx = sprintf("%05d",($file->{file_real_id}||$file->{file_id})/$c->{files_per_folder});
	my $watch_speed = $c->{"watch_speed_$quality"} || $c->{watch_speed_h} || $c->{watch_speed_n};
	if($c->{"watch_speed_auto_$quality"} && $file->{file_length})
	{
		$watch_speed = int 1.4*$file->{"file_size_$quality"}/$file->{file_length}/1024;
	}
	my $speed = $file->{download} ? $c->{down_speed} : $watch_speed;

	$speed = $self->{transfer_speed} if $self->{transfer_speed};

	my ($ip1,$ip) = $self->genIPLogic( $self->getIP );

	my $expire = $c->{symlink_expire}*60*60;
	my $time = time;
	require Digest::SHA;
	my $token = Digest::SHA::hmac_sha256_base64("$ip1|$time|$expire|$file->{file_real}|$quality|$speed", $c->{dl_key});
	$token=~tr/\+\//\-\_/;

	$fname||="v.mp4";

	return "$file->{srv_htdocs_url}/v/$file->{disk_id}/$dx/$file->{file_real}_$quality/$fname?t=$token&s=$time&e=$expire&f=$file->{file_id}&sp=$speed&i=$ip";
}

sub genHLSLink
{
	my ( $self, $file, $play ) = @_;
	return '' unless $c->{m_r};

	my @arr;
	for (@{$c->{quality_letters}},'o','p')
	{
		push @arr, "$file->{file_real}_$_" if $play->{$_};
	}

	my $cch;
	push @arr,  map{"lang/$_/$file->{file_code}_$_"} grep{!$cch->{$_}++} split(/\|/, $file->{file_captions});
	my ($pre,$sources) = $file->{file_captions} ? $self->makeURLSetLong(@arr) : $self->makeURLSet(@arr);
	return '' unless $sources;
	$sources = "$pre$sources,.urlset" if $pre;
	my $dx = sprintf("%05d",($file->{file_real_id}||$file->{file_id})/$c->{files_per_folder});
	
	my ($ip1,$ip) = $self->genIPLogic( $self->getIP );

	my $hlsextra;
	my $hls_speed = $c->{hls_speed} ? $c->{hls_speed} : 0;
	$hlsextra .= "&sp=$hls_speed";
	$hlsextra .= "&fr=$file->{file_real}" if $file->{file_captions};
	$hlsextra .= "&asn=$ENV{HTTP_X_ASN}" if $c->{ip_check_logic} eq 'asn';
	
	my $expire = $c->{symlink_expire}*60*60;
	my $time = time;
	
	require Digest::SHA;
	my $token = Digest::SHA::hmac_sha256_base64("$ip1|$time|$expire|$file->{file_real}|$hls_speed", $c->{dl_key});
	
	$token=~tr/\+\//\-\_/;
	my $hls_proxy_percent = $c->{hls_proxy_percent};
	$hls_proxy_percent=$1 if $file->{host_notes}=~/HLSCACHED=(\d+)/i;
	my $do_proxy = $c->{m_r} && $sources && $c->{hls_proxy} && int(rand 100)<$hls_proxy_percent ? 1 : 0;
	$do_proxy=0 if $file->{host_out} < $c->{hls_proxy_min_out};
	$do_proxy=0 if $file->{file_views} < $c->{hls_proxy_min_views};
	$do_proxy=0 if $c->{hls_proxy_last_hours} && $file->{last_view_sec} > $c->{hls_proxy_last_hours}*60*60;
	$do_proxy=0 if $file->{srv_type} && $file->{srv_type} ne 'STORAGE';
	my $hls_url;
	if($do_proxy)
	{
		my $sortout = $c->{hls_proxy_random_chance} && int(rand 100)>$c->{hls_proxy_random_chance} ? 'ROUND(20*h.host_out/h.host_net_speed),' : '';
		my $filter_host='';
		my $proxylist = $self->db->SelectARef("SELECT p.host_id, host_out/(host_net_speed+1) as x FROM Proxy2Files p, Hosts h WHERE p.file_id=? AND p.host_id = h.host_id ORDER BY x",$file->{file_real_id});
		my $proxy_limit = $file->{owner_premium} ? $c->{proxy_num_prem} : $c->{proxy_num_reg};
		$proxy_limit||=1;
		if($proxylist && $#$proxylist>=$proxy_limit-1 && $proxylist->[0]->{x}<0.9)
		{
			my $pids = join ',', map{$_->{host_id}} @$proxylist;
			$filter_host="AND h.host_id IN ($pids)";
		}
		my $proxy = $self->db->SelectRowCached(30,"SELECT * FROM Hosts h WHERE h.host_proxy=1 $filter_host ORDER BY $sortout RAND() LIMIT 1");
		
		my $pdom = $proxy->{host_htdocs_url};
		$pdom=~s/^https?:\/\///i;
		$pdom=~s/^([\w\-]+)\..+/$1/i;
		$hlsextra.="&p1=$pdom&p2=$pdom";

		my $srv = $file->{srv_htdocs_url};
		$srv=~s/^https?:\/\///i;
		$srv=~s/^(\w+)\..+/$1/i;
		
		if($proxy)
		{
			$self->db->Exec("INSERT INTO Proxy2Files SET file_id=?,host_id=? ON DUPLICATE KEY UPDATE created=NOW()", $file->{file_real_id}, $proxy->{host_id} );
			$hls_url = "$proxy->{host_htdocs_url}/hls2/$file->{disk_id}/$dx/$sources/master.m3u8?t=$token&s=$time&e=$expire&f=$file->{file_id}&srv=$srv&i=$ip$hlsextra";
		}
	}
	
	$hls_url ||= "$file->{srv_htdocs_url}/hls2/$file->{disk_id}/$dx/$sources/master.m3u8?t=$token&s=$time&e=$expire&f=$file->{file_id}&i=$ip$hlsextra" if $sources;
	return $hls_url;
}

sub makeURLSet
{
	my ($self,@l) = @_;
	my $i=0;
	for my $k (0..length($l[0]))
	{
		for (1..$#l){
			$i=$k if substr($l[0],$k,1) ne substr($l[$_],$k,1);
		}
		last if $i;
	}
	my $pre = substr($l[0],0,$i);
	substr($_,0,$i)='' for @l;
	$pre.=',' if $pre;
	return ( $pre, join(',',@l) );
}

sub makeURLSetLong
{
	my ($self,@l) = @_;
	my $pre = ',';
	return ( $pre, join(',',@l) );
}

# Get file in download page by file CODE
sub getFileRecord
{
	my ($self, $file_code) = @_;
	my $file = $self->db->SelectRowCachedKey("filedl$file_code",120,"SELECT f.*,s.*,h.*,u.*,u.usr_login as file_usr_login,DATE_FORMAT(file_created,'%b %e, %Y') as file_created_txt,UNIX_TIMESTAMP(usr_premium_expire) - UNIX_TIMESTAMP() as exp_sec,UNIX_TIMESTAMP() - UNIX_TIMESTAMP(file_last_download) as last_view_sec FROM (Files f, Servers s, Hosts h) LEFT JOIN Users u ON f.usr_id = u.usr_id WHERE f.file_code=? AND f.srv_id=s.srv_id AND s.host_id=h.host_id",$file_code);
	if($file)
	{
		$file->{owner_type} = $file->{exp_sec}>0 ? 'prem' : 'reg';
		$file->{owner_premium} = $file->{exp_sec}>0 ? 1 : 0;
	}
	return $file;
}

# Get file in download page by ID
sub getFileRecord2
{
	my ($self, $file_id) = @_;
	my $file = $self->db->SelectRowCachedKey("filedl$file_id",120,"SELECT f.*,s.*,h.*,u.*,u.usr_login as file_usr_login,DATE_FORMAT(file_created,'%b %e, %Y') as file_created_txt,UNIX_TIMESTAMP(usr_premium_expire) - UNIX_TIMESTAMP() as exp_sec,UNIX_TIMESTAMP() - UNIX_TIMESTAMP(file_last_download) as last_view_sec FROM (Files f, Servers s, Hosts h) LEFT JOIN Users u ON f.usr_id = u.usr_id WHERE f.file_id=? AND f.srv_id=s.srv_id AND s.host_id=h.host_id",$file_id);
	if($file)
	{
		$file->{owner_type} = $file->{exp_sec}>0 ? 'prem' : 'reg';
		$file->{owner_premium} = $file->{exp_sec}>0 ? 1 : 0;
	}
	return $file;
}

sub getPlayVersions
{
	my ($self, $file) = @_;
	my ($play,$playprem);
	for my $q (@{$c->{quality_letters}})
	{
		$play->{$q}=1		if $file->{"file_size_$q"} && $c->{"vid_play_$self->{utype}_$q"};
		$playprem->{$q}=1	if $file->{"file_size_$q"} && $c->{"vid_play_prem_$q"};
	}
	$play->{o}=1		if $file->{"file_size_o"} && $self->webPlayable($file) && ($c->{"vid_play_$self->{utype}_o"} || !keys %$play);
	$playprem->{o}=1	if $file->{"file_size_o"} && $self->webPlayable($file) && ($c->{"vid_play_prem_o"} || !keys %$play);

	if($play->{n} || $play->{l})
	{
		my $disable_hd=1 if $c->{overload_no_hd} && $file->{host_out} > $file->{host_net_speed}*0.9;
		$disable_hd=1 if $self->f->{embed} && $c->{embed_no_hd};
		$play->{o}=$play->{x}=$play->{h} = 
		$playprem->{o}=$playprem->{x}=$playprem->{h} = 0 if $disable_hd;
	}
	return ($play, $playprem);
}

sub webPlayable
{
    my ($self, $file, $q) = @_;
    $q||='o';
    my $spec = $file->{"file_spec_$q"};
    return 1 if $file->{"file_size_$q"} && $spec=~/h264|aac|mp3|mp4|m4a|wav|flac|ogg$/i;
    return 0;
}

sub cloneFile
{
	my ($self, $file, $fld_id) = @_;

	my $code = $self->randchar(12);
	while($self->db->SelectOne("SELECT file_id FROM Files WHERE file_code=?",$code)){$code = $self->randchar(12);}

	$self->db->Exec("INSERT INTO Files SET file_name=?,file_title=?,usr_id=?,srv_id=?,srv_id_copy=?,file_fld_id=?,file_descr=?,file_public=?,file_adult=?,file_code=?,file_real=?,file_real_id=?,file_size=?,file_size_o=?,file_size_n=?,file_size_h=?,file_size_l=?,file_size_p=?,file_size_x=?,file_ip=INET_ATON(?),file_md5=?,file_spec_o=?,file_spec_n=?,file_spec_h=?,file_spec_l=?,file_spec_p=?,file_spec_x=?,file_length=?,cat_id=?,file_status=?,file_screenlist=?,file_captions=?,file_created=NOW(),file_last_download=NOW(),video_thumb=?,video_thumb_t=?,audio_thumb=?,audio_artist=?,audio_title=?,audio_album=?,audio_genre=?",$file->{file_name},$file->{file_title},$self->getUserId,$file->{srv_id},$file->{srv_id_copy},$fld_id||0,$file->{file_descr}||'',$self->f->{file_public}||0,$self->f->{file_adult}||0,$code,$file->{file_real},$file->{file_real_id}||$file->{file_id},$file->{file_size},$file->{file_size_o},$file->{file_size_n},$file->{file_size_h},$file->{file_size_l},$file->{file_size_p},$file->{file_size_x},$self->getIP,$file->{file_md5},$file->{file_spec_o}||'',$file->{file_spec_n}||'',$file->{file_spec_h}||'',$file->{file_spec_l}||'',$file->{file_spec_p}||'',$file->{file_spec_x}||'',$file->{file_length},$self->f->{cat_id}||$file->{cat_id},'OK',$file->{file_screenlist},$file->{file_captions},$file->{video_thumb},$file->{video_thumb_t},$file->{audio_thumb},$file->{audio_artist},$file->{audio_title},$file->{audio_album},$file->{audio_genre});

	my $file_id = $self->db->getLastInsertId;

	$self->db->Exec("UPDATE Users SET usr_files_used=usr_files_used+1 WHERE usr_id=?",$self->getUserId);

	if($c->{srt_on})
	{
		my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
		my $res = $self->api2($file->{srv_id}, {  op => 'srt_clone',   file_code => $file->{file_code},   file_code_new => $code,   dx => $dx,   languages => $file->{file_captions}, });
	}

	return ($file_id, $code);
}

sub logFile
{
	my ($self, $file_real, $event) = @_;
	$self->db->Exec("INSERT INTO FileLogs SET file_real=?, event=?", $file_real, $event );
}

sub checkEventRate
{
	my ($self, $usr_id, $name, $limit) = @_;
	my $num = $self->db->SelectOne("SELECT value FROM StatsMiscMin WHERE usr_id=? AND minute=DAYOFYEAR(NOW())*24*60 + HOUR(NOW())*60 + MINUTE(NOW()) AND name=?", $usr_id, $name)||0;
	return $num if $num >= $limit;
	$self->db->Exec("INSERT INTO StatsMiscMin SET usr_id=?, minute=DAYOFYEAR(NOW())*24*60 + HOUR(NOW())*60 + MINUTE(NOW()), name=?, value=1 ON DUPLICATE KEY UPDATE value=value+1", $usr_id, $name);
	return $num;
}

package Session::PluginsList;
use lib '.';
use XFileConfig;

sub new {
  my ($class, $list) = @_;
  my $self = {};
  $self->{list} = $list;
  bless($self);
}

sub AUTOLOAD {
  use vars qw($AUTOLOAD);
  my ($self, @args) = @_;
  ( my $method = $AUTOLOAD ) =~ s{.*::}{};

  my @ret;
  foreach my $plg(@{ $self->{list} }) {
    print STDERR "Trying method: $plg\::$method\n" if $c->{debug} >= 2;
    my @result = wantarray() ? $plg->$method(@args) : scalar($plg->$method(@args));
    print STDERR "Method OK: $plg\::$method\n" if $c->{debug} && $result[0];
    return $result[0] if $result[0] && !wantarray();
    push @ret, grep {$_} @result;
  }
  print STDERR "No methods found: $method\n" if $c->{debug} && !@ret;
  return @ret;
}

sub DESTROY {
}

1;
