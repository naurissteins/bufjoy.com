package Plugins::filefactory;

use strict;
use warnings;
use lib '..';
use lib '../Modules/';
use Plugin;                                                                                                                                                                      
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use MIME::Base64;
#use Net::FTP;
use Data::Dumper;
use vars qw($VERSION);

our $options = {
		plugin_id => 1011,
		plugin_prefix=>'ff',
		domain=>'filefactory.com',
		name=>'filefactory',
		can_login=>1,
		upload=>1,
		download=>1,
};

sub check_link {
	shift;                                                                                                                                                                       
	my $link = shift;                                                                                                                                                            
	if ($link =~ /filefactory\.com/) {                                                                                                                                          
		return 1;                                                                                                                                                                
	}                                                                                                                                                                            
	return 0; 
}

sub max_filesize {
	return 2048*1024*1024;
}


sub login {
	my $self = shift;
	my $a = shift;
	$self->{action} = 'login';
	my $req = POST "http://www.filefactory.com/member/login.php",
	        Referer => 'http://filefactory.com/',
       	Content => [email=>$a->{login}, password=>$a->{password}, 'redirect'=>'/'];
	my $r = $self->request($req);
	
	if(($r->is_success) || ($r->code == 302)) {
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
	$self->get('http://filefactory.com');
	my $req = POST 'http://upload.filefactory.com/upload.php',
		Content_Type => "multipart/form-data",
		Content=>[Filedate=>["$c->{filesdir}/$file", $filename], Filename=>$filename];
	$self->up_file($req);
	my $download = '';
	if($self->{content}=~ /^[a-zA-Z0-9]{1,12}$/) {
		$download = 'http://www.filefactory.com/file/'.$self->{content}.'/'.$filename;
	} else {
#		print STDERR "content:$self->{content}:\n";
	}
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
		return {error=>1,errortext=>'Cannot get download link' }
	}
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};

}
1;
