#!/usr/bin/perl
use strict;
use lib '.';
use XFileConfig;
use Session;
use CGI::Carp qw(fatalsToBrowser);
use XUtils;

my $ses = Session->new();
my $f = $ses->f;
my $op = $f->{op};
$ses->{adm} = 1;


my $db= $ses->db;

XUtils::CheckAuth($ses);

$ses->redirect($c->{site_url}) unless $ses->getUser && $ses->getUser->{usr_adm};

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
    $ses->message("You can't login from this IP.");
  }
}

unless($ses->checkToken)
{
	my $url = "$c->{site_url}/adm?";
	my @vars;
	for(grep{$_!~/^(token)$/i} keys %$f)
	{
		push @vars, "$_=$f->{$_}";
	}
	push @vars, "token=".$ses->genToken;
	$url .= $ses->SecureStr( join '&', @vars );
	return $ses->PrintTemplate("secure_link.html", url => $url, margin=>int(rand(100)) );
}

my $utype = $ses->getUser ? ($ses->getUser->{premium} ? 'prem' : 'reg') : 'anon';

$c->{$_}=$c->{"$_\_$utype"} for qw(max_upload_files
                                   disk_space
                                   max_upload_filesize
                                   download_countdown
                                   captcha
                                   ads
                                   bw_limit
                                   remote_url
                                   direct_links
                                   down_speed
                                   max_rs_leech
                                   add_download_delay
                                   max_download_filesize
                                   torrent_dl_slots
                                   video_embed
                                   video_dl_orig
                                   fullscreen
                                   pre_download
                                   queue_url
                                   queue_url_max
                                   upload_enabled
                                   );

my $sub={
    file_edit        => \&FileEdit,
    admin_files      => \&AdminFiles,
    admin_files_deleted => \&AdminFilesDeleted,
    admin_users      => \&AdminUsers,
    admin_user_edit  => \&AdminUserEdit,
    admin_users_add  => \&AdminUsersAdd,
    admin_servers    => \&AdminServers,
    admin_server_add => \&AdminServerAdd,
    admin_server_save=> \&AdminServerSave,
    admin_server_del => \&AdminServerDelete,
    admin_settings   => \&AdminSettings,
    admin_news       => \&AdminNews,
    admin_news_edit  => \&AdminNewsEdit,
    admin_reports    => \&AdminReports,
    admin_server_import     => \&AdminServerImport,
    admin_mass_email => \&AdminMassEmail,
    admin_views      => \&AdminViews,
    admin_comments   => \&AdminComments,
    admin_payouts    => \&AdminPayouts,
    admin_payouts_history => \&AdminPayoutsHistory,
    admin_stats      => \&AdminStats,
    admin_torrents      => \&AdminTorrents,
    admin_anti_hack     => \&AdminAntiHack,
    admin_user_referrals=> \&AdminUserReferrals,
    admin_ipn_logs      => \&AdminIPNLogs,
    admin_enc_list      => \&AdminEncList,
    admin_transfer_list => \&AdminTransferList,
    admin_url_list      => \&AdminURLList,
    admin_servers_transfer => \&AdminServersTransfer,
    admin_host_edit     => \&AdminHostEdit,
    admin_host_save     => \&AdminHostSave,
    admin_categories    => \&AdminCategories,
    admin_category_form => \&AdminCategoryForm,
    admin_transactions  => \&AdminTransactions,
    admin_user_reports  => \&AdminUserReports,
    admin_users_monitor => \&AdminUsersMonitor,
    admin_sql_stats     => \&AdminSQLStats,
    admin_websites      => \&AdminWebsites,
    moderator_files_approve => \&ModeratorFilesApprove,
    admin_files_featured    => \&AdminFilesFeatured,
    admin_login_history     => \&AdminLoginHistory,
    admin_login_as          => \&LoginAsUser,
    admin_languages         => \&AdminLanguages,
    admin_language_form     => \&AdminLanguageForm,
    admin_translations      => \&AdminTranslations,
    admin_tags              => \&AdminTags,
    admin_high_bw_files     => \&AdminHighBWFiles,
    admin_misc              => \&AdminMisc,
    admin_external          => \&AdminExternal,
    admin_top_ips           => \&AdminTopIPs,
    admin_top_users			=> \&AdminTopUsers,
    admin_streams			=> \&AdminStreams,
    admin_ipblock_stats		=> \&AdminIPBlockStats,
    admin_ftp				=> \&AdminFTP,
    admin_decode_hash		=> \&AdminDecodeHash,
	 }->{ $op };

if($ENV{HTTP_REFERER} && $sub && !$ses->{ref_ok} && $op!~/(admin_torrents)/)
{
   my ($dm)=$ENV{HTTP_REFERER}=~/\/\/([^\/]+)/;
   $dm=~s/^www\.//;
   $dm=~s/:.*$//;
   my $pass = 1 if $ses->{domain} eq $dm;
   print("Content-type:text/html\n\nGo to <a href='$ENV{REQUEST_URI}'>http://$ses->{domain}$ENV{REQUEST_URI}</a>"),exit unless $pass;
}

if($sub && $ses->getUser)
{
   $ses->message("Access denied") if $op=~/^admin_/i && !$ses->getUser->{usr_adm} && $op!~/^(admin_reports|admin_comments)$/i;
   &$sub;
}
elsif($sub)
{
   $f->{redirect}=$ENV{REQUEST_URI};
   &LoginPage;
}
else
{
   $ses->message("Undefined operation");
}

sub X1
{
  return $ses->message("IP:".$ses->getIP);
}

sub ResendActivationCode
{
   my ($adm_mode) = @_;
   sleep(1) unless $adm_mode;
   ($f->{usr_id},$f->{usr_login}) = split(/-/,$f->{d});
   my $user = $db->SelectRow("SELECT usr_id,usr_login,usr_email,usr_security_lock,DECODE(usr_password,?) as usr_password
                              FROM Users
                              WHERE usr_id=?
                              AND usr_login=?",
                              $c->{pasword_salt},$f->{usr_id},$f->{usr_login});
   sleep(3) && $ses->message("Invalid ID") unless $user;

   my $t = $ses->CreateTemplate("registration_email.html");
   $t->param( 'usr_login'=>$user->{usr_login}, 'usr_password'=>$user->{usr_password}, 'confirm_id'=>"$user->{usr_id}-$user->{usr_security_lock}" );
   $c->{email_text}=1;
   $ses->SendMailQueue($user->{usr_email}, $c->{email_from}, "$c->{site_name} registration confirmation", $t->output);
   $ses->redirect_msg("?op=admin_users","Activation email sent") if $adm_mode;
   $ses->message("Activation email just resent.<br>To activate it follow the activation link sent to your e-mail.");
}

sub Msg
{
    $ses->message(" ");
}

