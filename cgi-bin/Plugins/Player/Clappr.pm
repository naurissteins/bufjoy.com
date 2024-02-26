package Plugins::Player::Clappr;
use strict;
use XFileConfig;
use vars qw($ses $c);

sub makePlayerCode
{
	my ($self, $f, $file, $c, $player ) = @_;
	return if $player ne 'clappr';

    my (@plugins_core, @plugins_playback, @tracks, @playback,
    	$extra, $extra_html_pre, $extra_html, $extra_js, $ontime_func, $extra_pause);

    if($c->{m_z} && $c->{time_slider})
    {
        $extra_html.=qq[<script type="text/javascript" src="/player/clappr/clappr-thumbnails-plugin.js"></script>\n];
        push @plugins_core, 'ClapprThumbnailsPlugin';
        $extra.=",scrubThumbnails: {
        backdropHeight: 80,
        spotlightHeight: 112,
        thumbs: thumbs
      }";
        my $frames = $c->{m_z_cols}*$c->{m_z_rows};
    	my $dt = $file->{file_length}/$frames;
$extra_html.=<<ENP
<script type="text/javascript">
    var spriteSheetUrl = "$file->{img_timeslide_url}";
    var numThumbs = $frames;
    var thumbWidth = 200;
    var thumbHeight = 112;
    var numColumns = $c->{m_z_cols};
    var timeInterval = $dt;

    var thumbs = ClapprThumbnailsPlugin.buildSpriteConfig(spriteSheetUrl, numThumbs, thumbWidth, thumbHeight, numColumns, timeInterval);
</script>
ENP
;
    }
    my $vast_ontime_func;
    if($c->{m_w} && $file->{video_ads} && $c->{vast_tag} && !$ses->getCookie('vastski'))
    {
    	$extra_html.=qq[<script type="text/javascript" src="/player/clappr/clappr-ima-plugin.min.js"></script>\n];
    	push @plugins_core, 'ClapprImaPlugin';
    	my $vpaidmode = {'disabled'=>0, 'enabled'=>1, 'insecure'=>2}->{$c->{vast_vpaid_mode}} || 0;
    	# locale: 'fr', nonLinearMaxDuration: 8000, disableNonLinearForIOS: true,
    	$extra.=qq|,imaPlugin: { disableNonLinearForIOS: true, requestAdIfNoAutoplay: true, onAdPlayerReady: function (adPlay) { adPlayer=adPlay; }, 
    								imaAdPlayer: { tag: '$c->{vast_tag}', vpaidMode: $vpaidmode, maxDuration: 30000 } 
    							} |;
    	if($c->{vast_midroll} && $c->{vast_midroll_time})
    	{
    		my $dtime = $c->{vast_midroll_time}=~/(\d+)\%/ ? int($file->{vid_length}*$1/100) : $c->{vast_midroll_time};
    		$extra_js.=qq|if(vastdone1==0)window.setTimeout( function (){ adPlayer.play(); }, $dtime*1000 );|;
    	}
    	if($c->{vast_postroll} && $c->{vast_postroll_time})
    	{
    		my $dt = $c->{vast_postroll_time}=~/(\d+)\%/ ? int($file->{vid_length}*$1/100) : $c->{vast_postroll_time};
    		my $dtime = $file->{vid_length} - $dt;
    		$vast_ontime_func=qq|if(x.current>=$dtime && vastdone2==0){ vastdone2=1; adPlayer.play(); }|;
    	}
    	if($c->{vast_pauseroll})
		{
			#my $pause_tag = $c->{vast_pauseroll_tag} || $c->{vast_tag};
			#$extra_pause.=qq|if(player.getCurrentTime()>1){alert('123='+player.getCurrentTime());adPlayer.play();}|;
		}
    	$ses->setCookie('vastski','1',"+$c->{vast_skip_mins}m") if $c->{vast_skip_mins} && !$ses->getCookie('vastski');
    }



my $show_box_after_limit=qq[ \$('#play_limit_box').show(); ] if $c->{video_time_limit};
my $time_fadein=$c->{player_ads_fadein}||0;
my $vtime = int $file->{vid_length}*$c->{track_views_percent}/100;
my $x2time = int $vtime/2;
my $extra_onready='';

