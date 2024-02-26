#!/usr/bin/perl
### SibSoft.net ###
use strict;
use lib '.';
use XFSConfig;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use LWP::UserAgent;
use JSON;

my $MAX_FILES_IN_TORRENT = 256; # avoid huge torrents with many small files

print("Content-type:text/html\n\nXFS"),exit if $ENV{QUERY_STRING}=~/mode=test/;

$c->{max_upload_filesize} = $c->{max_upload_filesize_prem};

backToMyTorrents("Torrent mod disabled on this site") unless $c->{m_t};

my $cg = CGI->new();

#########################

my $f;
$f->{$_}=$cg->param($_) for $cg->param();
$f->{ip} = &GetIP();

TorrentUpload();

sub parseTorrent
{
    require BitTorrent;
    my $bt = BitTorrent->new();
    my $tt = $bt->getTrackerInfo($_[0]);

    my ($over,@files);
    foreach my $ff ( @{$tt->{files}} )
    {
        next if $ff->{name}=~/padding_file/;
        $over=1 if $ff->{size} > $c->{max_upload_filesize}*1048576;
        #$files.="$ff->{name}:$ff->{size}\n";
        #push @files, qq[{"path":"$ff->{name}","size":$ff->{size}}];
        push @files, {"name"=>"$ff->{name}", "size"=>$ff->{size}};
    }

    backToMyTorrents("One or more files in torrent exceed filesize limit of $c->{max_upload_filesize} Mb") if $c->{max_upload_filesize} && $over;
    backToMyTorrents("Too many files > $MAX_FILES_IN_TORRENT") if @files > $MAX_FILES_IN_TORRENT;
    return ( $tt->{hash}, \@files );
}

sub TorrentUpload
{
    require TransmissionRPC;
    require File::Slurp;
    require MIME::Base64;

    my $ua = LWP::UserAgent->new(agent => $c->{user_agent},timeout => 360);
    my $rpc = TransmissionRPC->new($c->{transmission_endpoint} || 'http://127.0.0.1:9091/transmission/rpc/');

    my ($hash,$files);
    ($hash,$files) = parseTorrent($cg->tmpFileName($f->{file_0})) if $f->{file_0};
    $hash = lc($1) if $f->{magnet} =~ /btih:([0-9a-zA-Z]+)/;

    my $is_online = eval { $rpc->request('session-get', {}) };

    if(!$is_online) {
       print "Location: $c->{site_url}/?op=upload_result&st=Torrent%20engine%20is%20not%20running&fn=undef\n";
       print "Status: 302\n\n;";
       exit;
    }

    my @extras;
    push @extras, "$_=$f->{$_}" for grep{/^extra_/ && $f->{$_}} keys %$f;
    push @extras, "$_=$f->{$_}" for grep{$f->{$_}} ('cat_id','file_public','file_adult','tags','fld_id');

    # We have to add a torrent into database before pushing it to torrent client
    # to keep transmission-watcher integrity checks happy
    my $res = $ua->post("$c->{site_cgi}/fs.cgi", {
				        op			=> 'add_torrent',
				        dl_key		=> $c->{dl_key},
				        host_id		=> $c->{host_id},
				        sid			=> $hash,
				        sess_id		=> $f->{sess_id},
				        extras		=> join("\n",@extras),
    });

    backToMyTorrents("<b>Error while adding torrent to DB:</b><br>" . $res->decoded_content) if $res->decoded_content !~ /^OK/i;
    my ($extra)=$res->content=~/^OK:(.+)/;
    my $dd = JSON::decode_json($extra);
    #use Data::Dumper;

    # https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt
    my $res = $rpc->request('torrent-add', {
       'filename' => $f->{file_0} ? $cg->tmpFileName($f->{file_0}) : $f->{magnet},
       'download-dir' => "$c->{cgi_dir}/Torrents/workdir/$hash/",
       #"files-unwanted" => [2,3],
    });
    my $id = $res->{'arguments'}->{'torrent-added'}->{'id'};

    $dd->{downloadLimited} = \1;
    $dd->{uploadLimited}   = \1;
    $dd->{downloadLimit} = int $dd->{downloadLimit};
    $dd->{uploadLimit}   = int $dd->{uploadLimit};
    $dd->{'peer-limit'}  = int $dd->{'peer-limit'};
    $id = int $id;

    my $res = $rpc->request('torrent-set', {
    	'ids' => [$id],
    	%$dd
    }) if keys %$dd;

    backToMyTorrents("");
}

####################################################################################################################################

sub logit
{
   my $msg = shift;
   return unless $c->{uploads_log};
   my @t = &getTime;
   open(FILE,">>$c->{uploads_log}") || return;
   print FILE &GetIP." $t[0]-$t[1]-$t[2] $t[3]:$t[4]:$t[5] $msg\n";
   close FILE;
}

sub getTime
{
    my @t = localtime();
    return ( sprintf("%04d",$t[5]+1900),
             sprintf("%02d",$t[4]+1), 
             sprintf("%02d",$t[3]), 
             sprintf("%02d",$t[2]), 
             sprintf("%02d",$t[1]), 
             sprintf("%02d",$t[0]) 
           );
}

sub GetIP
{
 return $ENV{HTTP_X_FORWARDED_FOR} || $ENV{HTTP_X_REAL_IP} || $ENV{REMOTE_ADDR};
}

sub backToMyTorrents
{
   my ($msg) = @_;
   print"Content-type:text/html\n\n";
   print qq[<html><body onload="document.F1.submit()"><form name="F1" action="$c->{site_url}/" method="GET" style="display:none">
            <input type="hidden" name="op" value="my_torrents">
            <input type="hidden" name="msg" value="$msg">
            </form></body></html>];
   exit;
}

