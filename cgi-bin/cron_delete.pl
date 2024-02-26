#!/usr/bin/perl
use strict;
use lib '.';
use XFileConfig;
use File::Pid::Quick qw( logs/delete.pid );
use Session;

exit if $ENV{REMOTE_ADDR};

my $ses = Session->new();
my $db = $ses->db;
my $cx;

start:
exit if ++$cx>=10;

my $recent = $db->SelectARef("SELECT * FROM FilesTrash WHERE cleaned=0 LIMIT 20");

$cx+=$#$recent+1;

print(".\n"),sleep(3),goto start if $#$recent==-1;

$db->Exec("INSERT INTO Stats SET day=CURDATE(), deleted=? ON DUPLICATE KEY UPDATE deleted=deleted+?", $#$recent+1, $#$recent+1 );

my $ids = join ',', map{ $_->{file_id} } @$recent;
#die $ids;
my $codes = join ',', map{ "'$_->{file_code}'" } @$recent;
if($ids)
{
	$db->Exec("UPDATE FilesTrash SET cleaned=1 WHERE file_id IN ($ids)");

	$db->Exec("DELETE FROM FilesData WHERE file_id IN ($ids)");
	$db->Exec("DELETE FROM FilesDMCA WHERE file_id IN ($ids)");
	$db->Exec("DELETE FROM Comments WHERE cmt_type=1 AND cmt_ext_id IN ($ids)");
	$db->Exec("DELETE FROM Tags2Files WHERE file_id IN ($ids)");
	$db->Exec("DELETE FROM Votes WHERE file_id IN ($ids)");
	$db->Exec("DELETE FROM Favorites WHERE file_id IN ($ids)");
	$db->Exec("DELETE FROM Files2Playlists WHERE file_id IN ($ids)");
	$db->Exec("DELETE FROM Views WHERE file_id IN ($ids)");
	$db->Exec("DELETE FROM Downloads WHERE file_id IN ($ids)");
}
if($codes)
{
	$db->Exec("DELETE FROM Reports WHERE file_code IN ($codes)");
	$db->Exec("DELETE FROM QueueVTT WHERE file_code IN ($codes)");
}

my $userhash;
$userhash->{$_->{usr_id}}++ for @$recent;
for (keys %$userhash)
{
	$db->Exec("UPDATE Users SET usr_files_used=usr_files_used-? WHERE usr_id=?", $userhash->{$_}, $_ );
}

for my $file (@$recent)
{
	if($c->{srt_on} && $c->{srt_langs})
	{
		my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
		my $dir = "$c->{site_path}/srt/$dx";
		my $sfiles = "$dir/$file->{file_code}_";
		unlink <$sfiles*>;
	}

	#$ses->PurgeFileCaches($file); # purging in DeleteFileDisk
}

goto start;
