package Plugins::netload;

use strict;
use warnings;
use lib '..';
use Plugin;                                                                                                                                                                      
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use Data::Dumper;
use vars qw($VERSION);

$VERSION = "1.6" ;

our $options = {
		plugin_id => 1028,
		plugin_prefix=>'nl',
		domain=>'netload.in',
		name=>'netload',
		can_login => 1,
		upload=>1,
		download=>1,
};

sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /netload\.in/) {
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
my $base = 'http://www.netload.in';
sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';
	my $req = GET 'http://netload.in/';
	$self->request($req);
	$base = $self->{response}->base();
	
	$req = POST "${base}/index.php",
	        Referer => "http://netload.in",
	       	Content => [txtuser=>$a->{login}, txtpass=>$a->{password}, txtcheck=>'login', txtlogin=>'Login'];	
	$self->request($req);
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
	my $h = $self->getHT('http://netload.in/');
	if(($self->{response}->is_success)) {
		my $form = $h->look_down('_tag', 'form', 'name',"simple_upload");
		unless($form) {
			return {error=>1, errortext=>'Cannot upload'};		
		}
		my $action = $form->{action};
		my @inputs = $form->look_down('_tag', 'input');
		
		my %pcontent = map {$_->{name}=>$_->{value}} grep {$_->{name}}@inputs;
		$pcontent{'file'} = ["$c->{filesdir}/$file", $filename];
		my $req = POST $action,
	        	Referer => "http://netload.in/",
			Content_Type => "multipart/form-data",
	        	Content => \%pcontent;
		$self->up_file($req);
		my $remove = '';
		my $link = '';
		if($self->{content} =~ m~The download link is:.*?href\=[\"\'](http://netload.in/[^\"\']+)~s){ 
			$link = $1;
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
	if($ff->{type} =~ /html/) {
		return {error=>-2, error_text=>'Cannot download direct link'};
	}
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};
	

}

1;
