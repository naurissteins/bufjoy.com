package Plugins::mediafire;

use strict;
use warnings;
use lib '..';
use Plugin;                                                                                                                                                                      
use XML::Simple;
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use Data::Dumper;
use vars qw($VERSION);

$VERSION = "1.6" ;

our $options = {
		plugin_id => 1014,
		plugin_prefix=>'mf',
		domain=>'mediafire.com',
		name=>'mediafire',
		required_login=>1,
		can_login => 1,
		upload=>1,
		download=>1,
};

sub is_broken {
	my $self = shift;
	my $link = shift;
	$self->get($link);
	return 1 if($self->{content} =~ /Invalid or Deleted File/);
	return 0;
}

sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /mediafire\.com/) {
		return 1;
	}
	return 0;
}

sub max_filesize {
	return 1024*1024*1024;
}

sub login {
	my $self = shift;
	$self->{action} = 'login';
	my $a = shift;
	$self->get('http://mediafire.com/');
	my $req = POST 'http://mediafire.com/dynamic/login.php',
		Content =>[login_email=>$a->{login}, login_pass=>$a->{password}];
	$self->request($req);
	
	return 1;
}

	

sub upload_file {
	my $self = shift;
	my $file = shift;
	my $filename = shift;
	my $description = shift;
	$self->{action} = 'upload';
	my $configurl = 'http://www.mediafire.com/basicapi/uploaderconfiguration.php?'.int(rand 100000);
	my $req = GET $configurl, Referer=>'http://www.mediafire.com/myfiles.php';

	$self->request($req);
	if(($self->{response}->is_success)) {
		my $conf = XMLin($self->{content});
#		my $action = sprintf('http://www.mediafire.com/douploadtoapi/?track=%s&ukey=%s&user=%s&uploadkey=%s&filenum=0&uploader=0&MFULConfig=%s',
#		$conf->{config}->{trackkey},$conf->{config}->{ukey},$conf->{config}->{user},$conf->{config}->{folderkey}, $conf->{MFULConfig}
#		);
		my $action = sprintf('http://www.mediafire.com/douploadtoapi/?track=%s&ukey=%s&user=%s&uploadkey=%s&upload=0',
		$conf->{config}->{trackkey},$conf->{config}->{ukey},$conf->{config}->{user},$conf->{config}->{folderkey}
		);
		print STDERR $action;
		my $size = -s "$c->{filesdir}/$file";
		my $size0 = $size;
#		open FD, "< $c->{filesdir}/$file";
#		binmode FD;
#		my $rd = sub {read(FD, my $buf, 655535);return $buf;};

#		$req = HTTP::Request->new("POST",$action, [
		$req = POST $action,
#			'Content-Length'=>-s "$c->{filesdir}/$file",
#			Content_Type => "application/octet-stream",
			'X-Filename'=>$filename,
			'X-Filesize'=>$size0,
			Content_Type => "multipart/form-data",
			Referer=>$configurl,
	        	Content => [Filename=>$filename, Filedata=>["$c->{filesdir}/$file", $filename], 'Upload'=>'Submit Query'];
#		]
#		$req->header('X-Filename',$filename);
#		$req->header('X-Filesize',$size0);

		$self->up_file($req);
		my $res = XMLin($self->{content});
		my $key = $res->{doupload}->{key};
		my $try = 4;
		my $link = '';
		my $remove = '';
		while ($try) {
			sleep(4);
			$self->get(sprintf "http://www.mediafire.com/basicapi/pollupload.php?key=%s&MFULConfig=%s", $key, $conf->{MFULConfig});
			$res = XMLin($self->{content});
			if($res->{doupload}->{status}!=6) {
				$link = 'http://www.mediafire.com/?'.$res->{doupload}->{quickkey};
				last ;
			}
			$try--;
		}	
		return {download=>$link, remove=>$remove};
		
	}
}

sub download {
	my $self = shift;
	my $url = shift;
	my $prefix = shift;
	my $update_stat = shift;
	my $req;
	my $response;
	my $dlink = '';
	$self->{action} = 'download';
	$req = GET $url;
	my $ff = $self->direct_download($req, $url, $prefix, $update_stat);
	$log->write(2, 'type:'.$ff->{type});
	if($ff->{type} =~ /html/) {#direct download don't enable or user not premium
		$self->get($url);
		return {error=>-2, error_text=>'Cannot download direct link'};
	}
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};

}

1;
