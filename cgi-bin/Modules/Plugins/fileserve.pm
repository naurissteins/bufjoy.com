package Plugins::fileserve;

use strict;
use warnings;
use lib '..';
use lib '../Modules/';
use Plugin;                                                                                                                                                                      
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use Data::Dumper;
use vars qw($VERSION);

our $options = {
		plugin_id => 1009,
		plugin_prefix=>'fv',
		domain=>'fileserve.com',
		name=>'fileserve',
		required_login=>1,
		can_login=>1,
		upload=>1,
		download=>1,
};

sub check_link {
	shift;                                                                                                                                                                       
	my $link = shift;                                                                                                                                                            
	if ($link =~ /fileserve\.com/) {                                                                                                                                          
		return 1;                                                                                                                                                                
	}                                                                                                                                                                            
	return 0; 
}

sub is_broken {
	my $self = shift;
	my $link = shift;
	$self->get($link);
	return 1 if($self->{content} =~ /File not available/);
	return 0;
}

sub max_filesize {
	return 1048*1024*1024;
}


sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';
	$self->get('http://fileserve.com/');
	my $req = POST "http://fileserve.com/login.php",
	        Referer => 'http://fileserve.com/',
       	Content => [loginUserName=>$a->{login}, loginUserPassword=>$a->{password}, loginFormSubmit=>'Login'];
	my $r = $self->request($req);
	
	if(($r->is_success) || ($r->code == 302)) {
		$self->get('http://fileserve.com/dashboard.php');
		my $content = $r->as_string();
		return 0 if($content =~ /Ââåäåí íåïðàâèëüíûé email èëè ïàðîëü/);
		return 0 if($content =~ /Ð’Ð²ÐµÐ´ÐµÐ½ Ð½ÐµÐ¿Ñ€Ð°Ð²Ð¸Ð»ÑŒÐ½Ñ‹Ð¹ email Ð¸Ð»Ð¸ Ð¿Ð°Ñ€Ð¾Ð»ÑŒ/);
		return 0 if($content =~ /captcha/);
		$self->{last_account} = $a;
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
	my $h = $self->getHT('http://fileserve.com');
	my $form = $h->look_down('_tag', 'form', 'id',"uploadForm");
	unless($form) {
		return {error=>1, errortext=>'Cannot upload'};
	}
	my $action = $form->{action};
	$self->get($action.'?callback=jsonp1318320389467&_=1318320436586');
	my ($sess_id) = $self->{content} =~ /sessionId:'([^']+)\'/;	
	my $req = POST $action.$sess_id,
		Content_Type => "multipart/form-data",
		Content=>[file=>["$c->{filesdir}/$file", $filename]];
	$self->up_file($req);
	my $download = '';
	if($self->{content} =~ /\"shortenCode\":\"([^\"]+)/) {
		my $sc = $1;
		$download = 'http://fileserve.com/file/'.$sc.'/'.$filename;
	};
	return {download=>$download, remove=>''};
	
}

sub download {
	my $self = shift;
	my $url = shift;
	my $prefix = shift;
	my $update_stat = shift;
	my $req = GET $url;
	my $response;
	my $dlink = '';
	$self->{action} = 'download';
	
	my $ff = $self->direct_download($req, $url, $prefix, $update_stat);
	$log->write(2, 'type:'.$ff->{type});
	if($ff->{type} =~ /html/) {#direct download don't enable or user not premium
		my $r = $self->get($url);
		return {error=>1, errortext=>'Cannot get download link'}
	}
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};

}
1;
