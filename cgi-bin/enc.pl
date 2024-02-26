#!/usr/bin/perl
use strict;
#use warnings;
use lib '.';
use XFSConfig;
use LWP::UserAgent;
use File::Copy;
use XUpload;
use JSON;
use File::Flock::Tiny;
exit if $ENV{REMOTE_ADDR}; # allow only run from console

# ping main server with encoding progress each X secs
my $progress_update_interval = 10;

my $restart;
$SIG{HUP} = sub { $restart=1 };

print("Host Encoder processes=0\n"),exit unless $c->{host_max_enc};
my @xx=`ps ax|grep enc.pl`;
@xx = grep {$_!=$$} map{/^\s*(\d+)/;$1} grep{/perl/} @xx;
print join("\n", @xx),"\n";
print("reached max processes list\n"),exit if scalar(@xx)>=$c->{host_max_enc};

$SIG{ALRM} = sub {
   kill -9, $$;
};

$c->{ffmpeg}||="$c->{cgi_dir}/ffmpeg";

require Log;
my $log = Log->new(filename=>'enc.txt');

my ($cycles,$length_changed);
while(++$cycles < 1000)
{
   print("Exiting on signal"),exit if $restart;

   my $str = XUpload::postMain({
		                       op           => "queue_enc_next",
		                       }
		                      )->content;

 $str=~s/[\n\r]+//g;
 print(".\n"),sleep(1+$c->{host_max_enc}*4),next unless $str;
 print $str,"\n";

 my $dd = JSON::decode_json($str);

 my ($disk_id,$real_id,$file_real,$type,$video_settings) = ($dd->{disk_id},$dd->{file_real_id},$dd->{file_real},$dd->{type},$dd->{settings});
 
 print"Disk:$disk_id  file_real_id:$real_id file_real:$file_real type:$type\n";
 if($file_real eq 'RESTART')
 {
    print("Exiting on restart...\n");
    `killall -HUP enc.pl`;
    exit;
 }

 sleep(10),next unless $file_real; # some bad answer returned from main

 my $dx = sprintf("%05d",$real_id/$c->{files_per_folder});
 my $dir_uploads  = "$c->{cgi_dir}/uploads/$disk_id/$dx";
 my $file = "$c->{cgi_dir}/uploads/$disk_id/$dx/$file_real\_o";
 print"FILE:$file\n";

 unless(-d $dir_uploads)
 {
    my $mode = 0777;
    mkdir $dir_uploads, $mode;
    chmod $mode, $dir_uploads;
 }

 sleep(10) unless -e $file; # Hack for files not flushed to disk yet
 # Hack for re-encode when no Original exist
 move("$dir_uploads/$file_real\_h",$file) if !-f $file && -f "$dir_uploads/$file_real\_h";
 move("$dir_uploads/$file_real\_n",$file) if !-f $file && -f "$dir_uploads/$file_real\_n";
 move("$dir_uploads/$file_real\_l",$file) if !-f $file && -f "$dir_uploads/$file_real\_l";
 unless(-e $file)
 {
     $log->log("Source file not found: $file. Skipping.");
     sendError($real_id,"Source file not found: $file");
     next;
 }



 my $vdata={};
 XUpload::getVideoInfo($file,$vdata);

 $video_settings->{$_}=$vdata->{$_} for keys %$vdata;
 my $length = $vdata->{ID_LENGTH};
 my ($width,$height) = ($vdata->{ID_VIDEO_WIDTH},$vdata->{ID_VIDEO_HEIGHT});
 $video_settings->{srt} = $vdata->{srt};
 $video_settings->{vid_audio_bitrate} = $vdata->{ID_AUDIO_BITRATE} if $vdata->{ID_AUDIO_BITRATE} && $vdata->{ID_AUDIO_BITRATE} < $video_settings->{vid_audio_bitrate};
 $video_settings->{vid_audio_rate} = '' if $vdata->{ID_AUDIO_RATE} && $vdata->{ID_AUDIO_RATE} < $video_settings->{vid_audio_rate};

 # VOB aspect ratio fix
 if($vdata->{file_spec_txt}=~/Video: mpeg2/i)
 {
    my ($a1,$a2) = $vdata->{file_spec_txt}=~/DAR (\d+):(\d+)/;
    $height = sprintf("%.0f", $width * $a2 / $a1 );
 }

 my $file_path = "$dir_uploads/$file_real\_o";  # Construct the full path to the file

 # Use ffprobe to check if the file is a video
 my $ffprobe_output = `ffprobe -v error -select_streams v -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $file_path`;
 my $is_audio_file = ($ffprobe_output !~ /h264|h265|hevc|mpeg1|mpeg2|mpeg3|mpeg4|mpeg4part2|mpeg4v2|vp8|vp9|av1|theora|divx|xvid|wmv|prores|cinepak|svq|h263|h261|dnxhd|dnxhr|vc1/);
 chomp $ffprobe_output;  # Remove any trailing newline

 # Initialize the file extension variable
 my $file_extension = '.mp4';  # Default to .mp4 

 print"($width x $height)($length secs)\n";

unless(($width && $height && $length) || ($is_audio_file && $length)) {
    $log->log("Can't parse video info for $file: $vdata->{file_spec_txt}");
    sendError($real_id,"Can't parse video info for $file");
    next;
}

 my $filenew = "$dir_uploads/$file_real\_$type";
 if(-s $filenew && !$video_settings->{reencode})
 {
	$log->log("File $filenew already exist and its not reencode. Skipping.");
	next;
 }

 my $error;
 $length_changed=0;
 if($type eq 'p')
 {
    $error = EncodePreview( $disk_id, $dir_uploads, $file_real, $real_id, $video_settings );
 }
 elsif ($ffprobe_output =~ /h264|h265|hevc|mpeg1|mpeg2|mpeg3|mpeg4|mpeg4part2|mpeg4v2|vp8|vp9|av1|theora|divx|xvid|wmv|prores|cinepak|svq|h263|h261|dnxhd|dnxhr|vc1/)
 {
    $error = EncodeVideo( $disk_id, $dir_uploads, $file_real, $real_id, $type, $width, $height, $video_settings );
 } 
 else 
 {
    $file_extension = '.mp3';  # Change the extension to .mp3 for audio files
    $error = EncodeAudio( $disk_id, $dir_uploads, $file_real, $real_id, $type, $video_settings );
 }
 
 if($error)
 {
     $log->log("Enc error:$error");
     unlink("$dir_uploads/$file_real\_$type$file_extension");
     unlink($filenew);
     sendError($real_id,$error);
     sleep 1;
     next;
 }

 my $file_size = -s $filenew;
 print"Filesize:$file_size\n";

 my $vinfo;
 my $file_spec = XUpload::getVideoInfo($filenew,$vinfo);

 my $length2 = $vinfo->{ID_LENGTH} if $length_changed;

 my $res = XUpload::postMain({
							op              => "queue_enc_done",
							file_real_id    => $real_id,
							quality         => $type,
							file_size       => $file_size,
							file_real       => $file_real,
							length_new      => $length2,
							file_spec       => $file_spec,
							})->content;
 print"FS:$res\n";
 #sleep 1;
}

