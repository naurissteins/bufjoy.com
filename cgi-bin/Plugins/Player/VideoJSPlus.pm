package Plugins::Player::VideoJSPlus;
use strict;
use XFileConfig;
use vars qw($ses $c);

# https://github.com/Pong420/videojs-plus

sub makePlayerCode
{
	my ($self, $f, $file, $c, $player ) = @_;
	return if $player ne 'vjsp';

    my ($extra_settings,$extra_html,$extra_js,@tracks,$extra_html_pre,@plugins,$extra_onready,$extra_onplay,$js_code_pre);

my $show_box_after_limit=qq[ \$('#play_limit_box').show(); ] if $c->{video_time_limit};
my $time_fadein=$c->{player_ads_fadein}||0;
my $vtime = int $file->{vid_length}*$c->{track_views_percent}/100;
my $x2time = int $vtime/2;

my ($vast_ontime_func,$vastdone1,$vastdone2);
if($c->{m_w} && $file->{vast_ads} && !$ses->getCookie('vastski'))
{
	# https://github.com/googleads/videojs-ima
	$extra_html.=qq[<link rel="stylesheet" href="/player/videojs7plus/videojs.ads.css" />
    				<link rel="stylesheet" href="/player/videojs7plus/videojs.ima.css" />
					<script src="//imasdk.googleapis.com/js/sdkloader/ima3.js"></script>
    				<script src="/player/videojs7plus/videojs.ads.min.js"></script>
    				<script src="/player/videojs7plus/videojs.ima.min.js"></script>
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

if($c->{srt_on})
{
    my @vtts;
    for(@{$file->{captions_list}})
    {
      push @vtts, qq[{kind: 'subtitles', srclang: '$_->{language}', label: '$_->{title}', src: '$_->{url}'}];
	}
	
	if($c->{srt_allow_anon_upload})
	{
		push @vtts, qq[{kind: 'subtitles', srclang: 'en-US', label: 'Upload SRT', src: '$c->{site_url}/srt/empty.vtt'}];
		$extra_js.=qq|player.on('subtitlechange', (event, sub) => { if(sub.label=='Upload SRT'){ showCCform(); } });|;
	}

	my $subs=join(",",@vtts);
	$extra_onready.=qq|var subtitles=[$subs];player.subtitles().load(subtitles);| if @vtts;
	$extra_html.=qq[<script src="$c->{cdn_url}/player/videojs7plus/plugins/subtitles/index.js" type="text/javascript"></script>] if @vtts;
	
	my $srt_opacity=$c->{srt_opacity}/100;
	my $srt_opacity_text=$c->{srt_opacity_text}/100;
	$extra_html.="<style>
		.vjs-text-track-cue > div {
			font-size: $c->{srt_size}% !important;
			color: $c->{srt_color} !important;
			text-shadow: 1px 1px 2px $c->{srt_shadow_color} !important;
			font-family: $c->{srt_font} !important;
			background: $c->{srt_back_color} !important;
			opacity: $srt_opacity_text !important;
			padding-left: 0.3em  !important;
			padding-right: 0.3em  !important;
			padding-bottom: 0.2em  !important;
			border-radius: 6px;
			line-height: 1.43em;
		}
		</style>";
}

if($file->{file_skip_time}=~/^\d+$/)
{
	$extra_onplay.=qq|si11=1;\$('<button type="button" id="si11" class="si11" onclick="player.currentTime( $file->{file_skip_time} )" style="position:absolute;padding:7px;border:1px solid #fff;border-radius:3px;bottom:7em;right:1em;opacity:0.9;background: transparent;color:#FFF;">SKIP INTRO</button>').appendTo('div.video-js');|;
	$vast_ontime_func.=qq|if(si11==1 && player.currentTime()>=$file->{file_skip_time}){\$('#si11').hide();si11=0;}|;
}

my $js_code=<<ENP
var vvplay,vvad;

player.on('play', function(){ doPlay(); });
player.on('ended', function(){ \$('div.video_ad').show(); $show_box_after_limit });
player.on('timeupdate',function() { 
    if($time_fadein>0 && player.currentTime()>=$time_fadein && vvad!=1){vvad=1;\$('div.video_ad_fadein').fadeIn('slow');}
    $vast_ontime_func
});
function doPlay()
{
  \$('div.video_ad').hide();
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
	$extra_html.='<script src="/player/videojs7plus/videojs-watermark.js"></script><link rel="stylesheet" href="/player/videojs7plus/videojs-watermark.css">';
}

my (@sources, $sources_code);

if($file->{hls_direct})
{
	#$sources_code = qq[player.updateSrc({src: "$file->{hls_direct}", type: "application/x-mpegURL"}, {hls: true});];
	# https://github.com/chrisboustead/videojs-hls-quality-selector
	$extra_html.=qq[<script src="$c->{cdn_url}/player/videojs7plus/videojs-contrib-quality-levels.min.js"></script>
					<script src="$c->{cdn_url}/player/videojs7plus/plugins/quality-hls/index.js"></script>];
	#$js_code.="player.hlsQualitySelector({displayCurrentQuality: true});";
	push @sources, qq[{src: "$file->{hls_direct}", type: "application/x-mpegURL"}];
	$sources_code = 'sources:['.join(', ', @sources).']';
	my $labels = join ', ', map{"'$_->{height}p': '$_->{label}'"} @{$file->{direct_links}};
	$extra_onready.=qq[videojs.addLanguage('en-us', { $labels });\n];
}
elsif($file->{dash_direct})
{
	#$sources_code = qq|player.src({src: "$file->{dash_direct}", type: "application/dash+xml"});|;
	push @sources, qq[{src: "$file->{dash_direct}", type: "application/dash+xml"}];
	$sources_code = 'sources:['.join(', ', @sources).']';
	$extra_html.=qq[<script src="$c->{cdn_url}/player/videojs7plus/dash.all.min.js"></script>
					<script src="$c->{cdn_url}/player/videojs7plus/videojs-dash.min.js"></script>];
}
elsif($file->{direct_links})
{
	for(@{$file->{direct_links}})
	{
		my $default='default: true,' if $_->{mode} eq $c->{player_default_quality};
		push @sources, qq|{$default label:'$_->{label}', sources:[{src: '$_->{direct_link}', type: 'video/mp4'}]}|;
	}
	my $sources_code2='[ '.join(', ', @sources).' ]';
	$js_code_pre.=qq[const qualities = $sources_code2;];
	$extra_html.=qq[<script src="$c->{cdn_url}/player/videojs7plus/plugins/quality/index.js"></script>];
	$sources_code='qualities';
}

	my $tracks_code = join "\n", @tracks;

	unless($file->{hls_direct} || $file->{dash_direct})
	{
		# https://github.com/silvermine/videojs-quality-selector
		# $extra_html.=qq[<link href="$c->{cdn_url}/player/videojs7plus/videojs-quality-selector.css" rel="stylesheet">
		# 				<script src="$c->{cdn_url}/player/videojs7plus/videojs-quality-selector.min.js"></script>];
		# $js_code.="player.controlBar.addChild('QualitySelector');";
	}


$file->{vid_length} = $c->{video_time_limit} if $c->{video_time_limit};

$file->{player_img} ||= $file->{video_img_url};


if($c->{m_z} && $c->{time_slider})
{
	# https://github.com/chrisboustead/videojs-vtt-thumbnails
	$extra_html.=qq[<link  href="$c->{cdn_url}/player/videojs7plus/videojs-vtt-thumbnails.css" rel="stylesheet">
    				<script src="$c->{cdn_url}/player/videojs7plus/videojs-vtt-thumbnails.min.js" type="text/javascript"></script>];
    $js_code.=qq[player.vttThumbnails({src: '$c->{site_url}/dl?op=get_slides&length=$file->{vid_length}&url=$file->{video_img_folder}/$file->{file_real}0000.jpg'});];
}

if($c->{player_chromecast})
{
	$extra_html.=qq[<script src="/player/videojs7plus/silvermine-videojs-chromecast.min.js"></script>
			   		<link href="/player/videojs7plus/silvermine-videojs-chromecast.css" rel="stylesheet">
			   		<script type="text/javascript" src="https://www.gstatic.com/cv/js/sender/v1/cast_sender.js?loadCastFramework=1"></script>];
	$extra_settings.=",techOrder: [ 'chromecast', 'html5' ]";
	push @plugins, "chromecast: {}";
}

my $plugins_code = join ',', @plugins;
my $autoplay = $file->{autostart} ? 'autoplay' : '';

$extra_html.=qq[<script src="$c->{cdn_url}/js/dnsads.js"></script>] if $c->{adb_no_money};

my $html=qq[$extra_html_pre<link href="$c->{cdn_url}/player/videojs7plus/videojs-plus.css?v=$c->{cdn_version_num}" rel="stylesheet">
            <div id='vplayer' style="width:100%;height:100%;text-align:center;">
                
                
            <video id="vjsplayer"
			    class="video-js vjs-big-play-centered vjs-theme-$c->{vjs_theme}"
			    width="$file->{play_w}" height="$file->{play_h}"
			    controls 
			    preload="$c->{mp4_preload}" $autoplay>
			    $tracks_code
			</video></div>

<script src="$c->{cdn_url}/player/videojs7plus/video.min.js?v=$c->{cdn_version_num}"></script>
<script src="$c->{cdn_url}/player/videojs7plus/videojs-plus.umd.js"></script>

$extra_html

<style>
.video-js {
	width:100%;
	height:100%;
}
.vjs-big-play-button {display:block;}
.vjs-texttrack-settings {
  /*display: none;*/
}
</style>
];

$extra_settings.=qq[,title: "$file->{file_title}"] if $c->{player_show_title};

my $code=<<ENP
$js_code_pre
var player = videojs('vjsplayer',{
								//"fluid": true,
								$sources_code,
								language: "en-us",
								poster: "$file->{player_img}",
								plugins:{
										 $plugins_code
										}
								$extra_settings
								});

player.ready(function() {
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
