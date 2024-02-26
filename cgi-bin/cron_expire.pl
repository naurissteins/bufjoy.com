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
my $br='<br>' if $ENV{REMOTE_ADDR};
print"Content-type:text/html\n\n" if $br;
if($f->{token})
{
	XUtils::CheckAuth($ses);
	$ses->{tokenok}=1 if $ses->checkToken;
}
print('restricted'),exit if $ENV{REMOTE_ADDR} && !$ses->{tokenok};

my $del_approved=1 if !$ENV{REMOTE_ADDR} || ($ses->{tokenok} && $f->{delok});

# Delete expired files
if($c->{files_expire_access_reg} || $c->{files_expire_access_prem})
{
	print"---File expire---$br\n";
	my @files;
	my $limit="LIMIT $c->{files_expire_limit}" if $c->{files_expire_limit};
	if($c->{files_expire_access_reg})
	{
		my $list = $db->SelectARef("SELECT f.*
									FROM Files f, Users u
									WHERE f.usr_id=u.usr_id
									AND u.usr_premium_expire<NOW()
									AND u.usr_no_expire=0
									AND u.usr_notes NOT LIKE '%NOEXPIRE%'
									AND file_last_download < NOW()-INTERVAL ? DAY
									$limit",
									$c->{files_expire_access_reg});
		push @files, @$list;
		print"Reg files to delete:".($#$list+1)."$br\n";
	}
	if($c->{files_expire_access_prem})
	{
		my $list = $db->SelectARef("SELECT f.*
									FROM Files f, Users u
									WHERE f.usr_id=u.usr_id
									AND u.usr_premium_expire>=NOW()
									AND u.usr_no_expire=0
									AND u.usr_notes NOT LIKE '%NOEXPIRE%'
									AND file_last_download < NOW()-INTERVAL ? DAY
									$limit",
									$c->{files_expire_access_prem});
		push @files, @$list;
		print"Premium files to delete:".($#$list+1)."$br\n";
	}

	print"Have ".($#files+1)." files to expire...$br\n";

	unless($del_approved)
	{
		my $rand = int rand(100000);
		print qq[$br<input type="button" value="Delete expired" onclick="window.location='?delok=1&token=$f->{token}&r=$rand'">$br\n];
	}
	elsif(@files)
	{
		print"Adding files to del queue...$br\n";
		$ses->DeleteFilesMass(\@files);
	}
}

# Delete expired qualities
if($c->{expire_quality_access_reg} || $c->{expire_quality_access_prem})
{
	print"$br\n---Quality expire---$br\n";
	my @files;
	if($c->{expire_quality_access_reg})
	{
		my $list = $db->SelectARef("SELECT f.*
									FROM Files f, Users u
									WHERE f.usr_id=u.usr_id
									AND u.usr_premium_expire<NOW()
									AND u.usr_no_expire=0
									AND u.usr_notes NOT LIKE '%NOEXPIRE%'
									AND file_last_download < NOW()-INTERVAL ? DAY
									AND file_size_$c->{expire_quality_name} > 0",
									$c->{expire_quality_access_reg});
		push @files, @$list;
		print"Reg files to delete quality:".($#$list+1)."$br\n";
	}
	if($c->{expire_quality_access_prem})
	{
		my $list = $db->SelectARef("SELECT f.*
									FROM Files f, Users u
									WHERE f.usr_id=u.usr_id
									AND u.usr_premium_expire>=NOW()
									AND u.usr_no_expire=0
									AND u.usr_notes NOT LIKE '%NOEXPIRE%'
									AND file_last_download < NOW()-INTERVAL ? DAY
									AND file_size_$c->{expire_quality_name} > 0",
									$c->{expire_quality_access_prem});
		push @files, @$list;
		print"Prem files to delete quality:".($#$list+1)."$br\n";
	}

	print"Have ".($#files+1)." files to del ".uc($c->{expire_quality_name})." quality...$br\n";
	unless($del_approved)
	{
		my $rand = int rand(100000);
		print qq[$br<input type="button" value="Delete expired" onclick="window.location='?delok=1&token=$f->{token}&r=$rand'">$br\n];
		exit;
	}
	elsif(@files)
	{
		print"Deleting files quality $c->{expire_quality_name}...$br\n";
		my $cx;
		for my $file (@files)
		{
			# skip if it's the last quality available
			next if $file->{file_size_o}+$file->{file_size_n}+$file->{file_size_h}+$file->{file_size_l}+$file->{file_size_x} == $file->{"file_size_$c->{expire_quality_name}"};
			print"del quality $file->{file_real}-$c->{expire_quality_name}: ";
			$ses->DeleteFileQuality( $file, $c->{expire_quality_name}, 0);
			# print $ses->api2($file->{srv_id}, 
			#           {
			#            op           => 'delete_file_spec',
			#            file_real_id => $file->{file_real_id}||$file->{file_id},
			#            file_real    => $file->{file_real},
			#            type         => $c->{expire_quality_name},
			#           } )."$br\n";
			$db->Exec("UPDATE Files SET file_size_$c->{expire_quality_name}=0, file_spec_$c->{expire_quality_name}='' WHERE file_real=?",$file->{file_real});
			$db->Exec("UPDATE Users SET usr_disk_used=usr_disk_used-? WHERE usr_id=?", int($file->{"file_size_$c->{expire_quality_name}"}/1024), $file->{usr_id} );
			last if $c->{files_expire_limit} && ++$cx >= $c->{files_expire_limit};
		}
	}
}

print"-----------------------$br\nALL DONE\n";
print"$br$br<a href='$c->{site_url}/adm?op=admin_servers'>Back to server management</a>" if $br;
