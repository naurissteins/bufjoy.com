package Plugins::vimeo;

use strict;
use warnings;
use lib '..';
use lib '../Modules/';
use URI;
use HTTP::Request::Common qw(POST GET);
use HTML::TreeBuilder;
use base 'Plugin'; 

our $options = {
		plugin_id => 1101,
		plugin_prefix=>'vm',
		domain=>'vimeo.com',
		name=>'vimeo',
		can_login=>0,
		upload=>0,
		download=>1,
		signature=>'',
};


sub domain {
	return('vimeo.com');
}

sub download {
	my $self = shift;
	my $url = shift;
	# Simulating AJAX request
	my $vid_id = $1 if $url =~ /^https?:\/\/[^\/]+\/([0-9]+)/;
	my $req = GET "http://vimeo.com/$vid_id?action=download";
	$req->header(Referer => "http://vimeo.com/$vid_id");
	$req->header('X-Requested-With' => 'XMLHttpRequest');
	my $res = $self->request($req);
	
	# Extracting elements from DOM tree
	my $tree = HTML::TreeBuilder->new;
	$tree->parse($res->decoded_content);
	my $list_root = $tree->look_down('id' => 'download_videos');
	return {error=>1,error_text=>"No downloads for this video"} unless $list_root;
	my @links = $list_root->look_down('_tag' => 'a');
	return {error=>1,error_text=>"No downloads for this video"} unless @links;

	# Building URL
	$url = URI->new_abs($links[$#links]->attr('href'), $url);
	$req = GET $url;
	$req->header(Referer => "http://vimeo.com/$vid_id");
	my $ff = $self->direct_download($req, $url, undef, @_);
	return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};
}

sub check_link {
	shift;
	return ($_[0] =~ /vimeo\.com/);
}
