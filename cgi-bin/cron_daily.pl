#!/usr/bin/perl
use strict;
use lib '.';
use CGI::Util qw(unescape escape);
use XFileConfig;
use Session;

my $ses = Session->new();
my $db= $ses->db;

### Cleanup DailyTraffic ###
$db->Exec("DELETE FROM DailyTraffic 
			WHERE dayhour < TO_DAYS(CURDATE())*24+HOUR(NOW())-6 
			AND   dayhour > TO_DAYS(CURDATE())*24+HOUR(NOW())-30 
			AND bandwidth < 1024*100"); # 6 hours ago and BW<100 MB

$db->Exec("DELETE FROM DailyTraffic WHERE dayhour<TO_DAYS(CURDATE())*24+HOUR(NOW())-24*14"); # older than 14 days

# Delete old torrents
$db->Exec("DELETE FROM Torrents WHERE created<NOW() - INTERVAL 30 DAY");

# Delete old IP stats
$db->Exec("DELETE FROM StatsIP WHERE day<CURDATE()-INTERVAL 14 DAY");

# Delete old abuses
$db->Exec("DELETE FROM Reports WHERE created<NOW() - INTERVAL 3 MONTH");

$db->Exec("DELETE FROM Sessions WHERE last_time<NOW() - INTERVAL 7 DAY");

if($c->{truncate_views_daily})
{
   $db->Exec("TRUNCATE Views");
}
elsif($c->{clean_ip2files_days})
{

}

$db->Exec("DELETE FROM Views WHERE created<NOW() - INTERVAL 24 HOUR AND finished=0"); # clean not-finished yesterday views

$db->Exec("DELETE FROM Downloads WHERE created<NOW() - INTERVAL 24 HOUR AND finished=0"); # clean not-finished yesterday downloads

$db->Exec("DELETE FROM DelReasons WHERE last_access<NOW() - INTERVAL 6 MONTH");

# Clean old logins
$db->Exec("DELETE FROM LoginHistory WHERE created<NOW() - INTERVAL 30 DAY");

$db->Exec("DELETE FROM StatsCountry WHERE day<CURDATE() - INTERVAL 30 DAY");

$db->Exec("DELETE FROM FilesTrash WHERE file_deleted<NOW() - INTERVAL 1 DAY");

$db->Exec("DELETE FROM Pairs WHERE created<NOW() - INTERVAL 3 DAY");

$db->Exec("DELETE FROM ChangeFields WHERE created<NOW() - INTERVAL 14 DAY");

$db->Exec("DELETE FROM StatsPerf WHERE time < NOW() - INTERVAL 180 DAY");

$db->Exec("DELETE FROM StatsMisc WHERE day < NOW() - INTERVAL 365 DAY");

$db->Exec("DELETE FROM StatsMiscMin WHERE minute < DAYOFYEAR(NOW())*24*60 + (HOUR(NOW())-48)*60 + MINUTE(NOW())");

$db->Exec("DELETE FROM FileLogs WHERE created < NOW() - INTERVAL 90 DAY");

# Use $ses->getTime to get the current date
my @dd = $ses->getTime;
# Assuming $dd[2] contains the day of the month, similar to the structure in your snippet
my $current_day_of_month = $dd[2];

if($current_day_of_month == 1) {
    # If it's the first day of the month, truncate Views and Downloads
    $db->Exec("TRUNCATE TABLE Views");
    $db->Exec("TRUNCATE TABLE Downloads");
    print "Views and Downloads have been truncated.\n";
}

# Check and update disk space if premium has expired
my $expired_users = $db->SelectARef("SELECT usr_id, usr_login FROM Users WHERE usr_premium_expire < NOW() AND usr_disk_space > 0");
foreach my $user (@$expired_users) {
    $db->Exec("UPDATE Users SET usr_disk_space = 0 WHERE usr_id = ?", $user->{usr_id});
    print "User ($user->{usr_id}) $user->{usr_login}: Disk space set to zero (premium expired).\n";
}

if($c->{plans_storage})
{
	my $stors = $db->SelectARef("SELECT * FROM StorageSlots WHERE expire=CURDATE()");
	for my $x (@$stors)
	{
		print"Deduct $x->{gb} GB from $x->{usr_id}\n";
		$db->Exec("UPDATE Users SET usr_disk_space=usr_disk_space-? WHERE usr_id=?", $x->{gb}, $x->{usr_id} );
		$db->Exec("DELETE FROM StorageSlots WHERE id=?", $x->{id} );
	}
}

### Deleted files email ###
if($c->{deleted_files_reports})
{
    #$c->{email_text}=1;
    $c->{email_html}=1;
    my $users = $db->SelectARef("SELECT DISTINCT usr_id FROM FilesTrash");
    for my $u (@$users)
    {
       my $files = $db->SelectARef("SELECT * FROM FilesTrash 
                                    WHERE usr_id=?
                                    AND file_deleted>NOW()-INTERVAL 24 HOUR
                                    AND hide=0
                                    ORDER BY file_name",$u->{usr_id});
       next if $#$files==-1;
       my $user = $db->SelectRow("SELECT * FROM Users WHERE usr_id=?",$u->{usr_id});
       next unless $user;

       for(@$files)
       {
         $_->{file_url} = $ses->makeFileLink($_);
       }
       my $t = $ses->CreateTemplate("email_deleted_files_user.html");
	   $t->param( files => $files, %$user );
	   print"Send to: $user->{usr_email}\n".$t->output,"\n\n";
       $ses->SendMailQueue( $user->{usr_email}, $c->{email_from}, "$c->{site_name}: deleted files list", $t->output );

       $db->Exec("DELETE FROM FilesTrash WHERE usr_id=?",$u->{usr_id});
    }
}

# Google sitemaps
if($c->{ping_google_sitemaps})
{
      my $perfile=5000;
      print"Generating Google Sitemap...<br>\n";
      
      my @list;
      my $cx=0;
      while( my $files=$db->SelectARef("SELECT file_code,file_name FROM Files LIMIT ?,$perfile",$cx*$perfile) )
      {
         last if $#$files==-1;
         open(F, ">$c->{site_path}/upload-data/sitemap$cx.txt")||die"can't open sitemap.txt: $!";
         for(@$files)
         {
            print F $ses->makeFileLink($_),"\n";
         }
         close F;
         `gzip -c $c->{site_path}/upload-data/sitemap$cx.txt > $c->{site_path}/upload-data/sitemap$cx.txt.gz`;
         push @list, "sitemap$cx.txt.gz";
         unlink("$c->{site_path}/upload-data/sitemap$cx.txt");
         $cx++;
      }
      
      my @dd = $ses->getTime;
      my $date = "$dd[0]-$dd[1]-$dd[2]";
      open(F,">$c->{site_path}/upload-data/sitemap_index.xml")||die"can't open sitemap_index.xml: $!";
      print F qq[<?xml version="1.0" encoding="UTF-8"?>\n<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n];
      for(@list)
      {
        print F qq[   <sitemap>\n      <loc>$c->{site_url}/upload-data/$_</loc>\n      <lastmod>$date</lastmod>\n   </sitemap>\n];
      }
      print F qq[</sitemapindex>];
      close F;
      
      require LWP::UserAgent;
      my $ua = LWP::UserAgent->new();
      $ua->get( "http://www.google.com/webmasters/tools/ping?sitemap=".escape("$c->{site_url}/upload-data/sitemap_index.xml") )->content;
      $ua->get( "http://www.bing.com/ping?sitemap=".escape("$c->{site_url}/upload-data/sitemap_index.xml") )->content;
}