sub EncodeAudio 
{
 my ($disk_id, $dir_uploads, $code, $real_id, $type, $settings) = @_;

 my $length = $settings->{ID_LENGTH};
 $settings->{'length'} = $length; # for watermark only

   
 if ($settings->{ID_VIDEO_FPS}<1) { # If fps not found, it's and audio file
   if ($settings->{ID_AUDIO_BITRATE}<199 || $settings->{ID_LENGTH}>1200) {
      print "Skipping audio encoding due to bitrate being less than 199\n";
      my $file = { file_path => "$dir_uploads/$code\_$type", 
                  file_real => $code, 
                  file_real_id => $real_id,
                  file_length => $length,
                  disk_id => $disk_id };
      my $error = XUpload::Wave($file);
      $log->log($error) if $error;
      return 0;
   } 
 }  

 my $file_enc = "$c->{cgi_dir}/temp/$disk_id/$code\_$type.mp3";

 return "Qmode=$settings->{vid_quality_mode}, Arate=$settings->{vid_audio_bitrate}" unless $settings->{vid_quality_mode} && $settings->{vid_audio_bitrate};

 my $file = "$dir_uploads/$code\_o";
 return "File not found on disk: $file" unless -f $file;

 my $x = File::Flock::Tiny->trylock($file_enc);
 return "already encoding" unless $x;

 my $audio_str = "-c:a libmp3lame -q:a 5 -vn -map a -map_metadata 0:s:0 -threads 1";

 # -async 1 (before -i)
 my $timeout = $c->{no_ffmpeg_timeout} ? '' : 'timeout -s 9 3h ';
 my $input_str = "$timeout$c->{ffmpeg} -analyzeduration 6000M -probesize 2147M -i $file -max_muxing_queue_size 9999 -y";
 my $ffmpeg_string; 

 $ffmpeg_string="$input_str $audio_str -threads 1 $file_enc";
 print"ENC STR: $ffmpeg_string\n";

 alarm(3600*3); # fire alarm after 3 hours
 $/="\r";
 open F, "$ffmpeg_string 2>&1|";
 my $t=0;
 my $last;
 while(<F>)
 {
    print "FFMPEG Output: $_\n";  # Add this line for debugging
    $last=$_;
    next if time < ($t+$progress_update_interval);
    #next unless $_=~/frame=/i;
    $t=time;
    my ($ct,$ctt) = $_=~/time=([\d\:]+)\.(\d+)/i;
    my ($fps) = $_=~/fps=\s*(\d+)/i;
    $ct = $1*3600 + $2*60 + $3 if $ct=~/^(\d+):(\d+):(\d+)$/;
    $ct+=sprintf("%.0f",$ctt/100);
    my $res = XUpload::postMainQuick(
			                       {
				                       op              => "enc_progress",
				                       file_real_id    => $real_id,
				                       file_real		=> $code,
				                       progress        => sprintf("%.0f",100*$ct/$length),
				                       fps             => $fps||0,
				                       quality         => $type,
			                       }
			                       );
 }
 $/="\n";
 alarm(0); # stop alarm

 print"LAST:$last\n";
 unless($last=~/video:\d+/is)
 {
    $log->log("Error while encoding file $file : $last");
    $last=(split(/\n/,$last))[-1];
    sendError($real_id,$last);
    unlink($file_enc);
    next;
 }

 my $fsize = -s $file_enc;
 print"Fsize:$fsize\n";

 my $target_file = "$dir_uploads/$code\_$type";
 
 if($fsize)
 {
    move($file_enc,$target_file) || return "can't rename $file_enc to $target_file : $!";
    print"renamed $target_file\n\n";
 }
 else
 {
 	$log->log("Error while encoding file $file to $file_enc : zero filesize");
    sendError($real_id,"empty result file");
    next;
 }

 unlink($file_enc);

my $file = { file_path		=> $target_file, 
   file_real		=> $code, 
   file_real_id	=> $real_id,
   file_length 	=> $length,
   disk_id			=> $disk_id,
};

   my $error = XUpload::Wave( $file );
   $log->log($error) if $error;

 return 0;
}

