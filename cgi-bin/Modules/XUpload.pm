package XUpload;

use strict;
use lib '.';
use XFSConfig;
use LWP::UserAgent;
use File::Copy;
use Encode;
use vars qw($log);
use File::Find;
use File::Basename;
use IPC::Open3;

our ($uax,$uaxs);

$c->{ffmpeg}||="$c->{cgi_dir}/ffmpeg";

sub ImportDir
{
   my ($path, %opts) = @_;

   delete $opts{op};

   my $usr_id=$opts{usr_id};
   delete $opts{usr_id};

   my $sid=$opts{sid};
   delete $opts{sid};

   $path =~ s/\/+$//;

   die("No path") if !$path;

  find({ wanted => sub{ wanted($sid) }, no_chdir => 1 }, $path);
  
  sub wanted
  {
     my ($sidx) = @_;
     next unless -f $File::Find::name;
     next unless $File::Find::name=~/\.($c->{video_extensions})$/i;
     my $fld_path = $1 if $File::Find::dir =~ /^\Q$path\E\/(.*)/;
      my $xfile = { file_tmp => $File::Find::name, file_name_orig => basename($File::Find::name), usr_id=>$usr_id };
      my $ff = ProcessFile($xfile, { ip => '2.2.2.2', fld_path => "$opts{prefix}/$fld_path", sid => $sidx, %opts });
  }
}

