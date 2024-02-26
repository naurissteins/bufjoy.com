#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;
use LWP::UserAgent;
exit if $ENV{REMOTE_ADDR}; # allow only run from console

my $txt = `atop 10 2`;
$txt=~s/^.+ATOP -//s;

my ($avg) = $txt=~/avg5\s*([\d\.]+)/s;

my ($str_speed) = $txt=~/bond\d+(.+?)\n/is;
$str_speed=$1 if !$str_speed && $txt=~/pcki(.+?)\n/is;
$str_speed=$1 if !$str_speed && $txt=~/enp(.+?)\n/is;

my ($in,$mkin) = $str_speed=~/si\s*(\d+) (G|M|K)bps/si;
my ($out,$mkout) = $str_speed=~/so\s*(\d+) (G|M|K)bps/si;
$in||=0;
$out||=0;
$in  = sprintf("%.0f",$in/1024) if lc($mkin) eq 'k';
$out = sprintf("%.0f",$out/1024) if lc($mkout) eq 'k';
$in*=1000 if $mkin eq 'G';
$out*=1000 if $mkout eq 'G';
print"AVG: $avg\nIN:  $in Mbps\nOUT: $out Mbps\n";

my $conn;
my $ua = LWP::UserAgent->new(timeout => 10);
$c->{nginx_port}||='8777';
my $nurl = $c->{nginx_port} eq '443' ? 'https://127.0.0.1' : 'http://127.0.0.1';
my $ns = $ua->get("$nurl:$c->{nginx_port}/nstatus")->content;
($conn) = $ns=~/Writing: (\d+)/i;
print"Connections:$conn\n";

my $atop = "$avg:$in:$out:$conn";

######################################

my $dfh;
my $df=`df -BK -P`;
for(split(/\n/,$df))
{
  my ($d,$v) = $_=~/\/(.+?)\s+\S+\s+(\d+)K/gis;
  next unless $d;
  $d=~s/^.+\///;
  $d=~s/^\/dev\///;
  #print"$d:$v\n";
  $dfh.="$d:$v\n";
}

print"$dfh\n";
######################################

my $txt = join '', `iostat -x 10 2`;
$txt=~s/^.+Device//is;
$txt=~s/^.+Device//is;
$txt=~s/\n/\n\n/g;
my $ioh;
while($txt=~/\n([\w\-]+)\s+.+?([\d\.]+)\n/gis)
{
  $ioh.="$1:$2\n";
}
print"$ioh\n";

my $ua = LWP::UserAgent->new(agent => $c->{user_agent},timeout => 360);
my $res = $ua->post("$c->{site_url}/fs",
                    {
                       op       => 'atop',
                       dl_key   => $c->{dl_key},
                       host_id  => $c->{host_id},
                       atop  => $atop,
                       df    => $dfh,
                       io    => $ioh,
                    }
                   )->content;
print"RES:$res\n";