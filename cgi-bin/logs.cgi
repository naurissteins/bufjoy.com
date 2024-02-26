#!/usr/bin/perl
use strict;
use lib '.';
use XFileConfig;
use Session;
use CGI::Carp qw(fatalsToBrowser);

my $ses = Session->new();
my $f = $ses->f;
my $db= $ses->db;
sendBack("111") if $ENV && $ENV{REQUEST_METHOD} ne 'POST';
sendBack("222") if $f->{dl_key} ne $c->{dl_key};

sub sendBack
{
	print"Content-type:text/html\n\n".shift;
	exit;
}
sub logg
{
	my $msg = shift;
	return unless $c->{fs_logs_on};
	open(FILE,">>logs/fs.log")||return;
	print FILE "$msg\n";
	close FILE;
}


# Initialize hashes for tracking views and downloads
my %views_counted;
my %downloads_counted;

sub already_viewed {
    my ($file_id, $ip) = @_;
    my $viewed = $db->SelectRow("SELECT 1 FROM Views WHERE file_id=? AND ip=? AND finished=1 LIMIT 1", $file_id, $ip);
    return $viewed ? 1 : 0;
}

sub already_downloaded {
    my ($file_id, $ip) = @_;
    my $downloaded = $db->SelectRow("SELECT 1 FROM Downloads WHERE file_id=? AND ip=? AND finished=1 LIMIT 1", $file_id, $ip);
    return $downloaded ? 1 : 0;
}

$|++;
print"Content-type:text/html\n\n";
my ($views_sum,$downloads_sum,$bwhash,$iphash,$bandwidth_sum);

my $list = $db->SelectARefCached("SELECT DISTINCT host_ip FROM Hosts");
my $srvip;
$srvip->{$_->{host_ip}}=1 for @$list;

my $gi;

for(split(/\n/,$f->{data}))
{

	$_=~s/[\n\r]+//g;
	my ($file_real,$file_id,$mode,$ip,$bandwidth,$ip2);

 	( $file_id, $file_real, $mode, $ip2, $bandwidth ) = split(/\|/,$_);
	$ip = unpack('N',pack('C4', split('\.',$ip2) ));   

	next unless $ip;
	next if $srvip->{$ip2};

    $bandwidth_sum+=$bandwidth;
	$iphash->{$ip}->{traffic}+=$bandwidth;

    my $file = $db->SelectRowCached("SELECT * FROM Files f, Users u WHERE f.file_id=? AND f.usr_id=u.usr_id",$file_id);

    next unless $file;
	next if $file_real && $file->{file_real} ne $file_real; # file_id to not match file_real, fake
    $bwhash->{$file->{file_id}} += $bandwidth; 

    logg("File ID: $file_id, IP: $ip2");

    my $view_details = $db->SelectRow("SELECT created FROM Views WHERE file_id=? AND ip=? ORDER BY created DESC LIMIT 1", $file_id, $ip);
    if ($view_details && !already_viewed($file_id, $ip)) {

        # Count the view and mark it as counted
        $views_counted{"$file_id|$ip"} = 1;

        # Fetch view details
        my $view_details = $db->SelectRow("SELECT * FROM Views WHERE file_id=? AND ip=? LIMIT 1", $file_id, $ip);

        $view_details->{size} += $bandwidth;

        $views_sum++;
        $db->Exec("UPDATE Views SET size=?, views_full=1, finished=1 WHERE file_id=? AND ip=? LIMIT 1", $view_details->{size}, $file_id, $ip);
        $db->Exec("INSERT INTO TmpFiles SET file_id=?, views_full=1 ON DUPLICATE KEY UPDATE views_full=views_full+1", $file_id); 

        # Update StatsCountry
        if (defined $view_details->{country}) {
            $db->Exec("INSERT INTO StatsCountry SET usr_id=?, day=CURDATE(), country=?, views=1 ON DUPLICATE KEY UPDATE views=views+1", $file->{usr_id}, $view_details->{country});
        }

        # Update TmpStats2 based on the latest action
        $db->Exec("INSERT INTO TmpStats2 SET usr_id=?, views=1 ON DUPLICATE KEY UPDATE views=views+1", $file->{usr_id}) if $file->{usr_id};

        # For StatsIP
        $iphash->{$ip}->{view}+=1; 

    } 
    
    my $download_details = $db->SelectRow("SELECT created FROM Downloads WHERE file_id=? AND ip=? ORDER BY created DESC LIMIT 1", $file_id, $ip);
    if ($download_details && !already_downloaded($file_id, $ip)) {

        # Count the download and mark it as counted
        $downloads_counted{"$file_id|$ip"} = 1;

        # Fetch download details
        my $download_details = $db->SelectRow("SELECT * FROM Downloads WHERE file_id=? AND ip=? LIMIT 1", $file_id, $ip);

        $download_details->{size} += $bandwidth;

        $downloads_sum++;
        $db->Exec("UPDATE Downloads SET size=?, finished=1 WHERE file_id=? AND ip=? LIMIT 1", $download_details->{size}, $file_id, $ip);     
        $db->Exec("INSERT INTO TmpFiles SET file_id=?, downloads=1 ON DUPLICATE KEY UPDATE downloads=downloads+1", $file_id);

        # Update StatsCountry
        if (defined $download_details->{country}) {
            $db->Exec("INSERT INTO StatsCountry SET usr_id=?, day=CURDATE(), country=?, downloads=1 ON DUPLICATE KEY UPDATE downloads=downloads+1", $file->{usr_id}, $download_details->{country});
        }

        # Update TmpStats2 based on the latest action
         $db->Exec("INSERT INTO TmpStats2 SET usr_id=?, downloads=1 ON DUPLICATE KEY UPDATE downloads=downloads+1", $file->{usr_id}) if $file->{usr_id};

    }
    
}

$views_sum||=0;
$downloads_sum||=0;
logg("SUM: views=$views_sum, downloads_sum=$downloads_sum, bandwidth=$bandwidth_sum");

if ($views_sum > 0 || $downloads_sum > 0) {
    $db->Exec("INSERT INTO Stats
            SET day=CURDATE(), 
                views=$views_sum, 
                bandwidth=$bandwidth_sum,
                downloads=$downloads_sum
            ON DUPLICATE KEY 
            UPDATE 
            views=views+$views_sum,
            bandwidth=bandwidth+$bandwidth_sum,
            downloads=downloads+$downloads_sum");   
}              

for(keys %$iphash)
{
  my $tt = sprintf("%.0f",$iphash->{$_}->{traffic}/1048576)||0;
  my $vv = $iphash->{$_}->{view}||0;
  $db->Exec("INSERT INTO StatsIP
             SET day=CURDATE(), ip=?, traffic=$tt, views=$vv
             ON DUPLICATE KEY 
             UPDATE traffic=traffic+$tt, views=views+$vv",$_) if $tt>0;
}          

for(keys %$bwhash)
{
  $db->Exec("INSERT INTO TmpFiles
             SET file_id=?, bandwidth=?
             ON DUPLICATE KEY UPDATE bandwidth=bandwidth+?
            ",$_, int($bwhash->{$_}/1024), int($bwhash->{$_}/1024) );
}          

if($c->{m_r} && $f->{host_id})
{
		$db->Exec("UPDATE Hosts SET host_cache_rate=? WHERE host_id=?",$f->{cache_rate},$f->{host_id});
}          

print"OK";          