sub ProcessFile
{
   my ($file,$f) = @_;

   $f->{ip}||=$ENV{REMOTE_ADDR};

   unless($log)
   {
     require Log;
     $log = Log->new(filename=>'upload.txt', mute=>1);
   }

   unless(-f $file->{file_tmp})
   {
      $file->{file_status}="No file on disk ($file->{file_tmp})";
      return $file;
   }

   my $notvideo=1 if $file->{file_name_orig}!~/\.($c->{video_extensions}|$c->{audio_extensions})$/i;
   if($notvideo && !$c->{allow_non_video_uploads})
   {
      $file->{file_status}="Not video file ($file->{file_name_orig})";
      return $file;
   }

	$file->{file_size} = -s $file->{file_tmp};

	if($c->{md5_sum_full_file})
	{
		($file->{md5}) = `md5sum "$file->{file_tmp}"`=~/^(\w+)\s+/;
	}
	else
	{
		my $chunk=4096;
		open(FILE,$file->{file_tmp})||die"cant open file for md5:$!";
		my $data;
		read(FILE,$data,$chunk);
		seek(FILE,0-$chunk,2);
		read(FILE,$data,$chunk,$chunk);
		require Digest::MD5;
		$file->{md5} = Digest::MD5::md5_base64( $data );
	}

	$file->{file_spec} = getVideoInfo($file->{file_tmp},$f,$file->{file_name_orig}) unless $notvideo;

	($file->{srt_hash},$file->{file_captions}) = getVideoSRTs($file->{file_tmp},$f) if $c->{srt_auto} && !$notvideo;

	my @arr;
	push @arr, "$_|||$file->{srt_hash}->{$_}" for keys %{$file->{srt_hash}};
	$file->{data_srt} = join('^^^',@arr);

   if($f->{ID_VIDEO_WIDTH}!~/^\d+$/i && !$c->{allow_non_video_uploads})
   {
      $file->{file_status}="Not video file format";
      return $file;
   }

   my $is_audio = $c->{audio_extensions} && $file->{file_name_orig} =~ /\.($c->{audio_extensions})$/i;
   my $is_video = $c->{video_extensions} && $file->{file_name_orig} =~ /\.($c->{video_extensions})$/i;
   $file->{file_length} = $f->{ID_LENGTH};

   if ($is_audio) {
      $file->{audio_artist} = $f->{ID_AUDIO_ARTIST};
      $file->{audio_title} = $f->{ID_AUDIO_TITLE};
      $file->{audio_album} = $f->{ID_AUDIO_ALBUM};
      $file->{audio_genre} = $f->{ID_AUDIO_GENRE};
   }

   # Get file thumbnail
   my $audio_thumb;
   my $video_thumb;
   my $video_thumb_t;
   my $rand = join '', map int rand 10, 1..10;
   if ($is_audio) {
      $audio_thumb = "aud_".$rand.".jpg";
      $file->{audio_thumb} = $audio_thumb;
   } elsif ($is_video) {
      $video_thumb = "vid_".$rand.".jpg";
      $video_thumb_t = "vid_".$rand."_t.jpg";
      $file->{video_thumb} = $video_thumb;
      $file->{video_thumb_t} = $video_thumb_t;
   }

   $f->{fld_name}=~s/[\"\<\>\0]+//g;
   $f->{file_ip} = $f->{ip};

   my %extra;
   $extra{$_}=$f->{$_} for grep{/^extra_/} keys %$f;

   my $effects = join '|', map{/^eff_(.+)$/;"$1=$f->{$_}"} grep{/^eff_/ && $f->{$_}} keys %$f;

   $f->{disk_id} = @{$f->{disk_id}}[0] if ref $f->{disk_id} eq 'ARRAY';

   LWPFS:
   my $res = postMain(
                       {
                       %$f,
                       host_id      => $c->{host_id},
                       file_title   => $file->{file_title},
                       file_name    => $file->{file_name_orig},
                       file_descr   => $file->{file_descr},
                       file_size    => $file->{file_size},
                       file_public  => $file->{file_public},
                       file_adult   => $file->{file_adult},
                       file_md5     => $file->{md5},
                       file_spec    => $file->{file_spec},
                       file_length  => $file->{file_length},
                       usr_id       => $file->{usr_id},
                       no_limits    => $file->{no_limits},
                       sid          => $f->{sid},
                       api_key      => $f->{key},
                       cat_id       => $file->{cat_id},
                       tags         => $file->{tags},
                       usr_login    => $file->{usr_login}||'',
                       usr_id       => $file->{usr_id}||'',
                       url_queue_id => $file->{url_queue_id}||'',
                       file_src     => $file->{url_src} || $file->{url} || '',
                       effects      => $effects,
                       data_srt     => $file->{data_srt},
                       file_captions=> $file->{file_captions},
                       video_thumb   => $file->{video_thumb},
                       video_thumb_t   => $file->{video_thumb_t},
                       audio_thumb   => $file->{audio_thumb},
                       audio_artist   => $file->{audio_artist},
                       audio_title   => $file->{audio_title},
                       audio_album   => $file->{audio_album},
                       audio_genre   => $file->{audio_genre},
                       %extra,
                       }
                      );
   my $info = $res->content;
   $log->log("INFO:$info");

   if($extra{'retry'}<2 && (!$res->is_success || !$info=~/^\d+:/))
   {
      $log->log("Bad response. Let's try one more time.");
      sleep 1;
      $extra{'retry'}++;
      goto LWPFS;
   }

   ($file->{file_id},$file->{file_code},$file->{file_real},$file->{utype},$file->{msg},$file->{extra}) = $info=~/^(\d+):(\w+):(\w+):(\w+):(.*?)\n(.*)$/s;

   if($file->{msg} ne 'OK')
   {
      $file->{file_status}=$file->{msg}||$info;
      $file->{file_status}="fs.cgi error" if $file->{file_status}=~/Software error/i;
      unlink($file->{file_tmp});
      return $file;
   }

   if(!$file->{file_code})
   {
      $file->{file_status}="error connecting to DB";
      return $file;
   }

   my $extra;
   for(split /\n/, $file->{extra})
   {
      /^(.+?)=(.*)$/;
      $extra->{$1}=$2;
   }

   $file->{disk_id} ||= $f->{disk_id} || $extra->{disk_id};
   SaveFile( $file, $f, $extra, $audio_thumb, $video_thumb, $video_thumb_t ) if $file->{file_code} eq $file->{file_real};
   return $file;
}

sub SaveFile
{
   my ($file,$f,$extra,$audio_thumb,$video_thumb,$video_thumb_t) = @_;
   my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
   $file->{dx} = $dx;
   my $dirup = "$c->{cgi_dir}/uploads/$file->{disk_id}/$dx";
   
   unless(-d $dirup)
   {
      my $mode = 0777;
      mkdir($dirup,$mode) || do{$log->log("Fatal Error: Can't mkdir ($!)");&xmessage("Fatal Error: Can't mkdir ($!)")};
      chmod $mode,$dirup;
   }

   my $file_dst = "$dirup/$file->{file_code}_o";

   move($file->{file_tmp},$file_dst) || 
      copy($file->{file_tmp},$file_dst) || 
         do{
               my $error = "Can't copy file from temp dir ($file->{file_tmp})($file_dst)($!)";
               postMain({
                           op        => 'delete_file_db',
                           file_id   => $file->{file_id},
                          });
               if($file->{url_queue_id})
               {
                  $file->{file_status}=$error;
                  return;
               }
               $log->log($error);
               xmessage($error);
           };

   my $mode = 0666;
   chmod $mode, $file_dst;
   unlink($file->{file_tmp}) if -e $file->{file_tmp};

   my $idir = "$c->{htdocs_dir}/i/$file->{disk_id}/$dx";
   unless(-d $idir)
   {
      mkdir $idir;
      chmod 0777, $idir;
   }

   $c->{thumb_position} = sprintf("%.1f",$file->{file_length}*$1/100) if $c->{thumb_position}=~/^([\d\.]+)%$/;
   $c->{thumb_position}=5 unless $c->{thumb_position}=~/^[\d\.]+$/;
   $c->{thumb_position}=3 if $c->{thumb_position}<3;


   if($c->{custom_snapshot_upload} && $file->{snapshot_file_tmp})
      {
         `convert -resize 2000x2000\> -strip $file->{snapshot_file_tmp} $idir/$file->{file_code}.jpg` if -f $file->{snapshot_file_tmp} && -s $file->{snapshot_file_tmp} < $c->{custom_snapshot_upload}*1073741824;
      }

   if($c->{video_extensions} && ($file->{file_name}=~/\.($c->{video_extensions})$/i || $file->{file_name_orig}=~/\.($c->{video_extensions})$/i))
   {
      my $thw = 1280 if $f->{ID_VIDEO_WIDTH}>1280;
      makeSnap($file_dst, "$idir/$video_thumb", $c->{thumb_position}, $thw, 0, 'fast');

         
      `convert $idir/$video_thumb -resize 720x405^ -gravity center -extent 720x405 $idir/$video_thumb_t`;
       unless(-f "$idir/$video_thumb_t")
         {
            makeSnap($file_dst, "$idir/$video_thumb_t", $c->{thumb_position}, 720, 0, 'fast');
         }
         
      copy("$c->{htdocs_dir}/i/default.jpg","$idir/$file->{file_code}.jpg")   unless -e "$idir/$file->{file_code}.jpg";
      copy("$c->{htdocs_dir}/i/default.jpg","$idir/$file->{file_code}_t.jpg") unless -e "$idir/$file->{file_code}_t.jpg";

      createScreenlist( $file_dst, $file, $f, $idir, $extra) if $extra->{screenlist}; 

   } elsif($c->{image_extensions} && ($file->{file_name}=~/\.($c->{image_extensions})$/i || $file->{file_name_orig}=~/\.($c->{image_extensions})$/i)) {
      my ($ext) = $file->{file_name} =~ /\.([^.]+)$/;

      # Define the output file path
      my $output_file = "$idir/$file->{file_code}_t.$ext";

      # Skip resizing for GIFs to preserve animations
      if ($ext =~ /^gif$/i) {
         copy($file_dst, $output_file) or die "Copy failed: $!";
      } else {
         # Define the maximum width for the thumbnail
         my $max_width = 1280;

         # Use convert for other image formats to create a thumbnail
         my $cmd = "convert '$file_dst' -resize ${max_width}x '${output_file}'";
         system($cmd) == 0 or die "Failed to convert image: $!";
      }

   } elsif($c->{audio_extensions} && ($file->{file_name}=~/\.($c->{audio_extensions})$/i || $file->{file_name_orig}=~/\.($c->{audio_extensions})$/i)) {
      audioCover($file_dst, "$idir/$audio_thumb") if defined $audio_thumb;
      copy("$c->{htdocs_dir}/i/default.jpg","$idir/$audio_thumb") unless -e "$idir/$audio_thumb";
   }

}

sub audioCover {
    my ($file_path, $final_path, $instant) = @_;
    unlink($final_path);

    # Get the dimensions of the image
    my $ffprobe = $c->{ffprobe} // 'ffprobe'; # Assuming ffprobe is in the same path as ffmpeg
    my $dims = `$ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$file_path"`;
    my ($width, $height) = split 'x', $dims;

    my $size = '';
    # Apply scale only if width is greater than 500
    if ($width > 500) {
        $size = "-vf scale=500:-1";
    }

    my $timeout = 'timeout 10s ' unless $c->{no_ffmpeg_timeout};
    my $str = qq[$timeout$c->{ffmpeg} -i "$file_path" $size -q:v 3 $final_path];
    return $str if $instant;
    my $x = `$str >/dev/null 2>/dev/null`;
    return $x;
}

sub Wave {
   my ($file) = @_;
    
	$file->{file_real}||=$file->{file_code};
	$file->{file_real_id}||=$file->{file_id};
	$file->{disk_id}||='01';

   my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
   my $idir = "$c->{htdocs_dir}/i/$file->{disk_id}/$dx";
	mkdir($idir,0777) unless -d $idir;

   #my $cover = "$idir/$file->{file_real}_t.jpg";
   my $sp = "$idir/$file->{file_real}_sp.png";
   my $w1 = "$idir/$file->{file_real}_w1.png";
   my $w2 = "$idir/$file->{file_real}_w2.png";
   return 0 if $file->{file_path} && -f $w2;

	my $file_path = "$c->{cgi_dir}/uploads/$file->{disk_id}/$dx/$file->{file_real}\_o";
	return "ERROR:No source file /$file->{disk_id}/$dx/$file->{file_real}" unless -f $file_path;   

   my $filter_w1 = "[0:a]aformat=channel_layouts=mono,compand=gain=-6,showwavespic=s=934x112:colors=white,negate[a];color=#111827:934x112[c];[c][a]alphamerge";  
   #my $filter_w2 = "aformat=channel_layouts=mono,compand=gain=-6,showwavespic=s=2000x100:colors=#8c8c8c";
   my $filter_sp = "showspectrumpic=s=640x512:scale=log:color=rainbow";

   my $timeout = 'timeout 10s ' unless $c->{no_ffmpeg_timeout};


   # Get the dimensions of the image
   #my $ffprobe = $c->{ffprobe} // 'ffprobe'; # Assuming ffprobe is in the same path as ffmpeg
   #my $dims = `$ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$file_path"`;
   #my ($width, $height) = split 'x', $dims;

   #my $size = '';
    # Apply scale only if width is greater than 500
   #if ($width > 500) {
   #     $size = "-vf scale=500:-1";
   #}   

   # Generate Artwork
   #my $str_cover = qq[$timeout$c->{ffmpeg} -i "$file_path" $size -q:v 3 -update true $cover];
   #`$str_cover >/dev/null 2>/dev/null`;
   #print"Artwork Done\n";      

   # Generate Spectogram
   my $str_sp = qq[$timeout$c->{ffmpeg} -i "$file_path" -lavfi "$filter_sp" -update true $sp];
   `$str_sp >/dev/null 2>/dev/null`;

   # Generate Waveform 1
   my $str_w1 = qq[$timeout$c->{ffmpeg} -i "$file_path" -filter_complex "$filter_w1" -vframes 1 -update true $w1];
   my $x = `$str_w1 >/dev/null 2>/dev/null`;

   # Generate Waveform 2
   #my $str_w2 = qq[$timeout$c->{ffmpeg} -i "$file_path" -filter_complex "$filter_w2" -update true $w2];
   #my $x = `$str_w2 >/dev/null 2>/dev/null`;
   return $x;

}


sub makeSnap
{
    my ($file_path, $final_path, $timestamp, $resize_w, $resize_h, $fast, $instant) = @_;
    unlink($final_path);

    $fast=1;

    $resize_h||='-1' if $resize_w;
    my $size = "-vf scale=$resize_w:$resize_h" if $resize_w && $resize_h;
    my $timeout='timeout 10s ' unless $c->{no_ffmpeg_timeout};
    my ($ss1,$ss2);
    if($fast){ $ss1="-ss $timestamp"; } else { $ss2="-ss $timestamp"; }
    my $str = qq[$timeout$c->{ffmpeg} $ss1 -i "$file_path" $ss2 -an -dn -sn -update 1 -frames:v 1 -y $size -q:v 3 $final_path];
    return $str if $instant;
    my $x = `$str >/dev/null 2>/dev/null`;
    return $x;
}

sub createScreenlist
{
	my ($file_path, $file, $f, $idir, $extra) = @_;
	my $bgcolor='#e9e9e9';
	my $text_color='#303030';
	my $logo_color='#F6F6F6';
	my $prewidth = $extra->{m_x_width}-2;
	my $vborder = 1;
	my $vsize = sprintf("%.0f", ($prewidth-$extra->{m_x_cols}*2) / $extra->{m_x_cols} );
	$extra->{m_x_cols}||=3;
	$extra->{m_x_rows}||=3;
	my $frames=$extra->{m_x_cols}*$extra->{m_x_rows};

	my $rand = join '', map int rand 10, 1..7;
	my $temp_dir = "$c->{cgi_dir}/temp/$file->{disk_id}/$rand";
	mkdir $temp_dir;
	chmod 0777, $temp_dir;

	my @scmd;
	for my $i (1..$frames)
	{
		my $ss = sprintf("%.1f",$i*$file->{file_length}/($frames+1));
		my $out = makeSnap($file_path, "$temp_dir/".sprintf("%03d",$i).".jpg", $ss, $vsize, 0, 'fast', 'instant');
		push @scmd, "$out >/dev/null 2>/dev/null" if $out;
	}
	system( join(';',@scmd) );

	`montage -background "$bgcolor" $temp_dir/0*.jpg -tile $extra->{m_x_cols}x -geometry +1+1 $temp_dir/11.png`;
	unlink(<$temp_dir/0*.jpg>);

	my $file_size = $file->{file_size} || -s $file_path;
	my $fsize = makeFileSize($file_size);
	$file->{file_length2} = sprintf("%02d:%02d:%02d",int($file->{file_length}/3600),int(($file->{file_length}%3600)/60),$file->{file_length}%60);
	my $info="File Name: $file->{file_name_orig}\n";
	$info.="File Size: $fsize ($file_size bytes)\n";
	$info.="Resolution: $f->{ID_VIDEO_WIDTH}x$f->{ID_VIDEO_HEIGHT}\n" if $f->{ID_VIDEO_WIDTH};
	$info.="Duration: $file->{file_length2} ($file->{file_length} seconds)";
	my $top_size = $prewidth."x60";
	my $stamp=qq[-gravity East -fill '$logo_color' -font $c->{cgi_dir}/Modules/fonts/font_arialblack.ttf -pointsize 36 -weight Bold -annotate +30-1 '$extra->{m_x_logo}'] if $extra->{m_x_logo};
	`convert -size $top_size xc:$bgcolor -gravity NorthWest -fill "$text_color" -font $c->{cgi_dir}/Modules/fonts/font_tahoma.ttf -pointsize 13 -weight Normal -annotate +4+0 "$info" $stamp $temp_dir/22.png`;
	my $border=$vborder;
	`convert -bordercolor "$bgcolor" $temp_dir/22.png $temp_dir/11.png -append -strip -border $border -quality 85 $idir/$file->{file_code}_x.jpg`;
	$extra->{m_x_th_width}||=400;
	$extra->{m_x_th_height}||=400;
	`convert $temp_dir/11.png -thumbnail '$extra->{m_x_th_width}x$extra->{m_x_th_height}' -strip -quality 80 $idir/$file->{file_code}_xt.jpg`;

	unlink(<$temp_dir/*.png>);
	unlink(<$temp_dir/*.jpg>);
	rmdir($temp_dir);
}

sub createTimeslides
{
	my ($file) = @_;

	$file->{file_real}||=$file->{file_code};
	$file->{file_real_id}||=$file->{file_id};
	$file->{disk_id}||='01';

	my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});

	my $idir = "$c->{htdocs_dir}/i/$file->{disk_id}/$dx";
	mkdir($idir,0777) unless -d $idir;

	my $slides_file = "$idir/$file->{file_real}0000.jpg";
	return 0 if $file->{file_path} && -f $slides_file;

	my $file_path = $file->{file_path} || 
					"$c->{cgi_dir}/uploads/$file->{disk_id}/$dx/$file->{file_real}\_l";
	   $file_path = "$c->{cgi_dir}/uploads/$file->{disk_id}/$dx/$file->{file_real}\_n" unless -f $file_path;
	   $file_path = "$c->{cgi_dir}/uploads/$file->{disk_id}/$dx/$file->{file_real}\_h" unless -f $file_path;
	   $file_path = "$c->{cgi_dir}/uploads/$file->{disk_id}/$dx/$file->{file_real}\_x" unless -f $file_path;
	   $file_path = "$c->{cgi_dir}/uploads/$file->{disk_id}/$dx/$file->{file_real}\_o" unless -f $file_path;
	return "ERROR:No source file /$file->{disk_id}/$dx/$file->{file_real}" unless -f $file_path;
	
	my $rand = join '', map int rand 10, 1..7;
	my $temp_dir = "$c->{cgi_dir}/temp/$file->{disk_id}/$rand";
	mkdir($temp_dir, 0777) || return "ERROR:mkdir temp $temp_dir:$!";

	my $frames=$c->{m_z_cols}*$c->{m_z_rows};
	for my $i (1..$frames)
	{
	   my $ss = sprintf("%.1f",$i*$file->{file_length}/($frames+1));
	   my $th = "$temp_dir/".sprintf("%03d",$i);
	   my $thp = "$temp_dir/p".sprintf("%03d",$i);
	   makeSnap( $file_path, "$th\_s.png", $ss, 200, 112, 'fast');
	}

	`montage $temp_dir/*_s.png -tile $c->{m_z_cols}x -geometry +0+0 $slides_file`;

	unlink(<$temp_dir/*.png>);
	rmdir($temp_dir);
	return 0;
}

sub xmessage
{
   my ($msg) = @_;
   $msg=~s/'/\\'/g;
   $msg=~s/<br>/\\n/g;
   print"Content-type: text/html\n\n";
   print"<HTML><HEAD><Script>alert('$msg');</Script></HEAD><BODY><b>$msg</b></BODY></HTML>";
   exit;
}

sub makeFileSize
{
   my ($size)=@_;
   return '' unless $size;
   return "$size Bytes" if $size<=1024;
   return sprintf("%.0f Kb",$size/1024) if $size<=1024*1024;
   return sprintf("%.01f Mb",$size/1048576) if $size<=1024*1024*1024;
   return sprintf("%.01f Gb",$size/1073741824);
}

sub getVideoInfo
{
	my ($file_tmp,$f,$filename) = @_;
	return '' unless -s $file_tmp;
	my $file_spec;
	my $info_json = `$c->{cgi_dir}/ffprobe -v quiet -print_format json -show_format -show_streams "$file_tmp"`;
	return '' if $info_json!~/^\{/ || length($info_json)<30;
	$info_json=~s/,\n\s+"disposition": \{.+?\}//gs;
	require JSON;
 	my $x = eval { JSON::decode_json($info_json) };
 	return '' if $@;

 	$f->{file_spec_txt} = $info_json;
 	$f->{file_spec_json} = $x;
 	$f->{ID_LENGTH} = sprintf("%.02f", $x->{format}->{duration}||60*30 );
 	$f->{ID_DEMUXER} = $x->{format}->{format_name};
 	$f->{ID_DEMUXER}='mp4' if $f->{ID_DEMUXER}=~/mp4/i;

 	my @videos = grep{$_->{codec_type} eq "video"} @{$x->{streams}};
 	my @audios = grep{$_->{codec_type} eq "audio"} @{$x->{streams}};
 	my @subs   = grep{$_->{codec_type} eq "subtitle"} @{$x->{streams}};

 	$f->{videos} = \@videos;
 	$f->{subs} = \@subs;

 	my $v = $videos[0];
 	my $a = $audios[0];

 	if(@audios >= 2)
 	{
 	  my $ii=0; my @il=('lat','swe','nor','mlt','ndo','lug','kua','ina','aka');
 	  my $i=0;
 	  for(@audios)
 	  {
 	  	$_->{ind} = $i++;
 	  	$_->{lang} = $_->{tags} && $_->{tags}->{language} ? $_->{tags}->{language} : $il[$ii++];
 	  }
 	  $f->{audios} = \@audios;
 	}

 	$v->{avg_frame_rate}=~s/\/1$//;
 	($f->{ID_VIDEO_WIDTH}, $f->{ID_VIDEO_HEIGHT}, $f->{ID_VIDEO_BITRATE}, $f->{ID_VIDEO_CODEC}, $f->{ID_VIDEO_FPS}) = ($v->{width}, $v->{height}, sprintf("%.0f",$v->{bit_rate}/1000), $v->{codec_name}, $v->{avg_frame_rate});

 	#($f->{ID_AUDIO_BITRATE}, $f->{ID_AUDIO_RATE}, $f->{ID_AUDIO_CODEC}) = (sprintf("%.0f",$a->{bit_rate}/1000), $a->{sample_rate}, $a->{codec_name});
   ($f->{ID_AUDIO_BITRATE}, $f->{ID_AUDIO_RATE}, $f->{ID_AUDIO_CODEC}) = (defined $a->{bit_rate} ? sprintf("%.0f", $a->{bit_rate} / 1000) : sprintf("%.0f", $x->{format}->{bit_rate} / 1000), $a->{sample_rate}, $a->{codec_name});

 	if(!$v->{bit_rate} && $x->{format}->{bit_rate}){ $f->{ID_VIDEO_BITRATE}=sprintf("%.0f", ($x->{format}->{bit_rate}-$a->{bit_rate})/1000 ); }

   my $audio_title;
   foreach my $key (keys %{$x->{format}->{tags}}) {
      if (lc($key) eq 'title') {
         $audio_title = $x->{format}->{tags}->{$key};
         last;
      }
   }

   my $audio_artist;
   foreach my $key (keys %{$x->{format}->{tags}}) {
      if (lc($key) eq 'artist' || lc($key) eq 'artists') {
         $audio_artist = $x->{format}->{tags}->{$key};
         last;
      }
   }   

   my $audio_album;
   foreach my $key (keys %{$x->{format}->{tags}}) {
      if (lc($key) eq 'album') {
         $audio_album = $x->{format}->{tags}->{$key};
         last;
      }
   }

   my $audio_genre;
   foreach my $key (keys %{$x->{format}->{tags}}) {
      if (lc($key) eq 'genre') {
         $audio_genre = $x->{format}->{tags}->{$key};
         last;
      }
   }         

   $f->{ID_AUDIO_ARTIST} = $audio_artist;
   $f->{ID_AUDIO_TITLE} = $audio_title;
   $f->{ID_AUDIO_ALBUM} = $audio_album;
   $f->{ID_AUDIO_GENRE} = $audio_genre;

	my @fields = qw(ID_LENGTH ID_VIDEO_WIDTH ID_VIDEO_HEIGHT ID_VIDEO_BITRATE ID_AUDIO_BITRATE ID_AUDIO_RATE ID_VIDEO_CODEC ID_AUDIO_CODEC ID_VIDEO_FPS ID_DEMUXER);
 	$file_spec = join('|', map{$f->{$_}}@fields );

 	$f->{srt}=1 if @subs;

	return $file_spec;
}

sub getVideoInfoOld
{
   my ($file_tmp,$f,$filename) = @_;
   my $file_spec;
   my @fields = qw(ID_LENGTH ID_VIDEO_WIDTH ID_VIDEO_HEIGHT ID_VIDEO_BITRATE ID_AUDIO_BITRATE ID_AUDIO_RATE ID_VIDEO_CODEC ID_AUDIO_CODEC ID_VIDEO_FPS ID_DEMUXER);

   if($c->{vid_info_parser} eq 'mplayer' || !$c->{vid_info_parser})
   {
       my $info = `mplayer $file_tmp -identify -frames 0 -quiet -ao null -vo null 2>/dev/null | grep ^ID_`;
       do{($f->{$_})=$info=~/$_=([\w\.]{2,})/is} for @fields;
       $f->{ID_LENGTH} = sprintf("%.0f",$f->{ID_LENGTH});
       ($f->{ID_VIDEO_FPS}) = $info=~/, ([\d\.]+) tbr,/i unless $f->{ID_VIDEO_FPS};
       $f->{ID_VIDEO_CODEC}='XVID' if $info=/ID_VIDEO_FORMAT=XVID/i;
       $f->{ID_VIDEO_BITRATE}=int($f->{ID_VIDEO_BITRATE}/1000);
       $f->{ID_AUDIO_BITRATE}=int($f->{ID_AUDIO_BITRATE}/1000);
   }
   else
   {
       my $info = `$c->{ffmpeg} -i "$file_tmp" 2>&1`;
       ($f->{file_spec_txt}) = $info=~/(Input #.+)$/is;
       $f->{file_spec_txt}=~s/\nAt least one.+$//i;

       ($f->{ID_AUDIO_RATE}) = $info=~/, (\d+) Hz,/i;
       ($f->{ID_VIDEO_WIDTH},$f->{ID_VIDEO_HEIGHT}) = $info=~/, (\d{3,4})x(\d{3,4})/i;
       my ($durH,$durM,$durS) = $info=~/Duration: (\d+):(\d+):(\d+)/i;
       $f->{ID_LENGTH} = $durH*3600 + $durM*60 + $durS;
       ($f->{ID_AUDIO_BITRATE}) = $info=~/Audio:.+?, (\d+) kb\/s/i;
       ($f->{ID_VIDEO_BITRATE}) = $info=~/, (\d+) kb\/s,/i;
       unless($f->{ID_VIDEO_BITRATE})
       {
           ($f->{ID_VIDEO_BITRATE}) = $info=~/bitrate: (\d+) kb\/s/i;
           $f->{ID_VIDEO_BITRATE} = $f->{ID_VIDEO_BITRATE}-$f->{ID_AUDIO_BITRATE} if $f->{ID_VIDEO_BITRATE};
       }
       ($f->{ID_AUDIO_RATE}) = $info=~/, (\d+) Hz,/i;
       ($f->{ID_VIDEO_CODEC}) = $info=~/Video: (.+?)[\(\,]/i;
       ($f->{ID_AUDIO_CODEC}) = $info=~/Audio: (\w+?)[\,\s]/i;
       ($f->{ID_DEMUXER}) = $info=~/Input #\d+, (.+?), from/i;
       ($f->{ID_VIDEO_FPS})   = $info=~/, ([\d\.]+) tbr,/i;
       ($f->{ID_VIDEO_FPS}) ||= $info=~/, ([\d\.]+) fps,/i;
       $f->{srt}=1 if $info=~/Subtitle: (ass|srt|webvtt)/i;
       ($f->{video_map}) = $info=~/Stream #(\d+:\d+).*: Video:/i;
	   my @as;
	   push @as,$1 while $info=~/Stream #(\d+:\d+).+?: Audio:/ig;
	   $f->{audio_map} = \@as;

       $file_spec = join('|', map{$f->{$_}}@fields );
   }
   $f->{ID_VIDEO_CODEC}=~s/^ffo//gi;
   $f->{ID_VIDEO_CODEC}=~s/^ff//gi;
   $f->{ID_VIDEO_CODEC}=~s/(^\s+|\s+$)//gi;
   $f->{ID_VIDEO_CODEC}='MPEG2' if $f->{ID_VIDEO_CODEC} eq 'mpeg2video';
   $f->{ID_AUDIO_CODEC}='AAC' if $f->{ID_AUDIO_CODEC}=~/^(faad|faac)$/i;
   $f->{ID_AUDIO_CODEC}='PCM' if $f->{ID_AUDIO_CODEC}=~/^PCM_\w+/i;
   $f->{ID_VIDEO_FPS}=~s/\.000$//;
   $f->{ID_DEMUXER}='mp4' if $f->{ID_DEMUXER}=~/(mp4|m4a)/i;
   $f->{ID_DEMUXER}='' unless $f->{ID_DEMUXER}=~/^avi|flv|mp4|mkv|mpeg|wmv$/i;
   $f->{ID_DEMUXER}||='flv' if $filename=~/\.flv$/i;
   $f->{ID_DEMUXER}||='mp4' if $filename=~/\.mp4$/i;
   $f->{ID_VIDEO_BITRATE}||=128;

   $file_spec = join('|', map{$f->{$_}}@fields );

   return $file_spec;
}

sub getVideoSRTs
{
	my ($file_tmp,$f) = @_;
	my $hh;
	my @extra_langs=('cat','bul','may','ind','tha');
	my $elid=0;
	my @arr;
	for( grep{$_->{codec_type} eq 'subtitle'} @{$f->{file_spec_json}->{streams}} )
	{
		my $sid = $_->{index};
		my $slang = $_->{tags} ? $_->{tags}->{language}||'eng' : 'eng';
		my $srt = `$c->{ffmpeg} -i "$file_tmp" -vn -an -map 0:$sid -f webvtt -`;
		if( $hh->{$slang} && length($hh->{$slang}) > length($srt) ){ next; }
		push @arr, $slang unless $hh->{$slang};
		$hh->{$slang} = $srt;
	}

	return ($hh, join('|',@arr) );
}

sub getVideoSRTsOLD
{
  my ($file_tmp,$f) = @_;
  my $txt = `$c->{ffmpeg} -i "$file_tmp" 2>&1`;

  my $hh;
  my @extra_langs=('cat','bul','may','ind');
  my $elid=0;
  while($txt=~/Stream #(\d+:\d+)(.*?): Subtitle/gi)
  {
    my ($sid,$slang)=($1,$2);
    $slang=$1 if $slang=~/\(\w\w\w\)/;
    $slang||='eng';

    my $srt = `$c->{ffmpeg} -i "$file_tmp" -vn -an -map $sid -f webvtt -`;
    $slang = $extra_langs[$elid++] if $hh->{$slang};
    $hh->{$slang} = $srt;
  }

  my @arr;
  push @arr, "$_|||$hh->{$_}" for keys %$hh;

  return join('^^^',@arr);
}

sub postMain
{
	my ($data) = @_;
	$uax ||= LWP::UserAgent->new(agent => $c->{user_agent}, timeout => 300);

	my $try=0;
	LOOP:

	my $res = $uax->post("$c->{site_url}/fs",
	                  {
	                     dl_key => $c->{dl_key},
	                     host_id => $c->{host_id},
	                     %$data,
	                  }
	                 );
	unless($res->is_success)
	{
		print STDERR "fs.cgi error: ".$res->status_line." : ".$res->content;
		if(++$try<=3){sleep(2);goto LOOP;}
	}

	return $res;
}

sub postMainQuick
{
	my ($data) = @_;
	$uaxs ||= LWP::UserAgent->new(agent => $c->{user_agent}, timeout => 3);

	return $uaxs->post("$c->{site_url}/fs",
	                  {
	                     dl_key => $c->{dl_key},
	                     host_id => $c->{host_id},
	                     %$data,
	                  }
	                 );
}

1;
