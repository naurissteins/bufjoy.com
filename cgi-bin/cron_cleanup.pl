#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;
use File::Path qw(remove_tree);

exit if $ENV{REMOTE_ADDR};

CleanupFolder("$c->{cgi_dir}/temp",3600*6);
CleanupFolder("$c->{htdocs_dir}/i/tmp",3600*6);

CleanupFolder("$c->{cgi_dir}/vod",3600*12) if -d "$c->{cgi_dir}/vod";

sub CleanupFolder
{
    # delete folders / files older than X seconds
    my ($dir,$lifetime) = @_;
    my $ddir;
    return unless -e $dir;
    opendir($ddir, $dir) || die"Can't open dir($dir): $!";
    while( defined(my $fn=readdir($ddir)) )
    {
        if($fn=~/^\d\d$/)
        {
            CleanupFolder("$dir/$fn",$lifetime);
            next;
        }
        next if $fn=~/^(\.|\.\.|\.htaccess|status\.html)$/i;

        my $ftime = (lstat("$dir/$fn"))[9];
        my $dt = (time - $ftime);
        print"[$dir/$fn] $dt\n";
        next if $dt < $lifetime;
        if(-d "$dir/$fn")
        {
            remove_tree("$dir/$fn");
            print"rmdir $dir/$fn\n";
        }
        else
        {
            unlink("$dir/$fn");
            print"del $dir/$fn\n";
        }
    }
}

