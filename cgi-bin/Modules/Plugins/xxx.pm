package Plugins::xxx;

use strict;
use warnings;
use lib '..';
use lib '../Modules/';
use Plugin;                                                                                                                                                                      
use HTTP::Request::Common qw(POST GET);
use base 'Plugin';

our $options = {
		plugin_id => 1111,
		plugin_prefix=>'xx',
		domain=>'youtube.com',
		name=>'xxx',
		can_login=>0,
		upload=>0,
		download=>1,
		signature=>'',
};

# https://github.com/rg3/youtube-dl/

# Installation:
# wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl
# chmod a+x /usr/local/bin/youtube-dl
# chown apache:apache /usr/local/bin/youtube-dl

sub check_link {
        shift;
        my $link = shift;
        return 0;
        if ($link =~ /(gounlimited\.to|vidoza\.net|youporn\.com|moevideo\.net|playreplay\.net|videochart\.net|vivo\.sx|dailymotion\.com|veoh\.com|pornhub\.com|xhamster\.one)/) {
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

sub download {
	my $self = shift;
	my $link = shift;
	my $prefix = shift;
	my $update_stat = shift;

	my $title = `/usr/local/bin/youtube-dl --get-filename -o "%(title)s" $link`;  # --restrict-filenames
	chomp($title);
	return {error=>1,errortext=>'Invalid video'} if $title=~/ERROR:/;

	my $url = `/usr/local/bin/youtube-dl -g $link`;
	print"URL:$url\n";
        return {error=>1,errortext=>'Video not available'} if $url=~/ERROR:/;
	my $req = GET $url; 
	my $ff = $self->direct_download($req, $url, $prefix, $update_stat);
	my $fname = "$title.mp4";
        $fname=~s/\?//g;
	return {error=>0, filename=>$fname||$ff->{filename}, filesize=>$ff->{filesize}};
}

sub domain {
	return('youtube.com');
}


1;