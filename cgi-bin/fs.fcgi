#!/usr/bin/perl
use lib '.';
use lib Modules;

use Sibsoft::Filter50864_6;
use SecTetx;

use XFileConfig;
use Session;
use fs;
use CGI::Fast;
use DataBase;
$c->{fast_cgi}=1;
#use Module::Refresh;
my $db = DataBase->new();
while (my $q = CGI::Fast->new)
{
   #Module::Refresh->refresh_module_if_modified('XFileConfig.pm');
   #Module::Refresh->refresh;
   fs::run($q, $db);
}