############################

sub EncodeVideo
{
 my ($disk_id, $dir_uploads, $code, $real_id, $type, $width, $height, $settings) = @_;

 my $length = $settings->{ID_LENGTH};
 $settings->{'length'} = $length; # for watermark only

 my $file_enc = "$c->{cgi_dir}/temp/$disk_id/$code\_$type.mp4";

 return "Qmode=$settings->{vid_quality_mode}, Arate=$settings->{vid_audio_bitrate}" unless $settings->{vid_quality_mode} && $settings->{vid_audio_bitrate};

 my $file = "$dir_uploads/$code\_o";
 return "File not found on disk: $file" unless -f $file;

 my $x = File::Flock::Tiny->trylock($file_enc);
 return "already encoding" unless $x;

 my $enc_mode;
 if($settings->{vid_quality_mode} eq 'crf')
 {
     $enc_mode="-crf $settings->{vid_quality}";
 }
 else
 {
     $enc_mode="-b:v $settings->{vid_bitrate}k";
 }

 my $fpsnew = $settings->{ID_VIDEO_FPS};
 $fpsnew=~s/[^\d\.\/]+//g;
 $fpsnew=$settings->{max_fps_limit} if $settings->{max_fps_limit} && eval"$fpsnew">$settings->{max_fps_limit}; # limit to X fps if original if higher
 $fpsnew = $settings->{vid_fps} if $settings->{vid_fps} && $settings->{vid_fps}=~/^\d+$/;
 my $gop = sprintf("%.0f", eval"$fpsnew * 5" ); # I-frame each 5 seconds
 #my $gop2 = $gop*2;
 #my $fps_limit=qq[-force_key_frames "expr:eq(mod(n,$gop),0)" -x264opts rc-lookahead=$gop:keyint=$gop2:min-keyint=$gop] unless $settings->{turbo_boost};
 my $fps_limit=qq[-g $gop -keyint_min $gop -sc_threshold 0] unless $settings->{turbo_boost};
 $fps_limit.=" -r $fpsnew";

 $settings->{vid_preset}||='medium';

 my ($resize_w,$resize_h) = $settings->{vid_resize}=~/^(\d*)x(\d*)$/;
 my ($wnew,$hnew) = makeNewSize( $width,$height, $resize_w,$resize_h );
 print"Video resize: $wnew:$hnew pixels\n";

 my @vf;
 push @vf, "yadif" if $settings->{deinterlace};

 if($settings->{cropl} || $settings->{cropt} || $settings->{cropr} || $settings->{cropb} || $settings->{crop_auto})
 {
    if($settings->{crop_auto})
    {
        my $x = `$c->{ffmpeg} -ss 5 -i $file -t 1 -an -sn -vf cropdetect=30:2 -y /tmp/crop.mp4 2>&1`;
        print"$x\n";
        my ($cw,$ch,$cdx,$cdy) = $x=~/crop=(\d+):(\d+):(\d+):(\d+)/i;
        print"CROP:($cw,$ch,$cdx,$cdy)\n";
        push @vf, "crop=$cw:$ch:$cdx:$cdy";
        $wnew = $cw;
        $hnew = $ch;
    }
    else
    {
        $settings->{cropl}||=0;
        $settings->{cropt}||=0;
        my $dxx = $settings->{cropl}+$settings->{cropr};
        my $dyy = $settings->{cropt}+$settings->{cropb};
        push @vf, "crop=in_w-$dxx:in_h-$dyy:$settings->{cropl}:$settings->{cropt}";
        $wnew = $wnew-$dxx;
        $hnew = $hnew-$dyy;
    }
 }

 push @vf, "hue='s=0'" if $settings->{grayscale};
 push @vf, "transpose=$settings->{rotate}" if $settings->{rotate} && $settings->{rotate}=~/^(1|2)$/;
 push @vf, "scale=$wnew:$hnew" if $wnew && $hnew;
 push @vf, "hqdn3d=2:2:6:6" if $settings->{denoise};
 #$settings->{srt_burn_color}=lc $settings->{srt_burn_color};
 #$settings->{srt_burn_coloroutline} = lc $settings->{srt_burn_coloroutline};
 if($settings->{srt_burn} && $settings->{srt})
 {
 	my $blackbox=",BorderStyle=3" if $settings->{srt_burn_blackbox};
 	#$settings->{srt_burn_size} = sprintf("%.0f", $1*$hnew/100 ) if $settings->{srt_burn_size}=~/^([\d\.]+)\%$/;
 	my $burn_index;
 	if($settings->{srt_burn_default_language})
 	{
 		my $xtrack='';
 		my $cx=0;
	    for(@{$settings->{subs}}){ $xtrack=$cx if $_->{tags}->{language} eq $settings->{srt_burn_default_language} && $_->{codec_name}!~/^(hdmv_pgs_subtitle|dvd_subtitle)$/i; $cx++; }
	    $burn_index = ":si=$xtrack" if $xtrack=~/^\d+$/;
 	}
 	push @vf, "subtitles=$file$burn_index:fontsdir=$c->{cgi_dir}/Modules/fonts:force_style='FontName=$settings->{srt_burn_font},FontSize=$settings->{srt_burn_size},MarginV=$settings->{srt_burn_margin},PrimaryColour=&H$settings->{srt_burn_color},SecondaryColour=&H$settings->{srt_burn_coloroutline}$blackbox'" if $burn_index;
 }

 my $videofilters = $settings->{watermark_mode} ? configureWatermark($settings,@vf) : @vf ? '-vf "'.join(',', @vf).'"' : '';

 my $flags = '-movflags faststart';
 $flags .= " -pix_fmt yuv420p"; # better compatibility and less errors
 $flags .= ' -sws_flags lanczos' if $settings->{vid_resize_method}; # better-slower resize for geeks
 $flags .= " -map_chapters -1 -map_metadata -1";
 $flags .= ' -refs 1' if $settings->{turbo_boost};
 my $flags_audio_streams;
 if($settings->{audios})
 {
	 my $video_index = @{$settings->{videos}}[0]->{index} if $settings->{videos};
	 if($settings->{multi_audio_on})
	 {
	 	my @audio_streams;
	 	if($settings->{default_audio_lang})
	 	{
	 		push @audio_streams, grep{$_->{lang} eq $settings->{default_audio_lang}} @{$settings->{audios}};
	 		push @audio_streams, grep{$_->{lang} ne $settings->{default_audio_lang}} @{$settings->{audios}};
	 	}
	 	else
	 	{
	 		push @audio_streams, @{$settings->{audios}};
	 	}
	 	my $ind=0;
	 	$flags_audio_streams .= " -map 0:$video_index ".join ' ', map{"-map 0:$_->{index} -metadata:s:a:".$ind++." language='$_->{lang}'"} @audio_streams;

	 	## Put subtitles into MP4:
	 	#$flags_audio_streams .= join ' ', map{" -map 0:$_->{index} -metadata:s:s:".$ind++." language=".$_->{tags}->{language}} @{$settings->{subs}};
	 	# $flags_audio_streams .= ' -c:s mov_text';
	 	###-metadata:s:s:0 language=spa -metadata:s:s:1 language=eng
	 }
	 elsif($settings->{default_audio_lang})
	 {
	 	my $stream_index;
	 	for(@{$settings->{audios}})
	 	{
	 		$stream_index=$_->{index} if $_->{lang} eq $settings->{default_audio_lang};
	 	}
	 	$flags_audio_streams .= " -map 0:$video_index -map 0:$stream_index" if $stream_index;
	 }
 }
 $flags .= $flags_audio_streams;
 #$flags .= " -map_chapters -1 -map_metadata -1"; # -map 0:v:0 -map 0:a:0  or -map 0:0 -map 0:1
 #$flags .= " -map $settings->{video_map}" if $settings->{video_map};
 #$flags .= " -map $_" for @{$settings->{audio_map}};
 if($settings->{vid_crf_bitrate_max} && $settings->{vid_crf_bitrate_max}=~/^\d+$/)
 {
    $settings->{vid_crf_bitrate_max} = int($settings->{vid_crf_bitrate_max} * $hnew / $resize_h) if $resize_h && $hnew < $resize_h; # hack for lower resolutions
    my $bufsize = $settings->{vid_crf_bitrate_max}*5; # 5 seconds limit interval
    $flags .= " -maxrate $settings->{vid_crf_bitrate_max}k -bufsize $bufsize".'k';
 }

 if($settings->{tt1} && $settings->{tt1}=~/^[\d\:\.]+$/)
 {
    $settings->{tt1}=$1*3600 + $2*60 + $3 if $settings->{tt1}=~/^(\d+):(\d+):(\d+)$/;
    $settings->{tt1}=$1*60 + $2 if $settings->{tt1}=~/^(\d+):(\d+)$/;
    $flags .= " -ss $settings->{tt1}";
    $length_changed=1;
 }
 if($settings->{tt2} && $settings->{tt2}=~/^[\d\:\.]+$/ && $settings->{tt1} && $settings->{tt1}=~/^[\d\.]*$/)
 {
    $settings->{tt2}=$1*3600 + $2*60 + $3 if $settings->{tt2}=~/^(\d+):(\d+):(\d+)$/;
    $settings->{tt2}=$1*60 + $2 if $settings->{tt2}=~/^(\d+):(\d+)$/;
    $flags .= " -t ".($settings->{tt2}-$settings->{tt1});
    $length_changed=1;
 }
 # if($settings->{vid_mobile_support})
 # {
 #    $flags .= " -profile:v main -level 3.1";
 # }
 
 my $audio_channels = $settings->{vid_audio_channels} ? "-ac $settings->{vid_audio_channels}" : ""; # Mono/Stereo or default
 my $audio_rate = "-ar $settings->{vid_audio_rate}" if $settings->{vid_audio_rate};
 my $audio_codec = 'aac';
 $settings->{vid_audio_bitrate}||=128;
 my $audio_filter= "-af 'volume=$settings->{volume}'" if $settings->{volume} && $settings->{volume}=~/^[\d\.]+$/;
 my $audio_str = $settings->{transcode_audio} ? "-c:a copy" : "-c:a $audio_codec $audio_rate -b:a $settings->{vid_audio_bitrate}k $audio_channels $audio_filter";
 #$audio_str.=" -cutoff 18000" if $settings->{vid_audio_bitrate}>100 && $audio_codec eq 'libfdk_aac'; # tune low-pass cutoff filter

 my $video_str = "-c:v libx264 -preset $settings->{vid_preset} $fps_limit $enc_mode $videofilters";

 # -async 1 (before -i)
 my $timeout = $c->{no_ffmpeg_timeout} ? '' : 'timeout -s 9 3h ';
 my $input_str = "$timeout$c->{ffmpeg} -analyzeduration 6000M -probesize 2147M -i $file -max_muxing_queue_size 9999 -y";
 my $ffmpeg_string;
 if($settings->{transcode_video}) # Just transcode video
 {
    $ffmpeg_string="$input_str $audio_str -c:v copy -movflags faststart -map_chapters -1 -map_metadata -1 $flags_audio_streams -threads 1 $file_enc";
 }
 else
 {
    $ffmpeg_string="$input_str $audio_str $video_str $flags -threads 0 $file_enc";
 }

 print"ENC STR: $ffmpeg_string\n";

 alarm(3600*3); # fire alarm after 3 hours
 $/="\r";
 open F, "$ffmpeg_string 2>&1|";
 #my $ua2 = LWP::UserAgent->new(agent => $c->{user_agent}, timeout => 5);
 my $t=0;
 my $last;
 while(<F>)
 {
   print "FFMPEG Output: $_\n";  # Add this line for debugging
    #print"$_\n";
    $last=$_;
    next if time < ($t+$progress_update_interval);
    next unless $_=~/frame=/i;
    $t=time;
    my ($ct,$ctt) = $_=~/time=([\d\:]+)\.(\d+)/i;
    my ($fps) = $_=~/fps=\s*(\d+)/i;
    $ct = $1*3600 + $2*60 + $3 if $ct=~/^(\d+):(\d+):(\d+)$/;
    $ct+=sprintf("%.0f",$ctt/100);
    my $res = XUpload::postMainQuick(
			                       {
				                       op              => "enc_progress",
				                       file_real_id    => $real_id,
				                       file_real		=> $code,
				                       progress        => sprintf("%.0f",100*$ct/$length),
				                       fps             => $fps||0,
				                       quality         => $type,
			                       }
			                       );
 }
 $/="\n";
 alarm(0); # stop alarm

 print"LAST:$last\n";
 unless($last=~/video:\d+/is)
 {
    $log->log("Error while encoding file $file : $last");
    $last=(split(/\n/,$last))[-1];
    sendError($real_id,$last);
    unlink($file_enc);
    next;
 }

 my $fsize = -s $file_enc;
 print"Fsize:$fsize\n";

 my $target_file = "$dir_uploads/$code\_$type";
 
 if($fsize)
 {
    move($file_enc,$target_file) || return "can't rename $file_enc to $target_file : $!";
    print"renamed $target_file\n\n";
 }
 else
 {
 	$log->log("Error while encoding file $file to $file_enc : zero filesize");
    sendError($real_id,"empty result file");
    #unlink($file_enc);
    next;
 }

 unlink($file_enc);

 if( $c->{m_z} )
 {
    my $file = { file_path		=> $target_file, 
    			file_real		=> $code, 
    			file_real_id	=> $real_id,
    			file_length 	=> $length,
    			disk_id			=> $disk_id,
    			 };

    my $error = XUpload::createTimeslides( $file );
    $log->log($error) if $error;
 }

 return 0;
}
### end of EncodeVideo #########################

