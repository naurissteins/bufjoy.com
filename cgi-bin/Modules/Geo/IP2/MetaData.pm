package Geo::IP2::MetaData;
use strict;
use Geo::IP2::Reader;

sub readMetadata
{
   my ($fh) = @_;
   my $pos = findMetadata($fh);
   seek($fh, $pos, 2);
   return Geo::IP2::Reader::readObject($fh);
}

sub findMetadata
{
   my ($fh) = @_;
   my $data;
   ## Returns metadata position relative to file end
   my $prefix = "\xab\xcd\xefMaxMind.com";
   for my $i(1..128)
   {
      my $buf;
      seek($fh, -$i * 1024, 2);
      read($fh, $buf, 1024);
      $data = $buf . $data;
      my $idx = index($data, $prefix);
      return -(length($data) - $idx - length($prefix)) if $idx != -1;
   }
   die("No metadata found");
}

1;
