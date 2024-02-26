package Plugins::sendspace;

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
		plugin_id => 1027,
		plugin_prefix=>'ss',
		domain=>'sendspace.com',
		name=>'sendspace',
		can_login => 1,
		upload=>1,
		download=>1,
};

sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /sendspace\.com/) {
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
my $base = 'http://www.sendspace.com';
sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';
	$self->{account} = $a;
	$self->get('http://www.sendspace.com/');
	my $req = POST "http://www.sendspace.com/login.html",
	        Referer => 'http://www.sendspace.com/',
       		Content => [action=>'login',submit=>'login',action_type=>'login',target=>'%252F',username=>$a->{login}, password=>$a->{password}];
	my $r = $self->request($req);
	if(($r->is_success) || ($r->code == 302)) {
		my $content = $self->{content};
		return 0 if($content =~ /No such username or wrong password/);
		return 1;

	} else {
		return 0;
	}
	return 1;
	
	return 1;
}


sub upload_file {
	my $self = shift;
	my $file = shift;
	my $filename = shift;
	my $description = shift;
	$self->{action} = 'upload';
	my $h = $self->getHT('http://sendspace.com');
	my $form = $h->look_down('_tag', 'form', 'enctype',"multipart/form-data");
	my @inputs = $form->look_down('_tag', 'input');
	my %pcontent;
	foreach my $i(@inputs) {
	             $pcontent{$i->{name}} = $i->{value} if($i && $i->{name} && $i->{value});
	}
	$pcontent{'upload_file[]'} = ["$c->{filesdir}/$file", $filename];
	$pcontent{'js_enabled'} = 1;
	$pcontent{'file[]'} = '';
	my $action = $form->{action};
	my $req = POST $action,
		Content_Type => "multipart/form-data",
        	Content => [	
			%pcontent
			];
		$self->up_file($req);
		unless($self->{content} =~ m~class="share link">([^\<]+)~s){ 
			return {error=>1, errortext=>'Cannot upload'};
		}
		my $link = $1;
		my $remove = '';
		return {download=>$link, remove=>$remove};
		
	
}
sub GRC {
	my $self = shift;
	my $length=32;
	my @letters=('a'..'f','k'..'o', 'u','p','q','r', 's','t','v','x','1'..'0');
	my $s = '';
	my $lettersLength = scalar(@letters);
	for(my $i = 0 ; $i < $length ; $i++) {
		$s.= $letters[int rand($lettersLength)];
	}
	return $s;
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
		$self->get($url);
		my $dlink = '';
		if($self->{content} =~ m~id="download_button" href=\"([^\"]+)~s) {
				$dlink = $1;
		} else {
				return {error=>-2, error_text=>'Cannot download direct link'};
		}
		$dlink = 'http://www.sendspace.com'.$dlink unless($dlink =~ m~http://~);
		$req = GET $dlink,Referer=>$url;
		$ff = $self->direct_download($req, $url, $prefix, $update_stat);
		return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}} unless($ff->{type}=~ /html/);
		
	}
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};
	

}

1;
