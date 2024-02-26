package Geo::IP2::Reader;
use strict;

sub readObject
{
   my ($fh, $hints) = @_;
   my $ret;

   my $control_byte = readInt8($fh);
   #_debug("Pos: " . tell($fh));
   #_debug("Control byte: $control_byte");
   
   my $type = ($control_byte & 0b11100000) >> 5;
   $type = readInt8($fh) + 7 if !$type; # 'extended' types accordingly to MMDB format reference
   die if !$type;

   my $size = $control_byte & 0b00011111;
   $size = readLongSize($fh, $size) if $size >= 29;

   #_debug("Type: $type");
   #_debug("Size: $size");

   return readMap($fh, $size, $hints) if $type == 7;
   return readPointer($fh, $control_byte, $hints) if $type == 1;
   return readUTF8String($fh, $size) if $type == 2;
   return readDouble($fh, $size) if $type == 3;
   return readInt($fh, $size) if $type =~ /^(5|6|8|9|10)$/;
   return readArray($fh, $size, $hints) if $type == 11;
   return readBoolean($size) if $type == 14;
   die("Unknown type: $type");
}

sub readMap
{
   my ($fh, $size, $hints) = @_;
   #_debug("readMap($fh, $size)");
   my $ret = {};

   for(1..$size)
   {
      my $key = readObject($fh, $hints);
      #_debug("key=$key");
      my $value = readObject($fh, $hints);
      #_debug("value=$value");

      $ret->{$key} = $value;
   }

   return $ret;
}

sub readUTF8String
{
   my ($fh, $size) = @_;
   #_debug("readUTF8String($size)");
   return readN($fh, $size);
}

sub readInt
{
   my ($fh, $size) = @_;
   die if $size > 4;
   #_debug("readInt($fh, $size)");

   my $padding = "\0" x (4 - $size);
   return unpack("N", $padding . readN($fh, $size));
}

sub readDouble
{
   my ($fh, $size) = @_;
   return readN($fh, $size);
}

sub readArray
{
   my ($fh, $size, $hints) = @_;
   #_debug("readArray($fh, $size)");
   my $ret = [];

   for(1..$size)
   {
      my $value = readObject($fh, $hints);
      #_debug("value=$value");

      push @$ret, $value;
   }

   return $ret;
}

sub readN
{
   my ($fh, $n) = @_;
   my $buf;
   read($fh, $buf, $n);
   return $buf;
}

sub readPointer
{
   my ($fh, $control_byte, $hints) = @_;
   #_debug("readPointer($fh, $control_byte)");
   #_debug("data_section_start=$hints->{data_section_start}");
   die("data_section_start not specified") if !$hints->{data_section_start};

   my $size = ($control_byte & 0b00011000) >> 3;
   #_debug("Pointer size: $size");
   my $vvv = $control_byte & 0b00000111;
   die("Invalid pointer") if $size > 3;

   my $offset;
   $offset = readInt8($fh) + ($vvv << 8) if $size == 0;
   $offset = readInt16($fh) + ($vvv << 16) + 2048 if $size == 1;
   $offset = readInt24($fh) + ($vvv << 24) + 526336 if $size == 2;
   $offset = readInt32($fh) if $size == 3;


   my $curpos = tell($fh);
   my $file_offset = $hints->{data_section_start} + 16 + $offset;
   #_debug("Seeking to offset $file_offset");
   seek($fh, $file_offset, 0);
   my $ret = readObject($fh, $hints);
   seek($fh, $curpos, 0);

   return $ret;
}

sub readInt8 { return unpack("C", readN(shift, 1)); }
sub readInt16 { return unpack("n", readN(shift, 2)); }
sub readInt24 { return unpack("N", "\0" . readN(shift, 3)); }
sub readInt32 { return unpack("N", readN(shift, 4)); }
sub readBoolean { return shift() ? 1 : 0 }

sub readLongSize
{
   my ($fh, $size) = @_;
   return 29 + readInt8($fh) if $size == 29;
   return 285 + readInt16($fh) if $size == 30;
   return 65821 + readInt24($fh) if $size == 31;
}

sub _debug { print "@_\n" if $ENV{SS_DB_READER_DEBUG}; }

1;
