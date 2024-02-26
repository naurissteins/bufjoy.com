package Plugins::youtube;

use strict;
use warnings;
use lib '..';
use lib '../Modules/';
use Plugin;                                                                                                                                                                      
use HTTP::Request::Common qw(POST GET);
use base 'Plugin';

our $options = {
		plugin_id => 1100,
		plugin_prefix=>'yt',
		domain=>'youtube.com',
		name=>'youtube',
		can_login=>0,
		upload=>0,
		download=>1,
		signature=>'',
};

# https://github.com/rg3/youtube-dl/

# Installation:
# wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl
# chmod a+x /usr/local/bin/youtube-dl

sub download {
	my $self = shift;
	my $link = shift;
	my $prefix = shift;
	my $update_stat = shift;

	my $xxx = `/usr/local/bin/youtube-dl --get-description --get-filename -o "%(title)s" $link`;  # --restrict-filenames
	my ($descr,$title) = $xxx=~/^(.*)\n(.+)$/s;
	chomp($title);
	return {error=>1,errortext=>'Invalid video'} if $title=~/ERROR:/;
	my $url = `/usr/local/bin/youtube-dl -f 22/18/5 -g $link`;
	print"URL:$url\n";
        return {error=>1,errortext=>'Video not available'} if $url=~/ERROR:/;
	my $req = GET $url;
	my $ff = $self->direct_download($req, $url, $prefix, $update_stat);
	my $fname = "$title.mp4";
        $fname=~s/\?//g;
	return {error=>0, filename=>$fname, filesize=>$ff->{filesize}, descr=>$descr};
}

sub domain {
	return('youtube.com');
}

sub check_link {
	return 0;
	return($_[1] =~ /youtube\.com/);
}

1;