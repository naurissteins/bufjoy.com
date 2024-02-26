package Plugins::depositfiles;

use strict;
use warnings;
use lib '..';
use lib '../Modules/';
use Plugin;
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use MIME::Base64;
use URI::Escape;
use Data::Dumper;
use vars qw($VERSION);

our $options = {
		plugin_id => 1000,
		plugin_prefix=>'df',
		domain=>'depositfiles.com',
		name=>'depositfiles',
		can_login=>1,
		upload=>1,
		download=>1,
		signature=>'',
};

sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /depositfiles\.com/) {
		return 1;
	}
	return 0; 
}

sub is_broken {
	my $self = shift;
	my $link = shift;
	$self->get($link);
	return 1 if($self->{content} =~ /Such file does not exist/);
	return 0;
}
sub max_filesize {
	return 2048*1024*1024;
}

sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';
#	$browser->agent('Mozilla/5.0 (Windows; U; Windows NT 5.1; ru; rv:1.8.1.20) DepositFiles/FileManager 0.9.9.206 ');
#	$self->get('http://depositfiles.com/');
	my $req = POST "http://depositfiles.com/login.php?return=%2F",
	        Referer => "http://depositfiles.com/",
        	Content => [go=>1,login=>$a->{login}, password=>$a->{password}];
	$req->header('Accept', 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
	$req->header('Accept-Language','en-us,en;q=0.5');

	$self->request($req);
	if(($self->{response}->is_success) || ($self->{response}->code == 302)) {
		return 0 if($self->{content} && $self->{content} =~ /Your password or login is incorrect/ );
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
	$self->get('http://depositfiles.com/es/');
	if(($self->{response}->is_success)) {
		my $h = HTML::TreeBuilder->new_from_content($self->{content});
		$h->ignore_unknown(0);
		$h = $h->elementify();		
		my $form = $h->look_down('_tag', 'form', 'id', 'upload_form');
		my @inputs = $form->look_down('_tag', 'input');
		my ($ssid);
		my $a = '1234567890qwertyuiopasdfghjklzxcvbnm';
		my @a = split('', $a);
		for(my $i=0;$i<32;$i++) {
			$ssid.=$a[int rand scalar(@a)];
		}
		my %pcontent = map {$_->{name}=>$_->{value} } grep {$_->{name}}@inputs;
		$pcontent{agree} = 1;
		$pcontent{email} = '';
		$pcontent{padding} = '';
		$pcontent{files} = ["$c->{filesdir}/$file", $filename];
		$pcontent{UPLOAD_IDENTIFIER} = time.$ssid;
		$form->{action} =~ s/s-ID=.*/s-ID=$pcontent{UPLOAD_IDENTIFIER}/;
		$form->{action} =~ m~://([^\/]+)~;
		$self->get('http://'.$1.'/ajax/callbacker.htm?url='.uri_escape($form->{action}).'&callback=every_func_ajax_callback&domain=depositfiles.com');
		my $req = POST $form->{action},
			Referer => 'http://'.$1.'/ajax/callbacker.htm?url='.uri_escape($form->{action}).'&callback=every_func_ajax_callback&domain=depositfiles.com',
			Content_Type => "multipart/form-data",
			Content => \%pcontent;
		$self->up_file($req);
		unless($self->{content} =~ /parent.ud_download_url\s*?\=\s*?'(.*?)'/s) {
			return {error=>1, errortext=>'Cannot upload'};
		}
		my $link = $1;
		$self->{content} =~ /parent.ud_delete_url\s*?\=\s*?'(.*?)'/s;
		my $remove = $1;
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
	$url =~ s~\.com\/.*?\/?files~.com\/ru\/files~;
	$response = $self->get($url);
	unless ($response->is_success) {
		$log->write(2, $response->status_line);
		return {error=>1, error_text =>'Cannot get direct link'};
	}
	my $content = $response->content;
	if($content =~ /id\=\"download_url.*?href=\"([^\"]*?)\"/s) {
		$dlink = $1;
	} else {
		unless ($content =~ /\<div class\="downloadblock"\>/s) {
			$log->write(2, "Cannot find first form");
			return {error=>1, error_text=>'Cannot get direct link'};
		}
		my $action = $1;
		$log->write(2, "action: $action");
#		$action = 'http://depositfiles.com'.$action unless($action =~ m|http://|);
		$action = $url;
		$req = POST $action,
			Referer=>$url,
			Content => [gateway_result=>1];
		$response = $self->request($req);
		unless($response->is_success) {
			$log->write(2, "First POST error");
			$log->write(2, $response->status_line);
			return {error=>1, error_text=>'Cannot get direct link'};
		}
		$content = $response->content;
		if($content =~ /(get_file.php\?fid\=[a-z0-9]+)/s) {
			my $link = 'http://depositfiles.com/'.$1;
			$log->write(2, 'wait for 60 seconds');
			sleep(60);
			$req = GET $link, Referer=>$url;
			$response = $self->request($req);
			$log->write(2,$response->content);
			$response->content =~ /action=\"([^\"]+)/;
			$dlink = $1;
		} else {

			return {error=>1, error_text=>'Cannot get direct link'};
		}

	}
	$log->write(2, "dlink: $dlink");
	if(!$dlink || $dlink !~ m~http://~) {
		return {error=>-2, error_text=>'Cannot download direct link'};
	}

	$req = GET $dlink;
	my $ff = $self->direct_download($req, $url, $prefix, $update_stat);
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};

}
1;
