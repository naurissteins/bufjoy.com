#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;

my ($sent_total, $sent_cached);

my $hh;

sub parseLog
{
	my ($logfile) = @_;
	return unless -s $logfile;
	open FF, $logfile;
	while(<FF>)
	{
		chomp;
		my ($file_id, $code, $mode, $ip, $sent, $hit) = split /\|/, $_;
		#print"$code,$mode,$ip,$sent,$hit\n";

		if($hit){
			$sent_total += $sent;
			$sent_cached += $sent if $hit eq 'HIT';
		}

		next unless $code && $mode && $ip && $sent;

		# skip if sent bytes < 16KB
		next if $sent < 16*1024;

		$hh->{"$file_id|$code|$mode|$ip"} += $sent;
	}
	close FF;
}

parseLog("/usr/local/nginx/logs/xvs_hls2.txt");
parseLog("/usr/local/nginx/logs/xvs_mp4.txt");


my $data;
for(keys %$hh)
{
	$data.="$_|$hh->{$_}\n";
}

print $data,"\n";
#exit;

$sent_total||=1;
my $cache_rate =  int( 100 * $sent_cached / $sent_total );
print"Traffic cached: $sent_cached of $sent_total = $cache_rate%\n";

if($data)
{
   require LWP::UserAgent;
   print"Sending stats...\n";
   my $size = length $data;
   my $ua = LWP::UserAgent->new(agent => $c->{user_agent},timeout => 300);
   my $res = $ua->post("$c->{site_cgi}/logs.cgi",
                       {op			=> 'stats',
                        dl_key		=> $c->{dl_key},
                        data		=> $data,
                        hls2		=> 1,
                        cache_rate	=> $cache_rate,
                        host_id		=> $c->{host_id},
                       }
                      )->content;
   print"Sent($size):$res\n";
}