sub makeNewSize
{
    my ($width,$height, $resize_w,$resize_h) = @_;
    my ($wnew,$hnew);
    if($resize_w && !$resize_h)
    {
        $wnew = $resize_w<$width ? $resize_w : $width;
        $hnew = sprintf("%.0f", ($height * $wnew/$width) );
    }
    elsif(!$resize_w && $resize_h)
    {
        $hnew = $resize_h<$height ? $resize_h : $height;
        $wnew = sprintf("%.0f", ($width * $hnew/$height) );
    }
    elsif(!($resize_w || $resize_h) || ($width<=$resize_w && $height<=$resize_h) )
    {
        # empty resize parameters or video is smaller both sides - no resize
        $wnew = $width;
        $hnew = $height;
    }
    else
    {
        $wnew = $resize_w;
        $hnew = sprintf("%.0f", ($height * $resize_w/$width) );

        if($hnew > $resize_h)
        {
            $wnew = sprintf("%.0f", ($width * $resize_h/$height) );
            $hnew = $resize_h;
        }
    }

    # Improve size for better compression
    my $block=4; # block size. possible values: 2,4,8,16,32
    $wnew = sprintf("%.0f", $wnew / $block) * $block;
    $hnew = sprintf("%.0f", $hnew / $block) * $block;    
    return ($wnew,$hnew);
}

