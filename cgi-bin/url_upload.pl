#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;
use LWP::UserAgent;
use HTTP::Cookies;
#use HTML::Form;
use XUpload;
exit if $ENV{REMOTE_ADDR}; # allow only run from console

my $user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/86.0.4240.75 Safari/537.36'; #'Wget/1.13.4 (linux-gnu)'

exit unless $c->{host_max_url};
my @xx = grep {$_!=$$} map{/^\s*(\d+)/;$1} grep{/perl/} `ps ax|grep url_upload.pl`;
print join("\n", @xx),"\n";
print("reached max processes list: $c->{host_max_url}\n"),exit if scalar(@xx)>=$c->{host_max_url};

my $restart;
$SIG{HUP} = sub { $restart=1 };

require Log;
our $log = Log->new(filename=>'url_upload.txt', mute=>1);

require SessionF;
require Plugin;
$Plugin::browser = LWP::UserAgent->new(timeout => 90,
                                       requests_redirectable => ['GET', 'HEAD','POST'],
			                			agent   => $user_agent,
			                			cookie_jar => HTTP::Cookies->new( hide_cookie2 => 1, ignore_discard => 1 ) );


my $ses = SessionF->new();
$ses->LoadPlugins();

my $xua = LWP::UserAgent->new(agent => $c->{user_agent}, timeout => 90);

