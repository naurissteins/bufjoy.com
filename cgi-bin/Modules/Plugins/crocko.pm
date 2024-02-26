package Plugins::crocko;

use strict;
use warnings;
use lib '..';
use Plugin;                                                                                                                                                                      
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use XML::Simple;
use Data::Dumper;
use vars qw($VERSION);

$VERSION = "1.6" ;

our $options = {
		plugin_id => 1029,
		plugin_prefix=>'cr',
		domain=>'crocko.com',
		name=>'crocko',
		required_login=>1,
		can_login => 1,
		upload=>1,
		download=>1,
};

sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /crocko\.com/) {
		return 1;
	}
	return 0;
}

sub is_broken {
	my $self = shift;
	my $link = shift;
	$self->get($link);
	return 1 if($self->{content} =~ /this file has been removed/);
	return 0;
}

sub max_filesize {
	return 2048*1024*1024;
}
sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';
	my $req = GET 'http://crocko.com/';
	$self->request($req);
#	$base = $self->{response}->base();
	
	$req = POST "http://crocko.com/accounts/login",
	        Referer => "http://crocko.com",
	       	Content => [login=>$a->{login}, password=>$a->{password}];	
	$self->request($req);
	$self->{account} = $a;
	if(($self->{response}->is_success) || ($self->{response}->code == 302)) {
		return 0 if($self->{content} =~ /No user found with such email/);
		return 0 if($self->{content} =~ /Login failed/);
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
	my $req = POST 'http://api.crocko.com/apikeys',Content=>[login=>$self->{account}->{login}, password=>$self->{account}->{password}];
	$self->request($req);
	my $x = XMLin($self->{content});
	my $apikey = $x->{entry}->{content}->{content};
	if($apikey) {
		my $req = POST 'http://api.crocko.com/files',
			Authorization=>$apikey,
			Content_Type => "multipart/form-data",
	        	Content => [upload=>["$c->{filesdir}/$file", $filename]];
		$self->up_file($req);
		$x = XMLin($self->{content});
		my $remove = '';
		my $link = $x->{entry}->{link}->[0]->{href};
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
	if($ff->{type} =~ /html/) {
		return {error=>-2, error_text=>'Cannot download direct link'};
	}
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};
	

}

1;
