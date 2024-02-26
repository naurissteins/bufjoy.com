package Plugins::Player::Fluid;
use strict;
use XFileConfig;
use vars qw($ses $c);

# https://docs.fluidplayer.com/docs/configuration/layout/

sub makePlayerCode
{
	my ($self, $f, $file, $c, $player) = @_;
	return if $player ne 'fluid';

	my ($extra_settings,$extra_html,$extra_js,@tracks,$extra_html_pre,@plugins,$extra_onplay, $layout_code);

	if($c->{srt_on} && $c->{srt_auto_langs})
	{
		my @list;
		my $default=' default';
		for(@{$file->{captions_list}})
		{
			push @tracks, qq[<track kind="metadata" src="$_->{url}" srclang="$_->{language}" label="$_->{title}"$default>];
			$default='';
		}
		$layout_code.="subtitlesEnabled: true,";
	}

	my $show_box_after_limit=qq[ \$('#play_limit_box').show(); ] if $c->{video_time_limit};
	my $time_fadein=$c->{player_ads_fadein}||0;
	my $vtime = int $file->{vid_length}*$c->{track_views_percent}/100;
	my $x2time = int $vtime/2;

	if($c->{m_w} && $file->{vast_ads} && !$ses->getCookie('vastski'))
	{
		my @rolls;
		push @rolls, "{roll: 'preRoll', vastTag: '$c->{vast_tag}'}" if $c->{vast_preroll} && $c->{vast_tag};
		push @rolls, "{roll: 'midRoll', vastTag: '$c->{vast_midroll_tag}', timer: $c->{vast_midroll_time}}" if $c->{vast_midroll} && $c->{vast_midroll_tag};
		push @rolls, "{roll: 'postRoll', vastTag: '$c->{vast_postroll_tag}'}" if $c->{vast_postroll} && $c->{vast_postroll_tag};
		my $rolls_code = join ',',  @rolls;
		$extra_settings.="vastOptions: {allowVPAID: true, adList: [$rolls_code]},";
	}

my $js_code=<<ENP
var vvplay,vvad;

player.on('play', function(){ doPlay(); });
player.on('ended', function(){ \$('div.video_ad').show(); $show_box_after_limit });
player.on('timeupdate',function(currentTime) { 
    if($time_fadein>0 && currentTime>=$time_fadein && vvad!=1){vvad=1;\$('div.video_ad_fadein').fadeIn('slow');}
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


 my (@sources, $sources_code);

if($file->{hls_direct})
{
	@sources=();
	push @sources, qq[<source src="$file->{hls_direct}" type="application/x-mpegURL">];
}
elsif($file->{dash_direct})
{
	@sources=();
	push @sources, qq|<source src="$file->{dash_direct}" type="application/dash+xml">|;
}
elsif($file->{direct_links})
{
	for(@{$file->{direct_links}})
	{
		#my $default=',selected: true' if $_->{mode} eq $c->{player_default_quality};
		my $hd=' data-fluid-hd' if $_->{mode}=~/^(h|x)$/;
		push @sources, qq[<source$hd src="$_->{direct_link}" type="video/mp4" title="$_->{label}">];
	}
}
 

 $sources_code = join('', @sources);

 my $tracks_code = join "", @tracks;


$file->{vid_length} = $c->{video_time_limit} if $c->{video_time_limit};

$file->{player_img} ||= $file->{video_img_url};


if($c->{m_z} && $c->{time_slider})
{

 	$layout_code.=qq[timelinePreview: {file: '/dl?op=get_slides&length=$file->{vid_length}&url=$file->{img_timeslide_url}', type: 'VTT' },];
}

my $plugins_code = join ',', @plugins;
my $autoplay = $file->{autostart} ? 'autoplay' : '';

$extra_html.=qq[<script src="$c->{cdn_url}/js/dnsads.js"></script>] if $c->{adb_no_money};
#<script type="text/javascript" src="$c->{cdn_url}/playerjs7/videojs.watermark.js"></script>
#<link href="/VideoJS/videojs.watermark.css" rel="stylesheet">

my $html=qq[$extra_html_pre
            <div id='vplayer' style="width:100%;height:100%;text-align:center;">
            	
            </div>

<script src="https://cdn.fluidplayer.com/v3/current/fluidplayer.min.js"></script>
<style>
#fplayercontext_option_homepage {display:none;}
</style>

];

$layout_code.=qq[autostart: true,] if $file->{autostart};
$layout_code.=qq[title: "$file->{file_title}",] if $f->{embed} && $file->{usr_embed_title};
$layout_code.=qq[controlForwardBackward: { show: true },] if $c->{player_forward_rewind};
my $logohide=',hideWithControls: true' if $c->{player_logo_hide};
my $logo_position = $c->{player_logo_position};
$logo_position=~s/-/ /;
$layout_code.=qq[logo: {imageUrl: "$c->{player_logo_url}", clickUrl: "$c->{player_logo_link}", position: "$logo_position", opacity: "$c->{player_logo_opacity}", imageMargin: "$c->{player_logo_padding}"$logohide},] if $c->{player_logo_url};

my $code=<<ENP
\$('#vplayer').append('<video id="fplayer" style="width:100%; height:100%;" crossOrigin="anonymous">$sources_code $tracks_code</video>');

var player = fluidPlayer('fplayer', {
							layoutControls: { 
								posterImage: '$file->{player_img}',
								preload: '$c->{mp4_preload}',
								playButtonShowing: true,
								controlBar: { autoHide: true, autoHideTimeout: 5, animated: false },
								contextMenu: { controls: true, links: [ {href: '$c->{site_url}', label: '$c->{site_name}'} ] },
								playbackRateEnabled: true,
								allowTheatre: false,
								$layout_code
							},
							$extra_settings
							}
						);


$js_code

ENP
;
       
#$file->{img_timeslide_url}
#window.HELP_IMPROVE_VIDEOJS = false;
	return($html,$code);
}

1;
