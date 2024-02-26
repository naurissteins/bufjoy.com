package Plugins::vidoza;

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

$VERSION = "1.0" ;

our $options = {
                plugin_id => 1073,
                plugin_prefix=>'vi',
                domain=>'vidoza.net',
                name=>'vidoza',
                download=>1,
};

sub check_link {
        shift;
        my $link = shift;
        if ($link =~ /vidoza/i) {
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

        print"LL:$link\n";
        #my ($fcode) = $link=~/\/v\/([\w-]+)/i;
        #return {error=>1,errortext=>'Invalid video'} unless $fcode;

        my $response = $self->request(GET $link);
        unless ($response->is_success) {
                #$log->write(2, $response->status_line);
                print"GET error:".$response->status_line."\n";
                return {error=>1, error_text =>'Cannot get direct link'};
        }
        my $content = $response->content;
        my ($url) = $content=~/source src="(.+?)"/i;
        ($url) = $content=~/src: "(.+?)"/i unless $url;
        return {error=>1,errortext=>'Video not available'} unless $url;
        print"URL:$url\n";

        my $req = GET $url;
        my $ff = $self->direct_download($req, $url, $prefix, $update_stat);

        return {error=>0, filename=>$ff->{filename}, filesize=>$ff->{filesize}};
}

1;
