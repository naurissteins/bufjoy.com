package Plugins::feurl;

use strict;
use warnings;
use lib '..';
use Plugin;                          
                                                                                                                                           
use base 'Plugin'; 
use HTTP::Request::Common qw(POST GET);
use MIME::Base64;
use XML::Simple;
use Data::Dumper;
use vars qw($VERSION);

$VERSION = "1.6" ;

our $options = {
		plugin_id => 1062,
		plugin_prefix=>'fu',
		domain=>'feurl.com',
		name=>'feurl',
		#required_login=>1,
		#can_login => 1,
		#upload=>1,
		download=>1,
};

sub check_link {
	shift;
	my $link = shift;
	if ($link =~ /(feurl\.|fembed\.|femax20\.)/i) {
		return 1;
	}
	return 0;
}

sub is_broken {
	my $self = shift;
	my $link = shift;
	$self->get($link);
	return 1 if($self->{content} =~ /video does not exist/i);
	return 0;
}

sub max_filesize {
	return 5*1024*1024*1024;
}

sub download {
	my $self = shift;
	my $link = shift;
	my $prefix = shift;
	my $update_stat = shift;

	my ($fcode) = $link=~/\/v\/([\w-]+)/i;
	return {error=>1,errortext=>'Invalid video'} unless $fcode;
	#return {error=>1,errortext=>'Invalid video'} if $title=~/ERROR:/;
	my $response = $self->request(POST "https://feurl.com/api/source/$fcode");
	unless ($response->is_success) {
		$log->write(2, $response->status_line);
		return {error=>1, error_text =>'Cannot get direct link'};
	}
	my $content = $response->content;
	my ($url) = $content=~/"file":"([^"]+?)","label":"720p"/i;
	unless($url)
	{
	  ($url) = $content=~/"file":"([^"]+?)","label":"480p"/i
	}
	unless($url)
	{
	  ($url) = $content=~/"file":"([^"]+?)","label":"1080p"/i
	}
	unless($url)
	{
	  ($url) = $content=~/"file":"([^"]+?)","label":"360p"/i
	}

	$url=~s/\\//g;
	print"URL:$url\n";
    return {error=>1,errortext=>'Video not available'} unless $url;
	my $req = GET $url;
	my $ff = $self->direct_download($req, $url, $prefix, $update_stat);
	#my $fname = "$title.mp4";
        #$fname=~s/\?//g;
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};
}

1;