my $stop_code='';
if($c->{video_time_limit})
{
  $stop_code=<<ENS
  window.setTimeout( function (){ 
  	player.stop(); $show_box_after_limit 
  }, $c->{video_time_limit}*1000 );
ENS
;
}

  # window.setTimeout( function (){ 
  # 	if(x2ok!=0)
  # 	{ 
  # 		\$.get( '$c->{site_url}/dl?op=view2&file_code=$file->{file_code}&hash=$file->{ophash}&p=clappr&x2='+x2ok, function(data){} ); 
  # 	} 
  # 		}, $vtime*1000 );



 my @sources;
 if($c->{m_q} && ($file->{smil} || $file->{rtmp}))
 {
     $extra_html.=q[<script type="text/javascript" src="/player/clappr/rtmp.min.js"></script>];
     push @plugins_playback, 'RTMP';
      $extra.=",rtmpConfig: {
         swfPath: '/player/clappr/assets/RTMP.swf',
         scaling:'stretch',
         playbackType: 'vod',
         bufferTime: 0.5,
         startLevel: -1,
         autoSwitch: true,
     }";
 }

 if($file->{hls_direct}) # || $file->{dash_direct}
 {
 	if($c->{m_8} && $c->{multi_audio_on})
 	{
	 	# https://github.com/voc/clappr-audio-track-selector-plugin
	 	$extra_html.=qq[<script type="text/javascript" src="/player/clappr/audio-track-selector.min.js"></script>];
	 	push @plugins_core, 'AudioTrackSelector';
 	}
 	# $extra_html.=qq[<script type="text/javascript" src="/player/clappr/level-selector.min.js"></script>];
 	# push @plugins_core, 'LevelSelector';
 	# $extra.=qq|,levelSelectorConfig: {
  #   title: 'Quality',
  #   labels: {
  #       3: 'Higher',
  #       2: 'High',
  #       1: 'Med',
  #       0: 'Low',
  #   },
  #   labelCallback: function(playbackLevel, customLabel) {
  #       return playbackLevel.level.height+'p';
  #   }
  # 	}|;

	# https://github.com/ewwink/clappr-quality-selector-plugin
	$extra_html.=qq[<script type="text/javascript" src="/player/clappr/quality-selector.js"></script>];
	unshift @plugins_core, 'QualitySelector';
	my $default_quality;
	if($c->{player_default_quality} && $file->{"hash_$c->{player_default_quality}"})
	{
		my $qnum = {'l'=>0, 'n'=>1, 'h'=>2}->{$c->{player_default_quality}}||0;
		$default_quality="defaultQuality: $qnum,"
	}
	my $lcx=0;
	my $labels = join ',', map{$lcx++.": '$_->{label}'"} @{$file->{direct_links}};

			        # 3: 'Ultra',
			        # 2: 'High',
			        # 1: 'Med',
			        # 0: 'Low',
			    
	$extra.=qq|,qualitySelectorConfig: {
				title: '',
			    labels: { $labels },
			    $default_quality
			    labelCallback: function(playbackLevel, customLabel) {
			        return customLabel; // + ' ' + playbackLevel.level.height+'p';
			    }
		}|;

	# if($c->{player_default_quality} && $file->{"hash_$c->{player_default_quality}"})
	# {
	# 	my $lnum = {'l'=>0, 'n'=>1, 'h'=>2}->{$c->{player_default_quality}};
	# 	#$extra_js.="window.setTimeout('player.core.getCurrentPlayback().currentLevel = $lnum',1000);\n";
	# 	#$extra_js.="player.core.activePlayback.on(Clappr.Events.PLAYBACK_LEVELS_AVAILABLE, function(levels) { player.core.activePlayback.currentLevel = $lnum; });\n";
	# 	$file->{hls_start_level}=", startLevel: $lnum";
	# }
 }

