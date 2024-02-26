#!/usr/bin/perl
use strict;
use lib '.';
use XFSConfig;
use XUpload;
exit if $ENV{REMOTE_ADDR}; # allow only run from console

my $max_deleted_per_disk = 100;

my ($processed,$deleted,$deleted_total,$size_total);

opendir(DISKS, "$c->{cgi_dir}/uploads") || die("Error:cant open $c->{cgi_dir}: $!");
while( defined(my $disk_id=readdir(DISKS)) )
{
   next unless $disk_id=~/^\d\d$/;
   ScanDisk($disk_id);
}
$size_total = sprintf("%.02f Gb",$size_total/1024**3);
print"\nTotal deleted files: $deleted_total\nFilesize deleted: $size_total\n";


sub ScanDisk
{
   my ($disk_id) = @_;
   my $dir = "$c->{cgi_dir}/uploads/$disk_id";
   my $idir = "$c->{htdocs_dir}/i/$disk_id";
   print"\n--- Scan disk dir = $dir\n";

   opendir(DIR, $dir) || die("Error:cant open $dir $!");

   $deleted=0;
   my @arr;
   while( defined(my $fn=readdir(DIR)) ) # read dx dirs
   {
      next if $fn =~ /^\.{1,2}$/;
      next unless -d "$dir/$fn";
      next unless $fn=~/^\d{5}$/;
      opendir(DIR2, "$dir/$fn")||next;
      my $codehash={};
      while( defined(my $fn2=readdir(DIR2)) ) # read files
      {
         next if $fn2 =~ /^\.{1,2}$/;
         next if $fn2 =~ /\_\w\w\w$/; # skip captions
         my ($fcode,$qq) = split /\_/, $fn2;
         next if $codehash->{$fcode}++;
         my $ftime = (lstat("$dir/$fn/$fn2"))[9];
#         next if (time - $ftime) < 3600; # skip last-hour files
         push @arr, "$fn2";
         $processed++;
         #print"[$fn2]\n";
      }
      closedir(DIR2);

      # del empty dir and go next
      if($#arr==-1)
      {
        my $ftime = (lstat("$dir/$fn"))[9];
        next if (time - $ftime) < 3600*24*3; # do not delete last 3 days empty folders
        print"Del empty dir $dir/$fn\n";
        rmdir("$dir/$fn");
        rmdir("$idir/$fn");
        next;
      }

      processFiles( "$dir/$fn", "$idir/$fn", \@arr ) if @arr;
      @arr=();
   }
   closedir(DIR);

   print"Files removed from disk: $deleted\n\n";
}

sub processFiles
{
	my ($sdir, $idir, $arr) = @_;
	print"$processed.\n";
	my $res = XUpload::postMain(
								{
								#host_id => $c->{host_id}, # uncomment this to filter by server also
								op     => 'check_codes',
								codes  => join(',', @$arr ),
								}
								);

	die("Error: fs bad answer: ".$res->content) unless $res->content=~/^OK/;
	my ($bad) = $res->content=~/^OK:(.+?)$/;
	for my $cc ( split(/\,/,$bad) )
	{
	 return if $deleted >= $max_deleted_per_disk;
	 $cc=~s/_\w$//;
	 next unless $cc=~/^\w{12}$/;
	 print"Del files $sdir/$cc\_*\n";
	 my @files = <$sdir/$cc*>;
	 for(@files)
	 {
	 	my $fsize = -s $_;
	 	$size_total += $fsize;
	 	$fsize = sprintf("%.0f",$fsize/1024/1024);
	 	print" $_ [$fsize MB]\n";
	 	unlink($_) || print"can't delete $_: $!\n";
	 }
	 my @images = <$idir/$cc*>;
	 print"Del images:\n ".join("\n ",@images)."\n";
	 unlink(@images) || print"can't delete $idir/$cc: $!\n";
	 $deleted++;
	 $deleted_total++;
	}
}