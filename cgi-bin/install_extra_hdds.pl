#!/usr/bin/perl
use strict;

#,'/disk3','/disk4','/disk5','/disk6','/disk7','/disk8','/disk9','/disk10','/disk11','/disk12'

my @list = ('/disk2');
my $cx = 2;
for my $d (@list)
{
  mkdir "$d/temp";
  mkdir "$d/uploads";
  mkdir "$d/i";
  `chmod -R 777 $d`;

  my $disk = sprintf("%02d",$cx);

  symlink("$d/temp","temp/$disk");
  symlink("$d/uploads","uploads/$disk");
  symlink("$d/i","../htdocs/i/$disk");
  print"$d done.\n";

  $cx++;
}