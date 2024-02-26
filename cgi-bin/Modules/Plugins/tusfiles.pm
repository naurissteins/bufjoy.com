package Plugins::tusfiles;

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

$VERSION = "1.0" ;

our $options = {
		plugin_id => 1035,
		plugin_prefix=>'tf',
		domain=>'tusfiles.net',
		name=>'tusfiles',
		can_login => 1,
		upload=>1,
		download=>1,
};

sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /tusfiles\.net/) {
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
	return 1024*1024*1024;
}
sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';

	$self->get('http://www.tusfiles.net/login.html');
	my $req = POST "http://www.tusfiles.net/",
	        Referer => "http://www.tusfiles.net/login.html",
	       	Content => [op=>'login','login'=>$a->{login}, 'password'=>$a->{password}, returnto=>'/'];
	$self->request($req);
	if(($self->{response}->is_success) || ($self->{response}->code == 302)) {
		return 0 if($self->{content} =~ /Incorrect Login or Password/);	
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
	my $h = $self->getHT('http://www.tusfiles.net');
	my $form = $h->look_down('_tag', 'form', 'enctype'=>"multipart/form-data");
	my @inputs = $form->look_down('_tag', 'input', 'name', qr(^.+$));
	my %data = map {$_->{name}=>$_->{value}}@inputs;;
	print STDERR Dumper(\%data);	
	my ($action) = $form->{action};
	my $up_id = '';
	for(my $i=0;$i<12;$i++) {
		$up_id.=int(rand(10));
	}
	$data{'file_0'} = ["$c->{filesdir}/$file", $filename];
	$data{tos} = 1;
	my $req = POST $action.$up_id,
		Content_Type => "multipart/form-data",
	       	Content => \%data;
	$self->up_file($req);
	my $remove = '';
	my $link = '';
	if($self->{content} =~ /not enough disk space on your account/) {
        	return {error=>1, errortext=>'Not enough disk space on your account'}

	}
        $h = HTML::TreeBuilder->new_from_content($self->{content});
        $h->ignore_unknown(0);
        $h = $h->elementify();
	my $links = $h->look_down('_tag', 'input', 'id',qr(^ic0-\d*));
#	print STDERR 
	if($links) {
		$link = $links->{value};
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
		my $h = $self->requestHT($req);
		my $form = $h->look_down('_tag', 'form', 'name','F1');
		my @inputs = $form->look_down('_tag', 'input', 'name', qr(^.+$));
		my %data = map {$_->{name}=>$_->{value}}@inputs;;
		print Dumper(\%data);
		my $req = POST $url,
			Content=>\%data;
		my $ff = $self->direct_download($req, $url, $prefix, $update_stat);
		if($ff->{type} =~ /html/) {
			return {error=>-2, error_text=>'Cannot download direct link'};
		} 
	}
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};
	

}

1;
