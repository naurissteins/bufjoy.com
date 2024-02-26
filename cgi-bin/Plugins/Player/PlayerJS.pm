package Plugins::Player::PlayerJS;
use strict;
use XFileConfig;
use vars qw($ses $c);

# https://playerjs.com/docs/en=code
# https://beautifier.io/

# coupon code: XVIDEOSHARING

sub makePlayerCode
{
	my ($self, $f, $file, $c, $player ) = @_;
	return if $player ne 'pjs';

    my ($extra_settings,$extra_html,$extra_js,@tracks,$extra_html_pre,@plugins,$extra_onready,$extra_onplay);

my $show_box_after_limit=qq[ \$('#play_limit_box').show(); ] if $c->{video_time_limit};
my $time_fadein=$c->{player_ads_fadein}||0;
my $vtime = int $file->{vid_length}*$c->{track_views_percent}/100;
my $x2time = int $vtime/2;

if($c->{srt_on})
{
    my @vtts;
    for(@{$file->{captions_list}})
    {
      push @vtts, qq[[$_->{title}]$_->{url}];
	}
	
	if($c->{srt_allow_anon_upload})
	{
		push @vtts, qq[[Upload SRT]$c->{site_url}/srt/empty.vtt];
		#$extra_js.=qq|player.on('subtitlechange', (event, sub) => { if(sub.label=='Upload SRT'){ showCCform(); } });|;
	}

	my $subs=join(",",@vtts);
	$extra_settings.=qq[ ,"subtitle":"$subs", subtitle_start:0] if $subs;
	$extra_settings.=qq[ , subtitle_start:0];
}

# https://playerjs.com/docs/en=api
my $js_code=<<ENP
var vvplay,vvad;

function PlayerjsEvents(event,id,data){
	if(event=="play"){
		return doPlay();
	}
	if(event=="end"){
		return doEnd();
	}
	if(event=="time"){
		return doTime(data);
	}
	if(event=="subtitle"){
		return doSubtitle(data);
	}
}

function doEnd()
{
	\$('div.video_ad').show();
	$show_box_after_limit
}

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

function doTime(currentTime)
{
	if($time_fadein>0 && currentTime>=$time_fadein && vvad!=1){vvad=1;\$('div.video_ad_fadein').fadeIn('slow');}
}

function doSubtitle(title)
{
	if(title=='Upload SRT'){ showCCform(); }
}

function showCCform()
{
player.api('pause');

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

 \$dd.click(function (){ \$(this).remove(); player.api('play'); });
 \$dd.appendTo( \$('#playerjs') );
}

$extra_js

ENP
;

if($c->{player_logo_url})
{
	#$js_code.="\nplayer.watermark({'image' : '$c->{player_logo_url}'});";
}

 my (@sources, $sources_code);

if($file->{hls_direct})
{
	push @sources, $file->{hls_direct};
}
elsif($file->{dash_direct})
{
	push @sources, $file->{dash_direct};
}
elsif($file->{direct_links})
{
	for(@{$file->{direct_links}})
	{
		push @sources, qq[[$_->{label}]$_->{direct_link}];
	}
}

$sources_code = join(',', @sources);



 $file->{vid_length} = $c->{video_time_limit} if $c->{video_time_limit};

 $file->{player_img} ||= $file->{video_img_url};


if($c->{m_z} && $c->{time_slider})
{
    # https://playerjs.com/docs/en=thumbnails
    $extra_settings.=qq[, thumbnails:"$c->{site_url}/dl?op=get_slides&length=$file->{vid_length}&url=$file->{video_img_folder}/$file->{file_real}0000.jpg"];
}

my $plugins_code = join ',', @plugins;

$extra_html.=qq[<script src="$c->{cdn_url}/js/dnsads.js"></script>] if $c->{adb_no_money};

my $html=qq[$extra_html_pre

<script src="/player/pjs/playerjs.js" type="text/javascript"></script>

<div id="playerjs" style="width:100%;height:100%"></div>

$extra_html
];

$extra_settings .= qq[, title:"$file->{file_title}"] if $c->{player_show_title};
$extra_settings .= qq[, autoplay:1] if $file->{autostart};

$extra_settings .= qq[, preroll:"$c->{vast_tag}"] if $c->{vast_preroll} && $c->{vast_tag};
$extra_settings .= qq|, midroll:[{time:"$c->{vast_midroll_time}", vast:"$c->{vast_midroll_tag}"}]| if $c->{vast_midroll} && $c->{vast_midroll_tag};
$extra_settings .= qq[, postroll:"$c->{vast_postroll_tag}"] if $c->{vast_postroll} && $c->{vast_postroll_tag};
$extra_settings .= qq[, pauseroll:"$c->{vast_pauseroll_tag}"] if $c->{vast_pauseroll} && $c->{vast_pauseroll_tag};

my $filesrc = $file->{hls_playlist} ? qq|file:$file->{hls_playlist},plstart:"$file->{file_code}"| : qq|file:"$sources_code"|;

my $code=<<ENP
var player = new Playerjs({id:"playerjs", ready:"PlayerReady", duration:"$file->{vid_length}", poster:"$file->{player_img}", $filesrc $plugins_code $extra_settings});

function PlayerReady(id){
	$extra_onready
};

$js_code

ENP
;
       
	return($html,$code);
}

1;
