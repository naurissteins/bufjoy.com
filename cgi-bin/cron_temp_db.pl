#!/usr/bin/perl
use strict;
use lib '.';
use XFileConfig;
use Session;

my $ses = Session->new();
my $db= $ses->db;

### TmpUsers ###
print"[TmpUsers]\n";
my $list = $db->SelectARef("SELECT * FROM TmpUsers");
my $cx = $#$list+1;
print"$cx records\n";
$db->Exec("TRUNCATE TmpUsers") if $cx;
for(@$list)
{
	$db->Exec("UPDATE LOW_PRIORITY Users SET usr_money=usr_money+? WHERE usr_id=?", $_->{money}, $_->{usr_id} );
}
print"done.\n\n";

### TmpStats2 ###
print"[TmpStats2]\n";
my $list = $db->SelectARef("SELECT * FROM TmpStats2");
my $cx = $#$list+1;
print"$cx records\n";
$db->Exec("TRUNCATE TmpStats2") if $cx;
for(@$list)
{
	$db->Exec("INSERT INTO Stats2
				SET usr_id=$_->{usr_id}, day=CURDATE(),
				 views=$_->{views},
				 views_prem=$_->{views_prem},
				 views_adb=$_->{views_adb},
				 downloads=$_->{downloads},
				 profit_views=$_->{profit_views},
				 profit_refs=$_->{profit_refs}
				ON DUPLICATE KEY UPDATE
				 views=views+$_->{views},
				 views_prem=views_prem+$_->{views_prem},
				 views_adb=views_adb+$_->{views_adb},
				 downloads=downloads+$_->{downloads},
				 profit_views=profit_views+$_->{profit_views},
				 profit_refs=profit_refs+$_->{profit_refs}
				");
}
print"done.\n\n";

### TmpFiles ###
print"[TmpFiles]\n";
my $list = $db->SelectARef("SELECT * FROM TmpFiles");
my $cx = $#$list+1;
print"$cx records\n";
$db->Exec("TRUNCATE TmpFiles") if $cx;
for(@$list)
{
	$db->Exec("UPDATE LOW_PRIORITY Files 
		       SET file_views=file_views+?,
		       file_views_full=file_views_full+?,
		       file_money=file_money+?,
		       file_downloads=file_downloads+?,
		       file_last_download=NOW()
			   WHERE file_id=?", $_->{views}, $_->{views_full}, $_->{money}, $_->{downloads}, $_->{file_id} ) 
		if $_->{views} || $_->{views_full} || $_->{money} || $_->{downloads};

	$db->Exec("INSERT INTO DailyTraffic
               SET dayhour=TO_DAYS(CURDATE())*24+HOUR(NOW()), file_id=?, bandwidth=?
               ON DUPLICATE KEY UPDATE bandwidth=bandwidth+?
              ", $_->{file_id}, $_->{bandwidth}, $_->{bandwidth} ) if $_->{bandwidth};
}

### Set failed queues to Stuck ###
$db->Exec("UPDATE QueueEncoding SET status='STUCK', fps=0 WHERE status='ENCODING' AND updated<NOW()-INTERVAL 3 MINUTE");

$db->Exec("UPDATE QueueTransfer SET status='STUCK', speed=0 WHERE status='MOVING' AND updated<NOW()-INTERVAL 3 MINUTE");

$db->Exec("UPDATE QueueUpload SET status='STUCK', speed=0 WHERE status='WORKING' AND updated<NOW()-INTERVAL 3 MINUTE");

### Live Streaming mod jobs ###
if($c->{m_q})
{
	$db->Exec("DELETE FROM Stream2IP WHERE created<NOW()-INTERVAL 5 MINUTE");

	$db->Exec("UPDATE Streams SET stream_live=0 WHERE stream_live=1 AND updated<NOW()-INTERVAL 2 MINUTE");
}
print"done.\n\n";