#!/usr/bin/perl
### SibSoft.net ###
use strict;
use lib '.';
use XFSConfig;
use XUpload;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use LWP::UserAgent;

require Log;
my $log = Log->new(filename=>'upload.txt', mute=>1);

print("Content-type:text/html\n\nXFS"),exit if $ENV{QUERY_STRING}=~/mode=test/;

my $f;
my $cgi = new CGI;
for( $cgi->param() )
{
  my @val = $cgi->param($_);
  $f->{$_} = @val>1 ? \@val : $val[0];
}
$f->{ip} = getIP();

#use Data::Dumper;
#die Data::Dumper->Dump([$f]);


#my ($disk_id) = $ENV{QUERY_STRING}=~/disk_id=(\d+)/;
#xmessage("ERROR: Invalid Disk ID") unless $disk_id=~/^\d\d$/;
#$log->log("Starting upload. Size: $ENV{'CONTENT_LENGTH'}");
my @fields = qw(file_name file_title file_descr cat_id tags file_size file_public file_adult snapshot_path disk_id);
push @fields,$_ for grep {/^extra_/} keys %$f;

my @files;
my $list = ARef($f->{file_path});
for(my $cx=0;$cx<=$#$list;$cx++)
{
  my $u;
  $u->{file_tmp}      = $list->[$cx];
  $u->{$_} =  defined ARef($f->{$_})->[$cx] ? ARef($f->{$_})->[$cx]||'' : ARef($f->{$_})->[0] for @fields;
  $u->{file_name_orig}= $u->{file_name};
  $u->{file_name_orig}=~s/^.*\\([^\\]*)$/$1/;
  $u->{snapshot_file_tmp} = $u->{snapshot_path};
  push @files, $u;
}


my @files_out;
for my $file ( @files )
{
   $file->{file_status}="null filesize or wrong file path"
      if $file->{file_size}==0;

   if($file->{file_status})
   {
      unlink($file->{file_tmp});
      unlink($file->{snapshot_file_tmp}) if $file->{snapshot_file_tmp};
   }

   # --------------------
   $XUpload::log = $log;
   $file = XUpload::ProcessFile($file,$f) unless $file->{file_status};
   # --------------------

   $file->{file_status}||='OK';
   push @files_out, $file;
}

if($f->{key} && !$f->{html_redirect})
{
	print"Content-type: application/json\n\n";
	my @arr;
	for my $ff (@files)
	{
	   push @arr, qq|{ "filecode":"$ff->{file_code}", "filename": "$ff->{file_name_orig}", "status": "$ff->{file_status}" }|;
	}
	my $list = join ', ', @arr;
	print qq|{"msg": "OK", "status": 200, "files": [ $list ]}|;
	exit;
}

# Generate parameters array for POST
my @har;
push @har, { name=>'op', value=>'upload_result' };
push @har, { name=>'sess_id', value=>$f->{sess_id} };
for my $ff (@files)
{
   push @har, { name=>"fn", value=>$ff->{file_code}||$ff->{file_name_orig} };
   push @har, { name=>"st", value=>$ff->{file_status} };
}

if($f->{json})
{
	require JSON;
	my $list;
	push @$list, { code=>$_->{file_code}||$_->{file_name_orig}, status=>$_->{file_status} } for @files;
	print"Content-type: application/json\n\n";
	print JSON::encode_json({result => $list});
	exit;
}

### Sending data to MAIN
print"Content-type: text/html\n\n";
print"<HTML><BODY><Form name='F1' action='$c->{site_url}/' target='_parent' method='POST'>";
for my $x (@har)
{
	$x->{value}=~s/[<>\0\/\"]+//gs;
	print qq|<textarea name="$x->{name}">$x->{value}</textarea>|;
}
print"</Form><Script>document.location='javascript:false';document.F1.submit();</Script></BODY></HTML>";
exit;


######################################################

sub getIP
{
 return $ENV{HTTP_X_FORWARDED_FOR} || $ENV{HTTP_X_REAL_IP} || $ENV{REMOTE_ADDR};
}

sub ARef
{
  my $data=shift;
  $data=[] unless $data;
  $data=[$data] unless ref($data) eq 'ARRAY';
  return $data;
}