sub AdminViews
{
   my $filter_user = "AND i.usr_id=$f->{usr_id}" if $f->{usr_id}=~/^\d+$/;
   my $filter_owner = "AND i.owner_id=$f->{owner_id}" if $f->{owner_id}=~/^\d+$/;
   my $filter_ip = "AND i.ip=INET_ATON('$f->{ip}')" if $f->{ip}=~/^[\d\.]+$/;
   my $filter_file = "AND i.file_id=$f->{file_id}" if $f->{file_id}=~/^\d+$/;
   my $filter_key = "AND i.referer LIKE '%$f->{key}%'" if $f->{key};
   my $filter_fin = "AND i.finished=1" if $f->{finished};
   my $filter_money = "AND i.money>0" if $f->{money};
   my $filter_dl = $f->{download} ? "AND i.download=1" : "AND i.download=0";
   my $filter_country = "AND i.country='$f->{country}'" if $f->{country}=~/^\w\w$/;
   my $filter_last_hours = "AND i.created > NOW()-INTERVAL $f->{last_hours} HOUR" if $f->{last_hours}=~/^\d+$/;
   if($f->{file_code})
   {
   		my $file_id = $db->SelectOne("SELECT file_id FROM Files WHERE file_code=?",$f->{file_code});
   		$filter_file = "AND i.file_id=$file_id" if $file_id;
   }
   $f->{per_page}||=100;

   my $list = $db->SelectARef("SELECT i.*, INET_NTOA(i.ip) as ip
                               FROM Views i
                               WHERE 1
                               $filter_fin
                               $filter_user
                               $filter_owner
                               $filter_ip
                               $filter_file
                               $filter_key
                               $filter_money
                               $filter_dl
                               $filter_country
                               $filter_last_hours
                               ORDER BY created DESC".$ses->makePagingSQLSuffix($f->{page}));

   my $total = $db->SelectOne("SELECT COUNT(*)
                               FROM Views i
                               WHERE 1
                               $filter_fin
                               $filter_user
                               $filter_owner
                               $filter_ip
                               $filter_file
                               $filter_key
                               $filter_money
                               $filter_dl
                               $filter_country
                               $filter_last_hours
                              ");

   my $fids = join ',', map{$_->{file_id}} @$list;
   my $files = $db->SelectARef("SELECT file_id, file_code, file_name FROM Files WHERE file_id IN ($fids)") if $fids;
   my ($fh1,$fh2);
   for(@$files)
   {
     $fh1->{$_->{file_id}} = $_->{file_code};
     $fh2->{$_->{file_id}} = $_->{file_name};
   }

   for(@$list)
   {
      $_->{file_code} = $fh1->{$_->{file_id}};
      $_->{file_name} = $fh2->{$_->{file_id}};
      $_->{download_link} = $ses->makeFileLink($_);

      $_->{money}= $_->{money} eq '0.0000' ? '' : "\$$_->{money}";
      $_->{money}=~s/0+$//;
      $_->{money}=~s/\.$//;
      $_->{size} = sprintf("%.0f", $_->{size}/1024**2 );
   }
   if($c->{resolve_ip_country})
    {
        $_->{country} ||= $ses->getCountryCode($_->{ip}) for @$list;
    }
   $ses->PrintTemplate("admin_views.html",
                       list      =>$list,
                       usr_login => $f->{usr_login},
                       owner_id	 => $f->{owner_id},
                       file_code => $f->{file_code},
                       ip        => $f->{ip},
                       key       => $f->{key},
                       finished  => $f->{finished},
                       download  => $f->{download},
                       country	 => $f->{country},
                       last_hours => $f->{last_hours},
                       paging    => $ses->makePagingLinks($f,$total),
                       maincss      => 1,
                      );
}

sub AdminEncList
{
   if($f->{cancel} && $f->{file_real})
   {
      for (@{ARef($f->{file_real})})
      {
         /^(\w+)-(\w)$/;
         $db->Exec("DELETE FROM QueueEncoding WHERE file_real=? AND quality=? LIMIT 1",$1,$2);
      }
      $ses->redirect('?op=admin_enc_list');
   }
   if($f->{priority_up} && $f->{file_real})
   {
      for (@{ARef($f->{file_real})})
      {
         /^(\w+)-(\w)$/;
        $db->Exec("UPDATE QueueEncoding 
                   SET priority=priority+1
                   WHERE file_real=? AND quality=? LIMIT 1",$1,$2);
      }
      $ses->redirect('?op=admin_enc_list');
   }
   if($f->{restart} && $f->{file_real})
   {
      for (@{ARef($f->{file_real})})
      {
         /^(\w+)-(\w)$/;
        $db->Exec("UPDATE QueueEncoding 
                   SET status='PENDING',
                       progress=0,
                       fps=0,
                       error='',
                       started='0000-00-00 00:00:00',
                       updated='0000-00-00 00:00:00',
                       extra='reencode=1'
                   WHERE file_real=? AND quality=? LIMIT 1",$1,$2);
      }
      $ses->redirect('?op=admin_enc_list');
   }
   if($f->{delete} && $f->{file_real})
   {
      for (@{ARef($f->{file_real})})
      {
         /^(\w+)-(\w)$/;
         my $file = $db->SelectRow("SELECT * FROM Files WHERE file_real=?",$1);
         next unless $file;
         $ses->DeleteFile($file);
      }
      $ses->redirect('?op=admin_enc_list');
   }
   if($f->{restart_stuck})
   {
      $db->Exec("UPDATE QueueEncoding 
                 SET status='PENDING',
                     progress=0,
                     fps=0,
                     error='',
                     started='0000-00-00 00:00:00',
                     updated='0000-00-00 00:00:00',
                     extra='reencode=1'
                 WHERE status='STUCK'");
      $ses->redirect('?op=admin_enc_list');
   }
   if($f->{restart_errors})
   {
      $db->Exec("UPDATE QueueEncoding 
                 SET status='PENDING',
                     progress=0,
                     fps=0,
                     error='',
                     started='0000-00-00 00:00:00',
                     updated='0000-00-00 00:00:00',
                     extra='reencode=1'
                 WHERE status='ERROR'");
      $ses->redirect('?op=admin_enc_list');
   }
   if($f->{delete_errors})
   {
      $db->Exec("DELETE FROM QueueEncoding 
                 WHERE status='ERROR'");
      $ses->redirect('?op=admin_enc_list');
   }
   if($f->{delete_stuck})
   {
      $db->Exec("DELETE FROM QueueEncoding 
                 WHERE status='STUCK'");
      $ses->redirect('?op=admin_enc_list');
   }
   my $filter_host="AND h.host_id=$f->{host_id}" if $f->{host_id}=~/^\d+$/;
   my $filter_user="AND q.usr_id=$f->{usr_id}" if $f->{usr_id}=~/^\d+$/;

    $f->{per_page}||=500;
    my $order = $c->{enc_priority_time} ? "created, priority DESC" : "priority DESC, created";
    my $list = $db->SelectARef("SELECT q.*, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(q.started) as started2,
                                      UNIX_TIMESTAMP()-UNIX_TIMESTAMP(q.updated) as updated2,
                                      f.file_title, f.file_size, f.usr_id, f.file_code, f.file_name, f.file_length,
                                      h.*, u.usr_login
                               FROM (QueueEncoding q, Files f, Hosts h)
                               LEFT JOIN Users u ON q.usr_id=u.usr_id
                               WHERE q.file_id=f.file_id
                               AND q.host_id=h.host_id
                               $filter_host
                               $filter_user
                               ORDER BY $order
                              ".$ses->makePagingSQLSuffix($f->{page}));
    my $total = $db->SelectOne("SELECT COUNT(*)
                                FROM QueueEncoding q, Hosts h
                                WHERE file_real_id>0
                                AND q.host_id=h.host_id
                                $filter_host
                                $filter_user");

   my ($stucked,$errors);
   for(@$list)
   {
      $_->{site_url} = $c->{site_url};
      $_->{quality} = uc $_->{quality};

      $_->{file_title_txt} = $ses->shortenString( $_->{file_title}||$_->{file_name} );

      $_->{file_size2} = $ses->makeFileSize($_->{file_size});
      $_->{download_link} = $ses->makeFileLink($_);
      $_->{file_length2} = sprintf("%2d:%02d:%02d",int($_->{file_length}/3600),int(($_->{file_length}%3600)/60),$_->{file_length}%60);
      $_->{file_length2}=~s/0+:(\d\d:\d\d)/$1/;
      $_->{file_length2}=~s/0(\d:\d\d)/$1/;
      $_->{premium2}=$_->{premium} if $_->{premium}>1;

      if($_->{started} eq '0000-00-00 00:00:00')
      {
        $_->{started2}='';
      }
      else
      {
        $_->{started2} = $_->{started2}<60 ? "$_->{started2} sec" : ($_->{started2}<7200 ? sprintf("%.0f",$_->{started2}/60).' min' : sprintf("%.0f",$_->{started2}/3600).' hours');
        $_->{started2}.=' ago';
      }
      $_->{qstatus}='<i style="color:green;">[encoding]</i>' if $_->{status} eq 'ENCODING';
      if($_->{status} eq 'STUCK')
      {
         $_->{restart}=1;
         $_->{qstatus}='<i style="color:#c66;">[stuck]</i>';
         $stucked++;
      }
      if($_->{status} eq 'ERROR')
      {
         $_->{restart}=1;
         $_->{qstatus}=qq[<a href="#" onclick="\$('#err$_->{file_real}$_->{quality}').toggle();return false;"><i style="color:#e66;">[error]</i></a><div id='err$_->{file_real}$_->{quality}' style='display:none'>$_->{error}</div>];
         $errors++;
      }
   }

   my $chart1 = $db->SelectARef("SELECT h.host_id, h.host_name, status, COUNT(*) as num, SUM(fps) as fps
   								FROM QueueEncoding q, Hosts h
   								WHERE q.host_id=h.host_id
   								GROUP BY h.host_id, status
   								");

   my $charth;
   for my $x (@$chart1)
   {
     $charth->{$x->{host_id}}->{$x->{status}} += $x->{num};
     $charth->{$x->{host_id}}->{host_name} = $x->{host_name};
     $charth->{$x->{host_id}}->{fps} = $x->{fps} if $x->{status} eq 'ENCODING';
   }
   my @chart;
   for(sort {$a <=> $b} keys %$charth)
   {
      push @chart, {host_id=>$_, %{$charth->{$_}}};
   }

   my $chart_quality = $db->SelectARef("SELECT UPPER(q.quality) as quality, COUNT(*) as num
		                                FROM QueueEncoding q, Hosts h
		                                WHERE q.status='PENDING'
		                                AND q.host_id=h.host_id
		                                $filter_host
                               			$filter_user
		                                GROUP BY q.quality
		                                ORDER BY num DESC
		                                ");

   my $top_users = $db->SelectARef("SELECT u.usr_id, u.usr_login, COUNT(*) as x
                                    FROM QueueEncoding q, Users u
                                    WHERE q.usr_id=u.usr_id
                                    GROUP BY usr_id
                                    ORDER BY x DESC
                                    LIMIT 12
                                    ");
   
   $ses->PrintTemplate("admin_enc_list.html",
                       list => $list, 
                       paging => $ses->makePagingLinks($f,$total),
                       restart_stuck => $stucked,
                       restart_error => $errors,
                       chart => \@chart,
                       top_users => $top_users,
                       chart_quality => $chart_quality,
                       maincss      => 1,
                       );
}

sub AdminTransferList
{
	my $token = $ses->genToken;
	if($f->{restart} && $f->{file_real})
	{
		my $reals = join ',', map{"'$_'"} grep{/^\w{12}$/} @{ARef($f->{file_real})};
		$db->Exec("UPDATE QueueTransfer 
					SET status='PENDING', error='', started='0000-00-00 00:00:00', transferred=0, speed=0 
					WHERE file_real IN ($reals)");
		$ses->redirect('?op=admin_transfer_list');
	}
   if($f->{cancel} && $f->{file_real})
   {
      my $reals = join ',', map{"'$_'"} grep{/^\w{12}$/} @{ARef($f->{file_real})};
      $db->Exec("DELETE FROM QueueTransfer WHERE file_real IN ($reals)");
      $ses->redirect('?op=admin_transfer_list');
   }
   if($f->{delete} && $f->{file_real})
   {
      my $reals = join ',', map{"'$_'"} grep{/^\w{12}$/} @{ARef($f->{file_real})};
      my $files = $db->SelectARef("SELECT * FROM Files WHERE file_real IN ($reals)");
      $ses->DeleteFilesMass($files);
      $ses->redirect('?op=admin_transfer_list');
   }
   if($f->{restart_stucked})
   {
      $db->Exec("UPDATE QueueTransfer
                 SET status='PENDING', error='', started='0000-00-00 00:00:00', transferred=0, speed=0
                 WHERE status='STUCK'");
      $ses->redirect('?op=admin_transfer_list');
   }
   if($f->{delete_stucked})
   {
      $db->Exec("DELETE FROM QueueTransfer
                 WHERE status='STUCK'");
      $ses->redirect('?op=admin_transfer_list');
   }
   if($f->{restart_errors})
   {
      $db->Exec("UPDATE QueueTransfer
                 SET status='PENDING', error='', started='0000-00-00 00:00:00', transferred=0, speed=0
                 WHERE (status='MOVING' OR status='ERROR')
                 AND error<>''");
      $ses->redirect('?op=admin_transfer_list');
   }
   if($f->{delete_errors})
   {
      $db->Exec("DELETE FROM QueueTransfer
                 WHERE (status='MOVING' OR status='ERROR')
                 AND error<>''");
      $ses->redirect('?op=admin_transfer_list');
   }
   my $filter_srv1="AND q.srv_id1=$f->{srv_id1}" if $f->{srv_id1}=~/^\d+$/;
   my $filter_srv2="AND q.srv_id2=$f->{srv_id2}" if $f->{srv_id2}=~/^\d+$/;
   my $list = $db->SelectARef("SELECT q.*, f.*,
                                      UNIX_TIMESTAMP()-UNIX_TIMESTAMP(q.created) as created2,
                                      UNIX_TIMESTAMP()-UNIX_TIMESTAMP(q.updated) as dt,
                                      s1.srv_name as srv_name1, s2.srv_name as srv_name2
                               FROM QueueTransfer q, Files f, Servers s1, Servers s2
                               WHERE q.file_id=f.file_id
                               AND q.srv_id1=s1.srv_id
                               AND q.srv_id2=s2.srv_id
                               $filter_srv1
                               $filter_srv2
                               ORDER BY started DESC, created
                               LIMIT 1000
                              ");
   my ($stucked,$errors);
   for(@$list)
   {
      $_->{site_url} = $c->{site_url};
      $_->{file_title_txt} = $ses->shortenString( $_->{file_title}||$_->{file_name} );
      
      $_->{download_link} = $ses->makeFileLink($_);
      $_->{qstatus}=" <i style='color:green;'>[moving]</i>" if $_->{status} eq 'MOVING';
      if( $_->{status} eq 'STUCK' )
      {
         $stucked++;
         $_->{qstatus}=" <i style='color:#c66;'>[stuck]</i>";
      }
      if( $_->{status}=~/^(ERROR|MOVING)$/ && $_->{error} )
      {
         $errors++;
         $_->{qstatus}=qq[ <a href="#" onclick="\$('#err$_->{file_real_id}').toggle();return false;"><i style="color:#e66;">[error]</i></a><div id='err$_->{file_real_id}' style='display:none'>$_->{error}</div>];
      }
      
      $_->{created2} = $_->{created2}<60 ? "$_->{created2} secs" : ($_->{created2}<7200 ? sprintf("%.0f",$_->{created2}/60).' mins' : sprintf("%.0f",$_->{created2}/3600).' hours');
      $_->{created2}.=' ago';
      $_->{started2}='' if $_->{started} eq '0000-00-00 00:00:00';
      $_->{file_size_o}=0 if $_->{copy};
      for my $q (@{$c->{quality_letters}},'o','p')
      {
      	$_->{file_size_total} += $_->{"file_size_$q"};
      }
      
      $_->{progress} = sprintf("%.0f", 100*$_->{transferred}/$_->{file_size_total} ) if $_->{file_size_total};
      $_->{file_size_total} = sprintf("%.0f MB",$_->{file_size_total}/1024/1024);
      $_->{transferred_mb} = sprintf("%.01f",$_->{transferred}/1024/1024);
   }

   my $listto = $db->SelectARef("SELECT s.srv_id, s.srv_name, q.status, COUNT(*) as num
   								FROM QueueTransfer q, Servers s
   								WHERE q.srv_id2=s.srv_id
   								GROUP BY q.srv_id2, q.status");
   my $chart1;
   for my $x (@$listto)
   {
     $chart1->{$x->{srv_id}}->{$x->{status}} += $x->{num};
     $chart1->{$x->{srv_id}}->{srv_name} = $x->{srv_name};
   }
   my @srv_list_to;
   for(sort {$a <=> $b} keys %$chart1)
   {
      push @srv_list_to, {srv_id=>$_, %{$chart1->{$_}}};
   }

   my $listfrom = $db->SelectARef("SELECT s.srv_id, s.srv_name, q.status, COUNT(*) as num
   								FROM QueueTransfer q, Servers s
   								WHERE q.srv_id1=s.srv_id
   								GROUP BY q.srv_id1, q.status");
   my $chart2;
   for my $x (@$listfrom)
   {
     $chart2->{$x->{srv_id}}->{$x->{status}} += $x->{num};
     $chart2->{$x->{srv_id}}->{srv_name} = $x->{srv_name};
   }
   my @srv_list_from;
   for(sort {$a <=> $b} keys %$chart2)
   {
      push @srv_list_from, {srv_id=>$_, %{$chart2->{$_}}};
   }

   $ses->PrintTemplate("admin_transfer_list.html",
                       list => $list, 
                       stucked => $stucked,
                       errors => $errors,
                       srv_list_to => \@srv_list_to,
                       srv_list_from => \@srv_list_from,
                       maincss      => 1,
                      );
}

sub AdminURLList
{
   if($f->{del_id})
   {
      $db->Exec("DELETE FROM QueueUpload WHERE id=?",$f->{del_id});
      $ses->redirect('?op=admin_url_list');
   }
   if($f->{restart})
   {
      $db->Exec("UPDATE QueueUpload SET status='PENDING',size_dl=0,error='',srv_id=0 WHERE id=? LIMIT 1",$f->{restart});
      $ses->redirect('?op=admin_url_list');
   }
   if($f->{restart_stucked})
   {
      $db->Exec("UPDATE QueueUpload
                 SET status='PENDING',size_dl=0,error=''
                 WHERE status='STUCK'");
      $ses->redirect('?op=admin_url_list');
   }
   if($f->{delete_stucked})
   {
      $db->Exec("DELETE FROM QueueUpload
                 WHERE status='STUCK'");
      $ses->redirect('?op=admin_url_list');
   }
   if($f->{restart_errors})
   {
      $db->Exec("UPDATE QueueUpload
                 SET status='PENDING',size_dl=0,error='',srv_id=0
                 WHERE status='ERROR'");
      $ses->redirect('?op=admin_url_list');
   }
   if($f->{delete_errors})
   {
      $db->Exec("DELETE FROM QueueUpload
                 WHERE status='ERROR'");
      $ses->redirect('?op=admin_url_list');
   }
   $f->{per_page}||=100;
   my $list = $db->SelectARef("SELECT q.*, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(q.started) as started2,
                                      UNIX_TIMESTAMP()-UNIX_TIMESTAMP(q.updated) as updated2,
                                      u.usr_login
                               FROM QueueUpload q
                               LEFT JOIN Users u ON q.usr_id=u.usr_id
                               ORDER BY status DESC, started DESC
                              ".$ses->makePagingSQLSuffix($f->{page}));
   my $total = $db->SelectOne("SELECT COUNT(*) FROM QueueUpload");
   my ($stucked,$errors);
   for(@$list)
   {
      $_->{site_url} = $c->{site_url};
      if($_->{started} eq '0000-00-00 00:00:00')
      {
        $_->{started2}='';
      }
      else
      {
        $_->{started2} = $_->{started2}<60 ? "$_->{started2} secs" : ($_->{started2}<7200 ? sprintf("%.0f",$_->{started2}/60).' mins' : sprintf("%.0f",$_->{started2}/3600).' hours');
        $_->{started2}.=' ago';
      }
      $_->{qstatus}='<i style="color:green;">[uploading]</i>' if $_->{status} eq 'WORKING';
      if($_->{status} eq 'STUCK')
      {
         $_->{restart}=1;
         $_->{qstatus}='<i style="color:#c66;">[stuck]</i>';
         $stucked++;
      }
      if($_->{status}=~/^(WORKING|ERROR)$/ && $_->{error})
      {
         $_->{restart}=1;
         $_->{qstatus}=qq[<a href="#" onclick="\$('#err$_->{id}').toggle();return false;"><i style="color:#e66;">[error]</i></a><div id='err$_->{id}' style='display:none'>$_->{error}</div>];
         $errors++;
      }
      $_->{progress} = $_->{size_full} ? sprintf("%.0f",100*$_->{size_dl}/$_->{size_full}) : 0;
      $_->{size_full} = sprintf("%.0f",$_->{size_full}/1024**2);
      $_->{size_dl}   = sprintf("%.0f",$_->{size_dl}/1024**2);
      $_->{url} = substr($_->{url},0,60).'...' if length($_->{url})>60;
      $_->{error} =~ s/</&lt;/g;
      $_->{error} =~ s/>/&gt;/g;
   }
   
   $ses->PrintTemplate("admin_url_list.html",
                       list => $list,
                       paging => $ses->makePagingLinks($f,$total),
                       stucked => $stucked,
                       errors => $errors,
                       maincss      => 1,
                       );
}

sub AdminFiles
{
   if($f->{del_code})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my $file = $db->SelectRow("SELECT f.*, u.usr_aff_id
                                 FROM Files f 
                                 LEFT JOIN Users u ON f.usr_id=u.usr_id
                                 WHERE file_code=?",$f->{del_code});
      $ses->message("No such file") unless $file;
      $file->{del_money}=$c->{del_money_file_del};
      $ses->DeleteFile($file);
      $ses->redirect("?op=admin_files");
   }
   if(($f->{del_selected} || $f->{del_selected_now}) && $f->{file_id})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      die"security error" unless $ENV{REQUEST_METHOD} eq 'POST';
      my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{file_id})});
      $ses->redirect($c->{site_url}) unless $ids;
      my $files = $db->SelectARef("SELECT * FROM Files WHERE file_id IN ($ids)");
      $_->{del_money}=$c->{del_money_file_del} for @$files;
      $f->{now}=1 if $f->{del_selected_now};
      $ses->DeleteFilesMass($files);
      if($f->{del_info})
      {
         $db->Exec("INSERT INTO DelReasons SET file_code=?, file_name=?, info=?",$_->{file_code},$_->{file_name},$f->{del_info}) for @$files;
      }
      $ses->redirect_msg("?op=admin_files",($#$files+1)." files were deleted");
   }
   if($f->{dmca_selected} && $f->{file_id})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      die"security error" unless $ENV{REQUEST_METHOD} eq 'POST';
      my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{file_id})});
      $ses->redirect($c->{site_url}) unless $ids;
      my $files = $db->SelectARef("SELECT * FROM Files WHERE file_id IN ($ids)");
	  for(@$files)
	  {
		$db->Exec("INSERT IGNORE INTO FilesDMCA SET usr_id=?, file_id=?, del_by_id=?, del_time=NOW()+INTERVAL ? HOUR",
					$_->{usr_id}, $_->{file_id}, $ses->getUserId, $c->{m_a_delete_after} );
		$db->Exec("UPDATE Files SET file_status='LOCKED' WHERE file_id=?",$_->{file_id}) if $c->{m_a_lock_delete};
	  }
      $ses->redirect_msg("?op=admin_files",($#$files+1)." files were queued for deletion");
   }
   if($f->{dmca_rename_selected} && $f->{file_id})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      die"security error" unless $ENV{REQUEST_METHOD} eq 'POST';
      my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{file_id})});
      $ses->redirect($c->{site_url}) unless $ids;
      my $files = $db->SelectARef("SELECT * FROM Files WHERE file_id IN ($ids)");
      my @list;
	  for(@$files)
	  {
		my $code = $ses->randchar(12);
   		while($db->SelectOne("SELECT file_id FROM Files WHERE file_code=? OR file_real=?",$code,$code)){$code = $ses->randchar(12);}
		$db->Exec("UPDATE Files SET file_code=?, file_status='OK' WHERE file_id=?", $code, $_->{file_id});
		push @list, {old_code => $_->{file_code}, new_code => $code};
	  }
      return $ses->PrintTemplate("dmca_renamed.html", list => \@list);
   }
   if($f->{del_special}=~/^\w$/i && $f->{file_id})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{file_id})});
      $ses->redirect($c->{site_url}) unless $ids;
      my $files = $db->SelectARef("SELECT * FROM Files WHERE file_id IN ($ids)");
      for my $file (@$files)
      {
          $ses->DeleteFileQuality($file,$f->{del_special},1);
          $db->Exec("UPDATE Files SET file_size_$f->{del_special}=0, file_spec_$f->{del_special}='' WHERE file_real=?",$file->{file_real});
          $db->Exec("UPDATE Users SET usr_disk_used=usr_disk_used-? WHERE usr_id=?", int($file->{"file_size_$f->{del_special}"}/1024), $file->{usr_id} );
      }
      $ses->redirect($ENV{HTTP_REFERER}||"?op=admin_files");
   }
   if($f->{export_direct})
   {
       my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{file_id})});
       $ids||=0;
       my $files = $db->SelectARef("SELECT *
                                    FROM Files f, Servers s, Hosts h 
                                    WHERE file_id IN ($ids) 
                                    AND f.srv_id=s.srv_id
                                    AND s.host_id=h.host_id");
       print"Content-type: text/plain\n\n";
       for my $file (@$files)
       {
         my $mode;
         for my $q (reverse @{$c->{quality_letters}},'o')
         {
         	$mode||=$q if $file->{"file_size_$q"};
         }
         print genDirectLink($file,$mode,$file->{file_name}),"\n";
       }
       exit;
   }
   if($f->{reencode_selected})
   {
       $f->{effects} = join '|', map{/^eff_(.+)$/;"$1=$f->{$_}"} grep{/^eff_/ && $f->{$_}} keys %$f;
       $f->{effects}.="|reencode=1";
       my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})}) || 0;
       my $files = $db->SelectARef("SELECT * FROM Files f, Servers s
       								WHERE file_id IN ($ids)
       								AND f.srv_id=s.srv_id");

       for my $file (@$files)
       {
			my $qmax;
			for('o',reverse @{$c->{quality_letters}})
			{
				$qmax||=$_ if $file->{"file_size_$_"};
			}
			next unless $qmax;
			$ses->getVideoInfo($file,$qmax);

			for my $q (@{$c->{quality_letters}})
			{
				my ($w,$h) = $c->{"vid_resize_$q"}=~/^(\d*)x(\d*)$/;
				addEncodeQueueDB($file, 1, $q)
					if $c->{"vid_encode_$q"} && ( ($w && $file->{vid_width}>=$w) || ($h && $file->{vid_height}>=$h) || $q eq 'l' );
			}

			addEncodeQueueDB($file, 1, 'p')
				if $file->{file_size_p};
       }
       $ses->redirect_msg("?op=admin_files",@$files." files added to encoding queue");
   }
   if($f->{rethumb_selected})
   {
       my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})}) || 0;
       my $files = $db->SelectARef("SELECT f.*, s.srv_id, s.disk_id 
                                    FROM Files f, Servers s 
                                    WHERE file_id IN ($ids) 
                                    AND f.srv_id=s.srv_id");
       my %h;
       push @{$h{$_->{srv_id}}}, $_  for @$files;
       for my $srv_id (keys %h)
       {
         my $file = $db->SelectRow("SELECT * FROM Files WHERE file_id=?",$f->{file_id});
         if ($c->{video_extensions} && $file->{file_name} =~ /\.($c->{video_extensions})$/i) {
            my $list = join ':', map{ "$_->{disk_id}-$_->{file_real_id}-$_->{file_real}-$_->{file_length}-$_->{video_thumb}-$_->{video_thumb_t}" } @{$h{$srv_id}};
            $ses->api2($srv_id, {op=>'rethumb',list=>$list});
         } else {
            my $list = join ':', map{ "$_->{disk_id}-$_->{file_real_id}-$_->{file_real}-$_->{file_length}-$_->{audio_thumb}" } @{$h{$srv_id}};
            $ses->api2($srv_id, {op=>'rethumb_audio',list=>$list});
         }
       }
       $ses->redirect_msg("?op=admin_files",@$files." files regenerated thumbnails");
   }
   if($f->{rescreen_selected})
   {
       my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})}) || 0;
       my $files = $db->SelectARef("SELECT f.*, s.srv_id, s.disk_id 
                                    FROM Files f, Servers s 
                                    WHERE file_id IN ($ids) 
                                    AND f.srv_id=s.srv_id");
       my %h;
       push @{$h{$_->{srv_id}}}, $_  for @$files;
		
		my $edata;
		$edata->{$_}=$c->{$_} for qw(m_x_width m_x_cols m_x_rows m_x_logo m_x_th_width m_x_th_height);
		my $extra_data = join "\n", map{"$_=$edata->{$_}"} sort keys %$edata;

       for my $srv_id (keys %h)
       {
           my $list = join ':', map{ "$_->{disk_id}-$_->{file_real_id}-$_->{file_real}-$_->{file_length}-$_->{file_name}" } @{$h{$srv_id}};
           my $res = $ses->api2($srv_id, {op=>'rescreen', list=>$list, extra=>$extra_data});
           $ses->message("API ERROR:$res") unless $res eq 'OK';
       }
       my $ids = join ',', map{$_->{file_id}} @$files;
       $db->Exec("UPDATE Files SET file_screenlist=1 WHERE file_id IN ($ids)") if $ids;
       $ses->redirect_msg("?op=admin_files",@$files." files regenerated screenlist");
   }
   if($f->{reslide_selected})
   {
       my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})}) || 0;
       my $files = $db->SelectARef("SELECT f.*, s.srv_id, s.disk_id 
                                    FROM Files f, Servers s 
                                    WHERE file_id IN ($ids) 
                                    AND f.srv_id=s.srv_id");
       my %h;
       push @{$h{$_->{srv_id}}}, $_  for @$files;
       for my $srv_id (keys %h)
       {
           my $list = join ':', map{ "$_->{disk_id}-$_->{file_real_id}-$_->{file_real}-$_->{file_length}" } @{$h{$srv_id}};
           my $x = $ses->api2($srv_id, {op=>'reslide',list=>$list});
       }
       $ses->redirect_msg("?op=admin_files",@$files." files regenerated slides");
   }
   if($f->{reparse_selected})
   {
       my $ids = join(',',grep{/^\d+$/}@{ARef($f->{file_id})}) || 0;
       my $files = $db->SelectARef("SELECT f.*, s.srv_id, s.disk_id 
                                    FROM Files f, Servers s 
                                    WHERE file_id IN ($ids) 
                                    AND f.srv_id=s.srv_id");
       my %h;
       push @{$h{$_->{srv_id}}}, $_  for @$files;
       for my $srv_id (keys %h)
       {
           my $list = join ':', map{ "$_->{disk_id}-$_->{file_real_id}-$_->{file_real}" } @{$h{$srv_id}};
           my $res = $ses->api2($srv_id, {op=>'reparse',list=>$list});
           $ses->message("API ERROR:$res") unless $res eq 'OK';
       }
       return $ses->redirect_msg("/?op=file_edit&file_code=$f->{return_code}","File info reparsed") if $f->{return_code};
       return $ses->redirect_msg("?op=admin_files",@$files." files reparsed");
   }
   if($f->{transfer_files} && $f->{srv_id2} && $f->{file_id})
   {
      return &AdminServersTransfer;
   }
   if($f->{featured_add} && $f->{file_id})
   {
      for(@{&ARef($f->{file_id})})
      {
         $db->Exec("INSERT IGNORE INTO FilesFeatured SET file_id=?",$_);
      }
      $ses->redirect_msg("?op=admin_files_featured","Files were added to list");
   }
   if($f->{change_status} && $f->{file_id})
   {
       my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{file_id})});
       $db->Exec("UPDATE Files SET file_status=? WHERE file_id IN ($ids)",$f->{file_status2}) if $ids;
       $ses->redirect("?op=admin_files");
   }

   my $filter_files;
   if($f->{mass_search})
   {
      $f->{mass_search}=~s/\r//gs;
      $f->{mass_search}=~s/\s+\n/\n/gs;
      my (@arr,@arrid);
      push @arr,$1 while $f->{mass_search}=~/[\/\-](\w{12})(\_|\.|\/|\n|$)/gs;
      push @arr,$2 while $f->{mass_search}=~/(^|\n)(\w{12})/gs;
      while($f->{mass_search}=~/[\/\,](\w{48,})[\/\,]/gs)
      {
        
        my @arr = decodeHash($1);
        my $fid = $arr[2];
        push @arrid,$fid if $fid=~/^\d+$/;
      }
      $filter_files = "AND file_code IN ('".join("','",@arr)."')" if @arr;
      $filter_files .= " AND file_id IN (".join(',',@arrid).")" if @arrid;
   }
   $f->{sort_field}||='file_created';
   $f->{sort_order}||='down';
   $f->{per_page}||=$c->{items_per_page};
   if($f->{usr_login})
   {
       $f->{usr_id} = $db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$f->{usr_login});
       $f->{usr_id} = $f->{usr_login} if !$f->{usr_id} && $f->{usr_login}=~/^\d+$/;
   }
   
   my $filter_key    = "AND (file_name LIKE '%$f->{key}%' OR file_title LIKE '%$f->{key}%')" if $f->{key};
   my $filter_user   = "AND f.usr_id='$f->{usr_id}'" if $f->{usr_id};
   my $filter_server = "AND f.srv_id='$f->{srv_id}'" if $f->{srv_id}=~/^\d+$/;
   my $filter_server_copy = "AND (f.srv_id=$f->{srv_id_copy} OR f.srv_id_copy=$f->{srv_id_copy})" if $f->{srv_id_copy}=~/^\d+$/;
   my $filter_views_more = "AND f.file_views>$f->{views_more}" if $f->{views_more}=~/^\d+$/;
   my $filter_views_less = "AND f.file_views<$f->{views_less}" if $f->{views_less}=~/^\d+$/;
   my $size_type = $f->{size_type} ? "file_size_$f->{size_type}" : "file_size";
   my $filter_size_more = "AND f.$size_type>".$f->{size_more}*1048576 if $f->{size_more}=~/^\d+$/;
   my $filter_size_less = "AND f.$size_type<".$f->{size_less}*1048576 if $f->{size_less}=~/^\d+$/;
   my $filter_status    = "AND f.file_status='$f->{file_status}'" if $f->{file_status}=~/^\w+$/;
   my $filter_code      = "AND (f.file_code='$f->{file_code}' OR f.file_real='$f->{file_code}')" if $f->{file_code}=~/^\w+$/;
   my $filter_public    = "AND f.file_public=1" if $f->{public_only};
   my $filter_premium   = "AND f.file_premium_only=1" if $f->{premium_only};

   my ($filter_tag1,$filter_tag2);
   if($f->{tag_id}=~/^\d+$/)
   {
      $filter_tag1=",Tags2Files t2f";
      $filter_tag2="AND f.file_id=t2f.file_id AND t2f.tag_id=$f->{tag_id}";
   }
   
   my $filter_ip     = "AND f.file_ip=INET_ATON('$f->{ip}')" if $f->{ip}=~/^\d+\.\d+\.\d+\.\d+$/;
   my $files = $db->SelectARef("SELECT f.*, 
                                       INET_NTOA(file_ip) as file_ip,
                                       u.usr_id, u.usr_login
                                FROM (Files f $filter_tag1)
                                LEFT JOIN Users u ON f.usr_id = u.usr_id
                                WHERE 1
                                $filter_files
                                $filter_key
                                $filter_user
                                $filter_server
                                $filter_server_copy
                                $filter_views_more
                                $filter_views_less
                                $filter_size_more
                                $filter_size_less
                                $filter_ip
                                $filter_status
                                $filter_code
                                $filter_public
                                $filter_premium
                                $filter_tag2
                                ".$ses->makeSortSQLcode($f,'file_created').$ses->makePagingSQLSuffix($f->{page},$f->{per_page}) );
   my $total = $db->SelectOne("SELECT COUNT(*) as total_count
                                FROM (Files f $filter_tag1)
                                WHERE 1 
                                $filter_files
                                $filter_key 
                                $filter_user 
                                $filter_server
                                $filter_server_copy
                                $filter_views_more
                                $filter_views_less
                                $filter_size_more
                                $filter_size_less
                                $filter_ip
                                $filter_status
                                $filter_code
                                $filter_public
                                $filter_premium
                                $filter_tag2
                                ");
   $f->{thumbnail}||=$ses->getCookie('adm_thumb_mode');
   for(@$files)
   {
      $_->{site_url} = $c->{site_url};
      $_->{file_title_txt} = $ses->shortenString( $_->{file_title}||$_->{file_name}, $c->{display_max_filename_admin} );
      $_->{file_length2} = sprintf("%02d:%02d:%02d",int($_->{file_length}/3600),int(($_->{file_length}%3600)/60),$_->{file_length}%60);
      $_->{file_length2} =~ s/^00://;
      $_->{file_size_o} = $ses->makeFileSize($_->{file_size_o});
      $_->{file_size_n} = $ses->makeFileSize($_->{file_size_n});
      $_->{file_size_h} = $ses->makeFileSize($_->{file_size_h});
      $_->{file_size_x} = $ses->makeFileSize($_->{file_size_x});
      $_->{file_size_l} = $ses->makeFileSize($_->{file_size_l});
      $_->{file_size_p} = $ses->makeFileSize($_->{file_size_p});
      $_->{traffic}    = $_->{traffic} ? $ses->makeFileSize($_->{traffic}) : '';
      $_->{download_link} = $ses->makeFileLink($_);
      $_->{file_downloads}||='';
      $_->{file_views} = $_->{file_views}||$_->{file_views_full} ? "$_->{file_views_full} / $_->{file_views}" : "";
      $_->{file_last_download}='' unless $_->{file_downloads};
      $_->{file_money} = $_->{file_money} eq '0.0000' ? '' : '$'.$_->{file_money};
      $_->{file_money}=~s/0+$//;
      $_->{file_money}='' if $_->{file_money} eq '$0.';
      $_->{bandwidth}='' if $_->{bandwidth} eq '0';
      $_->{td_style}=' class="file_pending"' if $_->{file_status} eq 'PENDING';
      $_->{td_style}=' class="file_locked"'  if $_->{file_status} eq 'LOCKED';
      $ses->getVideoInfo($_) if $f->{thumbnail};
   }
   my %sort_hash = $ses->makeSortHash($f,['file_title','usr_login','file_downloads','file_money','file_size_n','file_created','file_views','file_length','bandwidth']);

    if($c->{resolve_ip_country})
    {
        $_->{country} = $ses->getCountryCode($_->{ip}) for @$files;
    }

   my $hosts = $db->SelectARef("SELECT *
                                FROM Hosts
                                ORDER BY host_id");
   my $servers = $db->SelectARef("SELECT s.*
                                  FROM Servers s
                                  WHERE srv_status<>'OFF'
                                  ORDER BY srv_id");
   for my $h (@$hosts)
   {
      @{$h->{servers}} = grep{$_->{host_id}==$h->{host_id}} @$servers;
   }
   $f->{file_status}||='';

   $ses->PrintTemplate("admin_files.html",
                       'files'   => $files,
                       'key'     => $f->{key},
                       'usr_id'  => $f->{usr_id},
                       'down_more'  => $f->{down_more},
                       'down_less'  => $f->{down_less},
                       'size_more'  => $f->{size_more},
                       'size_less'  => $f->{size_less},
                       "per_$f->{per_page}" => ' checked',
                       %sort_hash,
                       'paging'     => $ses->makePagingLinks($f,$total),
                       'items_per_page' => $c->{items_per_page},
                       'usr_login'  => $f->{usr_login},
                       'hosts'      => $hosts,
                       "file_status_$f->{file_status}" => ' checked',
                       "size_type_$f->{size_type}" => ' selected',
                       'file_code'  => $f->{file_code},
                       'thumbnail'  => $f->{thumbnail},
                       'public_only'=> $f->{public_only},
                       'premium_only'=> $f->{premium_only},
                       'm_h'        => $c->{m_h},
                       'm_h_hd'     => $c->{m_h_hd},
                       'm_h_lq'     => $c->{m_h_lq},
                       'm_x'        => $c->{m_x},
                       'm_z'        => $c->{m_z},
                       'm_q'        => $c->{m_q},
                       'vid_keep_orig' => $c->{vid_keep_orig},
                       'm_a'		=> $c->{m_a},
                       'm_a_delete_after' => $c->{m_a_delete_after},
                       'srv_id_copy'   => $f->{srv_id_copy},
                       maincss      => 1,
                      );
}

sub AdminUsers
{
   if($f->{del_id})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my $files = $db->SelectARef("SELECT srv_id,file_code,file_id,file_real,file_real_id FROM Files WHERE usr_id=?",$f->{del_id});
      $ses->DeleteFilesMass($files);
      $ses->DeleteUserDB($f->{del_id});
      $ses->redirect("?op=admin_users");
   }
   if($f->{del_pending}=~/^\d+$/)
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my $users = $db->SelectARef("SELECT * FROM Users WHERE usr_status='PENDING' AND usr_created<CURDATE()-INTERVAL ? DAY",$f->{del_pending});
      for my $user (@$users)
      {
         my $files = $db->SelectARef("SELECT srv_id,file_code,file_id,file_real,file_real_id FROM Files WHERE usr_id=?",$user->{usr_id});
         $ses->DeleteFilesMass($files);
         $ses->DeleteUserDB($user->{usr_id});
      }
      $ses->redirect_msg("?op=admin_users","Deleted users: ".($#$users+1));
   }
   if($f->{del_inactive}=~/^\d+$/)
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my $users = $db->SelectARef("SELECT * FROM Users 
                                   WHERE usr_created<CURDATE()-INTERVAL ? DAY 
                                   AND usr_lastlogin<CURDATE() - INTERVAL ? DAY",$f->{del_inactive},$f->{del_inactive});
      for my $user (@$users)
      {
         my $files = $db->SelectARef("SELECT * FROM Files WHERE usr_id=?",$user->{usr_id});
         $ses->DeleteFilesMass($files);
         $ses->DeleteUserDB($user->{usr_id});
      }
      $ses->redirect_msg("?op=admin_users","Deleted users: ".($#$users+1));
   }
   if($f->{del_users} && $f->{usr_id})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{usr_id})});
      $ses->redirect($c->{site_url}) unless $ids;
      my $users = $db->SelectARef("SELECT * FROM Users WHERE usr_id IN ($ids)");
      for my $user (@$users)
      {
         my $files = $db->SelectARef("SELECT * FROM Files WHERE usr_id=?",$user->{usr_id});
         $ses->DeleteFilesMass($files);
         $ses->DeleteUserDB($user->{usr_id});
      }
      $ses->redirect("?op=admin_users");
   }
   if($f->{update_files} && $f->{usr_id})
   {
   	  my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{usr_id})});
      $ses->redirect($c->{site_url}) unless $ids;
      my $users = $db->SelectARef("SELECT usr_id, 
      									COUNT(*) as usr_files_used, 
      									SUM(IF( file_code=file_real, ROUND( (file_size_o+file_size_n+file_size_h+file_size_l+file_size_x+file_size_p)/1024 ), 0)   ) as usr_disk_used
      								FROM Files 
      								WHERE usr_id IN ($ids)
      								GROUP BY usr_id");
      for (@$users)
      {
      	$db->Exec("UPDATE Users SET usr_files_used=?, usr_disk_used=? WHERE usr_id=?", $_->{usr_files_used}, $_->{usr_disk_used}, $_->{usr_id});
      }
      $ses->redirect("?op=admin_users");
   }
   if($f->{extend_premium_all})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      $db->Exec("UPDATE Users SET usr_premium_expire=usr_premium_expire + INTERVAL ? DAY WHERE usr_premium_expire>=NOW()",$f->{extend_premium_all});
      $ses->redirect("?op=admin_users");
   }
   if($f->{resend_activation})
   {
      my $user = $db->SelectRow("SELECT usr_id,usr_login FROM Users WHERE usr_id=?",$f->{resend_activation});
      $f->{d} = "$user->{usr_id}-$user->{usr_login}";
      &ResendActivationCode(1);
   }
   if($f->{activate})
   {
      $db->Exec("UPDATE Users SET usr_status='OK', usr_security_lock='' WHERE usr_id=?",$f->{activate});
      $ses->redirect_msg("?op=admin_users","User activated");
   }
   if($f->{mass_email} && $f->{usr_id})
   {
      &AdminMassEmail;
   }
   if($f->{change_status} && $f->{usr_id})
   {
   	  $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{usr_id})});
      $ses->redirect($c->{site_url}) unless $ids;
      my $users = $db->Exec("UPDATE Users SET usr_status=? WHERE usr_id IN ($ids)",$f->{usr_status2});
      $ses->redirect("?op=admin_users");
   }

   $f->{sort_field}||='usr_created';
   $f->{sort_order}||='down';
   my @filters;
   $f->{key}=~s/\s+$//;
   $f->{key}=~s/^\s+//;
   if($f->{key}=~/^\d+\.\d+\.\d+\.\d+$/)
   {
     my $ulist = $db->SelectARef("SELECT DISTINCT usr_id FROM Sessions WHERE ip=INET_ATON(?)",$f->{key});
     my $uids = join(',', map{$_->{usr_id}} @$ulist) || 0;
     push @filters, "AND (usr_lastip=INET_ATON('$f->{key}') OR u.usr_id IN ($uids))";
   }
   elsif($f->{key})
   {
		push @filters, "AND (usr_login LIKE '%$f->{key}%' OR usr_email LIKE '%$f->{key}%' OR usr_notes LIKE '%$f->{key}%' OR usr_pay_email LIKE '%$f->{key}%')";
   }
   push @filters, "AND usr_money>=$f->{money}" if $f->{money}=~/^[\d\.]+$/;
   push @filters, "AND usr_premium_expire>NOW()+INTERVAL $f->{premium_days} DAY" if $f->{premium_days}=~/^\d+$/;
   push @filters, "AND usr_aff_id=$f->{aff_id}" if $f->{aff_id}=~/^\d+$/;
   push @filters, "AND usr_status='$f->{usr_status}'" if $f->{usr_status}=~/^\w+$/;
   push @filters, "AND usr_files_used>=$f->{files_more}" if $f->{files_more}=~/^\d+$/;
   push @filters, "AND usr_files_used<=$f->{files_less}" if $f->{files_less}=~/^\d+$/;
   my $filter_str = join "\n", @filters;
   my $users = $db->SelectARef("SELECT u.*,
                                       INET_NTOA(usr_lastip) as usr_ip,
                                       ROUND(usr_disk_used/1024) as disk_used,
                                       UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec,
                                       TO_DAYS(CURDATE())-TO_DAYS(usr_lastlogin) as last_visit
                                FROM Users u
                                WHERE 1
                                $filter_str
                                ".$ses->makeSortSQLcode($f,'usr_created').$ses->makePagingSQLSuffix($f->{page}) );
   my $totals = $db->SelectRow("SELECT COUNT(*) as total_count
                                FROM Users u WHERE 1 
                                $filter_str
                                ");

   for(@$users)
   {
      $_->{site_url} = $c->{site_url};
      $_->{disk_used} = $_->{disk_used} ?  $_->{disk_used}>1024?sprintf("%.0f",$_->{disk_used}/1024)." GB":"$_->{disk_used} MB" : '';
      $_->{premium} = $_->{exp_sec}>0;
      $_->{last_visit} = defined $_->{last_visit} ? "$_->{last_visit} days ago" : 'Never';
      substr($_->{usr_created},-3)='';
      $_->{"status_$_->{usr_status}"}=1;
      $_->{usr_money} = $_->{usr_money}=~/^[0\.]+$/ ? '' : '$'.$_->{usr_money};
      $_->{usr_money}=~s/0+$//;
      $_->{usr_money}=~s/\.$//;
   }
   my %sort_hash = $ses->makeSortHash($f,['usr_login','usr_email','usr_created','usr_disk_used','usr_files_used','last_visit','usr_money']);

    if($c->{resolve_ip_country})
    {
        $_->{country} = $ses->getCountryCode($_->{ip}) for @$users;
    }
   
   $ses->PrintTemplate("admin_users.html",
                       users  => $users,
                       %{$totals},
                       key    => $f->{key},
                       premium_only => $f->{premium_only},
                       money => $f->{money},
                       premium_days => $f->{premium_days},
                       aff_id       => $f->{aff_id},
                       "status_$f->{usr_status}"   => ' checked',
                       %sort_hash,
                       paging => $ses->makePagingLinks($f,$totals->{total_count}),
                       m_o => $c->{m_o},
                       m_b => $c->{m_b},
                       items_per_page => $c->{items_per_page},
                       "per_$f->{per_page}" => ' checked',
                       files_more 	=> $f->{files_more},
                       files_less 	=> $f->{files_less},
                       maincss      => 1,
                      );
}

sub AdminUserEdit
{
    my @smods;
    push @smods,'usr_watermark' if $c->{m_v} && $c->{m_v_users} eq  'special';
    push @smods,'usr_snapshot'  if $c->{m_s} && $c->{m_s_users} eq  'special';
    push @smods,'usr_gif'       if $c->{m_g} && $c->{m_g_users} eq  'special';
    push @smods,'usr_ftp'       if $c->{m_f} && $c->{m_f_users} eq  'special';
    push @smods,'usr_torrent'   if $c->{m_t} && $c->{m_t_users} eq  'special';
    push @smods,'usr_website'   if $c->{m_b} && $c->{m_b_users} eq  'special';
    push @smods,'usr_effects'   if $c->{m_e} && $c->{m_e_users} eq  'special';
    push @smods,'usr_clone'     if $c->{m_n} && $c->{m_n_users} eq  'special';
    push @smods,'usr_streams'   if $c->{m_v} && $c->{m_q_users} eq  'special';
    push @smods,'usr_api'   	if $c->{m_6} && $c->{m_6_users} eq  'special';
    push @smods,'usr_api_spec' 	if $c->{m_6} && $c->{m_6_users_spec} eq  'special';
    push @smods,'usr_ads'   	if $c->{m_9} && $c->{m_9_users} eq  'special';
    push @smods,'usr_domains'   if $c->{m_y} && $c->{m_y_users} eq  'special';
    push @smods,'usr_autoapprove' if $c->{approve_required};

    if($f->{save})
    {
       $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
       $f->{usr_allowed_ips}=~s/\s+//g;
       $db->Exec("UPDATE Users 
                  SET usr_login=?, 
                      usr_email=?, 
                      usr_premium_expire=?, 
                      usr_status=?, 
                      usr_money=?,
                      usr_disk_space=?,
                      usr_mod=?,
                      usr_aff_id=?,
                      usr_notes=?,
                      usr_reseller=?,
                      usr_verified=?,
                      usr_allowed_ips=?,
                      usr_premium_only=?,
                      usr_premium_dl_only=?,
                      usr_sales_rate=?,
                      usr_website_rate=?,
                      usr_monitor=?,
                      usr_uploads_on=?,
                      usr_no_expire=?
                  WHERE usr_id=?",
                  $f->{usr_login},
                  $f->{usr_email},
                  $f->{usr_premium_expire},
                  $f->{usr_status},
                  $f->{usr_money},
                  $f->{usr_disk_space},
                  $f->{usr_mod},
                  $f->{usr_aff_id},
                  $f->{usr_notes},
                  $f->{usr_reseller},
                  $f->{usr_verified},
                  $f->{usr_allowed_ips},
                  $f->{usr_premium_only},
                  $f->{usr_premium_dl_only},
                  $f->{usr_sales_rate},
                  $f->{usr_website_rate},
                  $f->{usr_monitor},
                  $f->{usr_uploads_on},
                  $f->{usr_no_expire},
                  $f->{usr_id}
                 );
       $db->Exec("UPDATE Users SET usr_password=? WHERE usr_id=?", $ses->genPasswdHash( $f->{usr_password} ), $f->{usr_id} ) if $f->{usr_password};

        for my $m (@smods)
        {
           if($f->{$m})
           {
               $db->Exec("INSERT INTO UserData SET usr_id=?, name='$m', value='1' 
                          ON DUPLICATE KEY UPDATE value='1'",$f->{usr_id});
           }
           else
           {
               $db->Exec("DELETE FROM UserData WHERE usr_id=? AND name='$m' LIMIT 1",$f->{usr_id});
           }
        }

       $ses->redirect("?op=admin_user_edit&usr_id=$f->{usr_id}");
    }
    if($f->{ref_del})
    {
       $db->Exec("UPDATE Users SET usr_aff_id=0 WHERE usr_id=?",$f->{ref_del});
       $ses->redirect("?op=admin_user_edit&usr_id=$f->{usr_id}");
    }
    my $user = $db->SelectRow("SELECT *, 
                                      UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec, 
                                      DECODE(usr_password,'$c->{pasword_salt}') as usr_password,
                                      INET_NTOA(usr_lastip) as usr_lastip
                               FROM Users WHERE usr_id=?
                              ",$f->{usr_id});
    my $transactions = $db->SelectARef("SELECT * FROM Transactions WHERE usr_id=? AND verified=1 ORDER BY created DESC",$f->{usr_id});
    $_->{site_url}=$c->{site_url} for @$transactions;


    my $sessions = $db->SelectARef("SELECT INET_NTOA(ip) as ip, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(last_time) as dt FROM Sessions WHERE usr_id=?",$f->{usr_id});
    for (@$sessions)
    {
        $_->{dtt} = sprintf("%.0f hours ago",$_->{dt}/3600);
        $_->{dtt} = sprintf("%.0f mins ago",$_->{dt}/60) if $_->{dt}<3600*3;
        $_->{dtt} = "$_->{dt} secs ago" if $_->{dt}<60*3;
    }

    if($c->{resolve_ip_country})
    {
        $user->{last_country} = $ses->getCountryCode( $user->{usr_lastip} );
        $_->{country} = $ses->getCountryCode($_->{ip}) for @$sessions;
    }

    my $payments = $db->SelectARef("SELECT * FROM Payments WHERE usr_id=? ORDER BY created DESC",$f->{usr_id});

    my $referrals = $db->SelectARef("SELECT usr_id,usr_login,usr_created,usr_money,usr_aff_id 
                                     FROM Users 
                                     WHERE usr_aff_id=? 
                                     ORDER BY usr_created DESC 
                                     LIMIT 11",$f->{usr_id});
    $referrals->[10]->{more}=1 if $#$referrals>9;


    for(@smods)
    {
        $user->{"$_\_mod"}=1;
        $user->{$_} = $db->SelectOne("SELECT value FROM UserData WHERE usr_id=? AND name=?",$f->{usr_id},$_);
    }

    $user->{m_o} = $c->{m_o};
    $user->{usr_money}=~s/0{1,3}$//;

    if($c->{extra_user_fields})
    {
		$user->{extra_fields} = $db->SelectARef("SELECT * FROM UserData WHERE usr_id=? AND name LIKE 'usr_extra_%'",$f->{usr_id});
		$_->{name}=~s/^usr_extra_//i for @{$user->{extra_fields}};
    }

    $user->{login_history_num} = $db->SelectOne("SELECT COUNT(*) FROM LoginHistory WHERE usr_id=?",$f->{usr_id});

    require Time::Elapsed;
    my $et  = new Time::Elapsed;
    $ses->PrintTemplate("admin_user_form.html",
                        %{$user},
                        usr_id1 => $user->{usr_id},
                        expire_elapsed => $user->{exp_sec}>0 ? $et->convert($user->{exp_sec}) : '',
                        transactions   => $transactions,
                        payments       => $payments,
                        "status_$user->{usr_status}" => ' selected',
                        referrals      => $referrals,
                        %$c,
                        m_k_manual     => $c->{m_k} && $c->{m_k_manual},
                        sale_aff_percent    => $c->{sale_aff_percent},
                        uploads_selected_only   => $c->{uploads_selected_only},
                        sessions        => $sessions,
                        maincss      => 1,
                       );
}

sub AdminUserReferrals
{
   my $referrals = $db->SelectARef("SELECT usr_id,usr_login,usr_created,usr_money,usr_aff_id 
                                     FROM Users 
                                     WHERE usr_aff_id=? 
                                     ORDER BY usr_created DESC 
                                     ".$ses->makePagingSQLSuffix($f->{page}),$f->{usr_id});
   my $total = $db->SelectOne("SELECT COUNT(*) FROM Users WHERE usr_aff_id=?",$f->{usr_id});
   my $user = $db->SelectRow("SELECT usr_id,usr_login FROM Users WHERE usr_id=?",$f->{usr_id});
   $ses->PrintTemplate("admin_user_referrals.html",
                       referrals  => $referrals,
                       'paging' => $ses->makePagingLinks($f,$total),
                       %{$user},
                       maincss      => 1,
                      );
}

sub AdminTorrents
{
   if($f->{del_torrents} && $f->{sid})
   {
      my $sids = join("','",@{ARef($f->{sid})});
      $db->Exec("DELETE FROM Torrents WHERE sid IN ('$sids')");
      $ses->redirect("?op=admin_torrents");
   }
   if($f->{'kill'})
   {
      $ses->api_host($f->{host_id},{op => 'torrent_kill'});
      sleep 1;
      $db->Exec("UPDATE Hosts SET host_torrent_active=NOW()-INTERVAL 5 MINUTE WHERE host_id=?",$f->{host_id});
      $ses->redirect("?op=admin_torrents");
   }

   my $hosts = $db->SelectARef("SELECT h.*, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(h.host_torrent_active) as dt,
   								COUNT(t.sid) as num,
   								SUM(peers) as peers, 
   								ROUND(SUM(download_speed)/1024) as download_speed,
   								ROUND(SUM(downloaded)/1024/1024/1024,1) as downloaded,
   								ROUND(SUM(size)/1024/1024/1024,1) as size
								FROM Hosts h
								LEFT JOIN Torrents t ON h.host_id=t.host_id
								WHERE h.host_torrent=1
								GROUP BY h.host_id
								ORDER BY h.host_id");
   my $hname;
   $hname->{$_->{host_id}}=$_->{host_name} for @$hosts;
   $f->{host_names} = $hname;
   for(@$hosts)
   {
      if($_->{dt}<30)
      {
      	$_->{active}=1;
      }
      else
      {
		my $res = $ses->api_host($_->{host_id}, { op => 'torrent_status' });
		$_->{active}=1 if $res eq 'ON';
      }
   }

   my $torrents = getTorrents();
   $ses->PrintTemplate("admin_torrents.html",
                       torrents  => $torrents,
                       hosts   => $hosts,
                       maincss      => 1,
                      );
}

sub getTorrents
{
	my $filter_usr_id = "AND t.usr_id=$f->{usr_id}" if $f->{usr_id}=~/^\d+$/;
	my $filter_host_id = "AND t.host_id=$f->{host_id}" if $f->{host_id}=~/^\d+$/;

	my$torrents = $db->SelectARef("SELECT *, u.usr_login, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(created) as working
									FROM Torrents t, Users u
									WHERE t.usr_id=u.usr_id
									$filter_usr_id
									$filter_host_id
									ORDER BY created DESC
									");
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

	  $t->{seed_until} = $ses->makeFileSize($t->{size} * $t->{seed_until_rate});
	  $t->{download_speed} = sprintf("%.0f KB/s", $t->{download_speed}/1024 );
	  $t->{upload_speed} = sprintf("%.0f KB/s", $t->{upload_speed}/1024 );
	  $t->{downloaded} = sprintf("%.1f", $t->{downloaded}/1024**3 );
	  $t->{uploaded} = sprintf("%.1f", $t->{uploaded}/1024**3 );
	  $t->{size} = sprintf("%.1f", $t->{size}/1024**3 );
	  $t->{host_name} = $f->{host_names}->{$t->{host_id}} if $f->{host_names};
	}

	return $torrents;
}

sub AdminServers
{
	if($f->{root_cmd})
	{
		my $filter_host = $f->{host_id}=~/^\d+$/ ? "AND host_id=$f->{host_id}" : "";
		my $hosts = $db->SelectARef("SELECT DISTINCT host_id FROM Servers WHERE srv_status<>'OFF' $filter_host ORDER BY srv_last_upload DESC");
		my @errors;
		for(@$hosts)
		{
			my $res = $ses->api_host( $_->{host_id}, { op => 'root_cmd', cmd => $f->{cmd}, api_timeout => 5 } );
			push @errors,$_->{host_id} unless $res eq 'OK';
		}
		my $error="<br>These host_id returned error: ".join(", ",@errors) if @errors;
		return $ses->redirect_msg('?op=admin_servers',"Command sent.$error");
	}
	if($f->{change_status})
	{
		my $ids = join ',', grep{/^\d+$/} @{ARef($f->{srv_id})};
		$db->Exec("UPDATE Servers SET srv_status=? WHERE srv_id IN ($ids)",$f->{srv_status}) if $ids;
		$ses->redirect('?op=admin_servers');
	}
	if($f->{update_disk_used})
	{
		$ses->message("Not allowed in Demo mode") if $c->{demo_mode};
		for my $srv_id (@{ARef($f->{srv_id})})
		{
			my $res = $ses->api2($srv_id, { op => 'get_file_stats' });
			$ses->message("Error when requesting API.<br>$res") unless $res=~/^OK/;
			my ($files,$size) = $res=~/^OK:(\d+):(\d+)$/;
			$ses->message("Invalid files,size values: ($files)($size)") unless $files=~/^\d+$/ && $size=~/^\d+$/;
			my $file_count = $db->SelectOne("SELECT COUNT(*) FROM Files WHERE srv_id=?",$srv_id);
			$db->Exec("UPDATE Servers SET srv_files=?, srv_disk=? WHERE srv_id=?",$file_count,$size,$srv_id);
		}
		$ses->redirect('?op=admin_servers');
	}

	if($f->{check_db_to_file})
	{
		$ses->message("Not allowed in Demo mode") if $c->{demo_mode};
		$|++;
		print"Content-type:text/html\n\n<HTML><BODY>";
		print"Starting DB-File consistancy check...<br><br>";

		my $badnum=0;
		for my $srv_id (@{ARef($f->{srv_id})})
		{
		 print"ServerID=$srv_id<br>\n";
		 my $cx=0;
		 while( my $files=$db->Select("SELECT file_id, file_real_id, file_real
		                               FROM Files
		                               WHERE srv_id=? LIMIT $cx,1000",$srv_id) )
		 {
		    $files=&ARef($files);
		    $cx+=$#$files+1;
		    $_->{file_real_id}||=$_->{file_id} for @$files;
		    my $list = join ':', map{ "$_->{file_real_id}-$_->{file_real}" } @$files;
		    my $res = $ses->api2($srv_id,
		                         {
		                           op     => 'check_files',
		                           list   => $list,
		                         }
		                        );
		    $ses->AdminLog("Error when requesting API.<br>$res") unless $res=~/^OK/;
		    my ($codes) = $res=~/^OK:(.*)$/;
		    my $ids = join ',', map{"'$_'"} split(/\,/,$codes);
		    if($ids)
		    {
		       my $list = $db->SelectARef("SELECT * FROM Files WHERE file_real IN ($ids)");
		       $db->Exec("UPDATE Files SET file_status='LOCKED' WHERE file_real IN ($ids)");
		       $badnum+=$#$list+1;
		    }
		    print"+";
		 }
		 print"<br>Files marked LOCKED: $badnum<br><br>";
		}
		my $token=$ses->genToken;
		print"DONE.<br><br><a href='?op=admin_servers&token=$token'>Back to servers</a>";
		print"</BODY></HTML>";
		exit;
	}
	my $hsort="LIMIT 1" if $ses->{"\x70\x6C\x67"}->{"\x31"};
	require SecTett;
	if($f->{check_file_to_db})
	{
		$ses->message("Not allowed in Demo mode") if $c->{demo_mode};
		$|++;
		print"Content-type:text/html\n\n<HTML><BODY>";
		print"Starting File-DB consistancy check...<br><br>";
		my $deleted_db=0;
		for my $srv_id (@{ARef($f->{srv_id})})
		{
			print"ServerID=$srv_id<br>\n";
			my $res = $ses->api2($srv_id, { op => 'check_files_reverse' } );
			print"$res<br>";
		}
		print"DONE.<br><br><a href='$c->{site_url}/?op=admin_servers'>Back to site</a>";
		print"</BODY></HTML>";
		exit;
	}
	my $srv_ip = &SecTett::convertIP($ses,$c,$f->{srv_ip});
	my @warnings;
	if($f->{filter})
	{
		$ses->setCookie('srv_host_name',$f->{host_name}||'');
		$ses->setCookie('srv_type',$f->{srv_type}||'');
	}
	else
	{
		$f->{host_name} = $ses->getCookie('srv_host_name');
		$f->{srv_type} = $ses->getCookie('srv_type');
	}

	my $totals;

	for('srv_show_enc','srv_show_trans','srv_show_url')
	{
		$totals->{$_}=' checked' if $ses->getCookie($_);
	}
	my $henc;
	if($totals->{srv_show_enc})
	{
		my $enclist = $db->SelectARef("SELECT host_id, status, COUNT(*) AS x, SUM(fps) as fps FROM QueueEncoding GROUP BY host_id, status");
		for(@$enclist)
		{
			$henc->{$_->{host_id}}->{$_->{status}} = $_->{x};
			$henc->{$_->{host_id}}->{fps} += $_->{fps};
		}
	}
	my ($htransfrom,$htransto);
	if($totals->{srv_show_trans})
	{
		my $translist1 = $db->SelectARef("SELECT srv_id1, status, COUNT(*) AS x FROM QueueTransfer GROUP BY srv_id1, status");
		for(@$translist1)
		{
			$htransfrom->{$_->{srv_id1}}->{$_->{status}} = $_->{x};
		}
		my $translist2 = $db->SelectARef("SELECT srv_id2, status, COUNT(*) AS x FROM QueueTransfer GROUP BY srv_id2, status");
		for(@$translist2)
		{
			$htransto->{$_->{srv_id2}}->{$_->{status}} = $_->{x};
		}
	}
	my $hurl;
	if($totals->{srv_show_url})
	{
		my $urllist = $db->SelectARef("SELECT srv_id, status, COUNT(*) AS x FROM QueueUpload GROUP BY srv_id, status");
		for(@$urllist)
		{
			$hurl->{$_->{srv_id}}->{$_->{status}} = $_->{x};
		}
	}

	my $filter_name="AND host_name LIKE '%$f->{host_name}%'" if $f->{host_name};
	my $filter_out="AND host_out >= $f->{host_out}" if $f->{host_out}=~/^\d+$/;
	my $conns_out="AND host_connections >= $f->{host_connections}" if $f->{host_connections}=~/^\d+$/;
	my $host_type="AND host_proxy=1" if $f->{srv_type} eq 'PROXY';
	my $hosts = $db->SelectARef("SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(host_updated) as updated
								FROM Hosts
								WHERE 1
								$filter_name
								$filter_out
								$conns_out
								$host_type
								ORDER BY host_id $hsort
								");
	my $filter_type="AND srv_type = '$f->{srv_type}'" if $f->{srv_type}=~/^\w+$/;
	my $filter_util="AND disk_util>=$f->{disk_util}" if $f->{disk_util}=~/^\w+$/;
	my $servers = $db->SelectARef("SELECT s.*
									FROM Servers s
									WHERE 1
									$filter_type
									$filter_util
									ORDER BY srv_id
									");
	for my $s (@$servers)
	{
		$s->{srv_disk_percent} = sprintf("%.01f",100*$s->{srv_disk}/$s->{srv_disk_max});
		$s->{srv_disk}/=1073741824;
		$s->{srv_disk} = $s->{srv_disk}<10 ? sprintf("%.01f",$s->{srv_disk}) : sprintf("%.0f",$s->{srv_disk});
		$s->{srv_disk_max} = int $s->{srv_disk_max}/1073741824;
		my @a;
		push @a,"Regular" if $s->{srv_allow_regular};
		push @a,"Premium" if $s->{srv_allow_premium};
		$s->{user_types} = join '<br>', @a;
		$s->{on}=1 if $s->{srv_status} ne 'OFF';
		$s->{warn_util}=1 if $s->{disk_util}>80;
		$s->{warn_space}=1 if $s->{srv_disk} > $s->{srv_disk_max}*0.95;
		$s->{spec_filters}=1 if $s->{srv_users_only} || $s->{srv_countries_only};
		if($s->{srv_status} ne 'OFF')
		{
			$totals->{sum_srv_disk}+=$s->{srv_disk};
			$totals->{sum_srv_disk_max}+=$s->{srv_disk_max};
		}
		if($htransfrom->{$s->{srv_id}})
		{
			$s->{trans_from_PENDING}= $htransfrom->{$s->{srv_id}}->{PENDING};
			$s->{trans_from_MOVING}	= $htransfrom->{$s->{srv_id}}->{MOVING};
			$s->{trans_from_ERROR}	= $htransfrom->{$s->{srv_id}}->{ERROR};
			$s->{trans_from_STUCK}	= $htransfrom->{$s->{srv_id}}->{STUCK};
		}
		if($htransto->{$s->{srv_id}})
		{
			$s->{trans_to_PENDING}	= $htransto->{$s->{srv_id}}->{PENDING};
			$s->{trans_to_MOVING}	= $htransto->{$s->{srv_id}}->{MOVING};
			$s->{trans_to_ERROR}	= $htransto->{$s->{srv_id}}->{ERROR};
			$s->{trans_to_STUCK}	= $htransto->{$s->{srv_id}}->{STUCK};
		}
		if($hurl->{$s->{srv_id}})
		{
			$s->{url_PENDING}	= $hurl->{$s->{srv_id}}->{PENDING};
			$s->{url_WORKING}	= $hurl->{$s->{srv_id}}->{WORKING};
			$s->{url_ERROR}		= $hurl->{$s->{srv_id}}->{ERROR};
			$s->{url_STUCK}		= $hurl->{$s->{srv_id}}->{STUCK};
		}
	}
	$totals->{sum_srv_disk} = sprintf("%.0f",$totals->{sum_srv_disk}/1024);
	$totals->{sum_srv_numb} = sprintf("%.0f",$ses->iPlg('1')*@$hosts*1024);
	$totals->{sum_srv_disk_max} = sprintf("%.0f",$totals->{sum_srv_disk_max}/1024);

	for my $h (@$hosts)
	{
		@{$h->{servers}} = grep{$_->{host_id}==$h->{host_id}} @$servers;
		if( ($filter_type||$filter_util) && !@{$h->{servers}}){ $h->{hide}=1; next; }
		if($h->{updated}>60*30)
		{
			$h->{host_in}=$h->{host_out}=$h->{host_connections}=$h->{host_avg}=0;
		}
		$h->{warn_net}=1 if $h->{host_in}+$h->{host_out} > $h->{host_net_speed}*0.9;
		$totals->{sum_host_in}+=$h->{host_in};
		$totals->{sum_host_out}+=$h->{host_out};
		$h->{host_avg}=~s/\.\d\d$// if $h->{host_avg}>3;
		$h->{enc_PENDING}	= $henc->{$h->{host_id}}->{PENDING}		if $henc->{$h->{host_id}};
		$h->{enc_ENCODING}	= $henc->{$h->{host_id}}->{ENCODING}	if $henc->{$h->{host_id}};
		$h->{enc_STUCK}		= $henc->{$h->{host_id}}->{STUCK}		if $henc->{$h->{host_id}};
		$h->{enc_ERROR}		= $henc->{$h->{host_id}}->{ERROR}		if $henc->{$h->{host_id}};
		$h->{fps} = $henc->{$h->{host_id}}->{fps} if $henc->{$h->{host_id}};
	}
	$f->{srv_ips}=$ses->getIPs if $ses->{ENV} ne $c->{db_name};
	my $encoders = $db->SelectARef("SELECT srv_id FROM Servers 
									WHERE (srv_type='ENCODER' AND srv_status<>'OFF' AND srv_status<>'READONLY2')
									OR (srv_type IN ('UPLOADER','STORAGE') and srv_encode=1 AND srv_status='ON')");
	if($#$encoders==-1)
	{
		push @warnings, "There are no active encoding servers now!";
	}

	$ses->PrintTemplate("admin_servers.html",
						hosts		=> $hosts,
						'warnings'	=> join("<br>\n",@warnings),
						%$totals,
						token		=> $ses->genToken,
						host_name	=> $f->{host_name},
						host_out	=> $f->{host_out},
						host_connections => $f->{host_connections},
						disk_util	=> $f->{disk_util},
						"srv_type_$f->{srv_type}" => ' checked',
                  maincss      => 1,
						);
}

sub AdminServerAdd
{
   if($f->{get_dev})
   {
      my $res = $ses->api($f->{srv_cgi_url}, { op => 'get_dev', dl_key=>$c->{dl_key} } );
      print"Content-type:text/html\n\n";
      print $res;
      exit;
   }

   my $server;
   if($f->{srv_id})
   {
      $server = $db->SelectRow("SELECT * FROM Servers WHERE srv_id=?",$f->{srv_id});
      $server->{srv_disk_max}/=1024*1024*1024;
      $server->{"s_$server->{srv_status}"}=' checked';
   }
   elsif(!$db->SelectOne("SELECT srv_id FROM Servers LIMIT 1"))
   {
      $server->{srv_cgi_url}    = $c->{site_cgi};
      $server->{srv_htdocs_url} = "$c->{site_url}/files";
   }

   $server->{srv_allow_regular}=$server->{srv_allow_premium}=1 unless $f->{srv_id};
   if(!$f->{srv_id})
   {
      $ses->message("Create Host first!") unless $f->{host_id};
      $server->{host_id}=$f->{host_id};
      my $host = $db->SelectRow("SELECT * FROM Hosts WHERE host_id=?",$f->{host_id});
      $server->{srv_cgi_url}=$host->{host_cgi_url};
      $server->{srv_htdocs_url}=$host->{host_htdocs_url};
      $server->{srv_ip}=$host->{host_ip};
      my $last = $db->SelectRow("SELECT * FROM Servers WHERE host_id=? ORDER BY srv_id DESC LIMIT 1",$f->{host_id});
      if($last)
      {
          $server->{disk_id} = sprintf("%02d",++$last->{disk_id});
          my $let = (split(//,$last->{disk_dev_io}))[-1];
          $let = chr(ord($let)+1);
          $server->{disk_dev_io} = substr($last->{disk_dev_io},0,2).$let;
          $server->{disk_dev_df} = $server->{disk_dev_io};
          $server->{srv_disk_max} = $last->{srv_disk_max}/1024**3;
          $server->{"s_$last->{srv_status}"}=' checked';
          $server->{srv_encode} = $last->{srv_encode};
      }
      else
      {
          $server->{"s_ON"}=' checked';
      }
      $server->{disk_id} ||= '01';
      $server->{disk_id} = sprintf("%02d",$server->{disk_id});
      $server->{srv_name} = "$host->{host_name}-$server->{disk_id}";
   }
   $server->{srv_type}||='STORAGE';
   $server->{srv_users_only}=~s/(^,|,$)//g;
   $server->{srv_countries_only}=~s/(^,|,$)//g;

   $ses->PrintTemplate("admin_server_form.html",
                       %{$server},
                       "srv_type_$server->{srv_type}" => 'checked',
                       'm_f' => $c->{m_f},
                       'hls_proxy' => $c->{m_r} && $c->{hls_proxy} ? 1 : 0,
                       maincss      => 1,
                      );
}

sub AdminServerSave
{
   $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
   my (@tests,@arr);
   my $allow_save=1;
   require LWP::UserAgent;
   my $ua = LWP::UserAgent->new(timeout => 15,agent=>'Opera/9.51 (Windows NT 5.1; U; en)');
   $f->{srv_cgi_url}=~s/\/$//;
   $f->{srv_htdocs_url}=~s/\/$//;

   push @tests, 'max disk usage: ERROR' if !$f->{srv_disk_max} || $f->{srv_disk_max}<=0;

   $f->{srv_allow_regular}||=0;
   $f->{srv_allow_premium}||=0;
   $f->{srv_encode}||=0;
   $f->{srv_status}||='READONLY';
   $f->{srv_encode}=1 if $f->{srv_type} eq 'ENCODER';
   $f->{srv_users_only}=~s/[^\d\,]+//g;
   $f->{srv_countries_only}=~s/[^\w\,]+//g;
   $f->{srv_users_only}=",$f->{srv_users_only}," if $f->{srv_users_only};
   $f->{srv_countries_only}=",$f->{srv_countries_only}," if $f->{srv_countries_only};

   my @sflds = qw(host_id 
                  srv_name 
                  srv_ip 
                  srv_cgi_url 
                  srv_htdocs_url
                  srv_disk_max 
                  srv_status 
                  srv_allow_regular 
                  srv_allow_premium 
                  disk_id 
                  disk_dev_df
                  disk_dev_io
                  srv_type 
                  srv_encode 
                  srv_users_only
                  srv_countries_only
                 );
   $f->{srv_disk_max}*=1024*1024*1024;
   if($f->{srv_id})
   {
      my @dat = map{$f->{$_}}@sflds;
      push @dat, $f->{srv_id};
      $db->Exec("UPDATE Servers SET ".join(',',map{"$_=?"}@sflds)." WHERE srv_id=?", @dat );
      $c->{srv_status} = $f->{srv_status};
      my $data = join('~',map{"$_:$c->{$_}"}qw(site_url site_cgi max_upload_files max_upload_filesize ip_not_allowed srv_status));
      $ses->api2($f->{srv_id},{op=>'update_conf',data=>$data});
   }

   my $res = $ses->api($f->{srv_cgi_url}, {op => 'test', dl_key=>$c->{dl_key}, site_cgi=>$c->{site_cgi}, disk_id=>$f->{disk_id}} );
   if($res=~/^OK/)
   {
      push @tests, 'api.cgi: OK';
      $res=~s/^OK://;
      push @tests, split(/\|/,$res);
   }
   else
   {
      push @tests, "api.cgi: ERROR ($res)";
   }

   for(@tests)
   {
      $allow_save=0 if /ERROR/;
      push @arr, {'text' => $_,
                  'class'=> /ERROR/ ? 'err' : 'ok'
                 };
   }

   unless($allow_save)
   {
      $f->{srv_disk_max}/=1024*1024*1024;
      $f->{"s_$f->{srv_status}"}=' checked';
      $f->{"srv_type_$f->{srv_type}"}=' checked';
      $ses->PrintTemplate("admin_server_form.html",
                          'tests'      => \@arr,
                          %{$f},
                          "s_$f->{srv_status}" => ' selected',
                          maincss      => 1,
                         );
   }

   unless($f->{srv_id})
   {
      $ses->message("Already have this host-disk pair!") if $db->SelectOne("SELECT srv_id FROM Servers WHERE host_id=? AND disk_id=?",$f->{host_id},$f->{disk_id});
      $c->{srv_status} = $f->{srv_status};

      $db->Exec("INSERT INTO Servers SET srv_created=CURDATE(), ".join(',',map{"$_=?"}@sflds), map{$f->{$_}}@sflds );
      $f->{srv_id} = $db->getLastInsertId;

      my $data = join('~',map{"$_:$c->{$_}"}qw(dl_key site_url site_cgi max_upload_files max_upload_filesize ip_not_allowed));
      my $res = $ses->api($f->{srv_cgi_url},{dl_key=>$c->{dl_key},op=>'update_conf',data=>$data});
      $ses->message("Server created. But was unable to update FS config.<br>Probably fs_key was not epty. Update fs_key manually and save Site Settings to sync.($res)") unless $res eq 'OK';
   }

   $ses->redirect("?op=admin_servers#host$f->{host_id}");
}

sub AdminHostEdit
{
   if($f->{del} && $f->{host_id})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my $srv = $db->SelectOne("SELECT COUNT(*) FROM Servers WHERE host_id=?",$f->{host_id});
      $ses->message("Host should contain no servers to be deleted") if $srv>0;
      $db->Exec("DELETE FROM Hosts WHERE host_id=?",$f->{host_id});
      $ses->redirect('?op=admin_servers');
   }
   if($f->{get_host_info} && $f->{host_cgi_url})
   {
		my $res = $ses->api($f->{host_cgi_url}, { op => 'get_host_info', dl_key=>$c->{dl_key} } );
		print"Content-type:text/html\n\n";
		print $res;
		exit;
   }

   my $host = $db->SelectRow("SELECT * FROM Hosts WHERE host_id=?",$f->{host_id});
   unless($f->{host_id})
   {
		$host->{host_max_enc}=2;
		$host->{host_max_trans}=1;
		$host->{host_max_url}=1;
		$host->{host_net_speed}=1000;
   }
   $host->{"epr$host->{host_max_enc}"} = ' selected';
   $host->{"trans$host->{host_max_trans}"} = ' selected';
   $host->{"url$host->{host_max_url}"} = ' selected';
   $host->{$_} = $c->{$_} for qw(m_q m_t m_f m_r);

   $ses->PrintTemplate("admin_host_form.html",
                       %{$host},
                       maincss      => 1,
                      );
}

sub AdminHostSave
{
   $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
   my (@tests,@arr);
   my $allow_save=1;
   require LWP::UserAgent;
   my $ua = LWP::UserAgent->new(timeout => 15,agent=>'Opera/9.51 (Windows NT 5.1; U; en)');
   $f->{host_cgi_url}=~s/\/$//;
   $f->{host_htdocs_url}=~s/\/$//;
   $f->{host_live}||=0;

   my @sflds = qw(	host_name 
   					host_ip 
   					host_cgi_url 
   					host_htdocs_url 
   					host_max_enc 
   					host_max_trans 
   					host_max_url 
   					host_transfer_speed 
   					host_net_speed 
   					host_notes 
   					host_live 
   					host_torrent 
   					host_ftp
   					host_proxy);

   if($f->{host_id})
   {
      my @dat = map{$f->{$_}}@sflds;
      push @dat, $f->{host_id};
      $db->Exec("UPDATE Hosts SET ".join(',',map{"$_=?"}@sflds)." WHERE host_id=?", @dat );
   }


   $ses->message("Host with same cgi-bin / htdocs URL already exist in DB") 
      if !$f->{host_id} && $db->SelectOne("SELECT host_id FROM Hosts WHERE host_cgi_url=? OR host_htdocs_url=?",$f->{host_cgi_url},$f->{host_htdocs_url});

   my $res = $ses->api($f->{host_cgi_url}, {op        => 'test_host', 
                                            dl_key    => $c->{dl_key}, 
                                            site_url  => $c->{site_url},
                                            site_cgi  => $c->{site_cgi},
                                            util_test => $f->{util_test}||0,
                                           } );
   if($res=~/^OK/)
   {
      push @tests, 'api.cgi: OK';
      $res=~s/^OK:(.*?)://;
      push @tests, split(/\|/,$res);
   }
   else
   {
      push @tests, "api.cgi: ERROR ($res)";
   }

   $res = $ua->get("$f->{host_cgi_url}/upload.cgi?mode=test");
   push @tests, $res->content eq 'XFS' ? 'upload.cgi: OK' : "upload.cgi: ERROR (problems with <a href='$f->{host_cgi_url}/upload.cgi\?mode=test' target=_blank>link</a>)";

   $res = $ua->get("$f->{host_htdocs_url}/index.html");
   push @tests, $res->content=~/xvs/i ? 'htdocs URL accessibility: OK' : "htdocs URL accessibility: ERROR (should see XVS on <a href='$f->{host_htdocs_url}/index.html' target=_blank>link</a>)";

   for(@tests)
   {
      $allow_save=0 if /ERROR/;
      push @arr, {'text' => $_,
                  'class'=> /ERROR/ ? 'err' : 'ok'
                 };
   }

   unless($allow_save)
   {
      $ses->PrintTemplate("admin_host_form.html",
                          'tests'      => \@arr,
                          %{$f},
                          maincss      => 1,
                         );
   }

   unless($f->{host_id})
   {
      $db->Exec("INSERT INTO Hosts SET ".join(',',map{"$_=?"}@sflds), map{$f->{$_}||''}@sflds );
      $c->{host_id} = $db->getLastInsertId;
      $c->{host_max_enc}=$f->{host_max_enc};
      $c->{host_max_trans}=$f->{host_max_trans};
      $c->{host_max_url}=$f->{host_max_url};
      my $data = join('~',map{"$_:$c->{$_}"}qw(host_id dl_key site_url site_cgi max_upload_files max_upload_filesize ip_not_allowed host_max_enc host_max_trans host_max_url user_agent));
      my $res = $ses->api($f->{host_cgi_url},
      						{
      							dl_key => $c->{dl_key},
      							op => 'update_conf',
      							data => $data,
      							restart_daemons => 1,
      						}
      						);
      $ses->message("Host created. But was unable to update XFSConfig.pm.<br>Fix the problem and save Site Settings to sync.($res)") unless $res eq 'OK';
      $f->{host_id} = $c->{host_id};
   }
   else
   {
      my $data = join('~',map{"$_:$f->{$_}"}qw(host_max_enc host_max_trans host_max_url));
      my $res = $ses->api($f->{host_cgi_url},
                          {
                          	dl_key=> $c->{dl_key},
                           	op    => 'update_conf',
                           	data  => $data,
                           	restart_daemons => 1,
                          });
      $ses->message("Host saved. But was unable to update XFSConfig.pm.<br>Fix the problem and save Site Settings to sync.($res)") unless $res eq 'OK';
   }

   $ses->redirect("?op=admin_servers#host$f->{host_id}");
}

sub AdminServersTransfer
{
   $f->{files_num}=5000 if $f->{file_id};
   $ses->message("Number of files required!") unless $f->{files_num};

   my $server2 = $db->SelectRow("SELECT * FROM Servers WHERE srv_id=?",$f->{srv_id2});
   $ses->message("Target server status=$server2->{srv_status} do not allow transfers!") unless $server2->{srv_status}=~/^(ON|READONLY)$/i;
   $ses->message("Target server disk is full!") if $server2->{srv_disk} > $server2->{srv_disk_max};

   my $order="file_size_n DESC" if $f->{order} eq 'size_desc';
   $order="file_size_n" if $f->{order} eq 'size_enc';
   $order="file_id DESC" if $f->{order} eq 'id_desc';
   
   $order="file_id" if $f->{order} eq 'id_enc';
   
   $order="file_views" if $f->{order} eq 'views_enc';
   $order="file_views DESC" if $f->{order} eq 'views_desc';

   my ($t2,$select_hot,$filter_hot);
   if($f->{order} eq 'hot_desc')
   {
      $select_hot=", SUM(bandwidth) as traff";
      $t2=",DailyTraffic t";
      $filter_hot="AND f.file_real_id=t.file_id AND t.dayhour>TO_DAYS(CURDATE())*24+HOUR(NOW())-24*1";
      $order="traff DESC";
   }
   $order||='file_id';
   $f->{files_num}=~s/\D//g;
   my $queue_ids = $db->SelectARef("SELECT file_real_id FROM QueueEncoding WHERE status='ENCODING'");
   my $active_ids = join(',', map{$_->{file_real_id}} @$queue_ids) || 0;
   my $filter_views1="AND file_views>$f->{filter_views_more}" if $f->{filter_views_more}=~/^\d+$/;
   my $filter_views2="AND file_views<$f->{filter_views_less}" if $f->{filter_views_less}=~/^\d+$/;
   my $filter_size1="AND file_size_n>$f->{filter_size_more}*1024*1024" if $f->{filter_size_more}=~/^\d+$/;
   my $filter_size2="AND file_size_n<$f->{filter_size_less}*1024*1024" if $f->{filter_size_less}=~/^\d+$/;
   my $filter_files="AND f.file_id IN (".join(',',@{ARef($f->{file_id})}).")" if $f->{file_id};
   my $filter_server="AND srv_id=$f->{srv_id1}" if $f->{srv_id1}=~/^\d+$/ && !$filter_files;
   my $files = $db->SelectARef("SELECT f.srv_id, f.file_id, f.file_real_id, f.file_real $select_hot
                                FROM (Files f $t2)
                                LEFT JOIN QueueTransfer q ON q.file_real_id=f.file_real_id
                                WHERE f.srv_id<>?
                                $filter_server
                                $filter_views1
                                $filter_views2
                                $filter_size1
                                $filter_size2
                                $filter_files
                                AND f.file_real_id NOT IN ($active_ids)
                                ORDER BY $order
                                LIMIT $f->{files_num}",$f->{srv_id2});
   for my $ff (@$files)
   {
      $db->Exec("DELETE FROM QueueTransfer WHERE file_real_id=?", $ff->{file_real_id} );
      $db->Exec("INSERT IGNORE INTO QueueTransfer
                 SET file_real_id=?, 
                     file_real=?, 
                     file_id=?,
                     premium=?, 
                     srv_id1=?,
                     srv_id2=?,
                     copy=?,
                     created=NOW()", $ff->{file_real_id}||$ff->{file_id}, 
                                     $ff->{file_real}, 
                                     $ff->{file_id}, 
                                     0, 
                                     $ff->{srv_id},
                                     $f->{srv_id2},
                                     $f->{copy}||0
                                      ) if $ff->{srv_id}!=$f->{srv_id2};
   }
   $ses->redirect_msg("?op=admin_servers",($#$files+1)." files were added to Transfer Queue");
}

sub AdminServerImport
{
   
   if($f->{'import'})
   {
      my $server = $db->SelectRow("SELECT * FROM Servers WHERE srv_id=?",$f->{srv_id});
      my $usr_id = $db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$f->{usr_login});
      $ses->message("No such user '$f->{usr_login}'") unless $usr_id;
      my $res = $ses->api2($f->{srv_id},{op     => 'import_list_do',
                                         usr_id => $usr_id,
                                         pub    => $f->{pub},
                                         srv_id => $server->{srv_id},
                                         disk_id=> $server->{disk_id},
                                         delete_after => $f->{delete_after},
                                        }
                          );
      $ses->message("Error happened: $res") unless $res=~/^OK/;
      $res=~/^OK:(\d+)/;
      $ses->message("$1 files were completely imported to system");
   }
   my $res = $ses->api2($f->{srv_id},{op=>'import_list'});
   $ses->message("Error when requesting API.<br>$res") unless $res=~/^\[/;
   require JSON;
   my $jj = JSON::decode_json($res);
   my @files;
   for(@{$jj})
   {
      push @files, {name=>$_->{filename}, folder=>$_->{folder}, size=>sprintf("%.1f Mb",$_->{size}/1048576)};
   }
   $ses->PrintTemplate("admin_server_import.html",
                       'files'   => \@files,
                       'srv_id'  => $f->{srv_id},
                       maincss      => 1,
                      );
}

sub AdminServerDelete
{
   $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
   
   if($f->{password})
   {
      $f->{login}=$ses->getUser->{usr_login};
      $ses->message("Wrong password") unless $ses->checkPasswdHash( $f->{password} );
   }
   else
   {
      $ses->PrintTemplate("confirm_password.html",
                          'msg'=>"Delete File Server and all files on it?",
                          'btn'=>"DELETE",
                          'op'=>'admin_server_del',
                          'id'=>$f->{srv_id},
                          maincss      => 1);
   }

   my $srv = $db->SelectRow("SELECT * FROM Servers WHERE srv_id=?",$f->{id});
   $ses->message("No such server") unless $srv;

   my $files = $db->SelectARef("SELECT * FROM Files WHERE srv_id=?",$srv->{srv_id});
   $ses->DeleteFilesMass($files);

   $db->Exec("DELETE FROM Servers WHERE srv_id=?",$srv->{srv_id});

   $ses->redirect('?op=admin_servers');
}

sub AdminSettings
{
    if($f->{ipblock_update} && $c->{m_7})
    {
    	require LWP::UserAgent;
    	my $ua = LWP::UserAgent->new(timeout => 120);
    	require XUtils;
    	my @arr;
    	for my $dbn ('ipproxy','ipserver','iptor')
    	{
    		my $filename="$c->{cgi_path}/logs/$dbn.dat";
    		my $res = $ua->get("https://sibsoft.net/cgi-bin/client.cgi?op=download_ipblock_db&id=$ses->{cliid}&dbname=$dbn")->content;
    		if(length($res)>1000)
    		{
    		        open FF, ">$filename"."new";
			print FF $res;
			close FF;
			my $fsize=-s $filename."new";
    			push @arr, "$dbn : downloaded ".sprintf("%.0f KB", $fsize/1024);
    			rename($filename."new", $filename);
    		}
    		else
    		{
    			push @arr, "$dbn : error : $res";
    		}
    	}
    	http_out("Result:<br>".join("<br>",@arr));
    }
   if($f->{save})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my @fields = qw(
      				disable_anon_payments
      				proxy_pairs_expire
      				cdn_version_num
      				player_color
      				m_y
      				m_y_users
      				m_y_cf_auth_email
      				m_y_cf_auth_key
      				m_y_cf_account_id
      				max_folders_limit_reg
      				max_folders_limit_prem
      				show_upload_srv_id
      				proxy_num_reg
      				proxy_num_prem
      				my_views_enabled
      				my_views_last_days
      				plans_storage
      				downloads_money_percent
      				hls_speed
      				hls_proxy_random_chance
      				hls_proxy_min_out
      				hls_proxy_min_views
      				hls_proxy_last_hours
      				hls_proxy_divider
      				m_3_hot_stats_last_hours
      				m_3_hot_files_run
      				m_3_hot_disk_max
      				m_3_hot_max_filesize
      				m_3_hot_min_views
      				m_9
      				m_9_users
      				m_9_override_id
      				m_6_delete
      				m_6_users_spec
      				m_6_users
      				ip_check_logic
      				paypal2_private_key
      				paypal2_public_key
      				paypal2_url
      				save_source_raw_info
      				m_5_disable_right_click
      				m_5_disable_shortcuts
      				no_ipcheck_agent_only
      				no_ipcheck_countries
      				remember_player_position
      				turbo_boost
      				quality_labels_bitrate
      				quality_labels_mode
      				upload_server_selection
      				enc_priority_time

      				alt_ads_title0
      				alt_ads_title1
					alt_ads_title2
					alt_ads_title3
					alt_ads_title4
					alt_ads_percent0
					alt_ads_percent1
					alt_ads_percent2
					alt_ads_percent3
					alt_ads_percent4
					alt_ads_tags0
					alt_ads_tags1
					alt_ads_tags2
					alt_ads_tags3
					alt_ads_tags4

					m_5_devtools_mode
					m_5_devtools_redirect
					m_5_adb_mode
					m_5_adb_script
					m_5_video_only
					m_5_adb_delay
					m_5_adb_no_prem
					m_5_devtools_no_admin

					hls2
					m_f_track_current

					srt_opacity_text
					srt_shadow_color
					srt_back_color

					torrent_clean_inactive
					torrent_dl_speed_reg
					torrent_dl_speed_prem
					torrent_up_speed_reg
					torrent_up_speed_prem
					torrent_peers_reg
					torrent_peers_prem

					enc_queue_transcode_priority

					enc_priority_l
					enc_priority_n
					enc_priority_h
					enc_priority_x

					hls_proxy
					hls_proxy_percent
					recaptcha3_pub_key
					recaptcha3_pri_key

					download_orig_recaptcha_v3
					static_embed_recaptcha_v3

					vid_play_anon_o
					vid_play_reg_o
					vid_play_prem_o

					vid_enc_anon_n
					vid_enc_reg_n
					vid_enc_prem_n
					vid_play_anon_n
					vid_play_reg_n
					vid_play_prem_n

					vid_enc_anon_l
					vid_enc_reg_l
					vid_enc_prem_l
					vid_play_anon_l
					vid_play_reg_l
					vid_play_prem_l

					vid_enc_anon_h
					vid_enc_reg_h
					vid_enc_prem_h
					vid_play_anon_h
					vid_play_reg_h
					vid_play_prem_h

					vid_enc_anon_x
					vid_enc_reg_x
					vid_enc_prem_x
					vid_play_anon_x
					vid_play_reg_x
					vid_play_prem_x

					vast_pauseroll
					vast_pauseroll_tag
					m_6_req_limit_day
					m_6_req_limit_min
					vid_keep_orig_playable
					m_e
					m_e_users
					ticket_categories
					ticket_moderator_ids
					ticket_moderator_categories
					ticket_email_user
					ticket_email_admin
					p2p_self_tracker_url
					player_default_audio_sticky
					player_default_audio_track
					srt_burn_default_language
					srt_mass_upload
					min_upload_length_sec
					max_upload_length_min
					upload_limit_files_last24
					allow_non_video_uploads
					m_n_instant_md5_upload
					m_8
					multi_audio_user_custom
					multi_audio_user_list
					default_audio_lang
					multi_audio_on
					max_fps_limit
					email_validation_code
					vjs_theme
					player_forward_rewind
					vast_countries

					site_name
					cdn_url
					enable_file_descr
					enable_file_comments
					ip_not_allowed
					fnames_not_allowed
					captcha_mode
					email_from
					contact_email
					symlink_expire
					items_per_page
					payment_plans
					paypal_email
					alertpay_email
					item_name
					currency_code
					link_format
					enable_search
					search_public_only
					bw_limit_days
					registration_confirm_email
					mailhosts_not_allowed
					sanitize_filename
					bad_comment_words
					add_filename_postfix
					recaptcha_pub_key
					recaptcha_pri_key
					coupons
					tla_xml_key
					m_c
					m_c_views_rate1
					m_c_views_num1
					m_c_views_rate2
					m_c_views_num2
					m_c_views_user
					m_c_views_skip
					m_c_sale_init_rate
					m_c_sale_renew_rate
					m_c_sale_user
					srt_on
					srt_max_size_kb
					srt_edge_style
					srt_color
					srt_font
					srt_size
					srt_auto
					srt_auto_langs
					srt_auto_enable
					srt_burn
					srt_burn_font
					srt_burn_size
					srt_burn_margin
					srt_burn_color
					srt_burn_coloroutline
					srt_burn_blackbox
					extra_user_fields
					maintenance_upload 
					maintenance_upload_msg
					maintenance_download
					maintenance_download_msg
					maintenance_full
					maintenance_full_msg
					google_plus_client_id
					twit_consumer1
					twit_consumer2
					m_j
					m_j_domain
					m_j_instant
					m_j_hide
					sales_profit_on
					tier_factor
					tier_views_number
					embeds_money_percent
					no_reencoding_mp4
					no_reencoding_flv
					smtp_auth
					mailgun_api_url
					mailgun_api_key
					smtp_server
					smtp_user
					smtp_pass

					file_data_fields
					file_cloning
					resolve_ip_country
					m_k_add_money
					m_k_add_money_list
					m_o
					more_files_number
					xframe_allow_frames
					link_format_uppercase

					m_r
					m_r_dash
					m_r_hls
					m_w
					m_d
					m_ads
					m_d_f
					m_d_f_limit
					m_d_a
					m_d_c
					m_d_featured
					m_d_legal
					m_t
					m_x
					m_x_width
					m_x_rows
					m_x_cols
					m_x_logo
					m_x_prem_only
					m_x_th_width
					m_x_th_height
					webmoney_merchant_id
					webmoney_secret_key
					ping_google_sitemaps
					deurl_site
					deurl_api_key
					smscoin_id
					show_last_news_days
					link_ip_logic
					daopay_app_id
					cashu_merchant_id
					paypal_subscription
					m_h
					m_h_login
					m_h_password
					m_v_width
					m_v_height
					m_n
					payout_systems
					vid_keep_orig
					okpay_receiver
					hipay_url
					hipay_merchant_id
					hipay_merchant_password
					hipay_website_id
					pwall_app_id
					pwall_secret_key
					lr_acc
					lr_store
					category_required
					optimize_hdd_perfomance
					files_expire_limit
					news_enabled
					approve_required
					approve_required_first
					m_d_file_approve
					uploads_selected_only
					m_f
					m_f_users
					m_t_users
					m_f_subdomain

					thumb_width
					thumb_height
					thumb_position

					m_h
					m_h_hd
					m_h_lq

					vid_encode_n
					vid_resize_side_n
					vid_resize_n
					vid_quality_mode_n
					vid_quality_n
					vid_bitrate_n
					vid_audio_bitrate_n
					vid_audio_channels_n
					vid_audio_rate_n
					vid_preset_n
					vid_preset_alt_n
					vid_crf_bitrate_max_n
					vid_mobile_support_n
					vid_transcode_max_bitrate_n
					vid_transcode_max_abitrate_n
					watch_speed_n
					watch_speed_auto_n
					
					vid_encode_l
					vid_resize_side_l
					vid_resize_l
					vid_quality_mode_l
					vid_quality_l
					vid_bitrate_l
					vid_audio_bitrate_l
					vid_audio_channels_l
					vid_audio_rate_l
					vid_preset_l
					vid_preset_alt_l
					vid_fps_l
					vid_crf_bitrate_max_l
					vid_transcode_max_bitrate_l
					vid_transcode_max_abitrate_l
					watch_speed_l
					watch_speed_auto_l

					vid_encode_h
					vid_resize_side_h
					vid_resize_h
					vid_quality_mode_h
					vid_quality_h
					vid_bitrate_h
					vid_audio_bitrate_h
					vid_audio_channels_h
					vid_audio_rate_h
					vid_preset_h
					vid_preset_alt_h
					vid_play_h_anon
					vid_play_h_reg
					vid_play_h_prem
					vid_crf_bitrate_max_h
					vid_transcode_max_bitrate_h
					vid_transcode_max_abitrate_h
					watch_speed_h
					watch_speed_auto_h

					vid_encode_x
					vid_resize_side_x
					vid_resize_x
					vid_quality_mode_x
					vid_quality_x
					vid_bitrate_x
					vid_audio_bitrate_x
					vid_audio_channels_x
					vid_audio_rate_x
					vid_preset_x
					vid_preset_alt_x
					vid_play_x_anon
					vid_play_x_reg
					vid_play_x_prem
					vid_crf_bitrate_max_x
					vid_transcode_max_bitrate_x
					vid_transcode_max_abitrate_x
					watch_speed_x
					watch_speed_auto_x

					m_b
					m_b_users
					m_b_rate
					m_k
					m_k_plans
					m_k_manual
					max_watch_time_period
					m_z
					m_z_cols
					m_z_rows
					time_slider_anon
					time_slider_reg
					time_slider_prem
					track_views_percent

					enabled_anon
					max_upload_files_anon
					max_upload_filesize_anon
					download_countdown_anon
					captcha_anon
					ads_anon
					add_download_delay_anon
					bw_limit_anon
					remote_url_anon
					direct_links_anon
					down_speed_anon
					max_download_filesize_anon
					video_embed_anon
					video_embed2_anon
					flash_upload_anon
					files_expire_access_anon
					file_dl_delay_anon
					pre_download_anon
					fullscreen_anon
					max_watch_time_anon
					video_player_anon
					video_time_limit_anon

					enabled_reg
					upload_enabled_reg
					max_upload_files_reg
					disk_space_reg
					max_upload_filesize_reg
					max_upload_files_reg
					download_countdown_reg
					captcha_reg
					ads_reg
					add_download_delay_reg
					bw_limit_reg
					remote_url_reg
					direct_links_reg
					down_speed_reg
					max_download_filesize_reg
					max_rs_leech_reg
					torrent_dl_slots_reg
					video_embed_reg
					video_embed2_reg
					flash_upload_reg
					files_expire_access_reg
					file_dl_delay_reg
					pre_download_reg
					fullscreen_reg
					queue_url_max_reg
					queue_url_working_max_reg
					max_watch_time_reg
					video_player_reg
					video_time_limit_reg

					enabled_prem
					upload_enabled_prem
					max_upload_files_prem
					disk_space_prem
					max_upload_filesize_prem
					max_upload_files_prem
					download_countdown_prem
					captcha_prem
					ads_prem
					add_download_delay_prem
					bw_limit_prem
					remote_url_prem
					direct_links_prem
					down_speed_prem
					max_download_filesize_prem
					max_rs_leech_prem
					torrent_dl_slots_prem
					video_embed_prem
					video_embed2_prem
					flash_upload_prem
					files_expire_access_prem
					file_dl_delay_prem
					pre_download_prem
					fullscreen_prem
					queue_url_max_prem
					queue_url_working_max_prem
					max_watch_time_prem
					video_player_prem
					video_time_limit_prem

					views_profit_on
					tier_sizes
					tier1_countries
					tier2_countries
					tier3_countries
					tier4_countries
					tier1_money
					tier2_money
					tier3_money
					tier4_money
					tier5_money
					image_mod_no_download
					video_mod_no_download
					clean_ip2files_days
					truncate_views_daily
					anti_dupe_system
					two_checkout_sid
					plimus_contract_id
					moneybookers_email
					max_money_last24
					sale_aff_percent
					referral_aff_percent
					min_payout
					del_money_file_del
					convert_money
					convert_days
					money_filesize_limit
					dl_money_anon
					dl_money_reg
					dl_money_prem
					show_more_files
					bad_ads_words
					cron_test_servers
					m_i_magick
					deleted_files_reports

					download_anon
					download_reg
					download_prem

					index_featured_on
					index_featured_num
					index_featured_min_length
					index_featured_max_length
					index_most_viewed_on
					index_most_viewed_num
					index_most_viewed_hours
					index_most_viewed_min_length
					index_most_viewed_max_length
					index_most_rated_on
					index_most_rated_num
					index_most_rated_hours
					index_most_rated_min_length
					index_most_rated_max_length
					index_just_added_on
					index_just_added_num
					index_just_added_min_length
					index_just_added_max_length
					video_extensions
               audio_extensions
               image_extensions
               archive_extensions
					facebook_app_id_like
					facebook_like_on
					facebook_comments
					enc_queue_premium_priority
					server_transfer_speed
					m_p
					m_p_parts
					m_p_length
					m_p_source
					m_p_show_anon
					m_p_show_reg
					m_p_show_prem
					m_p_custom_upload

					m_v
					m_v_users
					m_v_image_logo
					m_v_fonts
					m_v_image_max_size

					m_s
					m_s_users
					m_s_samples
					m_s_upload

					m_g
					m_g_users
					m_g_frames_max

					m_l

					m_u
					memcached_address
					memcached_expire

					twitter_api_key
					twitter_api_secret

					facebook_app_id
					facebook_app_secret

					vk_app_id
					vk_app_secret

					google_app_id
					google_app_secret

					login_limit1_ips
					login_limit1_hours
					login_limit1_subnets
					login_limit2_max
					login_limit2_hours

					vid_resize_method
					player_js_encode
					max_url_uploads_user
					player_sharing
					tos_accept_checkbox
					custom_snapshot_upload
					m_f_update_on_cron
					m_f_update_on_reg
					m_f_update_on_buy
					m_f_sync_files_after
					next_upload_server_logic
					banned_countries
					player
					jw6_key
					player_lightsout
					bad_referers
					m_n
					m_n_users
					m_n_max_links
					jw5_skin
					jw6_skin
					m_1
					srt_convert_to_vtt
					player_embed_dl_button
					jw7_key
					jw7_skin
					player_related
					m_i
					m_i_server
					m_i_cf_zone_id
					m_i_cf_token
					use_cloudflare_ip_header
					max_money_x_limit
					max_money_x_days
					embed_static
					overload_no_hd
					m_h_enc_order
					fair_encoding_slots
					alt_preset_max_queues
					delete_disk_time
					player_image
					highload_mode
					highload_mode_auto
					srt_opacity
					srt_allow_anon_upload
					mp4_preload
					adb_no_money
					premium_no_money
					player_overlay_text
					embed_responsive
					no_video_ip_check
					m_a
					m_a_delete_after
					m_a_lock_delete
					player_image_stretching
					embed_disabled
					embed_disable_noref
					embed_disable_except_domains
					embed_no_hd
					player_logo_url
					player_logo_link
					player_logo_hide
					player_logo_position
					player_logo_padding
					player_logo_opacity
					p2p_on
					p2p_provider
					p2p_streamroot_key
					p2p_peer5_key
					p2p_min_host_out
					p2p_min_views
					p2p_min_views_30m
					p2p_only_srvname_with
					p2p_hours
					main_server_ip
					no_referer_no_money
					file_server_ip_check
					force_disable_adb
					player_about_text
					player_about_link
					bad_agents
					m_5
					m_6
					m_6_clone
					m_6_direct
					jw8_key
					player_chromecast
					max_complete_views_daily
					email_html
					player_default_quality
					hls_preload_mb
					m_a_hide_redirect
					overload_no_transfer
					overload_no_upload
					login_captcha
					alt_ads_mode
					embed_disable_only_domains
					m_3
					m_3_uploaded_days
					m_3_noviews_days
					m_3_serverdisk_min
					m_3_max_total_size
					m_q
					m_q_users
					m_q_max_streams_live
					m_q_allow_recording
					m_q_stop_invis_after
					m_r_no_mp4
					index_live_streams_on
					index_live_streams_num
					m_7
					m_7_video_noserver
					m_7_video_noproxy
					m_7_video_notor
					m_7_video_action
					m_7_video_action_message_txt
					m_7_video_download1
					m_7_video_embed
					m_7_money_noserver
					m_7_money_noproxy
					m_7_money_notor
					m_7_money_percent
					force_disable_popup_blocker
					vast_tag
					vast_client
					allow_no_encoding
					expire_quality_name
					expire_quality_access_reg
					expire_quality_access_prem
					no_ipcheck_mobile
					no_ipcheck_ipv6
					m_7_stats
					skip_uploader_priority
					dirlinks_allowed_referers
					video_page_disabled
					watch_require_recaptcha
					watch_require_recaptcha_expire
					player_logo_fadeout
					player_logo_mode
					vast_vpaid_mode
					vast_preload
					enc_queue_notmp4_priority
					player_playback_rates
					embed_alt_domain
					noplay_from_uploader_encoder
					m_w
					vast_preroll
					vast_midroll
					vast_midroll_time
					vast_postroll
					vast_postroll_time
					vast_midroll_tag
					vast_postroll_tag
					vast_skip_mins
					vast_alt_ads_hide
                     );

            push @fields, map { $_->{name} } @{ &getPluginsOptions('Payments') };

            my @fields_fs = qw(	site_url 
								site_cgi 
								ip_not_allowed
								dl_key
								m_x
								m_x_width
								m_x_rows
								m_x_logo
								m_x_prem_only
								m_x_th_width
								m_x_th_height
								video_extensions
                        audio_extensions
                        image_extensions
                        archive_extensions
								m_z
								m_z_cols
								m_z_rows
								m_t
								srt_auto

								thumb_width
								thumb_height
								thumb_position

								enabled_anon
								enabled_reg
								enabled_prem
								max_upload_filesize_prem

								custom_snapshot_upload
								m_f_sync_files_after
								main_server_ip
								dirlinks_allowed_referers
								allow_non_video_uploads
                        );
      $f->{payment_plans}=~s/\s//gs;
      $f->{item_name} = $ses->{cgi_query}->escape($f->{item_name});

      my $conf;
      open(F,"$c->{cgi_path}/XFileConfig.pm")||$ses->message("Can't read XFileConfig");
      $conf.=$_ while <F>;
      close F;

      $f->{ip_not_allowed}=~s/\r//gs;
      my @ips=grep{/^[\d\.]+$/}split(/\n/,$f->{ip_not_allowed});

      for(qw(ip_not_allowed fnames_not_allowed mailhosts_not_allowed bad_comment_words bad_ads_words coupons bad_referers bad_agents dirlinks_allowed_referers))
      {
        $f->{$_}=~s/\r//gs;
        $f->{$_}=~s/\n/|/gs;
        $f->{$_}=~s/\|{2,99}/|/gs;
        $f->{$_}=~s/\|$//gs;
      }

      

      $f->{ip_not_allowed}=~s/\*/\\d+/gs;
      $f->{ip_not_allowed}="^($f->{ip_not_allowed})\$" if $f->{ip_not_allowed};

      $f->{fnames_not_allowed}="($f->{fnames_not_allowed})" if $f->{fnames_not_allowed};

      $f->{mailhosts_not_allowed}="($f->{mailhosts_not_allowed})" if $f->{mailhosts_not_allowed};

      $f->{bad_comment_words}="($f->{bad_comment_words})" if $f->{bad_comment_words};

      $f->{bad_ads_words}="($f->{bad_ads_words})" if $f->{bad_ads_words};

      $f->{bad_referers}="($f->{bad_referers})" if $f->{bad_referers};
      $f->{bad_agents}="($f->{bad_agents})" if $f->{bad_agents};

      $f->{video_extensions}=~s/^\|+//;
      $f->{video_extensions}=~s/\|+$//;
      $f->{video_extensions}=~s/\|{2,10}/|/g;

      $f->{audio_extensions}=~s/^\|+//;
      $f->{audio_extensions}=~s/\|+$//;
      $f->{audio_extensions}=~s/\|{2,10}/|/g;      

      $f->{image_extensions}=~s/^\|+//;
      $f->{image_extensions}=~s/\|+$//;
      $f->{image_extensions}=~s/\|{2,10}/|/g;   

      $f->{archive_extensions}=~s/^\|+//;
      $f->{archive_extensions}=~s/\|+$//;
      $f->{archive_extensions}=~s/\|{2,10}/|/g;              

      $f->{player_playback_rates}=~s/[^\d\.\,\s]+//g;

      for my $x (@fields)
      {
         my $val = $f->{$x};
         $val=~s/\'//g;
         
         $conf=~s/(\W)$x\s*=>\s*('.*?')\s*,/"$1$x => '$val',"/e;
      }
      
      open(F,">$c->{cgi_path}/logs/XFileConfig.txt")||$ses->message("Can't write $c->{cgi_path}/logs/XFileConfig.txt:$!");
      print F $conf;
      close F;

      open(F,">$c->{cgi_path}/XFileConfig.pm")||$ses->message("Can't write XFileConfig");
      print F $conf;
      close F;

      unlink("$c->{cgi_path}/logs/XFileConfig.txt");

		my $tt = $ses->CreateTemplate('emb.html');
		$tt->param( static_embed_recaptcha_v3 => $f->{static_embed_recaptcha_v3},
					recaptcha3_pub_key => $f->{recaptcha3_pub_key},
					);
		$tt->param( m_i_server => $f->{m_i_server} ) if $f->{m_i};
		open(F,">$c->{site_path}/emb.html")||$ses->message("Can't write $c->{site_path}/emb.html:$!");
		print F $tt->output;
		close F;

      $f->{site_url}=$c->{site_url};
      $f->{site_cgi}=$c->{site_cgi};
      $f->{dl_key}  =$c->{dl_key};

      my $data = join('~',map{"$_:$f->{$_}"}@fields_fs);
      
      print"Content-type:text/html\n\n<HTML><BODY style='font:13px Arial;background:#eee;text-align:center;'>";
      my $failed=0;
      if($f->{update_fs_config})
      {
          my $servers = $db->SelectARef("SELECT * FROM Servers WHERE srv_status<>'OFF' GROUP BY srv_ip");
          $|++;
          print"Have ".($#$servers+1)." servers to update.<br><br>";
          for(@$servers)
          {
             print"ID=$_->{srv_id} $_->{srv_name}...";
             my $res = $ses->api($_->{srv_cgi_url},{ dl_key=>$c->{dl_key}, op=>'update_conf', data=>$data });
             if($res eq 'OK')
             {
                print"OK<br>";
             }
             else
             {
                print"FAILED! ($res)<br>";
                $failed++;
             }
         }
      }
      my $token = $ses->genToken;
      print"<br><br>Done.<br>$failed servers failed to update.<br><br><a href='?op=admin_settings'>Back to Site Settings</a>";
      print"<Script>window.location='?op=admin_settings&token=$token';</Script>" unless $failed;
      print"</BODY></HTML>";
      exit;
   }

   if($f->{expire_eval})
   {
   		print"Content-type: text/html\n\nEstimated number of files to be deleted next run of cron_expire.pl script with values selected:<br>";
   		if($f->{files_expire_access_reg})
	      {
	         my $reg = $db->SelectRow("SELECT COUNT(*) as num, ROUND(SUM(file_size_n+file_size_h+file_size_l+file_size_o+file_size_x)/1073741824,1) as size
	                                     FROM Files f, Users u
	                                     WHERE f.usr_id=u.usr_id
	                                     AND usr_premium_expire<NOW()
	                                     AND usr_no_expire=0
	                                     AND file_last_download < NOW()-INTERVAL ? DAY
	                                     ",
	                                     $f->{files_expire_access_reg});
	         print"Free users: $reg->{num} files to delete, ~ $reg->{size} GB total<br>\n";
	      }
	      if($f->{files_expire_access_prem})
	      {
	         my $prem = $db->SelectRow("SELECT COUNT(*) as num, ROUND(SUM(file_size_n+file_size_h+file_size_l+file_size_o+file_size_o)/1073741824,1) as size
	                                     FROM Files f, Users u
	                                     WHERE f.usr_id=u.usr_id
	                                     AND usr_premium_expire>NOW()
	                                     AND usr_no_expire=0
	                                     AND file_last_download < NOW()-INTERVAL ? DAY
	                                     ",
	                                     $f->{files_expire_access_prem});
	         print"Premium users: $prem->{num} files to delete, ~ $prem->{size} GB total<br>\n";
	      }
	      exit;
   }
   if($f->{expire_eval_quality})
   {
   		die"invalid quality" unless $f->{quality}=~/^(n|h|l|o|p)$/i;
   		print"Content-type: text/html\n\nEstimated size to be deleted next run of cron_expire.pl script with values selected:<br>";
   		if($f->{expire_quality_access_reg})
	      {
	         my $reg = $db->SelectRow("SELECT COUNT(*) as num, ROUND(SUM(file_size_$f->{quality})/1073741824,1) as size
	                                     FROM Files f, Users u
	                                     WHERE f.usr_id=u.usr_id
	                                     AND usr_premium_expire < NOW()
	                                     AND usr_no_expire = 0
	                                     AND file_last_download < NOW()-INTERVAL ? DAY
	                                     AND file_size_$f->{quality} > 0
	                                     ",
	                                     $f->{expire_quality_access_reg});
	         print"Free users: $reg->{num} files affected, ~ $reg->{size} GB total<br>\n";
	      }
	      if($f->{expire_quality_access_prem})
	      {
	         my $prem = $db->SelectRow("SELECT COUNT(*) as num, ROUND(SUM(file_size_$f->{quality})/1073741824,1) as size
	                                     FROM Files f, Users u
	                                     WHERE f.usr_id=u.usr_id
	                                     AND usr_premium_expire > NOW()
	                                     AND usr_no_expire = 0
	                                     AND file_last_download < NOW()-INTERVAL ? DAY
	                                     AND file_size_$f->{quality} > 0
	                                     ",
	                                     $f->{expire_quality_access_prem});
	         print"Premium users: $prem->{num} files affected, ~ $prem->{size} GB total<br>\n";
	      }
	      exit;
   }

   for(qw(ip_not_allowed fnames_not_allowed mailhosts_not_allowed bad_comment_words bad_ads_words coupons bad_referers bad_agents dirlinks_allowed_referers))
   {
		$c->{$_}=~s/[\^\(\)\$\\]//g;
   		$c->{$_}=~s/\|/\n/g;
   }
   $c->{ip_not_allowed}=~s/d\+/*/g;
   $c->{coupons}=~s/\|/\n/g;
   $c->{"link_format$c->{link_format}"}=' selected';
   $c->{"enp_$_"}=$ses->iPlg($_) for ('a'..'z',0..9);
   $c->{tier_sizes}||='0|10|100';
   $c->{tier1_countries}||='US|CA';
   $c->{tier1_money}||='1|2|3';
   $c->{tier2_countries}||='DE|FR|GB';
   $c->{tier2_money}||='1|2|3';
   $c->{tier3_money}||='1|2|3';
   $c->{"m_i_wm_position_$c->{m_i_wm_position}"}=1;
   $c->{m_m} = $ses->iPlg('m');
   $c->{cliid} = $ses->{cliid};
   $c->{"m_v_page_".$c->{m_v_page}}=1;
   $c->{m_f_users}||='registered';
   $c->{m_t_users}||='registered';
   $c->{m_6_users}||='registered';
   $c->{m_6_users_spec}||='registered';
   $c->{m_9_users}||='registered';
   $c->{m_y_users}||='registered';
   $c->{m_p_source}||='n';
   $c->{vid_quality_n}||=25;
   $c->{vid_bitrate_n}||=500;
   $c->{player_overlay_text} =~ s/"/&quot;/gs;
   for(qw(vid_resize_side_n vid_resize_side_h vid_resize_side_l 
          vid_quality_mode_n vid_quality_mode_h vid_quality_mode_l
          m_v_users
          m_s_users
          m_g_users
          m_f_users
          m_t_users
          m_6_users
          m_6_users_spec
          m_9_users
          m_p_source
          m_b_users
          m_e_users
          m_a_users
          m_n_users
          m_y_users
          tier_factor
          vid_container_n
          vid_container_h
          vid_container_l
          next_upload_server_logic
          player
          enable_search
          m_h_enc_order
          player_image
          mp4_preload
          player_image_stretching
          player_logo_position
          smtp_auth
          p2p_provider
          player_default_quality
          m_q_users
          m_7_video_action
          vast_client
          player_logo_mode
          vast_vpaid_mode
          email_validation_code
          m_5_devtools_mode
          m_5_adb_mode
          upload_server_selection
          quality_labels_mode
          ip_check_logic
          ))
   {
       $c->{"$_\_".$c->{$_}}=' checked';
   }
   for(qw(vid_audio_rate_n
          vid_audio_rate_h 
          vid_audio_rate_l 
          vid_preset_n 
          vid_preset_h 
          vid_preset_l
          vid_preset_n_alt
          vid_preset_h_alt
          vid_preset_l_alt
          vid_audio_channels_n
          vid_audio_channels_h
          vid_audio_channels_l
          vid_audio_bitrate_n
          vid_audio_bitrate_h
          vid_audio_bitrate_l
          m_s_samples
          jw5_skin
          jw6_skin
          srt_edge_style
          force_disable_adb
          srt_burn_font
          expire_quality_name
          vjs_theme
          hls_proxy_divider
          ))
   {
       $c->{"$_\_".$c->{$_}}=' selected';
   }
   return $ses->redirect('/') if $ses->{"\x70"."\x6C\x67"}->{1} && $db->SelectOne("SELECT COUNT(*) FROM Hosts")>1;

   my $message="Remove installation files for security: install.cgi / install.sql / install_main.sh / install_fs.sh" 
      if -f "$c->{cgi_path}/install.cgi" || -f "$c->{cgi_path}/install.sql" || -f "$c->{cgi_path}/install_main.sh" || -f "$c->{cgi_path}/install_fs.sh";

    require XCountries;
    my @lang_list;
    for (sort{$XCountries::iso_to_country->{$a} cmp $XCountries::iso_to_country->{$b}} grep{/^\w\w$/} keys %{$XCountries::iso_to_country})
    {
        push @lang_list, { value=>$_, name=>$XCountries::iso_to_country->{$_} };
    }

   my (@skins5,@skins6,@skins7);
   if(-d "$c->{site_path}/player5/skins")
   {
	opendir(DIRS,"$c->{site_path}/player5/skins");
	push @skins5, map{/^(.+)\.zip$/;{name=>$1,selected=>($1 eq $c->{jw5_skin} ? ' selected' : '')}} sort grep{/\.zip$/} readdir(DIRS);
   }
   if(-d "$c->{site_path}/player6/skins")
   {
    opendir(DIRS,"$c->{site_path}/player6/skins");
    push @skins6, map{/^(.+)\.xml$/;{name=>$1,selected=>($1 eq $c->{jw6_skin} ? ' selected' : '')}} sort grep{/\.xml$/} readdir(DIRS);
   }
   if(-d "$c->{site_path}/player7/skins")
   {
    opendir(DIRS,"$c->{site_path}/player7/skins");
    push @skins7, map{/^(.+)\.css$/;{name=>$1,selected=>($1 eq $c->{jw7_skin} ? ' selected' : '')}} sort grep{/\.css$/} readdir(DIRS);
   }

   my @srt_fonts = map{{font_name=>$_, selected=>($_ eq $c->{srt_burn_font} ? ' selected' : '')}} split /\s*\,\s*/, $c->{fileserver_fonts};
   
   my @qualities;
   for my $q (@{$c->{quality_letters}})
   {
   		my $x;
   		$x->{quality_name} = $q;
   		$x->{"quality_name_$q"} = 1;
   		$x->{hide}=1 if !$c->{enp_h} && $q ne 'n';
   		$x->{quality_title} = $c->{quality_labels}->{$q};
   		$x->{quality_enabled} = $c->{"vid_encode_$q"};
   		$x->{enc_priority} = $c->{"enc_priority_$q"};
   		for (qw(vid_resize
				vid_quality_mode
				vid_quality
				vid_bitrate
				vid_audio_bitrate
				vid_audio_rate
				vid_audio_channels
				vid_preset
				vid_preset_alt
				vid_enc_anon
				vid_enc_reg
				vid_enc_prem
				vid_crf_bitrate_max
				watch_speed
				watch_speed_auto
				vid_transcode_max_bitrate
				vid_transcode_max_abitrate
				vid_enc_anon
				vid_enc_reg
				vid_enc_prem
				vid_play_anon
				vid_play_reg
				vid_play_prem
   			))
   		{
   			$x->{$_} = $c->{"$_\_$q"};
   		}
   		for(qw( vid_enc_anon
   				vid_enc_reg
   				vid_enc_prem
   				vid_play_anon
   				vid_play_reg
   				vid_play_prem
   				vid_quality_mode
   			))
   		{
   			$x->{"$_\_$x->{$_}"}=' checked';
   		}
   		
   		for(qw( vid_preset
   				vid_preset_alt
   				vid_audio_bitrate
   				vid_audio_channels
   				vid_audio_rate
   			))
   		{
   			$x->{"$_\_$x->{$_}"}=' selected';
   		}
   		push @qualities, $x;
   }
   $c->{license_key} = "[Nulled Edition]";
   $ses->PrintTemplate("admin_settings.html",
                       %{$c},
                       "captcha_$c->{captcha_mode}" => ' checked',
                       item_name		=> $ses->{cgi_query}->unescape($c->{item_name}),
                       "comments_$c->{enable_file_comments}" => " selected",
                       message 			=> $message,
                       payments_list	=> [ $ses->getPlugins('Payments')->get_admin_settings ],
                       lang_list     	=> \@lang_list,
                       srt_fonts		=> \@srt_fonts,
                       qualities		=> \@qualities,
                       maincss      => 1,
                      );
}

sub AdminStats
{
   my @d1 = $ses->getTime(time-7*24*3600);
   my @d2 = $ses->getTime();
   my $day1 = $f->{date1}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date1} : "$d1[0]-$d1[1]-$d1[2]";
   my $day2 = $f->{date2}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date2} : "$d2[0]-$d2[1]-$d2[2]";

   my $days_delta = $db->SelectOne("SELECT DATEDIFF(?,?)", $day2, $day1 );

   my $list2 = $db->SelectARef("SELECT *, ROUND(bandwidth/pow(1024,3)) as bandwidth, DATE_FORMAT(day,'%e %b') as x
                               FROM Stats
                               WHERE day>=?
                               AND  day<=?",$day1,$day2);

   my $list = $ses->getDatesList($list2,$day1,$day2);

   for my $x (@$list)
   {
      $x->{$_}||=0 for qw(uploads downloads deleted views registered bandwidth paid profit);
   }

   my @list2 = @$list;
   my %totals;
   for my $x (@list2)
   {
      $x->{profit_total} = sprintf("%.05f",$x->{paid}+$x->{profit});
      $totals{"sum_$_"}+=$x->{$_} for qw(uploads deleted downloads views views_adb registered bandwidth paid profit profit_total payout);
   }

   my $listperf;
   if($days_delta>7)
   {
   	$listperf = $db->SelectARef("SELECT ROUND(AVG(encode)) as encode, 
   										ROUND(AVG(urlupload)) as urlupload, 
   										ROUND(AVG(transfer)) as transfer, 
   										ROUND(AVG(connections)) as connections, 
   										ROUND(AVG(speed_out)) as speed_out,
   										ROUND(AVG(speed_in)) as speed_in,
								DATE(`time`) as `time1`
								FROM StatsPerf
								WHERE time>=?
								AND  time<? + INTERVAL 1 DAY
								GROUP BY time1
								ORDER BY time1", $day1, $day2 );
   }
   else
   {
	$listperf = $db->SelectARef("SELECT *,
								`time` as `time1`
								FROM StatsPerf
								WHERE time>=?
								AND  time<? + INTERVAL 1 DAY
								ORDER BY time", $day1, $day2);
   }
   
	$totals{skip}=1;
	if($days_delta>3)
	{
		$totals{xunit} = 'day';
	}
	else
	{
		$totals{xunit} = 'hour';
		$totals{skip} = 2 if $#$listperf>48;
		$totals{skip} = 6 if $#$listperf>96;
	}
	
   $ses->PrintTemplate("admin_stats.html",
                       'list'       => $list,
                       'list2'      => \@list2,
                       'listperf'	=> $listperf,
                       'date1'      => $day1,
                       'date2'      => $day2,
                       %totals,
                       maincss      => 1,
                      );
}

sub AdminComments
{
   $ses->message("Access denied") if !$ses->getUser->{usr_adm} && !($c->{m_d} && $ses->getUser->{usr_mod} && $c->{m_d_c});
   if($f->{del_selected} && $f->{cmt_id})
   {
      my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{cmt_id})});
      $ses->redirect($c->{site_url}) unless $ids;
      $db->Exec("DELETE FROM Comments WHERE cmt_id IN ($ids)");
      $ses->redirect("?op=admin_comments");
   }
   if($f->{rr})
   {
      $ses->redirect( &CommentRedirect(split(/-/,$f->{rr})) );
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
   $ses->PrintTemplate("admin_comments.html",
                       'list'   => $list,
                       'key'    => $f->{key}, 
                       'paging' => $ses->makePagingLinks($f,$total),
                       maincss      => 1,
                      );
}

sub AdminPayouts
{
	if($f->{export_file} && $f->{pay_id})
	{
		my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{pay_id})});
		$ses->redirect($c->{site_url}) unless $ids;
		my $list = $db->SelectARef("SELECT p.*
									FROM Payments p
									WHERE id IN ($ids)
									AND status='PENDING'");
		my $date = sprintf("%d-%d-%d",&getTime());
		print qq{Content-Type: application/octet-stream\n};
		print qq{Content-Disposition: attachment; filename="paypal-mass-pay-$date.txt"\n};
		print qq{Content-Transfer-Encoding: binary\n\n};
		for my $x (@$list)
		{
		 next unless $x->{pay_type} =~ /paypal/i;
		 print"$x->{pay_info}\t$x->{amount}\t$c->{currency_code}\tmasspay_$x->{usr_id}\tPayment\r\n";
		}
		exit;
	}
	if($f->{mark_paid} && $f->{pay_id})
	{
		my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{pay_id})});
		$ses->redirect($c->{site_url}) unless $ids;
		$db->Exec("UPDATE Payments SET status='PAID', processed=NOW() WHERE id IN ($ids)" );
		my $sum = $db->SelectOne("SELECT SUM(amount) FROM Payments WHERE id IN ($ids)");
		$db->Exec("INSERT INTO Stats SET day=CURDATE(), payout=? ON DUPLICATE KEY UPDATE payout=payout+?",$sum,$sum);
		$ses->redirect_msg("?op=admin_payouts","Selected payments marked as Paid");
	}
	if($f->{mark_rejected} && $f->{pay_id})
	{
		my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{pay_id})});
		$ses->redirect($c->{site_url}) unless $ids;
		$db->Exec("UPDATE Payments SET status='REJECTED', processed=NOW() WHERE id IN ($ids)" );
		$ses->redirect_msg("?op=admin_payouts","Selected payments marked as Rejected");
	}
	my $filter_type="AND p.pay_type='$f->{pay_type}'" if $f->{pay_type}=~/^\w+$/;
	my $list = $db->SelectARef("SELECT p.*, u.usr_login, u.usr_email, u.usr_pay_email, u.usr_pay_type,
								(SELECT COUNT(*) FROM Payments p1 WHERE p1.usr_id=p.usr_id AND status='PAID') as num_ok,
								(SELECT COUNT(*) FROM Payments p2 WHERE p2.usr_id=p.usr_id AND status='REJECTED') as num_bad
								FROM Payments p, Users u
								WHERE status='PENDING'
								AND p.usr_id=u.usr_id
								$filter_type
								ORDER BY created");
	my $ptypes;
	my $amount_sum=0;
	for(@$list)
	{
		$ptypes->{$_->{pay_type}}++;
		$amount_sum+=$_->{amount};
	}
	my @pay_types = map{{name => $_}} keys %$ptypes;
	$ses->PrintTemplate("admin_payouts.html",
						list 				=> $list,
						pay_types			=> \@pay_types,
						amount_sum 			=> sprintf("%.02f",$amount_sum),
                  maincss      => 1,
						);
}

sub AdminPayoutsHistory
{
	if($f->{delete_selected} && $f->{id})
	{
		my $ids = join(',',grep{/^\d+$/}@{ARef($f->{id})});
		$ses->redirect('?op=admin_payouts_history') unless $ids;
		$db->Exec("DELETE FROM Payments WHERE id IN ($ids)");
		$ses->redirect('?op=admin_payouts_history');
	}
	my @d1 = $ses->getTime(time-90*24*3600);
	my @d2 = $ses->getTime(time+24*3600);
	my $day1 = $f->{date1}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date1} : "$d1[0]-$d1[1]-$d1[2]";
	my $day2 = $f->{date2}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date2} : "$d2[0]-$d2[1]-$d2[2]";
	my $filter_status="AND p.status='$f->{status}'" if $f->{status}=~/^(PAID|REJECTED)$/;
	my $filter_login="AND u.usr_login='$f->{usr_login}'" if $f->{usr_login}=~/^[\w\-\_]+$/;

    my $list = $db->SelectARef("SELECT p.*, u.usr_login, u.usr_email, u.usr_pay_email, u.usr_pay_type
                               FROM Payments p, Users u
                               WHERE p.status<>'PENDING'
                               AND p.usr_id=u.usr_id
                               AND p.created>'$day1 00:00:00'
                               AND p.created<'$day2 00:00:00'
                               $filter_status
                               $filter_login
                               ORDER BY p.created".$ses->makePagingSQLSuffix($f->{page}));

    my $total = $db->SelectOne("SELECT COUNT(*) 
    							FROM Payments p, Users u
    							WHERE status<>'PENDING'
    							AND p.usr_id=u.usr_id
    							AND p.created>'$day1 00:00:00'
    							AND p.created<'$day2 00:00:00'
                                $filter_status
                                $filter_login
    							");

    my $sum_amount;
    for(@$list)
    {
    	$sum_amount+=$_->{amount};
    }

    $ses->PrintTemplate("admin_payouts_history.html",
                        'list' => $list,
                        'paging' => $ses->makePagingLinks($f,$total),
                        date1 => $day1,
                        date2 => $day2,
                        sum_amount => $sum_amount,
                        usr_login => $f->{usr_login},
                        maincss      => 1,
                        );
}

sub AdminUsersAdd
{
   
   my ($list,$result);
   if($f->{generate})
   {
      my @arr;
      $f->{prem_days}||=0;
      for(1..$f->{num})
      {
         my $login = join '', map int rand 10, 1..7;
         while($db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$login)){ $login = join '', map int rand 10, 1..7; }
         my $password = $ses->randchar(10);
         push @arr, "$login:$password:$f->{prem_days}";
      }
      $list = join "\n", @arr;
   }
   $ses->message("Error: $ses->{lang}->{lng_registration_max_lim_reached}") if $ses->{"\x70"."\x6C\x67"}->{1} && $db->SelectOne("SELECT COUNT(*) FROM Users")>=100;
   if($f->{create} && $f->{list})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      my @arr;
      $f->{list}=~s/\r//gs;
      for( split /\n/, $f->{list} )
      {
         my ($login,$password,$days,$email) = split(/:/,$_);
         next unless $login=~/^[\w\-\_]+$/ && $password=~/^[\w\-\_]+$/;
         $days=~s/\D+//g;
         $days||=0;
         push(@arr, "<b>$login:$password:$days - ERROR:login already exist</b>"),next if $db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$login);
         $db->Exec("INSERT INTO Users 
                    SET usr_login=?, 
                        usr_password=?, 
                        usr_email=?,
                        usr_created=NOW(), 
                        usr_premium_expire=NOW()+INTERVAL ? DAY", $login, $ses->genPasswdHash($password), $email||'', $days);
         push @arr, "$login:$password:$days";
      }
      $result = join "<br>", @arr;
   }
   $ses->PrintTemplate("admin_users_add.html",
                       'list'   => $list,
                       'result' => $result,
                       maincss      => 1,
                      );
}

sub AdminNews
{
   
   if($f->{del_id})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      $db->Exec("DELETE FROM News WHERE news_id=?",$f->{del_id});
      $db->Exec("DELETE FROM Comments WHERE cmt_type=2 AND cmt_ext_id=?",$f->{del_id});
      $ses->redirect('?op=admin_news');
   }
   my $news = $db->SelectARef("SELECT n.*, COUNT(c.cmt_id) as comments
                               FROM News n 
                               LEFT JOIN Comments c ON c.cmt_type=2 AND c.cmt_ext_id=n.news_id
                               GROUP BY n.news_id
                               ORDER BY created DESC".$ses->makePagingSQLSuffix($f->{page}));
   my $total = $db->SelectOne("SELECT COUNT(*) FROM News");
   for(@$news)
   {
      $_->{site_url} = $c->{site_url};
   }
   $ses->PrintTemplate("admin_news.html",
                       'news' => $news,
                       'paging' => $ses->makePagingLinks($f,$total),
                       maincss      => 1,
                      );
}

sub AdminNewsEdit
{
   
   if($f->{save})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      $f->{news_text} = $ses->{cgi_query}->param('news_text');
      $f->{news_title2}||=lc $f->{news_title};
      $f->{news_title2}=~s/[^\w\s\-]//g;
      $f->{news_title2}=~s/\s+/-/g;
      if($f->{news_id})
      {
         $db->Exec("UPDATE News SET usr_id=?, news_title=?, news_title2=?, news_text=?, news_image=?, created=? WHERE news_id=?",$ses->getUserId,$f->{news_title},$f->{news_title2},$f->{news_text},$f->{news_image},$f->{created},$f->{news_id});
      }
      else
      {
         $db->Exec("INSERT INTO News SET usr_id=?, news_title=?, news_title2=?, news_text=?, news_image=?, created=?",$ses->getUserId,$f->{news_title},$f->{news_title2},$f->{news_text},$f->{news_image},$f->{created},$f->{news_id});
      }
      $ses->redirect('?op=admin_news');
   }
   my $news = $db->SelectRow("SELECT * FROM News WHERE news_id=?",$f->{news_id});
   $news->{created}||=sprintf("%d-%02d-%02d %02d:%02d:%02d", $ses->getTime() );
   $ses->PrintTemplate("admin_news_form.html",
                       %{$news},
                       maincss      => 1,
                      );
}

sub AdminMassEmail
{
   if($f->{'send'})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      $ses->message("Subject required") unless $f->{subject};
      $ses->message("Message") unless $f->{body};
      my $filter_premium=" AND usr_premium_expire>NOW()" if $f->{premium_only};
      my $filter_users=" AND usr_id IN (".join(',',grep{/^\d+$/}@{ARef($f->{usr_id})}).")" if $f->{usr_id};
      my $filter_no_emails=" AND usr_no_emails=0" unless $filter_users;
      my $users = $db->SelectARef("SELECT usr_id,usr_login,usr_email 
                                   FROM Users 
                                   WHERE 1
                                   $filter_premium 
                                   $filter_users
                                   $filter_no_emails");
      $|++;
      print"Content-type:text/html\n\n<HTML><BODY>";
      my $cx;

      for my $u (@$users)
      {
         next unless $u->{usr_email};
         my $body = $ses->{cgi_query}->param('body');
         $body=~s/%username%/$u->{usr_login}/egis;
         $body=~s/%unsubscribe_url%/"$c->{site_url}\/?op=unsubscribe&id=$u->{usr_id}&email=$u->{usr_email}"/egis;
         $ses->SendMailQueue($u->{usr_email}, $c->{email_from}, $f->{subject}, $body, -1);
         print"Sent to $u->{usr_email}<br>\n";
         $cx++;
      }
      print"<b>DONE.</b><br><br>Sent to <b>$cx</b> users.<br><br><a href='?op=admin_users'>Back to User Management</a>";
      exit;
   }
   my @users = map{{usr_id=>$_}} @{&ARef($f->{usr_id})};
   $ses->PrintTemplate("admin_mass_email.html",
                       users => \@users,
                       users_num => scalar @users,
                       maincss      => 1,
                       );
}

sub AdminReports
{
   $ses->message("Access denied") if !$ses->getUser->{usr_adm} && !($c->{m_d} && $ses->getUser->{usr_mod} && $c->{m_d_a});

   if($f->{file_code})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
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
      $ses->redirect("?op=admin_reports");
   }

   my $list = $db->SelectARef("SELECT r.*, f.*, r.file_code, INET_NTOA(ip) as ip,
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
   $ses->PrintTemplate("admin_reports.html",
                       'list'    => $list,
                       'paging'  => $ses->makePagingLinks($f,$total),
                       maincss      => 1,
                      );
}

sub AdminAntiHack
{
   my $gen_ip = $db->SelectARef("SELECT INET_NTOA(ip) as ip_txt, SUM(money) as money, COUNT(*) as downloads
                                 FROM IP2Files 
                                 WHERE created>NOW()-INTERVAL 48 HOUR
                                 GROUP BY ip
                                 ORDER BY money DESC
                                 LIMIT 20");

   my $gen_user = $db->SelectARef("SELECT u.usr_login, u.usr_id, SUM(money) as money, COUNT(*) as downloads
                                 FROM IP2Files i, Users u
                                 WHERE created>NOW()-INTERVAL 48 HOUR
                                 AND i.usr_id=u.usr_id
                                 GROUP BY i.usr_id
                                 ORDER BY money DESC
                                 LIMIT 20");

   my $rec_user = $db->SelectARef("SELECT u.usr_login, u.usr_id, SUM(money) as money, COUNT(*) as downloads
                                 FROM IP2Files i, Users u
                                 WHERE created>NOW()-INTERVAL 48 HOUR
                                 AND i.owner_id=u.usr_id
                                 GROUP BY i.owner_id
                                 ORDER BY money DESC
                                 LIMIT 20");

   $ses->PrintTemplate("admin_anti_hack.html",
                       'gen_ip'     => $gen_ip,
                       'gen_user'   => $gen_user,
                       'rec_user'   => $rec_user,
                       maincss      => 1,
                      );
}

sub AdminIPNLogs
{
   $f->{last}=7 unless defined $f->{last};
   my $filter_last = "AND created>NOW()-INTERVAL $f->{last} DAY" if $f->{last}=~/^\d+$/ && $f->{last}>0;
   my $filter = "AND info LIKE '%$f->{key}%'" if $f->{key};
   my $filter_id = "AND ipn_id=$f->{ipn_id}" if $f->{ipn_id}=~/^\d+$/;
   my $list = $db->SelectARef("SELECT * FROM IPNLogs 
                              WHERE 1
                              $filter
                              $filter_id
                              $filter_last
                              ORDER BY ipn_id DESC".$ses->makePagingSQLSuffix($f->{page}));
   my $total = $db->SelectOne("SELECT COUNT(*) FROM IPNLogs
                               WHERE 1
                               $filter
                               $filter_id
                               $filter_last");
   for(@$list)
   {
      $_->{info}=~s/\n/<br>/g;
   }
   $ses->PrintTemplate('admin_ipn_logs.html',
                       list      => $list,
                       paging    => $ses->makePagingLinks($f,$total),
                       key       => $f->{key},
                       "last_$f->{last}" => ' selected',
                       maincss      => 1,
                      );
}

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

sub AdminFilesFeatured
{
   $ses->message("Access denied") if !$ses->getUser->{usr_adm} && !($c->{m_d} && $ses->getUser->{usr_mod} && $c->{m_d_featured});
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
       exit;
   }
   if($f->{del_id})
   {
      $db->Exec("DELETE FROM FilesFeatured WHERE file_id=?",$f->{del_id});
      print"Content-type:text/html\n\n";
      print"\$('#f$f->{del_id}').hide('slow');";
      exit;
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
   $ses->PrintTemplate("admin_files_featured.html",
                       list          => $list,
                       maincss      => 1,
                      );
}

sub AdminCategories
{
   $ses->message("Access denied") if !$ses->getUser->{usr_adm};

   if($f->{cat1} && $f->{cat2})
   {
       my $num1 = $db->SelectOne("SELECT cat_num FROM Categories WHERE cat_id=?",$f->{cat1});
       my $num2 = $db->SelectOne("SELECT cat_num FROM Categories WHERE cat_id=?",$f->{cat2});
       $db->Exec("UPDATE Categories SET cat_num=? WHERE cat_id=?",$num2,$f->{cat1});
       $db->Exec("UPDATE Categories SET cat_num=? WHERE cat_id=?",$num1,$f->{cat2});
       $ses->redirect('?op=admin_categories');
   }

   my $list = $db->SelectARef("SELECT * FROM Categories ORDER BY cat_parent_id, cat_num");
   for my $i (0..$#$list)
   {
       $list->[$i]->{up}=$list->[$i-1]->{cat_id} if $i && $list->[$i-1]->{cat_parent_id}==$list->[$i]->{cat_parent_id};
       $list->[$i]->{down}=$list->[$i+1]->{cat_id} if $i<$#$list && $list->[$i+1]->{cat_parent_id}==$list->[$i]->{cat_parent_id};
   }

   my $fh;
   push @{$fh->{$_->{cat_parent_id}}},$_ for @$list;
   my @tree = buildTreeCategories($fh,0,0);

   $ses->PrintTemplate("admin_categories.html",
                       list  => \@tree,
                       maincss      => 1,
                      );
}

sub AdminCategoryForm
{
   $ses->message("Access denied") if !$ses->getUser->{usr_adm};
   if($f->{save})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      if($f->{cat_id})
      {
         $db->Exec("UPDATE Categories SET cat_name=?, cat_descr=?, cat_parent_id=?, cat_num=?, cat_premium=? WHERE cat_id=?",
                   $f->{cat_name}, $f->{cat_descr}||'', $f->{cat_parent_id}||0, $f->{cat_num},$f->{cat_premium}, $f->{cat_id});
         $ses->redirect('?op=admin_categories');
      }
      else
      {
         my $cat_num = $db->SelectOne("SELECT MAX(cat_num) FROM Categories WHERE cat_parent_id=?",$f->{cat_parent_id}||0);
         $db->Exec("INSERT INTO Categories SET cat_name=?, cat_descr=?, cat_parent_id=?, cat_num=?, cat_premium=?",
                   $f->{cat_name}, $f->{cat_descr}||'', $f->{cat_parent_id}||0, ++$cat_num, $f->{cat_premium}||0 );
         $ses->redirect('?op=admin_categories');
      }
   }
   if($f->{del})
   {
      $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
      $db->Exec("UPDATE Files SET cat_id=0 WHERE cat_id=?",$f->{del});
      $db->Exec("UPDATE Categories SET cat_parent_id=0 WHERE cat_parent_id=?",$f->{del});
      $db->Exec("DELETE FROM Categories WHERE cat_id=?",$f->{del});
      $ses->redirect('?op=admin_categories');
   }

   my $category = $db->SelectRow("SELECT * FROM Categories WHERE cat_id=?",$f->{cat_id}) if $f->{cat_id};

   my $list = $db->SelectARef("SELECT * FROM Categories");
   my $fh;
   push @{$fh->{$_->{cat_parent_id}}},$_ for @$list;
   my @folders_tree = buildTreeCategories($fh,0,0);
   for(@folders_tree)
   {
      $_->{selected}=' selected' if $_->{cat_id}==$category->{cat_parent_id};
   }

   $ses->PrintTemplate("admin_category_form.html",
                       %$category,
                       list => \@folders_tree,
                       maincss      => 1,
                      );
}

sub AdminTransactions
{
   if($f->{cleanup})
   {
      $db->Exec("DELETE FROM Transactions WHERE created<NOW()-INTERVAL 30 DAY AND verified=0");
      $ses->redirect("?op=admin_transactions");
   }
   my $filter_key = "AND (t.email LIKE '%$f->{key}%' OR txn_id LIKE '%$f->{key}%' OR ref_url LIKE '%$f->{key}%')" if $f->{key};
   my $filter_ip = "AND t.ip=INET_ATON('$f->{ip}')" if $f->{ip}=~/^[\d\.]+$/;
   my $filter_aff_id = "AND t.aff_id=$f->{aff_id}" if $f->{aff_id}=~/^\d+$/;
   my $filter_date = "AND t.created>'$f->{date} 00:00:00' AND t.created<='$f->{date} 23:59:59'" if $f->{date}=~/^[\d\-]+$/;
   $f->{last}='30' unless defined $f->{last};
   my $filter_last = "AND t.created>NOW()-INTERVAL $f->{last} DAY" if $f->{last};
   $filter_last='' if $filter_date;
   my $list = $db->SelectARef("SELECT t.*, INET_NTOA(t.ip) as ip, u.usr_login, u2.usr_login as aff_login
                               FROM (Transactions t, Users u)
                               LEFT JOIN Users u2 ON t.aff_id = u2.usr_id
                               WHERE verified=1
                               AND t.usr_id = u.usr_id
                               $filter_key
                               $filter_ip
                               $filter_last
                               $filter_date
                               $filter_aff_id
                               ORDER BY created".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}));

   my $total= $db->SelectOne("SELECT COUNT(*) FROM Transactions t
                               WHERE verified=1
                               $filter_key
                               $filter_ip
                               $filter_last
                               $filter_date
                               $filter_aff_id
                              ");
   $f->{"last_$f->{last}"} = ' selected';
   $ses->PrintTemplate("admin_transactions.html",
                       list => $list,
                       'paging' => $ses->makePagingLinks($f,$total),
                       %$f,
                       maincss      => 1,
                      );
}

sub addEncodeQueueDB
{
    my ($file, $priority, $quality) = @_;
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
               $file->{usr_id},
               $priority,
               $quality,
               $f->{effects}||'',
             );
}

sub AdminUserReports
{
   my @d1 = $ses->getTime();
   $d1[2]='01';
   my @d2 = $ses->getTime();
   my $day1 = $f->{date1}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date1} : "$d1[0]-$d1[1]-$d1[2]";
   my $day2 = $f->{date2}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date2} : "$d2[0]-$d2[1]-$d2[2]";
   my $list = $db->SelectARef("SELECT *, DATE_FORMAT(day,'%e') as day2
                               FROM Stats2
                               WHERE usr_id=?
                               AND day>=?
                               AND  day<=?
                               ORDER BY day",$f->{usr_id},$day1,$day2);
   $ses->message("Not enough reports data") if $#$list<0;
   my %totals;
   my (@days,@profit_dl,@profit_sales,@profit_refs);
   for my $x (@$list)
   {
      $x->{profit_total} = sprintf("%.05f",$x->{profit_views}+$x->{profit_sales}+$x->{profit_refs});
      $totals{"sum_$_"}+=$x->{$_} for qw(uploads uploads_mb views downloads sales profit_views profit_sales profit_refs refs profit_total);
   }

   my $divlines = $#$list-1;
   $divlines=1 if $divlines<1;
   my $xml = $ses->CreateTemplate("my_reports.xml");
   $xml->param(list=>$list, divlines=>$divlines);
   my $data_xml = $xml->output;
   $data_xml=~s/[\n\r]+//g;
   $data_xml=~s/\s{2,16}/ /g;

   $ses->PrintTemplate("admin_user_reports.html",
                       list => $list,
                       date1 => $day1,
                       date2 => $day2,
                       %totals,
                       data_xml => $data_xml,
                       usr_id   => $f->{usr_id},
                       maincss      => 1,
                      );
}

sub AdminUsersMonitor
{
   $ses->message("Users monitor mod is disabled") unless $c->{m_o};

   if($f->{monitor} && $f->{usr_id})
   {
       my $ids = join(',',grep{/^\d+$/}@{&ARef($f->{usr_id})});
       $db->Exec("UPDATE Users SET usr_monitor=1 WHERE usr_id IN ($ids)") if $ids;
       $ses->redirect('?op=admin_users_monitor');
   }

   $f->{last}||=7;
   
   my $mids = $db->SelectARef("SELECT usr_id,usr_login,usr_money FROM Users WHERE usr_monitor=1");
   my $ids = join ',', map{$_->{usr_id}} @$mids;
   my $uu;
   for(@$mids)
   {
      $uu->{$_->{usr_id}}->{usr_login} = $_->{usr_login};
      $uu->{$_->{usr_id}}->{usr_money} = sprintf("%.0f",$_->{usr_money});
   }

   my $users = $db->SelectARef("SELECT usr_id, 
                                       SUM(downloads) as downloads,
                                       SUM(downloads_prem) as downloads_prem,
                                       SUM(views) as views,
                                       SUM(views_prem) as views_prem,
                                       SUM(uploads) as uploads,
                                       ROUND(SUM(profit_views),1) as profit_views,
                                       ROUND(SUM(profit_sales)) as profit_sales,
                                       ROUND(SUM(profit_refs),1) as profit_refs,
                                       SUM(refs) as refs,
                                       ROUND(SUM(profit_site),1) as profit_site
                                FROM Stats2
                                WHERE day>=CURDATE()-INTERVAL ? DAY
                                AND usr_id IN ($ids)
                                GROUP BY usr_id
                                ORDER BY profit_sales DESC
                               ",$f->{last}) if $ids;

   my $users_old = $db->SelectARef("SELECT usr_id, 
                                       SUM(downloads) as downloads,
                                       SUM(downloads_prem) as downloads_prem,
                                       SUM(views) as views,
                                       SUM(views_prem) as views_prem,
                                       SUM(uploads) as uploads,
                                       ROUND(SUM(profit_views),1) as profit_views,
                                       ROUND(SUM(profit_sales)) as profit_sales,
                                       ROUND(SUM(profit_refs),1) as profit_refs,
                                       SUM(refs) as refs,
                                       ROUND(SUM(profit_site),1) as profit_site
                                FROM Stats2
                                WHERE day>=CURDATE()-INTERVAL ? DAY
                                AND day<CURDATE()-INTERVAL ? DAY
                                AND usr_id IN ($ids)
                                GROUP BY usr_id
                               ",$f->{last}*2,$f->{last}) if $ids;
   my $ohs;
   for(@$users_old)
   {
      $ohs->{$_->{usr_id}} = $_;
   }

   for(@$users)
   {
     $_->{usr_login} = $uu->{$_->{usr_id}}->{usr_login};
     $_->{usr_money} = $uu->{$_->{usr_id}}->{usr_money};
     for my $k (qw(downloads downloads_prem uploads views profit_views profit_sales profit_refs profit_site refs))
     {
       my $color='red' if $ohs->{$_->{usr_id}}->{$k} > $_->{$k};
       $color='green' if $ohs->{$_->{usr_id}}->{$k} < $_->{$k};
       $_->{"$k\_old"} = $ohs->{$_->{usr_id}}->{$k};
       $_->{$k} = "<b style='color:$color'>$_->{$k}</b>";
     }
   }


   my $top_profit_users = $db->SelectARef("SELECT u.usr_id, u.usr_login, ROUND(u.usr_money,1) as usr_money, TO_DAYS(CURDATE())-TO_DAYS(usr_created) as usr_created,
                                            SUM(views) as views,
                                            SUM(uploads) as uploads,
                                            ROUND(SUM(profit_views),1) as profit_views,
                                            ROUND(SUM(profit_sales)) as profit_sales,
                                            ROUND(SUM(profit_site)) as profit_site
                                           FROM Stats2 s, Users u
                                           WHERE s.usr_id=u.usr_id
                                           AND s.day>=CURDATE()-INTERVAL 3 DAY
                                           AND u.usr_monitor=0
                                           GROUP BY usr_id
                                           ORDER BY (profit_views+profit_sales+profit_site) DESC
                                           LIMIT 10
                                          ");

   $ses->PrintTemplate("admin_users_monitor.html",
                       users => $users,
                       top_profit_users => $top_profit_users,
                       maincss      => 1,
                      );
}

sub AdminSQLStats
{
    if($f->{optimize})
    {
        $db->Exec("OPTIMIZE TABLE $_") for grep {/^\w+$/} @{ARef($f->{table})};
        $ses->redirect('?op=admin_sql_stats');
    }
    if($f->{repair})
    {
        $db->Exec("REPAIR TABLE $_") for grep {/^\w+$/} @{ARef($f->{table})};
        $ses->redirect('?op=admin_sql_stats');
    }
    if($f->{dump})
    {
        my ($yy,$mm,$dd) = $ses->getTime;
        my $tables = join ' ', grep {/^\w+$/} @{ARef($f->{table})};
        print"Content-type: application/gzip\n";
        print qq[Content-Disposition: attachment; filename="dump-$c->{db_name}-$yy-$mm-$dd.sql.gz"\n\n];
        open GZ, "mysqldump -h$c->{db_host} -u$c->{db_login} -p$c->{db_passwd} $c->{db_name} $tables | gzip -c |";
        print $_ while <GZ>;
        exit;
    }

    my $truncate_table_list = 'FilesTrash|QueueDelete|IPNLogs|Sessions|Views|ViewsLog|LoginHistory|QueueEmail|QueueEncoding|QueueTransfer|QueueUpload|TmpFiles|TmpStats2|TmpUsers|StatsIP|Proxy2Files';
    if($f->{exec} eq 'trunc' && $f->{table}=~/^($truncate_table_list)$/i)
    {
        $db->Exec("TRUNCATE TABLE $f->{table}");
        $ses->redirect('?op=admin_sql_stats');
    }

    my $list = $db->SelectARef("SHOW TABLE STATUS");
    for(@$list)
    {
        $_->{Data_length} = $_->{Data_length} > 10*1024*1024 ? sprintf("%.0f MB",$_->{Data_length}/1024**2) : sprintf("%.0f KB",$_->{Data_length}/1024);
        $_->{Index_length} = $_->{Index_length} > 10*1024*1024 ? sprintf("%.0f MB",$_->{Index_length}/1024**2) : sprintf("%.0f KB",$_->{Index_length}/1024);
        $_->{"name_$_->{Name}"}=1;
        $_->{truncate}=1 if $_->{Name}=~/^($truncate_table_list)$/i;
    }
    $ses->PrintTemplate("admin_sql_stats.html",
                        list => $list,
                        maincss      => 1,
                       );
}

sub AdminWebsites
{
    if($f->{site_reset})
    {
      $db->Exec("UPDATE Websites SET money_sales=0",$ses->getUserId);
      $ses->redirect("?op=admin_websites");
    }
    my $list = $db->SelectARef("SELECT w.*, u.usr_login
                                FROM Websites w, Users u 
                                WHERE w.usr_id=u.usr_id 
                                ORDER BY money_sales DESC 
                                LIMIT 50");
    $ses->PrintTemplate("admin_websites.html",
                        list   => $list,
                        maincss      => 1,
                        );
}

sub buildTreeCategories
{
   my ($fh,$parent,$depth)=@_;
   my @tree;
   for my $x (@{$fh->{$parent}})
   {
      $x->{pre}='&nbsp;&nbsp;'x$depth;
      push @tree, $x;
      push @tree, buildTreeCategories($fh,$x->{cat_id},$depth+1);
   }
   return @tree;
}

sub CommentRedirect
{
   my ($cmt_type,$cmt_ext_id) = @_;
   if($cmt_type==1)
   {
      my $file = $db->SelectRow("SELECT * FROM Files WHERE file_id=?",$cmt_ext_id);
      $ses->message("Object doesn't exist") unless $file;
      $ses->setCookie("skip$file->{file_id}",1);
      return $ses->makeFileLink($file).'#comments';
   }
   elsif($cmt_type==2)
   {
      my $news = $db->SelectRow("SELECT * FROM News WHERE news_id=?",$cmt_ext_id);
      $ses->message("Object doesn't exist") unless $news;
      return "$c->{site_url}/n$news->{news_id}-$news->{news_title2}.html#comments";
   }
   $ses->message("Invalid object type");
}

sub AdminLoginHistory
{
    my $list = $db->SelectARef("SELECT *, INET_NTOA(ip) as ip
                                FROM LoginHistory 
                                WHERE usr_id=? 
                                ORDER BY created DESC 
                                LIMIT 1000",$f->{usr_id});
    if($c->{resolve_ip_country})
    {
        $_->{country} = $ses->getCountryCode($_->{ip}) for @$list;
    }
    $ses->PrintTemplate("admin_login_history.html",
                        list   => $list,
                        usr_id => $f->{usr_id},
                        maincss      => 1,
                        );
}

sub LoginAsUser
{
    my $session_id = $ses->getCookie( $ses->{auth_cook} );
	$db->Exec("UPDATE Sessions SET usr_id=? WHERE session_id=? LIMIT 1", $f->{usr_id}, $session_id );
	$db->PurgeCache( "ses$session_id" );
    $ses->redirect_msg("$c->{site_url}/?op=my_account","Logged in as user now");
}

sub AdminLanguages
{
    my $list = $db->SelectARef("SELECT l.*, COUNT(t.trans_name) as trans_num
                                FROM Languages l 
                                LEFT JOIN Translations t ON l.lang_id=t.lang_id
                                GROUP BY lang_id
                                ORDER BY l.lang_order");
    $ses->PrintTemplate("admin_languages.html",
                        list   => $list,
                        maincss      => 1,
                        );
}

sub AdminLanguageForm
{
    my $lang = $db->SelectRow("SELECT l.* FROM Languages l
                               WHERE lang_id=?",$f->{lang_id});
    if($f->{save})
    {
        $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
        if($f->{lang_id})
        {
            $db->Exec("UPDATE Languages SET lang_name=?, lang_order=?, lang_active=?
                       WHERE lang_id=?", $f->{lang_name}, $f->{lang_order}, $f->{lang_active}, $f->{lang_id});
        }
        else
        {
            $db->Exec("INSERT INTO Languages SET lang_name=?, lang_order=?, lang_active=?", $f->{lang_name}, $f->{lang_order}, $f->{lang_active});
        }
        $ses->redirect("?op=admin_languages");
    }
    my $max_order = $db->SelectOne("SELECT MAX(lang_order) FROM Languages");
    $lang->{lang_order} ||= $max_order+1;
    $ses->PrintTemplate("admin_language_form.html",
                        %$lang,
                        maincss      => 1,
                        );
}

sub AdminTranslations
{
    if($f->{save})
    {
        $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
        my @names  = @{&ARef($f->{trans_name})};
        my @values = @{&ARef($f->{trans_value})};
        my $cx=0;
        for(@names)
        {
            my $value = $values[$cx++];
            $value=~s/&lt;/</gs;
            $value=~s/&gt;/>/gs;
            next unless $_;
            if($value)
            {
                $db->Exec("INSERT INTO Translations 
                           SET lang_id=?, trans_name=?, trans_value=?
                           ON DUPLICATE KEY UPDATE trans_value=?",$f->{lang_id},$_,$value,$value);
            }
            else
            {
                $db->Exec("DELETE FROM Translations WHERE lang_id=? AND trans_name=?",$f->{lang_id},$_);
            }
        }
    }
    if($f->{copy_from} && $f->{from})
    {
        $ses->message("Not allowed in Demo mode") if $c->{demo_mode};
        my $list = $db->SelectARef("SELECT * FROM Translations WHERE lang_id=?",$f->{from});
        for(@$list)
        {
            $db->Exec("INSERT IGNORE INTO Translations SET lang_id=?, trans_name=?, trans_value=?",$f->{lang_id},$_->{trans_name},$_->{trans_value});
        }
        $ses->redirect("?op=admin_translations&lang_id=$f->{lang_id}");
    }
    
    my $languages = $db->SelectARef("SELECT * FROM Languages");

    my $list = $db->SelectARef("SELECT * FROM Translations WHERE lang_id=?",$f->{lang_id});
    my (@groups,$hh);
    for(@$list)
    {
        my ($grn) = $_->{trans_name}=~/^lng_(\w+?)_/;
        push @{$hh->{$grn}}, $_;
    }
    for(keys %$hh)
    {
        push @groups, { name=>$_, list=>$hh->{$_} };
    }
    @groups = sort{$a->{name} cmp $b->{name}} @groups;

    $ses->PrintTemplate("admin_translations.html",
                        groups  => \@groups,
                        lang_id => $f->{lang_id},
                        languages => $languages,
                        maincss      => 1,
                        );
}

sub AdminTags
{
    my $filter_key = qq[AND tag_value LIKE "%$f->{filter_key}%"] if $f->{filter_key};
    my $filter_short = "AND LENGTH(tag_value)<$f->{filter_short}" if $f->{filter_short}=~/^\d+$/;
    my $filter_long  = "AND LENGTH(tag_value)>$f->{filter_long}"  if $f->{filter_long}=~/^\d+$/;
    my $list = $db->SelectARef("SELECT t.*, COUNT(t2f.file_id) as files
                                FROM (Tags t)
                                LEFT JOIN Tags2Files t2f ON t.tag_id = t2f.tag_id
                                WHERE 1
                                $filter_key
                                $filter_short
                                $filter_long
                                GROUP BY t.tag_id
                                ORDER BY tag_id DESC
                                ".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}));
    my $total = $db->SelectOne("SELECT COUNT(*) FROM Tags
                                WHERE 1
                                $filter_key
                                $filter_short
                                $filter_long
                               ");
    $ses->PrintTemplate("admin_tags.html",
                        list    => $list,
                        paging       => $ses->makePagingLinks($f,$total),
                        filter_key   => $f->{filter_key},
                        filter_short => $f->{filter_short},
                        filter_long  => $f->{filter_long},
                        maincss      => 1,
                        );
}

sub AdminHighBWFiles
{
    $f->{hours}||=12;
    my $filter_srv = "AND f.srv_id='$f->{srv_id}'" if $f->{srv_id}=~/^\d+$/;
    my $list = $db->SelectARef("SELECT f.file_code, f.file_name, f.file_size,
                                ROUND(SUM(t.bandwidth)/1024/1024) as bandwidth
                                FROM DailyTraffic t, Files f
                                WHERE t.dayhour > TO_DAYS(CURDATE())*24 + HOUR(NOW()) - ?
                                AND t.file_id=f.file_id
                                $filter_srv
                                GROUP BY file_code
                                ORDER BY bandwidth DESC
                                LIMIT 100",$f->{hours});
    for(@$list)
    {
        $_->{download_link} = $ses->makeFileLink($_);
        $_->{file_size} = $ses->makeFileSize($_->{file_size});
    }
    $ses->PrintTemplate("admin_high_bw_files.html",
                        list    => $list,
                        hours     => $f->{hours},
                        srv_id	=> $f->{srv_id},
                        maincss      => 1,
                        );
}

sub http_out
{
    print"Content-type:text/html\n\n".shift;
    exit;
}

sub AdminMisc
{
    if($f->{memcached_stats})
    {
        my $mc = $ses->db->cacheDB || http_out("memcached is down");
        my $s = $mc->stats->{total};
        my $hit_rate = int(100*$s->{get_hits}/$s->{cmd_get}) if $s->{cmd_get};
        my $ram_curr = int $s->{bytes}/1024**2;
        http_out("Items: $s->{curr_items}<br>Size: $ram_curr MB<br>Cache hit rate: $hit_rate%");
    }
    if($f->{memcached_flush})
    {
        my $mc = $ses->db->cacheDB || http_out("memcached is down");
        $mc->flush_all;
        http_out("Flushed.");
    }
    if($f->{check_ip_ban}=~/^[\d\.]+$/)
    {
    	my @arr;
    	push @arr,'Server' if XUtils::getIPBlockedStatus( $ses->db, 'ipserver', $f->{check_ip_ban} );
   		push @arr,'Proxy' if XUtils::getIPBlockedStatus( $ses->db, 'ipproxy', $f->{check_ip_ban} );
   		push @arr,'Tor' if XUtils::getIPBlockedStatus( $ses->db, 'iptor', $f->{check_ip_ban} );
   		push @arr,'Whitelisted' if XUtils::getIPBlockedStatus( $ses->db, 'ipwhite', $f->{check_ip_ban} );
   		push @arr,'Blacklisted' if XUtils::getIPBlockedStatus( $ses->db, 'ipblack', $f->{check_ip_ban} );
   		push @arr,'Not listed' unless @arr;
   		http_out("Result: <b>".join(', ',@arr)."</b>");
    }
    if($f->{whitelist_ip}=~/^[\d\.]+$/)
    {
    	require Socket;require Storable;
    	XUtils::getIPBlockedStatus( $ses->db, 'ipwhite', '1.1.1.1' );
    	$ses->{db}->{ipwhite}->{ips}->{Socket::inet_aton($f->{whitelist_ip})}=9;
    	$ses->{db}->{ipwhite}->{total} = scalar keys %{$ses->{db}->{ipwhite}->{ips}};
    	Storable::store( $ses->{db}->{ipwhite}, "$c->{cgi_path}/logs/ipwhite.dat" );
    	http_out("Added.");
    }
    if($f->{blacklist_ip}=~/^[\d\.]+$/)
    {
    	require Socket;require Storable;
    	XUtils::getIPBlockedStatus( $ses->db, 'ipblack', '1.1.1.1' );
    	$ses->{db}->{ipblack}->{ips}->{Socket::inet_aton($f->{blacklist_ip})}=9;
    	$ses->{db}->{ipblack}->{total} = scalar keys %{$ses->{db}->{ipblack}->{ips}};
    	Storable::store( $ses->{db}->{ipblack}, "$c->{cgi_path}/logs/ipblack.dat" );
    	http_out("Added!");
    }
    if($f->{ipblock_stats})
    {
    	XUtils::getIPBlockedStatus( $ses->db, 'ipserver', '1.1.1.1' );
    	XUtils::getIPBlockedStatus( $ses->db, 'ipproxy', '1.1.1.1' );
    	XUtils::getIPBlockedStatus( $ses->db, 'iptor', '1.1.1.1' );
    	XUtils::getIPBlockedStatus( $ses->db, 'ipwhite', '1.1.1.1' );
    	XUtils::getIPBlockedStatus( $ses->db, 'ipblack', '1.1.1.1' );
    	my @out;
    	for my $name ('ipserver','ipproxy','iptor','ipwhite','ipblack')
    	{
    		my $name2=$name;
    		$name2=~s/^ip//;
    		my $created = join '-', $ses->getDate($ses->{db}->{$name}->{created});
    		push @out, "$name2 : ".$ses->{db}->{$name}->{total}." records, version: $created";
    	}
    	http_out( join("<br>",@out) );
    }
    if($f->{iproxy_config})
    {
    	my $hosts = $db->SelectARef("SELECT * FROM Hosts ORDER BY host_id");
    	my $out = join "<br>\n", map{"~^/$_->{host_id}/ $_->{host_htdocs_url};"} @$hosts;
    	http_out( "<br>".$out );
    }
    http_out("-");
}

sub AdminExternal
{
   if($f->{set_perm})
   {
      my $key_id = $1 if $f->{set_perm} =~ s/_(\d+)$//;
      my $perm = $1 if $f->{set_perm} =~ /^(perm_.*)/;
      $db->Exec("UPDATE APIKeys SET $perm=? WHERE key_id=?",
         $f->{value},
         $key_id);
      print "Content-type: application/json\n\n";
      print JSON::encode_json({ status => 'OK' });
      return;
   }
   if($f->{generate_key})
   {
      my @r = ('a'..'z');
      my $key_code = $r[rand scalar @r].$ses->randchar(15);
      $db->Exec("INSERT INTO APIKeys SET domain=?, key_code=?", $f->{domain}, $key_code);
      $ses->redirect("$c->{site_url}/?op=admin_external");
   }
   my $list = $db->SelectARef("SELECT * FROM APIKeys");
   $ses->PrintTemplate('admin_external.html',
               list => $list,
               maincss      => 1);
}

sub AdminTopIPs
{
    $f->{days}=3 unless $f->{days}=~/^\d+$/;
    my $list1 = $db->SelectARef("SELECT INET_NTOA(ip) AS ipt, ROUND(SUM(traffic)/1024,1) as traffic
                                  FROM StatsIP
                                  WHERE day>=CURDATE()-INTERVAL ? DAY
                                  GROUP BY ip
                                  ORDER BY traffic DESC
                                  LIMIT 25
                                  ",$f->{days});

    my $list2 = $db->SelectARef("SELECT INET_NTOA(ip) AS ipt, SUM(money) as money
                                  FROM StatsIP
                                  WHERE day>=CURDATE()-INTERVAL ? DAY
                                  GROUP BY ip
                                  ORDER BY money DESC
                                  LIMIT 25
                                  ",$f->{days});

    $ses->PrintTemplate('admin_top_ips.html',
                        list1 => $list1,
                        list2 => $list2,
                        days => $f->{days},
                        maincss      => 1,
                        );
}

sub AdminTopUsers
{
    $f->{days}=3 unless $f->{days}=~/^\d+$/;
    my $list = $db->SelectARef("SELECT u.usr_id, u.usr_login, SUM(profit_views+profit_sales+profit_refs+profit_site) as profit_views, SUM(views) as views, SUM(uploads) as uploads
                                  FROM Stats2 s, Users u
                                  WHERE day>=CURDATE()-INTERVAL ? DAY
                                  AND s.usr_id=u.usr_id
                                  GROUP BY usr_id
                                  ORDER BY profit_views DESC
                                  LIMIT 30
                                  ",$f->{days});

    $ses->PrintTemplate('admin_top_users.html',
                        list => $list,
                        days => $f->{days},
                        maincss      => 1,
                        );
}

sub getPluginsOptions
{
   my ($plgsection, $data) = @_;
   my @ret;
   for($ses->getPlugins($_[0]))
   {
      my $hashref = eval("\$$_\::options") || $_->options;
      my $aref = [];
      $aref = $hashref->{s_fields} if $hashref->{s_fields};
      $_->{value} = $data ? $data->{$_->{name}} : $c->{$_->{name}} for @$aref;
      push @ret, @$aref;
   }
   return \@ret;
}

sub AdminFilesDeleted
{
    if($f->{restore} && $f->{file_id})
    {
        my $ids = join(",",grep{/^\d+$/}@{&ARef($f->{file_id})});
        $ses->redirect($c->{site_url}) unless $ids;
        my $list = $db->SelectARef("SELECT * FROM FilesTrash WHERE file_id IN ($ids)");
        for my $x (@$list)
        {
            if($f->{new_codes})
            {
                $x->{file_code} = $ses->randchar(12);
                while($db->SelectOne("SELECT file_id FROM Files WHERE file_code=? OR file_real=?",$x->{file_code},$x->{file_code})){$x->{file_code} = $ses->randchar(12);}
            }
            delete @$x{'file_deleted', 'del_by', 'hide', 'old', 'dmca','file_spec_txt','cleaned'};
            
            my @par;
            push @par, qq|$_="$x->{$_}"| for keys %$x;
            $db->Exec("INSERT INTO Files SET ".join(',',@par));

            $db->Exec("DELETE FROM FilesTrash WHERE file_id=?",$x->{file_id});
            $db->Exec("DELETE FROM QueueDelete WHERE file_real_id=?",$x->{file_real_id});
        }
    }

    $f->{last}=24 unless defined $f->{last};
    my $filter_last="AND file_deleted>NOW()-INTERVAL $f->{last} HOUR" if $f->{last} && $f->{last}=~/^\d+$/;
    my $filter_user="AND f.usr_id='$f->{usr_id}'" if $f->{usr_id}=~/^\d+$/;
    my $filter_del_by="AND del_by='$f->{del_by}'" if $f->{del_by}=~/^\d+$/;
    my $filter_title="AND file_title LIKE '%$f->{file_title}%'" if $f->{file_title};
    my $filter_code="AND (file_code='$f->{file_code}' OR file_real='$f->{file_code}')" if $f->{file_code};
    my $files = $db->SelectARef("SELECT f.*, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(file_deleted) as ago, u1.usr_login, 
    							 (SELECT usr_login FROM Users u2 WHERE u2.usr_id=f.del_by) as del_by_login
                                 FROM (FilesTrash f, Users u1)
                                 WHERE f.usr_id=u1.usr_id
                                 $filter_last
                                 $filter_user
                                 $filter_del_by
                                 $filter_title
                                 $filter_code
                                 GROUP BY f.file_id
                                 ORDER BY file_deleted DESC".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}));

    my $total = $db->SelectOne("SELECT COUNT(*)
                                 FROM FilesTrash f
                                 WHERE 1
                                 $filter_last
                                 $filter_user
                                 $filter_del_by
                                 $filter_title
                                 $filter_code
                                 ");
    my $reals= join "','", map{$_->{file_real}} @$files;
    my $canrestore1 = $db->SelectARef("SELECT DISTINCT file_real FROM Files WHERE file_real IN ('$reals')");
    my $canrestore2 = $db->SelectARef("SELECT DISTINCT file_real FROM QueueDelete WHERE file_real IN ('$reals')");

    my %can = map{ $_->{file_real}=>1 } @$canrestore1,@$canrestore2;

    for(@$files)
    {
        $_->{ago} = sprintf("%.0f",$_->{ago}/60);
        $_->{ago} = $_->{ago}<180 ? "$_->{ago} mins" : sprintf("%.0f hours",$_->{ago}/60);
        $_->{restore} = $can{$_->{file_real}};
    }

    my $deleters_chart = $db->SelectARef("SELECT f.del_by, u.*, COUNT(*) as x 
    										FROM FilesTrash f, Users u 
    										WHERE f.file_deleted>NOW()-INTERVAL ? HOUR
    										AND f.del_by=u.usr_id
    										GROUP BY f.del_by
    										ORDER BY x DESC
    										LIMIT 100
    									", $f->{last}||24 );

    $ses->PrintTemplate("admin_files_deleted.html",
                        files  => $files,
                        paging => $ses->makePagingLinks($f,$total),
                        file_title  => $f->{file_title},
                        file_code	=> $f->{file_code},
                        usr_id   	=> $f->{usr_id},
                        del_by   	=> $f->{del_by},
                        last        => $f->{last},
                        per_page => $f->{per_page},
                        deleters_chart => $deleters_chart,
                        maincss      => 1,
                       );
}

sub decodeHash
{
 my ($hash) = @_;
    my $x = $ses->decode32($hash);

    require HCE_MD5;
    my $hce = HCE_MD5->new($c->{dl_key},"XVideoSharing");
    my ($end,$disk_id,$file_id,$usr_id,$dx,$id,$dmode,$speed,$i1,$i2,$i3,$i4,$expire,$flags) = unpack("SCLLSA12ASC4LC", $hce->hce_block_decrypt($x) );

    return ($end,$disk_id,$file_id,$usr_id,$dx,$id,$dmode,$speed,$i1,$i2,$i3,$i4,$expire,$flags);
}

sub AdminStreams
{
    return $ses->message("Streams mod disabled") unless $c->{m_q};
    if($f->{del}=~/^\d+$/ && $f->{token} && $ses->checkToken)
    {
        my $stream = $db->SelectRow("SELECT * FROM Streams WHERE stream_id=?", $f->{del} );
        $ses->message("Stream not found") unless $stream;
        $db->Exec("DELETE FROM Streams WHERE stream_id=?",$stream->{stream_id});
        $db->Exec("DELETE FROM Stream2IP WHERE stream_id=?",$stream->{stream_id});
        $ses->redirect_msg("?op=admin_streams","Stream deleted.");
    }
    my $list = $db->SelectARef("SELECT *,
    							(SELECT COUNT(*) FROM Stream2IP i WHERE i.stream_id=s.stream_id AND i.created>NOW()-INTERVAL 60 SECOND) as watchers
								FROM (Streams s, Users u, Hosts h)
								WHERE s.usr_id=u.usr_id
								AND s.host_id=h.host_id
								ORDER BY s.started DESC");

    $ses->PrintTemplate("admin_streams.html",
                        list  => $list,
                        maincss      => 1,
                      );
}

sub AdminIPBlockStats
{
	my $list = $db->SelectARef("SELECT * 
								FROM StatsMisc 
								WHERE usr_id=0 
								AND day>CURDATE()-INTERVAL 14 DAY");
	my $hm;
	$hm->{$_->{day}}=$_->{value} for grep{$_->{name} eq 'ipblock_money_saved'} @$list;
	my @arr;
	for(@$list)
	{
		next unless $_->{name} eq 'ipblock_blocked';
		$_->{ipblock_blocked}=$_->{value};
		$_->{ipblock_money_saved} = sprintf("%.05f", $hm->{$_->{day}}/10000 );
		push @arr, $_;
	}
	$ses->PrintTemplate("admin_ipblock_stats.html",
                        list  => \@arr,
                        maincss      => 1,
                      );
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

sub genDirectLink
{
   my ($file,$mode,$fname)=@_;
   my $speed = $file->{host_transfer_speed} || $c->{server_transfer_speed} || 25000;
   require HCE_MD5;
   my $hce = HCE_MD5->new($c->{dl_key},"XVideoSharing");
   my $usr_id = 0;
   my $dx = sprintf("%d",($file->{file_real_id}||$file->{file_id})/$c->{files_per_folder});
   my $flags;
   $flags |= 1;
   $flags |= 4;
   $flags |= 8;
   my $hash = &encode32( $hce->hce_block_encrypt(pack("SCLLSA12ASC4LC",
                                                       10000,
                                                       $file->{disk_id},
                                                       $file->{file_id},
                                                       $usr_id,
                                                       $dx,
                                                       $file->{file_real},
                                                       $mode,
                                                       $speed,
                                                       0,0,0,0,
                                                       time+60*9200,
                                                       $flags)) );
   $fname ||= $file->{file_real};
   $fname.='.mp4' unless $mode eq '0';
   $fname=~s/\.mp4\.mp4/.mp4/ig;
   $fname=~s/\s+/_/ig;
   return "$file->{srv_htdocs_url}/$hash/$fname";
}

sub AdminFTP
{
	require JSON;
	my $hosts = $db->SelectARef("SELECT * FROM Hosts WHERE host_ftp=1 ORDER BY host_id");
	for my $h (@$hosts)
	{
		my $data = eval { JSON::decode_json($h->{host_ftp_current}) } if $h->{host_ftp_current};
		$h->{uploads} = $data->{uploads};
		$h->{disk_used} = $data->{disk_used};
		$h->{dt} = time - $data->{updated};
		$h->{online}=1 if $h->{dt}<60*5;
	}
	

	$ses->PrintTemplate("admin_ftp.html",
						hosts  => $hosts,
						m_f_track_current => $c->{m_f_track_current},
                  maincss      => 1,
	);
}

sub AdminDecodeHash
{
	my $x;
	if($f->{url})
	{
		my ($hash) = $f->{url}=~/\/(\w{32,})\//;
		$hash="$1.$2" if !$hash && $f->{url}=~/\/(\w{32,}),(\w+),/;
		my ($end,$disk_id,$file_id,$usr_id,$dx,$id,$dmode,$speed,$i1,$i2,$i3,$i4,$expire,$flags) = decodeHash($hash);
		$x->{disk_id}	= sprintf("%02d",$disk_id);
		$x->{file_id}	= $file_id;
		$x->{usr_id}	= $usr_id;
		$x->{id}		= $id;
		$x->{dmode}		= uc $dmode;
		$x->{speed}		= $speed;
		$x->{ip}		= "$i1.$i2.$i3.$i4";
		my ($flag_dl, $flag_embed, $flag_transfer, $flag_noipcheck) = ( $flags & 1, $flags & 2, $flags & 4, $flags & 8 );
		my @flist;
		push @flist,'Download' if $flag_dl;
		push @flist,'Embed' if $flag_embed;
		push @flist,'Transfer' if $flag_transfer;
		push @flist,'NoIPCheck' if $flag_noipcheck;
		$x->{flags}		= join ', ', @flist;
	}
	$ses->PrintTemplate("admin_decode_hash.html",
						%$x,
                  maincss      => 1,
	);
}