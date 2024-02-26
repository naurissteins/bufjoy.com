#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;
#use CGI::Carp qw(fatalsToBrowser);
use CGI;

my $q = new CGI;
my $f;
$f->{$_}=$q->param($_) for $q->param;
#use Data::Dumper;
#die Dumper([$f]);

use Crypt::HCE_MD5;

my $hce = Crypt::HCE_MD5->new($XFSConfig::c->{dl_key},"XVideoSharing");
my $hls=$1 if $ENV{REQUEST_URI}=~/\/(?:hls|dash)\//i && $ENV{QUERY_STRING}=~/\/(?:hls|dash)\/(\w+)/; # HLS/DASH
my $rtmp=$f->{h} if $f->{h} && $f->{app};  # RTMP
my $mp4=$1 if $ENV{QUERY_STRING}=~/^pseudo=\/(\w+)\//;

$_ = $mp4 || $hls || $rtmp;
my $l;
tr|a-z2-7|\0-\37|;
$_=unpack('B*',$_);
s/000(.....)/$1/g;
$l=length;
$_=substr($_,0,$l & ~7) if $l & 7;
$_=pack('B*',$_);

my ($end,$disk_id,$file_id,$usr_id,$dx,$id,$dmode,$speed,$i1,$i2,$i3,$i4,$expire,$flags) = unpack("SCLLSA12ASC4LC", $hce->hce_block_decrypt($_) );
#logg("($ENV{REQUEST_URI}) $end,$disk_id,$file_id,$usr_id,$dx,$id,$dmode,$speed,$i1,$i2,$i3,$i4,$expire,$flags");
$dx=sprintf("%05d",$dx);
$disk_id=sprintf("%02d",$disk_id);
$speed *= 1024 if $speed;
my ($flag_dl, $flag_embed, $flag_transfer, $flag_noipcheck, $flag_noipcheck_mobile) = ( $flags & 1, $flags & 2, $flags & 4, $flags & 8, $flags & 16 );

my ($start) = $ENV{REQUEST_URI}=~/start=(\d+)/i;
my $startend = "&start=$start" if $start;
$startend .= "&end=$end" if $end;
$startend .= "&xvs=1";

my $ip = $ENV{HTTP_CF_CONNECTING_IP} || $ENV{HTTP_X_FORWARDED_FOR} || $ENV{HTTP_X_REAL_IP} || $ENV{REMOTE_ADDR};
$flag_noipcheck=1 if $flag_noipcheck_mobile && $ENV{HTTP_USER_AGENT}=~/(iphone|ipod|ipad|ios|android)/i;
$flag_noipcheck=1 if $c->{no_ipcheck_ipv6} && ($ip=~/:/ || $ENV{HTTP_CF_CONNECTING_IPV6});
$ip = inet_ntoa( ipv6to4( ipv6_aton($ip) ) ) if $ip=~/:/;

my $cgi_dir = $c->{cgi_dir};
my $upload_dir = "$cgi_dir/uploads/$disk_id/$dx";
    
my $ipt = $i1 ? "$i1.$i2.$i3.$i4" : $ip;

# fix for old orig folder
if($dmode eq 'o' && !-f "$cgi_dir/uploads/$disk_id/$dx/$id\_o")
{
	$dmode='R';
}

# if not found try other qualities
if($dmode=~/^(x|h|n|l)$/ && !-f "$upload_dir/$id\_$dmode")
{
	$dmode='l' if -f "$upload_dir/$id\_l";
	$dmode='n' if -f "$upload_dir/$id\_n";
	$dmode='h' if -f "$upload_dir/$id\_h";
}
# if not found try other disks
if($dmode=~/^(x|h|n|l|p)$/ && !-f "$cgi_dir/uploads/$disk_id/$dx/$id\_$dmode")
{
	for(1..12)
	{
		my $dd=sprintf("%02d",$_);
		last unless -d "$cgi_dir/uploads/$dd";
		if(-f "$cgi_dir/uploads/$dd/$dx/$id\_$dmode"){$disk_id=$dd;$upload_dir="$cgi_dir/uploads/$disk_id/$dx";last;}
	}
}

out("error_wrong_ip"),exit if $c->{dirlinks_allowed_referers} && !$flag_transfer && $ENV{HTTP_REFERER}!~/[\/\.]($c->{dirlinks_allowed_referers})\//i;

