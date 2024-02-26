package Plugins::zippyshare;

use strict;
use warnings;
use lib '..';
use lib '../Modules';
use Plugin;
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use MIME::Base64;
use XML::Simple;
use Data::Dumper;
use vars qw($VERSION);

$VERSION = "1.6" ;

our $options = {
		plugin_id => 1033,
		plugin_prefix=>'zp',
		domain=>'zippyshare.com',
		name=>'zippyshare',
		required_login=>1,
		can_login => 1,
		upload=>1,
		download=>1,
};

sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /zippyshare\.com/) {
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
	return 200*1024*1024;
}
sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';
	my $req = GET 'http://www.zippyshare.com/';
	$self->request($req);
#	$base = $self->{response}->base();
	
	$req = POST "http://www.zippyshare.com/services/login",
		Referer => "http://www.zippyshare.com/",
		Content => [login=>$a->{login}, pass=>$a->{password}];	
	$self->request($req);
	$self->{account} = $a;
#	if(($self->{response}->is_success) || ($self->{response}->code == 302)) {
#		return 0 if($self->{content} =~ /No user found with such email/);
#		return 0 if($self->{content} =~ /Login failed/);
#		return 1;
#	} else {
#		return 0;
#	}
}


sub upload_file {
	my $self = shift;
	my $file = shift;
	my $filename = shift;
	my $description = shift;
	$self->{action} = 'upload';
	my $h = $self->getHT('http://www.zippyshare.com/');
#	my $form = $h->look_down('_tag', 'form', 'name', 'upload_form2');
#	my $action = $form->{action};
#	my $token = $form->look_down('_tag','input', 'name', 'token');
	my ($up_id) = $self->{content} =~ /var uploadId = '([A-Z0-9]+)/s;#'
	my ($action) = $self->{content} =~ /enctype="multipart\/form-data" action="([^\"]+)"/s;
	my $req = POST $action,
		Content_Type => "multipart/form-data",
	       	Content => ['file1'=>'',uploadId=>$up_id,'fupload'=>["$c->{filesdir}/$file", $filename], terms=>1];
	$self->up_file($req);
	my $remove = '';
	my $link = '';
        $h = HTML::TreeBuilder->new_from_content($self->{content});
        $h->ignore_unknown(0);
        $h = $h->elementify();
	my $links = $h->look_down('_tag', 'textarea', 'id', 'plain-links');
	if($links) {
		$link = $links->as_text();
		$link =~ s/[\r\n]//g;
	}
	$h = $h->delete();
	return {download=>$link, remove=>$remove};
		
	
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
		$self->request($req);
		my $ourl = $url;
		my ($n) = $self->{content} =~ m~var n = (\d+)~;
		my ($b) = $self->{content} =~ m~var b = (\d+)~;
		my ($a, $z) = $self->{content} =~ /'dlbutton'\).href = "([^\"]+)"[^\"]+"([^\"]+)"/;
		$url =~ m~(http://[^/]+)~;
		my $dlink = $1.$a.int($n+$n*2+$b).$z;
		$req = GET $dlink;
		print STDERR "dlink:", $dlink;
		my $ff = $self->direct_download($req, $url, $prefix, $update_stat);
		if($ff->{type} =~ /html/) {
			return {error=>-2, error_text=>'Cannot download direct link'};
		} 
	}
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};
	

}

1;
