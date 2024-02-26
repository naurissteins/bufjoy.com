package Geo::IP2;
use strict;
use Geo::IP2::TreeWalker;
use Geo::IP2::Reader;
use Geo::IP2::MetaData;

sub new
{
   my ($class, $fn) = @_;
   my $self = {};

   open ($self->{fh}, $fn) || die("Couldn't open $fn: $!");
   binmode $self->{fh};

   $self->{metadata} = Geo::IP2::MetaData::readMetadata($self->{fh});
   for(qw(record_size node_count))
   {
      die("Couldn't find the following field in $fn metadata: $_") if !$self->{metadata}->{$_};
   }

   die("Not supported") if $self->{metadata}->{record_size} != 24;
   $self->{data_section_start} = $self->{metadata}->{node_count} * 6;

   bless $self, $class;
}

sub record_by_addr
{
   my ($self, $ip) = @_;
   my $ds_offset = $ip =~ /:/
      ? Geo::IP2::TreeWalker::findIPv6($self->{fh}, $ip, $self->{metadata})
      : Geo::IP2::TreeWalker::findIPv4($self->{fh}, $ip, $self->{metadata});
   return undef if $ds_offset < $self->{metadata}->{node_count};
   return undef if $ds_offset == $self->{metadata}->{node_count}; # Not found

   my $file_offset = $self->{data_section_start} + $ds_offset - $self->{metadata}->{node_count};
   seek($self->{fh}, $file_offset, 0);

   my $hints = { data_section_start => $self->{data_section_start} };
   return Geo::IP2::Reader::readObject($self->{fh}, $hints);
}

sub country_code_by_addr
{
   my ($self, $ip) = @_;
   return eval {
      my $rec = $self->record_by_addr($ip);
      $rec->{country}->{iso_code};
   }
}

1;
