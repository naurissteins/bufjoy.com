package Plugins::Player::Hola;
use strict;
use XFileConfig;
use vars qw($ses $c);

# https://github.com/hola/hola_player

sub makePlayerCode
{
	my ($self, $f, $file, $c, $player ) = @_;
	return if $player ne 'hola';

    my ($extra_settings,$extra_options,$extra_html,$extra_js,@tracks,$extra_html_pre,@plugins,$extra_onready,$extra_onplay,$videojs_options_extra);

    if($c->{srt_on})
	{
	    my @list;
	    for(@{$file->{captions_list}})
	    {
	      push @tracks, qq[<track kind="captions" src="$_->{url}" srclang="$_->{language}" label="$_->{title}">];
    	}
    }
    if($c->{srt_allow_anon_upload})
 	{
 		push @tracks, qq[<track kind="captions" src="$c->{site_url}/srt/empty.vtt" srclang="en" label="Upload SRT" id="x182">];
 		#$extra_onplay.=qq|\$('.vjs-subtitles-button').on('click', function() { alert('123'); }); |;
 		$extra_onplay.=qq|player.textTracks().on("change", function (event) { var a=this.tracks_; b=a[a.length-1]; if(b.src=="$c->{site_url}/srt/empty.vtt" && b.mode=="showing"){showCCform();} } );|;
 		#$extra_onplay.=qq|const trackEl = player.addRemoteTextTrack({src: '$c->{site_url}/srt/empty.vtt', label: 'Upload SRT'}, false);
		#https://github.com/videojs/video.js/issues/4979
 	}

my $show_box_after_limit=qq[ \$('#play_limit_box').show(); ] if $c->{video_time_limit};
my $time_fadein=$c->{player_ads_fadein}||0;
my $vtime = int $file->{vid_length}*$c->{track_views_percent}/100;
my $x2time = int $vtime/2;


if($c->{player_logo_url})
{
	$extra_options.=qq[watermark: { image: '$c->{player_logo_url}', position: '$c->{player_logo_position}', url: '$c->{player_logo_link}', fadeTime: '$c->{player_logo_fadeout}' },] if $c->{player_logo_mode}=~/video|both/;
	$extra_options.=qq[controls_watermark: { image: '$c->{player_logo_url}', tooltip: '$c->{site_name}', url: '$c->{player_logo_link}' },] if $c->{player_logo_mode}=~/controls|both/;
}

 my (@sources, $sources_code);
 
if($file->{hls_direct})
{
	$sources_code = qq[{src: "$file->{hls_direct}", type: "application/x-mpegURL"}];
}
elsif($file->{dash_direct})
{
	#$extra_html.=qq[<script src="$c->{cdn_url}/player/hola/hola_player.dash.js"></script>];
	$file->{dash_js}='.dash';
	$sources_code = qq[{src: "$file->{dash_direct}", type: "application/dash+xml"}];
}
elsif($file->{direct_links})
{
	for(@{$file->{direct_links}})
	{
		my $default=',selected: true' if $_->{mode} eq $c->{player_default_quality};
		push @sources, qq[{src: "$_->{direct_link}", type: "video/mp4", res: "$_->{height}", label: "$_->{label}"$default}];
	}
	$sources_code = join(', ', @sources);
}
 

 my $tracks_code = join "\n", @tracks;


$file->{vid_length} = $c->{video_time_limit} if $c->{video_time_limit};
if($file->{embed})
{
    #$file->{play_w}=$file->{play_h}='100%';
    #$extra.=",stretching:'fill'";
}
else
{
	#$extra.=qq[,width: "$file->{play_w}", height: "$file->{play_h}"];
}

$file->{player_img} ||= $file->{video_img_url};


if($c->{m_z} && $c->{time_slider})
{
	$extra_options.=qq[thumbnails:{ vtt:'$c->{site_url}/dl?op=get_slides&length=$file->{vid_length}&url=$file->{img_timeslide_url}' },];
}

if($c->{player_chromecast})
{
	$extra_html.=qq[<link  href="/player/hola/videojs-chromecast.css" rel="stylesheet">
<script src="/player/hola/videojs-chromecast.min.js"></script>
<script type="text/javascript" src="https://www.gstatic.com/cv/js/sender/v1/cast_sender.js?loadCastFramework=1"></script>];
	$videojs_options_extra.="\nchromecast:{},"
}

# https://developers.google.com/interactive-media-ads/docs/sdks/html5/tags
my ($ontime_func,$vast_onplay);
if($c->{m_w} && $file->{video_ads} && !$ses->getCookie('vastski'))
{
	$extra_options.= $c->{vast_preroll} && $c->{vast_tag} ? qq|ads: { adTagUrl: '$c->{vast_tag}' },| : "ads: {manual: true},";
	if($c->{vast_midroll} && $c->{vast_midroll_time})
	{
		my $dtime = $c->{vast_midroll_time}=~/(\d+)\%/ ? int($file->{vid_length}*$1/100) : $c->{vast_midroll_time};
		my $mid_tag = $c->{vast_midroll_tag} ? $c->{vast_midroll_tag} : $c->{vast_tag};
		$extra_onplay.=qq|if(vastdone1==0)window.setTimeout( function (){ player.ima.playAd('$mid_tag'); }, $dtime*1000 );|;
	}
	if($c->{vast_postroll} && $c->{vast_postroll_time})
	{
		my $dt = $c->{vast_postroll_time}=~/(\d+)\%/ ? int($file->{vid_length}*$1/100) : $c->{vast_postroll_time};
		my $dtime = $file->{vid_length} - $dt;
		my $post_tag = $c->{vast_postroll_tag} ? $c->{vast_postroll_tag} : $c->{vast_tag};
		$ontime_func=qq|if(player.currentTime()>=$dtime && vastdone2==0){ vastdone2=1; player.ima.playAd('$post_tag'); }|;
	}
	$ses->setCookie('vastski','1',"+$c->{vast_skip_mins}m") if $c->{vast_skip_mins} && !$ses->getCookie('vastski');
}

if($c->{remember_player_position})
{
	$ontime_func.=qq|if(player.currentTime()>=lastt+5){ lastt=player.currentTime(); ls.set('tt$file->{file_code}', Math.round(lastt), { ttl: 60*60*24*7 }); }|;
	$extra_onplay.=qq|var lastt = ls.get('tt$file->{file_code}'); if(lastt>0){ player.currentTime(lastt); }|;
	$extra_html.=qq|<script src="/js/localstorage-slim.js"></script>|;
}

$videojs_options_extra.=qq|\nplaybackRates: [$c->{player_playback_rates}],| if $c->{player_playback_rates};

my $plugins_code = join ',', @plugins;
my $autoplay = $file->{autostart} ? 'autoplay' : '';

$extra_html.=qq[<script src="$c->{cdn_url}/js/dnsads.js"></script>] if $c->{adb_no_money};

#<script src="https://cdnjs.cloudflare.com/ajax/libs/hola_player/1.0.165/hola_player.js"></script>
#<script src="//cdn.sc.gl/videojs-hotkeys/latest/videojs.hotkeys.min.js"></script>

my $js_code=<<ENP
var vvplay,vvad;
var vastdone1=0,vastdone2=0;
var lastt=0;
player.on('play', function(){ doPlay(); });
player.on('ended', function(){ \$('div.video_ad').show(); $show_box_after_limit });
player.on('timeupdate',function() { 
    if($time_fadein>0 && player.currentTime()>=$time_fadein && vvad!=1){vvad=1;\$('div.video_ad_fadein').fadeIn('slow');}
    $ontime_func
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
player.pause();

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

my $html=qq|    <div id='vplayer' style="width:100%;height:100%;text-align:center;">
                
                <video id="hola"
				    class="video-js vjs-default-skin vjs-big-play-centered"
				    width="$file->{play_w}" height="$file->{play_h}"
				    controls="true"
				    preload="$c->{mp4_preload}"
				    poster="$file->{player_img}" controls>
				    $tracks_code
				    $autoplay
				</video></div>

<script src="/player/hola/hola_player$file->{dash_js}.js"></script>
<script src="/player/hola/videojs.hotkeys.min.js"></script>
<script src="/player/hola/videojs-contrib-hls.min.js"></script>

<style>
.video-js {
	width:100%;
	height:100%;
}
.vjs-texttrack-settings {
	display: none;
}
.vjs-rightclick-popup {
	display: none;
}
</style>

$extra_html
|;

#"fluid": true,

my $code=<<ENP
var holaplayer;
window.hola_player({ player: '#hola',
    				share: false,
    				poster: '$file->{player_img}',
    				sources: [$sources_code],
					preload: '$c->{mp4_preload}',
					$extra_options
					videojs_options: { 
						html5: {
							hlsjsConfig: {
								debug: false, 
								startLevel: 1,
								maxBufferLength: 30, 
								maxBufferSize: $c->{hls_preload_mb}*1024*1024, 
								maxMaxBufferLength: 600, 
								capLevelToPlayerSize: true,
							}
						},
						$videojs_options_extra
					},
}, function(player){
	holaplayer = player;
		player.hotkeys({ volumeStep: 0.1, seekStep: 5, enableModifiersForNumbers: false });
		$js_code
	player.ready(function(){
        $extra_onready
    });
});

ENP
;
       
	return($html,$code);
}

1;