sub configureWatermark
{
    my ($settings,@vf) = @_;
    my $watermark;
    my $vff = join(',', @vf); 
    $vff = $vff.',' if $vff;
     if($settings->{watermark_mode} eq 'text')
     {
         my $x = $settings->{watermark_padding} if $settings->{watermark_position}=~/^(nw|w|sw)$/i;
         $x = '(w-tw)/2' if $settings->{watermark_position}=~/^(n|c|s)$/i;
         $x = 'w-tw-'.$settings->{watermark_padding} if $settings->{watermark_position}=~/^(ne|e|se)$/i;

         my $y = $settings->{watermark_padding} if $settings->{watermark_position}=~/^(nw|n|ne)$/i;
         $y = '(h-th)/2' if $settings->{watermark_position}=~/^(w|c|e)$/i;
         $y = 'h-th-'.$settings->{watermark_padding} if $settings->{watermark_position}=~/^(sw|s|se)$/i;

         my $draw = 1;
         $draw = '(lt(t\,'.$settings->{watermark_dispose_time}.')+gt(t\,'.($settings->{'length'}-$settings->{watermark_dispose_time}).'))' if $settings->{watermark_dispose_mode} eq 'start_end';
         $draw = 'lt(mod(t\,'.$settings->{watermark_dispose_blink1}.')\,'.$settings->{watermark_dispose_blink2}.')' if $settings->{watermark_dispose_mode} eq 'blink';

         my $shadow=":shadowy=1:shadowx=1:shadowcolor=$settings->{watermark_shadow_color}\@$settings->{watermark_opacity}" if $settings->{watermark_shadow_color};
         my $font="Modules/fonts/$settings->{watermark_font}.ttf" if -f "Modules/fonts/$settings->{watermark_font}.ttf";

         $watermark=qq[-vf "$vff drawtext=fontfile=$font:fontsize=$settings->{watermark_size}:fontcolor=$settings->{watermark_color}\@$settings->{watermark_opacity}$shadow:x=$x:y=$y:enable=$draw:text=$settings->{watermark_text}"]
             if $settings->{watermark_text};
     }
     if($settings->{watermark_mode} eq 'scroll')
     {
         my $y = $settings->{watermark_padding} if $settings->{watermark_position} eq 'top';
         $y = '(h-th)/2' if $settings->{watermark_position} eq 'middle';
         $y = 'h-th-'.$settings->{watermark_padding} if $settings->{watermark_position} eq 'bottom';

         my $shadow=":shadowy=1:shadowx=1:shadowcolor=$settings->{watermark_shadow_color}\@$settings->{watermark_opacity}" if $settings->{watermark_shadow_color};

         my $mod = int $settings->{watermark_scroll_start}+$settings->{watermark_scroll_length}*1.5;
         my $x = "(w-(mod(t\\,$mod)-$settings->{watermark_scroll_start})*w/$settings->{watermark_scroll_length})";
         my $font="Modules/fonts/$settings->{watermark_font}.ttf" if -f "Modules/fonts/$settings->{watermark_font}.ttf";

         $watermark=qq[-vf "$vff drawtext=fontfile=$font:fontsize=$settings->{watermark_size}:fontcolor=$settings->{watermark_color}\@$settings->{watermark_opacity}$shadow:x=$x:y=$y:text=$settings->{watermark_text}"]
             if $font && $settings->{watermark_text};
     }
     if($settings->{watermark_mode} eq 'image' && $settings->{watermark_image_url})
     {
         my $logo = "$c->{htdocs_dir}/i/watermark_$settings->{usr_id}.png";
         my $watermark_mov = "$c->{htdocs_dir}/i/watermark_$settings->{usr_id}.mov";
         my $watermark_logo;
         my $wsize = -s $logo;
         $settings->{watermark_padding}||=0;
         if($wsize != $settings->{watermark_image_size} || (!-f $watermark_mov && $settings->{watermark_fade}))
         {
             my $ua = LWP::UserAgent->new(agent => $c->{user_agent}, timeout => 90);
             my $res = $ua->get( $settings->{watermark_image_url}, ':content_file' => $logo );
             #print $res->content,"\n";
             if(-f $logo && $settings->{watermark_fade})
             {
                 my $fadeout_frames = 30; # fadeout length is about 1 sec
                 my $frames = 24 * $settings->{watermark_image_fadeout} + 1; # assuming 24 FPS
                 my $fade_start = $frames - $fadeout_frames - 1;
                 my $ffmpeg_mov=qq[$c->{ffmpeg} -y -loop 1 -i $logo -vframes $frames -vf "fade=out:$fade_start:$fadeout_frames:alpha=1" -vcodec png -pix_fmt rgba $watermark_mov];
                 print"FFMOV:$ffmpeg_mov\n";
                 `$ffmpeg_mov`;
             }
         }
         if(-f $watermark_mov && $settings->{watermark_fade})
         {
              $watermark_logo = $watermark_mov;
         }
         elsif(-f $logo)
         {
            $watermark_logo = $logo;
         }
         my $x = $settings->{watermark_padding} if $settings->{watermark_position}=~/^(nw|w|sw)$/i;
         $x = '(main_w-overlay_w)/2' if $settings->{watermark_position}=~/^(n|c|s)$/i;
         $x = 'main_w-overlay_w-'.$settings->{watermark_padding} if $settings->{watermark_position}=~/^(ne|e|se)$/i;

         my $y = $settings->{watermark_padding} if $settings->{watermark_position}=~/^(nw|n|ne)$/i;
         $y = '(main_h-overlay_h)/2' if $settings->{watermark_position}=~/^(w|c|e)$/i;
         $y = 'main_h-overlay_h-'.$settings->{watermark_padding} if $settings->{watermark_position}=~/^(sw|s|se)$/i;
         my $vff = "overlay=$x:$y,".join(',', @vf); 
         $watermark=qq[-vf "movie=$watermark_logo [logo]; [in][logo] $vff [out]"] if -s $watermark_logo;
     }
     return $watermark;
}

