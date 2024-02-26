package Plugins::turbobit;

use strict;
use warnings;
use lib '..';
use Plugin;
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use vars qw($VERSION);
$VERSION = "1.6" ;

our $options = {
		plugin_id => 1016,
		plugin_prefix=>'tb',
		domain=>'turbobit.net',
		name=>'turbobit',
		can_login=>1,
		required_login=>1,
		upload=>1,
		download=>1,
};


sub max_filesize {
	return 400*1024*1024;
}

sub is_broken {
	my $self = shift;
	my $link = shift;
	$self->get($link);
	return 1 if($self->{content} =~ /This file is either removed due to copyright claim or is deleted by the uploader/);
	return 0;
}

sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /turbobit\.net/) {
		return 1;
	}
	return 0;
}

sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';

	$self->get('http://turbobit.net/');
	my $req = POST "http://turbobit.net//user/login",
	        Referer => "http://turbobit.net/",
	       	Content => ['user[login]'=>$a->{login}, 'user[pass]'=>$a->{password}, returnto=>'/'];	
	$self->request($req);
	if(($self->{response}->is_success) || ($self->{response}->code == 302)) {
		$self->get('http://turbobit.net/?cookiecheck=1');
		return 0 if($self->{content} =~ /Не верный логин/);	
		return 1;

	} else {
		return 0;
	}
	return 1;
}
sub upload_file {
	my $self = shift;
	my $file = shift;
	my $filename = shift;
	my $description = shift;
	$self->{action} = 'upload';
	$self->get('http://turbobit.net/');
	if(($self->{response}->is_success)) {
		$self->{content} =~ /&urlSite=(http[^\&\"\']+)/;
		my $upload_url = $1;
		$self->{content} =~ /&userId=([^\&\"\']+)/;
		my $user_id0 = $1;
		$browser->agent('Shockwave Flash');
		my $req = POST $upload_url,
			Content_Type => "multipart/form-data",
	        	Content => [Filename=>$filename, apptype=>'fd2', stype=>'null', id=>'null', user_id=>$user_id0, Filedata=>["$c->{filesdir}/$file", $filename], 'Upload'=>'Submit Query'];
		$self->up_file($req);
		unless($self->{content} =~ m~"result":true~s) {
			return {error=>1, errortext=>'Cannot upload'};
		}
#		print $self->{content}, "\n";
		$self->{content} =~ /\"id\":\"([^\"]*)/;
		my $link = 'http://turbobit.net/'.$1.'.html';
		my $remove = '';
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
	$self->get($url);
	($dlink) = $self->{content} =~ m~(http://turbobit.net//?download[^\'\"]*)~s;
	if($dlink) {
		$req = GET $dlink;
#		print STDERR "req0:".$req->as_string;
		my $ff = $self->direct_download($req, $dlink, $prefix, $update_stat);
		$log->write(2, 'type:'.$ff->{type});
		if($ff->{type} =~ /html/) {
			return {error=>-2, error_text=>'Cannot download direct link'};
		}
		return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};
	} else {
		return {error=>-4, error_text=>'Cannot get direct link'};
	}

}
1;
