package Geo::IP2::TreeWalker;
use strict;
use Socket;
use Geo::IP2::Reader;
use Net::IP;

=pod
Returns: offset relative to data section (as per MMDB spec)
=cut

sub findIPv4
{
   my ($fh, $ip, $opts) = @_;
   die("node_count not specified") if !$opts->{node_count};

   my @binstr = split('', unpack("B*", inet_aton($ip)));

   if($opts->{ipv4_start})
   {
      seek($fh, $opts->{ipv4_start}, 0); # +60% performance gain
   }
   else
   {
      seek($fh, 0, 0);
      ## IPv6-to-IPv4 prefix
      left($fh) for (1..80);
      right($fh) for (1..16);
      $opts->{ipv4_start} = tell($fh);
   }

   my $value;

   ## Find IPv4
   for my $bit(@binstr) {
      $value = $bit ? right($fh) : left($fh);
      last if $value >= $opts->{node_count};
   }

   return $value;
}

## TODO: refactoring

sub findIPv6
{
   my ($fh, $ip, $opts) = @_;
   die("node_count not specified") if !$opts->{node_count};

   my @binstr = split('', Net::IP->new($ip)->binip());

   seek($fh, 0, 0);
   my $value;

   ## Find IPv6
   for my $bit(@binstr) {
      $value = $bit ? right($fh) : left($fh);
      last if $value >= $opts->{node_count};
   }

   return $value;
}

sub left { return goFurther(shift, 'left') }
sub right { return goFurther(shift, 'right') }

sub goFurther
{
   my ($fh, $direction) = @_;
   die("Wrong direction: $direction") if $direction !~ /^(left|right)$/;

   my $left = Geo::IP2::Reader::readInt24($fh);
   my $right = Geo::IP2::Reader::readInt24($fh);

   my $value = { left => $left, right => $right }->{$direction};
   #_debug("Record: $direction");
   #_debug("Record value: $value");

   seek($fh, $value * 6, 0);

   return $value;
}

sub _debug { print "@_\n" if $ENV{SS_DB_READER_DEBUG}; }

1;