sub EncodePreview
{
 my ($disk_id, $dir_uploads, $code, $real_id, $settings) = @_;

 my $length = $settings->{ID_LENGTH};

 my $file = "$dir_uploads/$code\_$settings->{m_p_source}";
 $file = "$dir_uploads/$code\_l" unless -e $file; # try Low
 $file = "$dir_uploads/$code\_n" unless -e $file; # try Norm
 $file = "$dir_uploads/$code\_h" unless -e $file; # try HD
 $file = "$dir_uploads/$code\_x" unless -e $file; # try UHD
 $file = "$dir_uploads/$code\_o" unless -e $file; # try Low
 unless(-f $file)
 {
    my $error = "File not found on disk preview: $file";
    $log->log($error);
    sendError($real_id,$error);
    return;
 }

 my $parts = $settings->{m_p_parts};
 my $dt = $parts>1 ? $length/($parts-1) : 1;
 my $dl = $settings->{m_p_length}/2;

 my $rand = join '', map int rand 10, 1..7;
 my $temp_dir = "$c->{cgi_dir}/temp/$disk_id/$rand";
 mkdir $temp_dir, 0777;

 if($parts*$settings->{m_p_length} > $length/2)
 {
    $parts = int( ($length/2)/$settings->{m_p_length} );
 }
 $parts=1 if $parts<1;

 my @arr;
 for my $i (0..$parts-1)
 {
     my $t = sprintf("%.0f",$i*$dt - $dl);
     $t = $length-$settings->{m_p_length}-5 if $i==($parts-1);
     $t = 5 if $i==0;
     next if $t<0;
     #-async 1 -fflags +igndts -fflags +genpts
     my $ffmpeg_string="$c->{ffmpeg} -fflags +discardcorrupt -ss $t -i $file -t $settings->{m_p_length} -c copy -bsf:v h264_mp4toannexb -f mpegts -y $temp_dir/p$i.ts";
     print"FFMPEG:$ffmpeg_string\n";
     `$ffmpeg_string`;
     push @arr, "$temp_dir/p$i.ts";
 }
 
 my $srcs=join '|', @arr;
 my $dx = sprintf("%05d",$real_id/$c->{files_per_folder});
 my $idir = "$c->{htdocs_dir}/i/$disk_id/$dx";
 mkdir($idir,0777) unless -d $idir;

 `$c->{ffmpeg} -fflags +discardcorrupt -i "concat:$srcs" -c copy -bsf:a aac_adtstoasc -movflags faststart -f mp4 -y $idir/$code\_p.mp4`;

 unlink(@arr);
 rmdir($temp_dir);

 return 0;
}

sub sendError
{
    my ($real_id,$error) = @_;
    my $res = XUpload::postMain(
		                         {op              => "enc_error",
		                          file_real_id    => $real_id,
		                          error           => $error
		                         });
}

# sub parseVideoInfo
# {
#     my ($file) = @_;
#     my @fields = qw(ID_LENGTH ID_VIDEO_WIDTH ID_VIDEO_HEIGHT ID_VIDEO_BITRATE ID_AUDIO_BITRATE ID_AUDIO_RATE ID_VIDEO_CODEC ID_AUDIO_CODEC ID_VIDEO_FPS);
#     my $info = join '', `mplayer "$file" -identify -frames 0 -quiet -ao null -vo null 2>/dev/null | grep ^ID_`;
#     my $f;
#     do{($f->{$_})=$info=~/$_=([\w\.]{2,})/is} for @fields;
#     $f->{ID_LENGTH} = sprintf("%.0f",$f->{ID_LENGTH});
#     ($f->{ID_VIDEO_FPS}) = $info=~/, ([\d\.]+) tbr,/i unless $f->{ID_VIDEO_FPS};
#     return $f;
# }