my ($cx,$fname2,$total_size,$current_bytes,$old_time,$old_size,$queue_id);
while($cx++<1000)
{
   print("Exiting on signal"),exit if $restart;
   sleep(1+$c->{host_max_url}*2);
   my $str = XUpload::postMain(
		                       {
		                       op           => "queue_url_next",
		                       host_id      => $c->{host_id},
		                       }
		                      )->content;

 print $str,"\n";
 $str=~s/\r//g;
 my ($id,$usr_id,$ip,$srv_id,$disk_id,$url,$prem_logins)=split(/\n/,$str);
 print(".\n"),sleep(1),next unless $srv_id=~/^\d+$/ && $disk_id=~/^\d+$/;
 $url=~s/&#39;/'/g;
 $url=~s/&#40;/(/g;
 $url=~s/&#41;/)/g;
 print"$id,$usr_id,$srv_id,$disk_id,$url\n";
 my $u = {url=>$url,file_size=>0,usr_id=>$usr_id,url_queue_id=>$id};
 ($u->{auth_login},$u->{auth_password})=split(':', $prem_logins, 2) if $prem_logins;
 ($u->{auth_login},$u->{auth_password})=($1,$2) if $u->{url}=~s/\/\/(.+?)\:(.+?)\@/\/\//;
 $queue_id = $id;
 my $temp_dir = "$c->{cgi_dir}/temp/$disk_id";

 my $ua = LWP::UserAgent->new(timeout => 120,
                              agent   => $user_agent,
                              cookie_jar => HTTP::Cookies->new( hide_cookie2 => 1, ignore_discard => 1 ) );

 # Try to get file size before starting the download
 if($url!~/^ftp/i && $url=~/\.($c->{video_extensions})$/i)
 {
    my $request  = HTTP::Request->new( HEAD => $url );
    my $uah = LWP::UserAgent->new(timeout => 5);
    my $response = $uah->request( $request );
    $u->{file_size} = $response->content_length;
 }

 # Prevent huge files DDOS
 if($c->{max_upload_filesize_prem} && $u->{file_size} > $c->{max_upload_filesize_prem}*1048576)
 {
    Error($id,"Max filesize limit exceeded!");
    next;
 }

 my ($plugin) = grep { $_->check_link($u->{url}) } @{ $ses->getPlugins() };
 if($plugin)
 {
     unless( $plugin->login({ login => $u->{auth_login}, password => $u->{auth_password} }) )
     {
        Error($id,"Can't login to site!");
        next;
     }
 }

 if($u->{file_error}){ Error($id,$u->{file_error}); next; }

 $fname2='';
 ($total_size,$current_bytes,$old_time)=(0,0,0);
 $u->{file_tmp} = "$temp_dir/".join('', map int rand(10), 1..10);
 $Plugin::tmpfile = $u->{file_tmp};

	if($u->{url}=~/googleapis.com\/drive\/v3\/files\/(.+?)\?/i)
	{
    	my $did=$1;
    	$u->{url_src}="https://drive.google.com/file/d/$did/view";
    	$u->{title_real}="$did.mp4";
	}

 my $resp;
 if($plugin)
 {
     my $ret = $plugin->download($u->{url}, "", \&hook_url);
     #$resp = $ret->{resp};
     use Data::Dumper;
     print Dumper($ret);
     print"Xname:$ret->{filename}\n";
     $u->{file_name_orig} = $ret->{filename};
     $u->{file_descr} = $ret->{descr};
     if($ret->{error}){ Error($id,$ret->{error_text}||$ret->{errortext}); next; }
 }
 elsif(0 && $u->{url}=~/(ok\.ru|clipwatching\.com|xvideos\.com)/i)
 {
 	$fname2=`/usr/local/bin/youtube-dl -e "$u->{url}"`;
 	chomp($fname2);
 	$fname2.='.mp4' if $u->{url}=~/(ok\.ru|clipwatching\.com|xvideos\.com)/i;
 	if($fname2=~/\.($c->{video_extensions})$/i)
 	{
		open FILE, qq[/usr/local/bin/youtube-dl --newline --http-chunk-size=20000M -o $u->{file_tmp} "$u->{url}" 2>&1|]; #--limit-rate 90K
		while(<FILE>)
		{
			if(time>$old_time+5)
  			{
			 $_=~s/\s{2,9}/ /g;
			 my ($perc,$total,$t1,$speed,$s1) = $_=~/([\d\.]+)\% of ~?([\d\.]+)(.iB)\s+at\s+([\d\.]+)(.iB)\/s/i;
			 $total*={'KiB'=>1024, 'MiB'=>1024**2, 'GiB'=>1024**3}->{$t1}||1;
			 $speed*=1024    if $s1 eq 'MiB';
			 my $curr = int $perc*$total/100;
			 $speed = int $speed;
			 #print"($_)[$perc,$total,$t1,$speed,$s1] [$curr of $total, speed=$speed KB/s]\n";
			 XUpload::postMainQuick(
			                       {
			                       op              => "upload_progress",
			                       id              => $queue_id,
			                       size_full       => $total,
			                       size_dl         => $curr,
			                       speed           => $speed,
			                       });
			 $old_time=time;
			}
	  	}
  	}
 }
 else
 {
     open FILE, ">$u->{file_tmp}" || die"Can't open dest file:$!";
     my $req = HTTP::Request->new(GET => $u->{url});
     $req->authorization_basic($u->{auth_login},$u->{auth_password}) if $u->{auth_login} && $u->{auth_password};
     $resp = $ua->request($req, \&hook_url );
     close FILE;
     $u->{file_name_orig}=$1 if $resp->header('Content-Disposition')=~/filename="(.+?)"/i;
 }

 unless($plugin)
 {
     $u->{file_error}="Received HTML page instead of file".$resp->content if $resp && $resp->content_type eq 'text/html' && $u->{url}!~/\.html$/i;
     $u->{file_error}="File download failed:".$resp->status_line if $resp && !$resp->is_success;
 }
 
 if($u->{file_error}){ Error($id,$u->{file_error}); next; }

 $u->{file_size}=-s $u->{file_tmp};
 $u->{file_name_orig}||=$fname2;
 $u->{file_name_orig}=$u->{title_real} if $u->{title_real};
 $u->{file_name_orig}=~s/.+\/(.+)$/$1/;
 $u->{file_name_orig}=~s/\.html?$//i;
 $u->{file_name_orig}=~s/\?\S.*$//;
 $u->{file_name_orig}=~s/\?+//g;
 $u->{file_name_orig}=~s/\/$//g;
 $u->{file_name_orig}=~s/[\n\r]+//g;
 $u->{file_name_orig}||=join('', map int rand(10), 1..5);
 

 my $f = {upload_mode=>'url',
          url_id => $id,
          srv_id=>$srv_id, 
          disk_id=>$disk_id, 
          ip=>$ip};
 #$u->{cat_id} = $cat_id||0;
 #$u->{file_public} = $file_public||0;

 # --------------------
 $XUpload::log = $log;
 my $file = &XUpload::ProcessFile($u,$f);
 # --------------------

 if($file->{file_status})
 {
    Error($id,"FS: $file->{file_status}");
    unlink($file->{file_tmp});
    next;
 }
 else
 {
	my $res = XUpload::postMain({
									op     => "queue_url_done",
									id     => $file->{url_queue_id},
								}
								);
	print"delq: ".$res->content."\n";
 }
 sleep 2;
}

#########################
sub hook_url
{
  my ($buffer,$res) = @_;
  print FILE $buffer;
  $current_bytes+=length($buffer);
  
  if(time>$old_time+10)
  {
     $total_size ||= $res->content_length;
     $fname2 ||= $res->base;
     my $speed_kb = sprintf("%.0f", ($current_bytes-$old_size)/1024/(time-$old_time) );
     $old_time = time;
     $old_size = $current_bytes;
     XUpload::postMainQuick(
	                       {
	                       op              => "upload_progress",
	                       id              => $queue_id,
	                       size_full       => $total_size,
	                       size_dl         => $current_bytes,
	                       speed           => $speed_kb,
	                       });
  }
}
#########################

sub logit
{
   my $msg = shift;
   open(FILE,">>url_upload.log") || return;
   print FILE "$msg\n";
   close FILE;
}

sub Error
{
	my ($id,$error) = @_;
	print"ERROR:$error\n";
	XUpload::postMain(
					{
					op     => "upload_error",
					id     => $id,
					error  => $error,
					}
					);
}

