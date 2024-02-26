package Plugins::uploaded;

use strict;
use warnings;
use lib '..';
use Plugin;                                                                                                                                                                      
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use vars qw($VERSION);
$VERSION = "1.6" ;


our $options ={
		plugin_id => 1007,
		plugin_prefix=>'ul',
		domain=>'uploaded.net',
		name=>'uploaded',
		required_login=>1,
		can_login => 1,
		upload=>1,
		download=>1,
};

sub max_filesize {
	return 1000*1024*1024;
}

sub is_broken {
	my $self = shift;
	my $link = shift;
	$self->get($link);
	return 1 if($self->{content} =~ /Page not found/);
	return 0;
}


sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /uploaded\.to/ || $link =~ /ul\.to/ || $link =~ /uploaded\.net/) {
		return 1;
	}
	return 0;
}
my $usr = '';
sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';
	$self->get('http://uploaded.net/');
	my $req = POST "http://uploaded.net/io/login",
	        Referer => 'http://uploaded.net/',
       	Content => [id=>$a->{login}, pw=>$a->{password}];
	$self->request($req);
	if(($self->{response}->is_success) || ($self->{response}->code == 302)) {
		return 0 if($self->{content} =~ /User and password do not match/);
print $self->{response}->as_string."\n";
		$self->get('http://uploaded.net/me');
		$usr = $a->{login};
		return 1;

	} else {
		return 0;
	}
}

sub upload_file {
	my $self = shift;
	my $file = shift;
	my $filename = shift;
	my $description = shift;
	$self->{action} = 'upload';
	my $r = $self->get('http://uploaded.net/me');
	if(($r->is_success)) {
		my $user_pw = '';
		if($self->{content} =~ /id="user_pw" value="([a-z0-9]+)"/) {
			$user_pw = $1;
		}
		my $req = GET 'http://uploaded.net/js/script.js', Referer=> 'http://uploaded.net';
		$self->request($req);
		unless($self->{content} =~ /uploadServer = \'([^\']+)/) {
			return {error=>1, errortext=>'Cannot upload'};
		}
		my $upload_server = $1;
		$log->write(2, "ups: $upload_server");
		my $action = $upload_server.'upload?admincode='.$self->generate(6);
		if($user_pw) {
			$action.='&id='.$usr.'&pw=' . $user_pw;
		}
		$log->write(2, $action);
		$req = POST $action,
			Content_Type => "multipart/form-data",
	        	Content => [Filename=>$filename, Filedata=>["$c->{filesdir}/$file", $filename], Upload=>'Submit Query'];
		$self->up_file($req);
		$self->{response}->content =~ m~([a-z0-9]*?),~i;
		my $link = 'http://ul.to/'.$1;

		return {download=>$link, remove=>''};
		
	}
	
}
sub generate {
	my $self = shift;
	my $len = shift;
	my $pwd = '';
	my @con = ('b','c','d','f','g','h','j','k','l','m','n','p','r','s','t','v','w','x','y','z');
	my @voc = ('a','e','i','o','u'); 
	for(my $i=0; $i < int($len/2); $i++) {
		my $c = int(rand(1000)%20);
		my $v =  int(rand(1000)%5);
		$pwd.=$con[$c].$voc[$v];
	}
	return $pwd;
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
#	$self->request($req);
	my $ff = $self->direct_download($req, $url, $prefix, $update_stat);
	if($ff->{type} =~ /html/) {
		return {error=>-2, error_text=>'Cannot download direct link'};
	}
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};

}

1;