if($file->{hls_direct})
{
	unshift @sources, qq["$file->{hls_direct}"];
	$extra.=",maxBufferLength: 30"; # HLS Buffer Length
	push @playback, "hlsjsConfig: {liveSyncDurationCount: 7, maxBufferLength: 30, maxBufferSize: $c->{hls_preload_mb}*1024*1024, maxMaxBufferLength: 600, capLevelToPlayerSize: true$file->{hls_start_level}}";
}
elsif($file->{dash_direct})
{
	unshift @sources, qq["$file->{dash_direct}"];
	push @plugins_playback, 'DashShakaPlayback';
	$extra_html.=qq[<script src="/player/clappr/dash-shaka-playback.min.js"></script>];
	$extra.=",shakaConfiguration: {
	        streaming: {
	          bufferingGoal: 30,
	          rebufferingGoal: 5,
	          bufferBehind: 90
	        }
	      }";
}
elsif($file->{direct_links})
{
	my $x = pop @{$file->{direct_links}};
	push @sources, qq["$x->{direct_link}"];
}

 my $sources_code = join(',',@sources);

	if($c->{player_chromecast})
	{
		$extra_html.=qq[<script type="text/javascript" src="/player/clappr/clappr-chromecast-plugin.min.js"></script>];
		push @plugins_core, 'ChromecastPlugin';
		$extra.=qq|,chromecast: { media: {title: "$file->{file_title}"}, poster: "$file->{video_img_url}" }|;
	}

	if($c->{player_playback_rates})
	{
		$extra_html.=qq[<script type="text/javascript" src="/player/clappr/clappr-playback-rate-plugin.min.js"></script>\n];
		#push @plugins_core, 'Clappr.MediaControl, PlaybackRatePlugin';
		push @plugins_core, 'PlaybackRatePlugin';
		my $rates = join ',', map{"{value: '$_', label: '$_'}"} map{sprintf("%.02f",$_)} split /\s*\,\s*/, $c->{player_playback_rates};
		$extra.=",playbackRateConfig: {defaultValue: '1.00', options: [$rates] }";
	}

 if($file->{p2p} && $file->{hls_direct})
 {
	if($c->{p2p_provider} eq 'streamroot')
	{
		$extra_html.='<script src="//cdn.streamroot.io/clappr0-hlsjs-provider/stable/clappr0-hlsjs-provider.js"></script>';
		push @plugins_playback, 'StreamrootHlsjs';
		$extra.=",p2pConfig: {streamrootKey: '$c->{p2p_streamroot_key}', contentId: '$file->{file_code}', cacheSize: '250', mobileBrowserEnabled: false}";
	}
	elsif($c->{p2p_provider} eq 'peer5')
	{
		 $extra_html_pre.=qq|<script src="//cdn.vdosupreme.com/vdo.js?id=$c->{p2p_peer5_key}"></script>
 							 <script src="//cdn.vdosupreme.com/vdo.clappr.plugin.js"></script>
 							 <script>
								peer5.configure({
								  contentIdReplacer: function(url) 
								  {
								   var aa = url.split(/\\//);
								   var hash = aa[4];
								   if (hash === '$file->{hash_n}') {
								      return url.replace(hash,'$file->{file_real}-n'); 
								   } else if ('$file->{hash_h}' && hash === '$file->{hash_h}') {
								      return url.replace(hash,'$file->{file_real}-h'); 
								   } else if ('$file->{hash_l}' && hash === '$file->{hash_l}') {
								      return url.replace(hash,'$file->{file_real}-l');
								   } else if ('$file->{hash_x}' && hash === '$file->{hash_x}') {
								      return url.replace(hash,'$file->{file_real}-x');
								   } else if ('$file->{hash_o}' && hash === '$file->{hash_o}') {
								      return url.replace(hash,'$file->{file_real}-o');
								   }
								   return url;
								  }
								});
		 				     </script>\n|;
	}
 }

 if($c->{srt_on})
 {
    my $srt_opacity=$c->{srt_opacity}/100;
    $extra_html.="<style>.cc-controls[data-cc-controls]{display: block;}
    video::cue {
    font-size: $c->{srt_size}%;
    opacity: $srt_opacity;
    color: $c->{srt_color};
    font-family: $c->{srt_font};
    text-shadow:1px 1px 2px $c->{srt_shadow_color};
    background: $c->{srt_back_color};
  }
    </style>";
    $extra_js.="\$('video')['0'].textTracks[0].mode='showing';" if $c->{srt_auto_enable};
    #my @arr = split /\s*\,\s*/, $c->{srt_langs};
    #my $dx = sprintf("%05d",$file->{file_id}/$c->{files_per_folder});
    #my $dir = "$c->{site_path}/srt/$dx";
    # my $srt_cook = $ses->getCookie("srt_cook");
    # my @list;
    # for(@arr)
    # {
    #   my $lang = {'English'=>'en', 'Spanish'=>'es', 'Turkce'=>'tr', 'Russian'=>'ru'}->{$_} || $_;
    #   push @tracks, qq[{src: "$c->{site_url}/srt/$dx/$file->{file_code}_$_.vtt", label: "$_", lang: "$lang", kind: "subtitles"}] if -f "$dir/$file->{file_code}_$_.vtt";
    #   push @tracks, qq[{src: "$c->{site_url}/srt/$dx/$file->{file_code}_$_\_$srt_cook.vtt", label: "My: $_", lang: "$lang", kind: "subtitles"}] if -f "$dir/$file->{file_code}_$_\_$srt_cook.vtt";
    # }
	for(@{$file->{captions_list}})
	{
		push @tracks, qq[{src: "$_->{url}", label: "$_->{title}", lang: "$_->{language}", kind: "subtitles"}];
	}
    if($c->{srt_allow_anon_upload})
	 {
	 	#push @tracks, qq[{file: "$c->{site_url}/srt/empty.srt", label: "Upload", kind: "captions"}];
	 	push @tracks, qq[{src: "/srt/empty.srt", label: "Upload SRT"}];
	 	#$extra_js.=qq[\$( "div.cc-controls li:nth-child(2)" ).click( function (){ alert('!!'); } );];
$extra_js.=<<ENP
\$( "div.cc-controls li:last-child" ).click( function (){
		showCCform();
		player.pause();
} );

function showCCform()
{
var \$dd=	\$("<div />").css({
   position: "absolute",
    width: "100%",
    height: "100%",
    left: 0,
    top: 0,
    zIndex: 1000000,
    background: "rgba(10%, 10%, 10%, 0.4)",
    "text-align": "center"
});
\$("<iframe />").css({
    width: "60%",
    height: "60%",
    zIndex: 1000001,
    "margin-top": "50px"
}).prop({'src':'$c->{site_url}/?op=upload_srt&file_code=$file->{file_code}', 'frameborder':'0', 'scrolling':'no'}).appendTo(\$dd);

 \$dd.click(function (){ \$(this).remove(); player.play(); });
 \$dd.appendTo( \$('#vplayer') );
}
ENP
;
	 }
	$c->{hls_preload_mb}||=60;
    #$extra.=",playback: {,hlsjsConfig: {liveSyncDurationCount: 7, maxBufferLength: 30, maxBufferSize: $c->{hls_preload_mb}*1024*1024, maxMaxBufferLength: 600, capLevelToPlayerSize: true$file->{hls_start_level}}}";
    push @playback, "crossOrigin: 'anonymous'";
    push @playback, "externalTracks: [".join(', ',@tracks)."]";

    # if($file->{hls_direct} && 0) # SRT for HLS
    # {
    # 	my $srt_file;
    # 	for(@arr)
	   #  {
	   #    $srt_file||="$c->{site_url}/srt/$dx/$file->{file_code}_$_.srt" if -f "$dir/$file->{file_code}_$_.srt";
	   #    #$srt_file||="$c->{site_url}/srt/$dx/$file->{file_code}_$_.vtt" if -f "$dir/$file->{file_code}_$_.vtt";
	  	# }
	  	# if($srt_file)
	  	# {
	   #  	$extra_html.=qq[<script type="text/javascript" src="/player/clappr/clappr-subtitles.js"></script>];
	   #  	push @plugins_core, 'ClapprSubtitle';
	   #  	my $srtauto = $c->{srt_auto_enable} ? 'true' : 'false';
	   #  	$extra.=qq|,subtitle : {src : "$srt_file", auto : $srtauto, color: '#$c->{srt_color}', backgroundColor : 'transparent', fontSize : '$c->{srt_size}px', textShadow : '1px 1px #000'}|;
    # 	}
    # }
 }

 my $plugins_code = '';
 my @plugins;
 # push @plugins, '"core": ['.join(",",@plugins_core).']' if @plugins_core;
 # push @plugins, '"playback": ['.join(",",@plugins_playback).']' if @plugins_playback;
 # $plugins_code.=',plugins: {'.join(",\n",@plugins).'}' if @plugins;
 push @plugins, @plugins_core;
 push @plugins, @plugins_playback;
 $plugins_code.=',plugins: ['.join(",",@plugins).']' if @plugins;

$extra.=qq[,watermark:"$c->{player_logo_url}", watermarkLink:"$c->{player_logo_link}", position:"$c->{player_logo_position}"] if $c->{player_logo_url};

$file->{vid_length} = $c->{video_time_limit} if $c->{video_time_limit};
if($file->{embed})
{
    $file->{play_w}=$file->{play_h}='100%';
    #$extra.=",stretching:'fill'";
}

$file->{player_img} ||= $file->{video_img_url};

my $show_box_after_preview='';
if($file->{preview})
{
 $show_box_after_preview=qq[\$('#over_player_msg').show();];
}

if($c->{remember_player_position})
{
	$ontime_func.=qq[if(x.current>=lastt+5 || x.current<lastt){ lastt=x.current; ls.set('tt$file->{file_code}', Math.round(lastt), { ttl: 60*60*24*7 }); }];
	$extra_js.=qq|var lastt = ls.get('tt$file->{file_code}'); if(lastt>0){ player.seek( lastt ); }|;
	$extra_html.=qq|<script src="/js/localstorage-slim.js"></script>|;
}

$extra.=qq[,autoPlay: true] if $file->{autostart};

my $js_code=<<ENP
var vvplay, vvad, x2ok=0, lastt=0;
var adPlayer,vastdone1=0,vastdone2=0;
//player.on(Clappr.Events.PLAYER_READY, function() { alert('!'); $extra_onready });
player.on(Clappr.Events.PLAYER_TIMEUPDATE, function(x) { 
    if($time_fadein>0 && x.current>=$time_fadein && vvad!=1){vvad=1;\$('div.video_ad_fadein').fadeIn('slow');}
    if(x2ok==0 && x.current>=$x2time && x.current<=($x2time+2)){x2ok=x.current;}
    $vast_ontime_func
    $ontime_func
});
player.on(Clappr.Events.PLAYER_PLAY, function() { doPlay(); });
player.on(Clappr.Events.PLAYER_ENDED, function() { \$('div.video_ad').show(); $show_box_after_limit $show_box_after_preview });
player.on(Clappr.Events.PLAYER_PAUSE, function() { $extra_pause });
function doPlay()
{
  \$('div.video_ad').hide();
  \$('#over_player_msg').hide();
  if(vvplay)return;
  vvplay=1;
  adb=0;
  if( window.cRAds === undefined ){ adb=1; }
  \$.get('$c->{site_url}/dl?op=view&file_code=$file->{file_code}&hash=$file->{ophash}&embed=$f->{embed}&adb='+adb, function(data) {\$('#fviews').html(data);} );

  $stop_code

  $extra_js
}



ENP
;

unshift @playback, "preload: '$c->{mp4_preload}', playInline: true, recycleVideo: Clappr.Browser.isMobile";
$extra .= ",playback: {".join(', ',@playback)."}";

my $code=<<ENP
var player = new Clappr.Player({
	sources: [$sources_code], 
	poster: "$file->{player_img}", 
	width: "100%",
    height: "100%",
    disableVideoTagContextMenu: true,
	parentId: "#vplayer",
	crossOrigin: 'anonymous',
	events: {
    	onReady: function() { $extra_onready },
	}
	$plugins_code
	$extra
	});

$js_code
ENP
;

$extra_html.=qq[<script src="$c->{cdn_url}/js/dnsads.js"></script>] if $c->{adb_no_money};

#<script type="text/javascript" src="https://cdn.jsdelivr.net/npm/@clappr/player@latest/dist/clappr.min.js"></script>
	my $html=qq[$extra_html_pre<script type="text/javascript" src="/player/clappr/clappr.min.js"></script>
                $extra_html
                <div id='vplayer' style="width:100%;height:100%;text-align:center;"></div>
                <style>
                button.media-control-button[data-hd-indicator] {display:none !important;}
                .clappr-watermark[data-watermark-top-right]{text-align:right !important; right:10px;}
                .clappr-watermark[data-watermark-top-left]{text-align:left !important;}
                </style>
                ]; #$file->{play_w}px, $file->{play_h}px

	return($html,$code);
}

1;
