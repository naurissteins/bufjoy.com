package Plugins::Player::VideoJS;
use strict;
use XFileConfig;
use vars qw($ses $c);

sub makePlayerCode
{
	my ($self, $f, $file, $c, $player ) = @_;
	return if $player ne 'vjs';

    my ($extra_settings, $extra_html, $extra_js, @tracks, $extra_html_pre, @plugins, $js_code_pre, $extra_css, 
    	$extra_onready, $extra_onplay, $extra_ontime, $extra_complete);

    if($c->{srt_on})
	{
	    my @list;
	    for(@{$file->{captions_list}})
	    {
	      push @tracks, qq[<track kind="captions" src="$_->{url}" srclang="$_->{language}" label="$_->{title}">];
    	}

    	my $srt_opacity=$c->{srt_opacity}/100;
    	my $srt_opacity_text=$c->{srt_opacity_text}/100;
    	my $font_size = $c->{srt_size}/100;
	    $extra_onready.=qq|
			\$(".vjs-fg-color > select").append(\$('<option>', {value:'$c->{srt_color}', text:'$c->{srt_color}'})).val('$c->{srt_color}');
			\$(".vjs-text-opacity > select").append(\$('<option>', {value:'$srt_opacity_text', text:'$c->{srt_opacity_text}%'})).val('$srt_opacity_text');
			\$(".vjs-bg-color > select").append(\$('<option>', {value:'$c->{srt_back_color}', text:'$c->{srt_back_color}'})).val('$c->{srt_back_color}');
			\$(".vjs-bg-opacity > select").append(\$('<option>', {value:'$srt_opacity', text:'$c->{srt_opacity}%'})).val('$srt_opacity');
			\$(".vjs-font-percent > select").append(\$('<option>', {value:'$font_size', text:'$c->{srt_size}%'})).val('$font_size');
		|;
		$extra_html.="<style>
		.vjs-text-track-cue > div {
			text-shadow: 1px 1px 2px $c->{srt_shadow_color} !important;
			font-family: $c->{srt_font} !important;
			padding-left: 0.3em  !important;
			padding-right: 0.3em  !important;
			padding-bottom: 0.2em  !important;
			border-radius: 6px;
			line-height: 1.43em;
		}
		</style>";

		if($c->{srt_allow_anon_upload})
		{
			push @tracks, qq[<track kind="captions" src="$c->{site_url}/srt/empty.vtt" srclang="th" label="Upload SRT" id="x182">];
			$extra_onplay.=qq|\$('.vjs-captions-menu-item:last').click(function() { showCCform(); });|;
		}
    }
    

if($c->{video_time_limit})
{
	$extra_onplay.=qq|window.setTimeout( function (){ player.hasStarted(false); player.currentTime(0); player.dispose(); \$('#vplayer').append('<img src="$file->{video_img_url}" style="width:100%;height:100%;">'); \$('#play_limit_box').show(); }, $c->{video_time_limit}*1000 );|;
	$extra_complete.=qq|\$('#play_limit_box').show();|;
}

if($file->{preview})
{
	$extra_complete.=qq|\$('#over_player_msg').show();|;
}

my $time_fadein=$c->{player_ads_fadein}||0;
my $vtime = 1 + int $file->{vid_length}*$c->{track_views_percent}/100;
my $x2time = int $vtime/2;

my ($vast_ontime_func,$vastdone1,$vastdone2);
if($c->{m_w} && $file->{vast_ads} && !$ses->getCookie('vastski'))
{
	# https://github.com/googleads/videojs-ima
	# mid/post-rolls: https://github.com/googleads/videojs-ima/issues/963
	# mid/post: /player/videojs7/vmap.xml
	$extra_html.=qq[<link rel="stylesheet" href="/player/videojs7/videojs.ads.css" />
    				<link rel="stylesheet" href="/player/videojs7/videojs.ima.css" />
					<script src="//imasdk.googleapis.com/js/sdkloader/ima3.js"></script>
    				<script src="/player/videojs7/videojs.ads.min.js"></script>
    				<script src="/player/videojs7/videojs.ima.min.js"></script>
    				];
    $extra_js.=qq[player.ima({id: "vjsplayer", adTagUrl: "$c->{vast_tag}"});
    var vastdone1=0,vastdone2=0;
    var contentPlayer =  document.getElementById('vjsplayer_html5_api');
if ((navigator.userAgent.match(/iPad/i) || navigator.userAgent.match(/iPhone/i) ||
      navigator.userAgent.match(/Android/i)) &&
    contentPlayer.hasAttribute('controls')) {
  contentPlayer.removeAttribute('controls');
};
var initAdDisplayContainer = function(ev) {
  player.ima.initializeAdDisplayContainer();
  wrapperDiv.removeEventListener(startEvent, initAdDisplayContainer);
};
var startEvent = 'click';
if (navigator.userAgent.match(/iPhone/i) || navigator.userAgent.match(/iPad/i) || navigator.userAgent.match(/Android/i)) { startEvent = 'touchend'; };
var wrapperDiv = document.getElementById('vjsplayer');
wrapperDiv.addEventListener(startEvent, initAdDisplayContainer);];

	# if($c->{vast_preroll})
	# {
	# 	$extra_onplay.=qq|player.ima.playAdBreak();|;
	# }
	# if($c->{vast_midroll} && $c->{vast_midroll_time})
	# {
	# 	my $dtime = $c->{vast_midroll_time}=~/(\d+)\%/ ? int($file->{vid_length}*$1/100) : $c->{vast_midroll_time};
	# 	my $mid_tag = $c->{vast_midroll_tag} ? $c->{vast_midroll_tag} : $c->{vast_tag};
	# 	#$extra_onplay.=qq|if(vastdone1==0)window.setTimeout( function (){ jwplayer().playAd('$mid_tag'); }, $dtime*1000 );|;
	# 	$vast_ontime_func.=qq|if(player.currentTime()>=$dtime && vastdone1==0){ vastdone1=1; console.log('mid!'); player.ima.initializeAdDisplayContainer(); player.ima.playAdBreak(); }|;
	# }
}

if($file->{file_skip_time}=~/^\d+$/)
{
	$extra_onplay.=qq|si11=1;\$('<button type="button" id="si11" class="si11" onclick="player.currentTime( $file->{file_skip_time} )" style="position:absolute;padding:7px;border:1px solid #fff;border-radius:3px;bottom:7em;right:1em;opacity:0.9;background: transparent;color:#FFF;">SKIP INTRO</button>').appendTo('div.video-js');|;
	$vast_ontime_func.=qq|if(si11==1 && player.currentTime()>=$file->{file_skip_time}){\$('#si11').hide();si11=0;}|;
}

if($c->{remember_player_position})
{
	$extra_ontime.=qq[if(player.currentTime()>=lastt+5 || player.currentTime()<lastt){ lastt=player.currentTime(); ls.set('tt$file->{file_code}', Math.round(lastt), { ttl: 60*60*24*7 }); }];
	$extra_onplay.=qq|var lastt = ls.get('tt$file->{file_code}'); if(lastt>0){ player.currentTime(lastt); }|;
	$extra_html.=qq|<script src="/js/localstorage-slim.js"></script>|;
	$extra_complete.=qq|ls.remove('tt$file->{file_code}');|;
}

$extra_onplay.=qq|window.setTimeout( function (){
    tott=player.currentTime();
   	v2done=1;
   	\$.post('$c->{site_url}/dl', {op: 'view2', hash: '$file->{ophash}', embed: '$f->{embed}', adb: adb, w: $vtime}, function(data){} );
    }, $vtime*1000 );| if $c->{views_tracking_mode2};

my $js_code=<<ENP
var vvplay,vvad;
var prevt=0, tott=0, v2done=0, lastt=0;;
\$.ajaxSetup({ headers: { 'Content-Cache': 'no-cache' } });

player.on('play', function(){ doPlay(); });
player.on('ended', function(){ \$('div.video_ad').show(); $extra_complete });
player.on('timeupdate',function() { 
    if($time_fadein>0 && player.currentTime()>=$time_fadein && vvad!=1){vvad=1;\$('div.video_ad_fadein').fadeIn('slow');}
    $vast_ontime_func
    $extra_ontime
});
function doPlay()
{
  \$('div.video_ad').hide();
  \$('#over_player_msg').hide();
  if(vvplay)return;
  vvplay=1;
  adb=0;
  if( window.cRAds === undefined ){ adb=1; }
  \$.get('$c->{site_url}/dl?op=view&file_code=$file->{file_code}&hash=$file->{ophash}&embed=$f->{embed}&adb='+adb, function(data) {\$('#fviews').html(data);} );

  $extra_onplay
}

function showCCform()
{
videojs('vjsplayer').pause();

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

$extra_js

ENP
;

if($c->{player_logo_url})
{
	$js_code.="\nplayer.watermark({'image' : '$c->{player_logo_url}'});";
	$extra_html.='<script src="/player/videojs7/videojs-watermark.js"></script><link rel="stylesheet" href="/player/videojs7/videojs-watermark.css">';
}

 my (@sources, $sources_code);

 	if($c->{player_default_quality})
	{
		my $vi = $ses->vInfo($file,$c->{player_default_quality});
		$file->{default_height} = $vi->{vid_height};
	}

	if($file->{hls_direct})
	{
		$sources_code = qq[{src: "$file->{hls_direct}", type: "application/x-mpegURL"}];

			# https://player.support.brightcove.com/plugins/quality-selection-plugin.html
			$extra_html.=qq[<link href="$c->{cdn_url}/player/videojs7/videojs-quality-menu.css" rel="stylesheet">
						<script src="$c->{cdn_url}/player/videojs7/videojs-quality-menu.min.js"></script>];
		my $defres="defaultResolution: '$file->{default_height}p'" if $file->{default_height};
		my $show_resolution = $c->{quality_labels_bitrate} ? 'true' : 'false';

		my $labels = join ',', map{"'$_->{height}':'$_->{label}'"} @{$file->{direct_links}};

		$js_code.="player.qualityMenu({resolutionLabelBitrates: $show_resolution, labels:{$labels}, $defres});";
	}
	elsif($file->{dash_direct})
	{
		#$file->{dash_direct} = 'https://bitmovin-a.akamaihd.net/content/MI201109210084_1/mpds/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.mpd';
		$sources_code = qq|{src: "$file->{dash_direct}", type: "application/dash+xml"}|;

		$extra_html.=qq[<link href="$c->{cdn_url}/player/videojs7/videojs-quality-menu.css" rel="stylesheet">
						<script src="$c->{cdn_url}/player/videojs7/videojs-quality-menu.min.js"></script>];
		my $defres="defaultResolution: '$file->{default_height}p'" if $file->{default_height};
		$js_code.="player.qualityMenu({resolutionLabelBitrates: true, $defres});";
	}
	elsif($file->{direct_links})
	{
		for(@{$file->{direct_links}})
		{
			my $default=',selected: true' if $_->{mode} eq $c->{player_default_quality};
			push @sources, qq[{src: "$_->{direct_link}", type: "video/mp4", res: "$_->{height}", label: "$_->{label}"$default}];
		}
		$sources_code = join(', ', @sources);

		# https://github.com/silvermine/videojs-quality-selector
		$extra_html.=qq[<link href="$c->{cdn_url}/player/videojs7/quality-selector.css" rel="stylesheet">
						<script src="$c->{cdn_url}/player/videojs7/silvermine-videojs-quality-selector.min.js"></script>];
		#$extra_onready.="player.controlBar.addChild('QualitySelector');";
	}

 if($file->{p2p} && $file->{hls_direct})
 {
	if($c->{p2p_provider} eq 'self')
	{
		$extra_html_pre.=q|<script src="https://cdn.jsdelivr.net/npm/p2p-media-loader-core@latest/build/p2p-media-loader-core.min.js"></script> 
						    <script src="https://cdn.jsdelivr.net/npm/p2p-media-loader-hlsjs@latest/build/p2p-media-loader-hlsjs.min.js"></script>
						   |;
		$extra_html.=q|<script src="https://cdn.jsdelivr.net/npm/videojs-contrib-hls.js@latest"></script>|;

		$js_code_pre.=qq|const p2pconfig = {
						  segments: {
						    swarmId: "$file->{file_real}"
						  },
						  loader:{
						  	trackerAnnounce: '$c->{p2p_self_tracker_url}',
						  	// how long to store the downloaded segments for P2P sharing
						    cachedSegmentExpiration:86400000,
						    // count of the downloaded segments to store for P2P sharing
						    cachedSegmentsCount:100,
						    // first 4 segments (priorities 0, 1, 2 and 3) are required buffer for stable playback
    						requiredSegmentsPriority:2,
						    // P2P will try to download only first 51 segment ahead of playhead position
						    p2pDownloadMaxPriority: 50,
						    // number of simultaneous downloads for P2P and HTTP methods
    						simultaneousP2PDownloads:20,
    						simultaneousHttpDownloads:1,
    						// enable mode, that try to prevent HTTP downloads on stream start-up
    						httpDownloadInitialTimeout: 120000, // try to prevent HTTP downloads during first 2 minutes
    						httpDownloadInitialTimeoutPerSegment: 17000, // try to prevent HTTP download per segment during first 17 seconds
    						// allow to continue aborted P2P downloads via HTTP
    						httpUseRanges: true,
						  }	
						};
						var engine = new p2pml.hlsjs.Engine(p2pconfig);
						var loaded_http=0,loaded_p2p=0;
						engine.on("peer_connect", peer => console.log("p2p_peer_connect", peer.id, peer.remoteAddress));
						engine.on("peer_close", peerId => console.log("p2p_peer_close", peerId));
						engine.on("segment_loaded", (segment, peerId) => console.log("p2p_segment_loaded from", peerId ? `peer \${peerId}` : "HTTP", segment.url));
						engine.on("piece_bytes_downloaded", function(method, size){ 
							if(method=='http')loaded_http+=size; else loaded_p2p+=size;
							console.log("piece_bytes_downloaded ", method, size, "Total HTTP:"+loaded_http, "P2P:"+loaded_p2p); 
						} );
						|;

		$js_code.=q|p2pml.hlsjs.initVideoJsContribHlsJsPlayer(player);|;
		$extra_settings.=q|,html5: {
		                    hlsjsConfig: {
		                        liveSyncDurationCount: 3, // To have at least 7 segments in queue
		                        loader: engine.createLoaderClass()
		                    }
		                }|;
	}
 }

 my $tracks_code = join "\n", @tracks;


$file->{vid_length} = $c->{video_time_limit} if $c->{video_time_limit};

$file->{player_img} ||= $file->{video_img_url};


if($c->{m_z} && $c->{time_slider})
{
	# https://github.com/phloxic/videojs-sprite-thumbnails#readme
	my $interval = sprintf("%.1f", $file->{vid_length} / ($c->{m_z_cols}*$c->{m_z_rows}) );
 	$extra_html.=qq[<script src="$c->{cdn_url}/player/videojs7/videojs-sprite-thumbnails.min.js" type="text/javascript"></script>];
 	$js_code.=qq[player.spriteThumbnails({
				    url: '$file->{video_img_folder}/$file->{file_real}0000.jpg',
				    width: $c->{thumb_width},
				    height: $c->{thumb_height},
				    interval: $interval
				  });];
}

$extra_html.=qq[<script src="$c->{cdn_url}/js/dnsads.js"></script>] if $c->{adb_no_money};
#<script type="text/javascript" src="$c->{cdn_url}/player/videojs7/videojs.watermark.js"></script>
#<link href="/VideoJS/videojs.watermark.css" rel="stylesheet">

my $themecss = qq|<link href="$c->{cdn_url}/player/videojs7/themes/$c->{vjs_theme}/index.css" rel="stylesheet">| if $c->{vjs_theme};

# https://github.com/silvermine/videojs-chromecast
# https://www.jsdelivr.com/package/npm/@silvermine/videojs-chromecast
if($c->{player_chromecast})
{
	$extra_html.=qq[<script src="/player/videojs7/silvermine-videojs-chromecast.min.js"></script>
			   		<link href="/player/videojs7/silvermine-videojs-chromecast.css" rel="stylesheet">
			   		<script type="text/javascript" src="https://www.gstatic.com/cv/js/sender/v1/cast_sender.js?loadCastFramework=1"></script>];
	$extra_settings.=",techOrder: [ 'chromecast', 'html5' ]";
	push @plugins, "chromecast: {}";
}

# https://github.com/silvermine/videojs-airplay
if($c->{player_chromecast})
{
	$extra_html.=qq[<script src="/player/videojs7/silvermine-videojs-airplay.min.js"></script>
			   		<link href="/player/videojs7/silvermine-videojs-airplay.css" rel="stylesheet">];
	push @plugins, "airPlay: {}";
}

if($c->{player_hidden_link})
{
	$file->{ophash2} = $ses->HashSave($file->{file_id},0);
	$extra_html.="<script src='$c->{cdn_url}/js/tear.js'></script>" if $c->{player_hidden_link_tear};
	my $tear= $c->{player_hidden_link_tear} ? "data['seed'] = data['seed'].replace(/[012567]/g, m => chars[m]); data['src'] = decrypt( data['src'], data['seed'] );" : "";
  	$extra_onready.=qq|var vvbefore;
			if(vvbefore)return; vvbefore=1;
			\$.post('$c->{site_url}/dl', {op: 'playerddl', file_code: '$file->{file_code}', hash: '$file->{ophash2}'}, function(data){ 
				var chars = {	'0':'5', '1':'6', '2':'7', 
								'5':'0', '6':'1', '7':'2'};
				$tear
				data['src'] = data['src'].replace(/[012567]/g, m => chars[m]);
				player.src(data);
				//player.loadMedia({src:data}, function(){ player.play(); });
			} );
  	|;
}

if($c->{player_playback_rates})
{
	$extra_settings.=",playbackRates: [$c->{player_playback_rates}]";
}

my $plugins_code = join ',', @plugins;
my $autoplay = $file->{autostart} ? 'autoplay' : '';

$extra_css.=".video-js .vjs-big-play-button {display: none;}" if $file->{autostart};

if($ses->isMobile)
{
	# https://github.com/mister-ben/videojs-mobile-ui
	$extra_html_pre.=qq|\n<link rel="stylesheet" href="/player/videojs7/videojs-mobile-ui.css">|;
	$extra_html.=qq|\n<script src="/player/videojs7/videojs-mobile-ui.min.js"></script>|;
	$js_code.=qq|\nplayer.mobileUi();|;
}

my $html=qq[$extra_html_pre<link href="$c->{cdn_url}/player/videojs7/video-js.css?v=$c->{cdn_version_num}" rel="stylesheet">
            $themecss
            <div id='vplayer' style="width:100%;height:100%;text-align:center;">
                
            <video id="vjsplayer"
			    class="video-js vjs-big-play-centered vjs-16-9 vjs-theme-$c->{vjs_theme}"
			    width="$file->{play_w}" height="$file->{play_h}"
			    controls 
			    preload="$c->{mp4_preload}" $autoplay>
			    $tracks_code
			</video></div>

<script src="$c->{cdn_url}/player/videojs7/video.min.js?v=$c->{cdn_version_num}"></script>
<script src="$c->{cdn_url}/player/videojs7/videojs.hotkeys.min.js"></script>

$extra_html

<style>
$extra_css
.video-js {
	width:100%;
	height:100%;
}
.vjs-texttrack-settings {
  /*display: none;*/
}
.vjs-quality-selector .vjs-menu {
	width: 12em !important;
	left: -4.5em !important;
}
.vjs-menu li {
	text-transform: none;
}
.vjs-quality-menu-wrapper .vjs-menu {
	width: 12em !important;
	left: -4.5em !important;
}
.vjs-quality-menu-item-sub-label {
	display: none;
}
</style>
];

my $code=<<ENP
$js_code_pre
var player = videojs('vjsplayer',{
								//fluid: true,
								sources: [$sources_code],
								poster: "$file->{player_img}",
								controlBar: { 
								    children: [
								    	'playToggle', 
								    	'volumePanel', 
								    	'currentTimeDisplay', 
								    	'progressControl', 
								    	'liveDisplay', 
								    	'seekToLive', 
								    	'durationDisplay', 
								    	'customControlSpacer', 
								    	'playbackRateMenuButton', 
								    	'chaptersButton', 
								    	'descriptionsButton', 
								    	'subsCapsButton', 
								    	'audioTrackButton', 
								    	'pictureInPictureToggle',
								    	'qualitySelector',
								    	'fullscreenToggle']
								},
								plugins:{
										 $plugins_code
										}
								$extra_settings
								});

player.ready(function() {
	this.hotkeys({volumeStep: 0.1, seekStep: 5, enableVolumeScroll: true});
	$extra_onready
});

$js_code

ENP
;
       
#$file->{img_timeslide_url}
#window.HELP_IMPROVE_VIDEOJS = false;
	return($html,$code);
}

1;
