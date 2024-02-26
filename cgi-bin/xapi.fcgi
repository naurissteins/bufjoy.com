#!/usr/bin/perl
use lib '.';
use lib Modules;

#use Sibsoft::Filter50864_6;
#use SecTetx;

use Session;
use xapi;
use CGI::Fast;
use XFileConfig;
use DataBase;
$c->{fast_cgi}=1;
use Module::Refresh;
my $db = DataBase->new();
while (my $q = CGI::Fast->new)
{
   #Module::Refresh->refresh_module_if_modified('XFileConfig.pm');
   Module::Refresh->refresh;
   xapi::run($q, $db);
}
