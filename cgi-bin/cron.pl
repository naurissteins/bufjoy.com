#!/usr/bin/perl
use strict;
use lib '.';
use XFileConfig;
use Session;
use XUtils;

my $ses = Session->new();
my $db= $ses->db;
my $f = $ses->f;

$|++;
print"Content-type:text/html\n\n";

if($ENV{REMOTE_ADDR})
{
	XUtils::CheckAuth($ses);
	print("YOU SHALL NOT PASS"),exit unless $ses->checkToken; 
}

my $servers = $db->SelectARef("SELECT * FROM Servers WHERE srv_status<>'OFF'");

# Update server files number
for my $srv (@$servers)
{
   my $filter = $srv->{srv_ssd} ? "srv_id_copy=$srv->{srv_id} OR srv_id=$srv->{srv_id}" : "srv_id=$srv->{srv_id}";
   my $num = $db->SelectOne("SELECT COUNT(*) FROM Files WHERE $filter");
   $db->Exec("UPDATE Servers SET srv_files=? WHERE srv_id=?",$num,$srv->{srv_id});
   #print"srv_id=$srv->{srv_id} : files=$num <br>\n";
}

$db->Exec("DELETE FROM LoginProtect WHERE created<NOW() - INTERVAL 3 HOUR");

### Clean old image captchas ###
if($c->{captcha_mode}==1)
{
   opendir(DIR, "$c->{site_path}/captchas");
   while( defined(my $fn=readdir(DIR)) )
   {
      next if $fn=~/^\.{1,2}$/;
      my $file = "$c->{site_path}/captchas/$fn";
      unlink($file) if (time -(lstat($file))[9]) > 1800;
   }
   closedir DIR;
}
######
 
if($c->{cron_test_servers})
{
   $c->{email_text}=1;
   my $servers = $db->SelectARef("SELECT * FROM Servers WHERE srv_status<>'OFF' GROUP BY host_id");
   for my $s (@$servers)
   {
      print"Checking server $s->{srv_name}...<br>\n";
      my $res = $ses->api($s->{srv_cgi_url}, {op => 'test', dl_key=>$c->{dl_key}, site_cgi=>$c->{site_cgi}} );
      my $error;
      for(split(/\|/,$res))
      {
         $error=1 if /ERROR/;
      }
      if($error || $res!~/^OK/)
      {
         $res=~s/\|/\n/gs;
         print"Server error:$res\n";
         $ses->SendMailQueue($c->{contact_email}, $c->{email_from}, "$s->{srv_name} server error","Error happened while testing server $s->{srv_name}:\n\n$res");
      }
      else
      {
         print"OK<br>\n";
      }
   }
}

if($c->{m_f} && $c->{m_f_update_on_cron})
{
    print"Syncing FTP users...<br>\n";
    $ses->syncFTPUsers(1);
}

# my %h;
# for(@$dellist)
# {
#    push @{$h{$_->{srv_id}}}, $_ ;
# }
# for my $srv_id (keys %h)
# {
#    my $list = join ':', map{ "$_->{file_real_id}-$_->{file_real}" } @{$h{$srv_id}};
#    my $realids = join ',', map{ $_->{file_real_id} } @{$h{$srv_id}};

#    my $res = $ses->api2($srv_id, { op => 'del_files', list => $list });
#    if($res=~/OK$/s)
#    {
#    	 $db->Exec("DELETE FROM DeleteQueue WHERE file_real_id IN ($realids)");
#    }
#    else
#    {
#       $ses->AdminLog("Error when deleting file. ServerID: $srv_id.\n$res");
#    }
# }

if($c->{highload_mode_auto})
{
	my $avg = `cat /proc/loadavg`;
	my ($avg15) = $avg=~/^[\d\.]+\s+[\d\.]+\s+([\d\.]+)/;
	print"AVG15: $avg15\n";
	if(!$c->{highload_mode} && $avg15>$c->{highload_mode_auto})
	{
		`perl -pi -e "s/highload_mode => ''/highload_mode => '1'/;" XFileConfig.pm`;
	}
	if($c->{highload_mode} && $avg15<$c->{highload_mode_auto})
	{
		`perl -pi -e "s/highload_mode => '1'/highload_mode => ''/;" XFileConfig.pm`;
	}
}

if($c->{m_a})
{
	### Delete DMCA queue ###
	my $dmca_list = $db->SelectARef("SELECT * FROM FilesDMCA d, Files f WHERE d.del_time < NOW() AND d.file_id=f.file_id LIMIT 5000");
	print"DMCA list: $#$dmca_list\n";
	$ses->DeleteFilesMass($dmca_list) if $#$dmca_list>-1;
	for(@$dmca_list)
	{
	  $db->Exec("INSERT INTO DelReasons SET file_code=?, file_name=?, info=?",$_->{file_code},$_->{file_name},"DMCA request");
	}
	$db->Exec("DELETE FROM FilesDMCA WHERE del_time < NOW() LIMIT 5000");
}

if($c->{m_t} && $c->{torrent_clean_inactive})
{
	$db->Exec("DELETE FROM Torrents WHERE updated<NOW()-INTERVAL ? HOUR",$c->{torrent_clean_inactive});
}

###
my $enc_num = $db->SelectOne("SELECT COUNT(*) FROM QueueEncoding WHERE status='PENDING' OR (status='ENCODING' AND updated>=NOW()-INTERVAL 60 SECOND)");

my $url_num = $db->SelectOne("SELECT COUNT(*) FROM QueueUpload WHERE status='PENDING' OR (status='WORKING' AND updated>=NOW()-INTERVAL 120 SECOND)");

my $trans_num = $db->SelectOne("SELECT COUNT(*) FROM QueueTransfer WHERE status='PENDING' OR (status='MOVING' AND updated>=NOW()-INTERVAL 120 SECOND)");

my $host_stat = $db->SelectRow("SELECT SUM(host_in) as host_in, SUM(host_out) as host_out, SUM(host_connections) as host_connections 
								FROM Hosts WHERE host_updated>NOW()-INTERVAL 30 MINUTE");

$db->Exec("INSERT INTO StatsPerf SET time=NOW(), encode=?, urlupload=?, transfer=?, speed_out=?, speed_in=?, connections=?",
			$enc_num||0, $url_num||0, $trans_num||0, $host_stat->{host_out}||0, $host_stat->{host_in}||0, $host_stat->{host_connections}||0
		);
###

$db->Exec("DELETE FROM Proxy2Files WHERE created < NOW() - INTERVAL ? DAY", $c->{proxy_pairs_expire}||2 );

###

if($ses->f->{token})
{
	print"-----------------------<br>ALL DONE<br><br><a href='$c->{site_url}/adm?op=admin_servers&token=".$ses->f->{token}."'>Back to server management</a>";
}