if($i1 && $ip !~ /^$i1\.$i2\./ && !$flag_noipcheck)
{
	#logg("wrong_ip: $ip - $i1.$i2");
	if($hls)
	{
		print"Content-type:text/html\n\n";
		print qq|{"sequences": [{"clips": [{"type": "source","path": "$c->{htdocs_dir}/wrong_ip.mp4"}]}]}|;
	}
	else
	{
		#out("error_wrong_ip");
		print"Content-type:video/mp4\n";
		print"X-Accel-Redirect: /wrong_ip.mp4\n\n";
	}
}
elsif($expire<time)
{
	#logg("expired: $expire - ".time);
	if($hls)
	{
		print"Content-type:text/html\n\n";
		print qq|{"sequences": [{"clips": [{"type": "source","path": "$c->{htdocs_dir}/expired.mp4"}]}]}|;
	}
	else
	{
		#out("error_expired");
		print"Content-type:video/mp4\n";
		print"X-Accel-Redirect: /expired.mp4\n\n";
	}
}
elsif($dmode eq 'R' && !-f "$cgi_dir/orig/$disk_id/$dx/$id")
{
	#logg("no orig file on disk $cgi_dir/orig/$disk_id/$dx/$id");
	out("error_nofile");
}
elsif($dmode=~/^(o|x|h|n|l|p)$/ && !-f "$upload_dir/$id\_$dmode")
{
	#logg("no file on disk $upload_dir/$id\_$dmode");
	out("error_nofile");
}
else
{
	if($hls && $dmode=~/^(o|x|h|n|l|p)$/)
	{
		#logg("x: $upload_dir/$id\_$dmode");
		print"Content-type:text/html\n\n";
print<<EOP
{
    "sequences": [
        {
            "clips": [
                {
                    "type": "source",
                    "path": "$upload_dir/$id\_$dmode"
                }
            ]
        }
    ]
}
EOP
;
	}
	elsif($hls && $dmode=~/^(R)$/)
	{
        print"Content-type:text/html\n\n";
print<<EOP
{
    "sequences": [
        {
            "clips": [
                {
                    "type": "source",
                    "path": "$cgi_dir/orig/$disk_id/$dx/$id"
                }
            ]
        }
    ]
}
EOP
;
	}
	elsif($mp4 && $flag_dl) # Downloads
	{
		my $redir = $dmode eq 'R' ? "/download/orig/$disk_id/$dx/$id" : "/download/uploads/$disk_id/$dx/$id\_$dmode";
		print"X-Accel-Redirect: $redir?id=$file_id&usr=$usr_id&speed=$speed&ip=$ipt&dmode=$dmode&flags=$flags"."\n\n";
	}
	elsif($flag_transfer) # Transfers
	{
		my $redir = $dmode eq 'R' ? "/transfer/orig/$disk_id/$dx/$id" : "/transfer/uploads/$disk_id/$dx/$id\_$dmode";
		print"X-Accel-Redirect: $redir?&speed=$speed&ip=$ipt"."\n\n";
	}
	elsif($mp4 && $dmode=~/^(x|h|n|l|p|o|R)$/)
	{
		my $redir = $dmode eq 'R' ? "orig/$disk_id/$dx/$id" : "uploads/$disk_id/$dx/$id\_$dmode";
		my $size = -s "$cgi_dir/uploads/$disk_id/$dx/$id\_$dmode";
		my $lra = 500*1024 + int $size*0.02; # no speed limit for first 500k + 2% of video
		$lra=1000*1024 if $lra<1000*1024;
		print"Content-type:video/mp4\n";
		print"X-Accel-Redirect: /video_mp4/$redir?id=$file_id&usr=$usr_id&speed=$speed&ip=$ipt&dmode=$dmode&flags=$flags&lra=$lra".$startend."\n\n";
	}
	else
	{
		out("OK");
	}
}

sub out
{
	print"Content-type:text/html\n\n";
	print shift;
}

sub logg
{
 my $msg=shift;
 open FILE, ">>$c->{cgi_dir}/logs/vod.log";
 my @t = localtime;
 my $timestamp = sprintf("%4d-%02d-%02d %02d-%02d-%02d", $t[5]+1900, $t[4], $t[3], $t[2], $t[1], $t[0]);
 print FILE "$timestamp | $msg\n";
 close FILE;
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