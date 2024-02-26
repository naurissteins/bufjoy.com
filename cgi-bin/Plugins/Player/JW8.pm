package Plugins::Player::JW8;
use strict;
use XFileConfig;
use vars qw($ses $c);

sub makePlayerCode
{
	my ($self, $f, $file, $c, $player ) = @_;
	return if $player ne 'jw8';

	my (@tracks, $extra, $extra_html_pre, $extra_html, $extra_js, $js_code_pre, 
		$extra_onready, $extra_onplay, $extra_ontime, $vast_ontime_func, $extra_complete, $extra_pause);

	if($c->{m_z} && $c->{time_slider})
	{
		push @tracks, qq[{file: "/dl?op=get_slides&length=$file->{file_length}&url=$file->{img_timeslide_url}", kind: "thumbnails"}];
	}

 # http://support.jwplayer.com/customer/portal/articles/1407438-adding-closed-captions
 # http://support.jwplayer.com/customer/portal/articles/1482067-styling-captions-for-fcc-compliance
 if($c->{srt_on})
 {
    # my $lnghash;
    # for(split /\s*\,\s*/, $c->{srt_auto_langs})
    # {
    # 	/(\w+)=(\w+)/;
    # 	$lnghash->{$1}=$2;
    # }

    my $srtauto=',"default": true' if $c->{srt_auto_enable};
    
	unless($file->{hls_direct})
	{
		for(@{$file->{captions_list}})
		{
			push @tracks, qq[{file: "$_->{url}", label: "$_->{title}", kind: "captions"$srtauto}];
			$srtauto='';
		}
	}
    my $bgopacity = 0;
    # https://developer.jwplayer.com/jwplayer/docs/jw8-player-configuration-reference#captions
    # fontSize: $c->{srt_size}
    my $srt_size = $c->{srt_size}/100;
    $extra.=qq[,captions: { 
	    			userFontScale: $srt_size, 
	    			color: '$c->{srt_color}', 
	    			backgroundColor: '$c->{srt_back_color}',
	    			fontFamily:"$c->{srt_font}", 
	    			backgroundOpacity: $c->{srt_opacity}, 
	    			fontOpacity: '$c->{srt_opacity_text}',
    			}];
  #   $extra_html.="<style>
		# .jw-text-track-cue {
		# 	text-shadow: 1px 1px 2px $c->{srt_shadow_color} !important;
		# 	line-height: 1.53em;
		# 	padding-left: 0.3em  !important;
		# 	padding-right: 0.3em  !important;
		# 	padding-bottom: 0.2em  !important;
		# 	border-radius: 6px;
		# }
		# </style>";
 }

if($c->{srt_allow_anon_upload})
{
push @tracks, qq[{file: "/srt/empty.srt", label: "Upload captions", kind: "captions"}];
$extra_onready.=<<ENP
player.on('captionsChanged',function(tr){
	if( RegExp('empty').test(tr.tracks[tr.track].id) )
	{
		jwplayer().pause(true);
		jwplayer().setCurrentCaptions(0);
		openIframeOverlay('/?op=upload_srt&file_code=$file->{file_code}');
	}
} );

function openIframeOverlay(url)
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
}).prop({'src':url, 'frameborder':'0', 'scrolling':'no'}).appendTo(\$dd);

 \$dd.click(function (){ \$(this).remove(); jwplayer().play(); });
 \$dd.appendTo( \$('#vplayer') );
}
ENP
;
}

 if($c->{player_sharing})
 {
    #$ses->{cgi_query}->url_encode
    require URL::Encode;
    #my $embed_code = URL::Encode::url_encode( qq[<IFRAME SRC="$c->{site_url}/embed-$file->{file_code}.html" FRAMEBORDER=0 MARGINWIDTH=0 MARGINHEIGHT=0 SCROLLING=NO allowfullscreen="true" WIDTH=$file->{play_w} HEIGHT=$file->{play_h}></IFRAME>] );
    my $embed_code = URL::Encode::url_encode( $file->{embed_code} );
    $embed_code=~s/\+/ /g;
    $file->{download_link}||=$ses->makeFileLink($file);
    $extra .= qq[,"sharing": {code: "$embed_code", link: "$file->{download_link}", sites: [] }]; #sites:["facebook","twitter","email"]
 }

 my $tracks_code = ',tracks: ['.join(",\n",@tracks).']';

 #$extra_onready.="jwplayer().resize( \$(window).width(), \$(window).height() );" if $f->{embed};
#$extra_js.=qq|jwplayer().on('displayClick', function() { jwplayer().setFullscreen(true); });| if $ses->isMobile; # autofullscreen on click for mobiles
$extra_js.=qq|jwplayer().addButton(
    "/images/download2.png",
    "Watch on site", 
    function() {
        //window.top.location.href = '$file->{download_link}';
        var win = window.open('$file->{download_link}', '_blank');
  		win.focus();
    },
    "download11"
);| if $f->{embed} && $c->{player_embed_dl_button};

 if($c->{m_w} && $file->{vast_ads} && !$ses->getCookie('vastski'))
 {
	my $preload = q|, "preloadAds": true| if $c->{vast_preload};
	my $tag_pre = $c->{vast_preroll} && $c->{vast_tag} ? qq|"tag": "$c->{vast_tag}", | : '';
	$extra.=qq[,"advertising": {$tag_pre "client": "$c->{vast_client}", "vpaidmode": "$c->{vast_vpaid_mode}"$preload}];
	if($c->{vast_midroll} && $c->{vast_midroll_time})
	{
		my $dtime = $c->{vast_midroll_time}=~/(\d+)\%/ ? int($file->{vid_length}*$1/100) : $c->{vast_midroll_time};
		my $mid_tag = $c->{vast_midroll_tag} ? $c->{vast_midroll_tag} : $c->{vast_tag};
		#$extra_onplay.=qq|if(vastdone1==0)window.setTimeout( function (){ jwplayer().playAd('$mid_tag'); }, $dtime*1000 );|;
		$vast_ontime_func.=qq|if(x.position>=$dtime && vastdone1==0){ vastdone1=1; jwplayer().playAd('$mid_tag'); }|;
	}
	if($c->{vast_postroll} && $c->{vast_postroll_time})
	{
		my $dt = $c->{vast_postroll_time}=~/(\d+)\%/ ? int($file->{vid_length}*$1/100) : $c->{vast_postroll_time};
		my $dtime = $file->{vid_length} - $dt;
		my $post_tag = $c->{vast_postroll_tag} ? $c->{vast_postroll_tag} : $c->{vast_tag};
		$vast_ontime_func.=qq|if(x.position>=$dtime && vastdone2==0){ vastdone2=1; jwplayer().playAd('$post_tag'); }|;
	}
	if($c->{vast_pauseroll})
	{
		my $pause_tag = $c->{vast_pauseroll_tag} || $c->{vast_tag};
		$extra_pause.=qq|jwplayer().playAd('$pause_tag');jwplayer().pause(true);|;
	}
	$ses->setCookie('vastski','1',"+$c->{vast_skip_mins}m") if $c->{vast_skip_mins} && !$ses->getCookie('vastski');
 }

if($c->{remember_player_position})
{
	$extra_ontime.=qq[if(x.position>=lastt+5 || x.position<lastt){ lastt=x.position; ls.set('tt$file->{file_code}', Math.round(lastt), { ttl: 60*60*24*7 }); }];
	$extra_onplay.=qq|var lastt = ls.get('tt$file->{file_code}'); if(lastt>0){ jwplayer().seek( lastt ); }|;
	$extra_html.=qq|<script src="/js/localstorage-slim.js"></script>|;
	$extra_complete.=qq|ls.remove('tt$file->{file_code}');|;
}

my $time_fadein=$c->{player_ads_fadein}||0;
my $vtime = int $file->{vid_length}*$c->{track_views_percent}/100;

if($c->{video_time_limit})
{
	$extra_onplay.=qq|window.setTimeout( function (){ jwplayer().stop(); jwplayer().remove(); \$('#play_limit_box').show(); }, $c->{video_time_limit}*1000 );|;
	$extra_complete.=qq|\$('#play_limit_box').show();|;
}

if($file->{preview})
{
	$extra_complete.=qq|\$('#over_player_msg').show();|;
	$file->{vid_length}='';
}

$extra_onready.=qq|jwplayer().addButton(
    '<svg xmlns="http://www.w3.org/2000/svg" class="jw-svg-icon jw-svg-icon-rewind2" viewBox="0 0 240 240" focusable="false"><path d="m 25.993957,57.778 v 125.3 c 0.03604,2.63589 2.164107,4.76396 4.8,4.8 h 62.7 v -19.3 h -48.2 v -96.4 H 160.99396 v 19.3 c 0,5.3 3.6,7.2 8,4.3 l 41.8,-27.9 c 2.93574,-1.480087 4.13843,-5.04363 2.7,-8 -0.57502,-1.174985 -1.52502,-2.124979 -2.7,-2.7 l -41.8,-27.9 c -4.4,-2.9 -8,-1 -8,4.3 v 19.3 H 30.893957 c -2.689569,0.03972 -4.860275,2.210431 -4.9,4.9 z m 163.422413,73.04577 c -3.72072,-6.30626 -10.38421,-10.29683 -17.7,-10.6 -7.31579,0.30317 -13.97928,4.29374 -17.7,10.6 -8.60009,14.23525 -8.60009,32.06475 0,46.3 3.72072,6.30626 10.38421,10.29683 17.7,10.6 7.31579,-0.30317 13.97928,-4.29374 17.7,-10.6 8.60009,-14.23525 8.60009,-32.06475 0,-46.3 z m -17.7,47.2 c -7.8,0 -14.4,-11 -14.4,-24.1 0,-13.1 6.6,-24.1 14.4,-24.1 7.8,0 14.4,11 14.4,24.1 0,13.1 -6.5,24.1 -14.4,24.1 z m -47.77056,9.72863 v -51 l -4.8,4.8 -6.8,-6.8 13,-12.99999 c 3.02543,-3.03598 8.21053,-0.88605 8.2,3.4 v 62.69999 z"></path></svg>',
    "Forward 10 sec", 
    function() {
        jwplayer().seek( jwplayer().getPosition()+10 );
    },
    "ff11"
);
\$("div[button=ff11]").detach().insertAfter('.jw-icon-rewind');

jwplayer().addButton(
    '<svg xmlns="http://www.w3.org/2000/svg" class="jw-svg-icon jw-svg-icon-rewind" viewBox="0 0 240 240" focusable="false"><path d="M113.2,131.078a21.589,21.589,0,0,0-17.7-10.6,21.589,21.589,0,0,0-17.7,10.6,44.769,44.769,0,0,0,0,46.3,21.589,21.589,0,0,0,17.7,10.6,21.589,21.589,0,0,0,17.7-10.6,44.769,44.769,0,0,0,0-46.3Zm-17.7,47.2c-7.8,0-14.4-11-14.4-24.1s6.6-24.1,14.4-24.1,14.4,11,14.4,24.1S103.4,178.278,95.5,178.278Zm-43.4,9.7v-51l-4.8,4.8-6.8-6.8,13-13a4.8,4.8,0,0,1,8.2,3.4v62.7l-9.6-.1Zm162-130.2v125.3a4.867,4.867,0,0,1-4.8,4.8H146.6v-19.3h48.2v-96.4H79.1v19.3c0,5.3-3.6,7.2-8,4.3l-41.8-27.9a6.013,6.013,0,0,1-2.7-8,5.887,5.887,0,0,1,2.7-2.7l41.8-27.9c4.4-2.9,8-1,8,4.3v19.3H209.2A4.974,4.974,0,0,1,214.1,57.778Z"></path></svg>',
    "Rewind 10 sec", 
    function() {
    	var tt = jwplayer().getPosition()-10;
    	if(tt<0)tt=0;
        jwplayer().seek( tt );
    },
    "ff00"
);
\$("div[button=ff00]").detach().insertAfter('.jw-icon-rewind');
\$("div.jw-icon-rewind").hide();
| if $c->{player_forward_rewind} && !$ses->isMobile;

# $extra_onready.=qq|jwplayer().addButton(
#     "/player/jw8/ff.png",
#     "Forward 10 sec", 
#     function() {
#         jwplayer().seek( jwplayer().getPosition()+10 );
#     },
#     "ff11"
# );
# \$("div[button=ff11]").detach().insertAfter('.jw-icon-rewind');

# jwplayer().addButton(
#     "/player/jw8/fr.png",
#     "Rewind 10 sec", 
#     function() {
#     	var tt = jwplayer().getPosition()-10;
#     	if(tt<0)tt=0;
#         jwplayer().seek( tt );
#     },
#     "ff00"
# );
# \$("div[button=ff00]").detach().insertAfter('.jw-icon-rewind');
# | if $c->{player_forward_rewind} && !$ses->isMobile;

if($c->{multi_audio_on})
{
	# List of languages: https://quickref.me/iso-639-1
	#my $alang = {'en' => 'English', 'ru' => 'Русский', 'fr' => 'Français', 'de' => 'Deutsch', 'es' => 'Español', it => 'Italiano', 'sv' => 'Svenska', 'pt' => 'Português'}->{ $file->{usr_default_audio_lang} };
	my $lhash;
	map{/^(\w+)=(\w+)$/;$lhash->{$1}=$2;} split(/,\s*/,$c->{multi_audio_user_list});
	my $alang = $lhash->{ $file->{usr_default_audio_lang} } || $c->{player_default_audio_track};
	my $set_default_audio=qq|if( !localStorage.getItem('default_audio') ) setTimeout("audio_set('$alang')", 300 );| if $alang;
	my $audio_sticky=qq|player.on("audioTrackChanged", function(event){ localStorage.setItem('default_audio',event.tracks[event.currentTrack].name);  });
		if( localStorage.getItem('default_audio') ){ setTimeout("audio_set(localStorage.getItem('default_audio'));", 300 ); }| if $c->{player_default_audio_sticky} && !$alang;
	$extra_js.=<<ENP
		player.on("audioTracks",function(event){
			var tracks=player.getAudioTracks();
			if(tracks.length<2)return;
			\$('.jw-settings-topbar-buttons').mousedown(function() { 
			\$('#jw-settings-submenu-audioTracks').removeClass('jw-settings-submenu-active');
			\$('.jw-submenu-audioTracks').attr('aria-expanded','false');
		});
		player.addButton("/images/dualy.svg","Audio Track",function(){
			\$('.jw-controls').toggleClass('jw-settings-open');
			\$('.jw-settings-captions, .jw-settings-playbackRates').attr('aria-checked','false');
			if( \$('.jw-controls').hasClass('jw-settings-open') ){ 
				\$('.jw-submenu-audioTracks').attr('aria-checked','true');
				\$('.jw-submenu-audioTracks').attr('aria-expanded','true');
				\$('.jw-settings-submenu-quality').removeClass('jw-settings-submenu-active');
				\$('.jw-settings-submenu-audioTracks').addClass('jw-settings-submenu-active');
			}
			else {
				\$('.jw-submenu-audioTracks').attr('aria-checked','false');
				\$('.jw-submenu-audioTracks').attr('aria-expanded','false');
				\$('.jw-settings-submenu-audioTracks').removeClass('jw-settings-submenu-active');
			}
		},"dualSound");
		$audio_sticky
		$set_default_audio
	});
	var current_audio;
	function audio_set(audio_name)
	{
		var tracks=player.getAudioTracks();
		if(tracks.length>1){
			for(i=0;i<tracks.length;i++){ if(tracks[i].name==audio_name){ if(i==current_audio){return;} current_audio=i; player.setCurrentAudioTrack(i); } }
		}
	}
ENP
;
}

$extra_ontime.=qq|if(x.viewable){ dt=x.position-prevt; if(dt>5)dt=1; tott += dt; }
    prevt=x.position;
    if(tott>=$vtime && !v2done){
    	v2done=1;
    	\$.post('/dl', {op: 'view2', hash: '$file->{ophash}', embed: '$f->{embed}', adb: adb, w: tott}, function(data){} );
    }| if $c->{views_tracking_mode2};

if($c->{player_hidden_link})
{
	$file->{ophash2} = $ses->HashSave($file->{file_id},0);
	$extra_html.="<script src='$c->{cdn_url}/js/tear.js'></script>" if $c->{player_hidden_link_tear};
	my $tear= $c->{player_hidden_link_tear} ? "data[0]['seed'] = data[0]['seed'].replace(/[012567]/g, m => chars[m]); data[0]['file'] = decrypt( data[0]['file'], data[0]['seed'] );" : "";
	$extra_onready.=qq|var vvbefore;
		if(vvbefore)return; vvbefore=1;
		player.stop();
		\$.post('/dl', {op: 'playerddl', file_code: '$file->{file_code}', hash: '$file->{ophash2}'}, function(data){ 
			var chars = {	'0':'5', '1':'6', '2':'7', 
							'5':'0', '6':'1', '7':'2'};
			$tear
			data[0]['file'] = data[0]['file'].replace(/[012567]/g, m => chars[m]);
			player.load(data); //.play();
		} );
  	|;
}

if($file->{file_skip_time}=~/^\d+$/)
{
	$extra_onplay.=qq|si11=1;\$('<button type="button" id="si11" class="si11" onclick="jwplayer().seek( $file->{file_skip_time} )" style="position:absolute;padding:7px;border:1px solid #fff;border-radius:3px;bottom:7em;right:1em;opacity:0.9;background: transparent;color:#FFF;">SKIP INTRO</button>').appendTo('div.jw-wrapper');|;
	$extra_ontime.=qq|if(si11==1 && x.position>=$file->{file_skip_time}){\$('#si11').hide();si11=0;}|;
}

my $js_code=<<ENP
var vvplay,vvad;
var vastdone1=0,vastdone2=0;
var player = jwplayer();
var prevt=0, tott=0, v2done=0, lastt=0;
\$.ajaxSetup({ headers: { 'Content-Cache': 'no-cache' } });
player.on('time', function(x) { 
    if($time_fadein>0 && x.position>=$time_fadein && vvad!=1){vvad=1;\$('div.video_ad_fadein').fadeIn('slow');}
    $vast_ontime_func
    $extra_ontime
});
player.on('seek', function(x) { prevt=x.position; });
player.on('play', function(x) { doPlay(x); });
player.on('complete', function() { \$('div.video_ad').show(); $extra_complete });
player.on('pause', function(x) { $extra_pause });
//player.on('all', function(x) { console.log(x); });

function doPlay(x)
{
  \$('div.video_ad').hide();
  \$('#over_player_msg').hide();
  if(vvplay)return;
  vvplay=1;
  adb=0;
  if( window.cRAds === undefined ){ adb=1; }
  \$.get('/dl?op=view&file_code=$file->{file_code}&hash=$file->{ophash}&embed=$f->{embed}&referer=$file->{referer}&adb='+adb, function(data) {\$('#fviews').html(data);} );
  $extra_onplay
}

function set_audio_track()
{
  var tracks=player.getAudioTracks(track_name);
  console.log(tracks);
  if(tracks.length>1){
  	for(i=0;i<tracks.length;i++){ if(tracks[i].name==track_name){ console.log('!!='+i); player.setCurrentAudioTrack(i); } }
  }
}

    player.on('ready', function(){
    		$extra_onready
    });

$extra_js

ENP
;

 my @sources;
 
 if($file->{hls_direct})
 {
    #@sources=();
    unshift @sources, qq[{file:"$file->{hls_direct}"}];
	if($c->{player_default_quality})
	{
		#defaultBandwidthEstimate
		my $vi = $ses->vInfo($file,$c->{player_default_quality});
		my $bitrate = ($vi->{vid_bitrate}+$vi->{vid_audio_bitrate})*1000;
		$extra_html_pre.="<script>localStorage.setItem('jwplayer.bitrateSelection', '$bitrate');</script>";
	}
	my @qlabels;
    for my $q ('o',reverse @{$c->{quality_letters}})
    {
		next unless $file->{"file_spec_$q"};
		my $vi = $ses->vInfo($file,$q);
		my $bitrate = ($vi->{vid_bitrate}+$vi->{vid_audio_bitrate})-1;
		my $qname=$c->{quality_labels}->{$q};
		push @qlabels, qq["$bitrate":"$qname"];
    }
    $extra.=",'qualityLabels':{".join(',',@qlabels)."}" if @qlabels;
 }
 elsif($file->{dash_direct})
 {
    unshift @sources, qq[{file:"$file->{dash_direct}"}];
    $extra.=qq[,dash: true];
 }
 elsif($file->{direct_links})
 {
 	for(@{$file->{direct_links}})
 	{
 		push @sources, qq[{file:"$_->{direct_link}",label:"$_->{label}"}];
 		$extra_html_pre.="<script>localStorage.setItem('jwplayer.qualityLabel', '$_->{label}');</script>" if $c->{player_default_quality} eq $_->{mode};
 	}
 }

 my $sources_code = join(',',@sources);

 if($c->{jw8_skin})
 {
    $extra.=qq[,skin: "$c->{jw8_skin}"];
    $extra_html.=qq[<link rel="stylesheet" type="text/css" href="$c->{cdn_url}/player/jw8/skins/$c->{jw8_skin}.css"></link>];
 }

$file->{vid_length} = $c->{video_time_limit} if $c->{video_time_limit};
if($file->{embed})
{
    #$file->{play_w}=$file->{play_h}='100';
    #
}
else
{
	#$extra.=qq[,width: "$file->{play_w}", height: "$file->{play_h}"];
}

$extra.=qq[,title:"$file->{file_title}", displaytitle:true] if $f->{embed} && $file->{usr_embed_title};

$c->{player_about_link}||=$c->{site_url};
$extra.=qq[,abouttext:"$c->{player_about_text}", aboutlink:"$c->{player_about_link}"];

$extra.=qq[,related: {file:"/dl?op=related&code=$file->{file_code}", onclick:"link", oncomplete:"show", displayMode:"shelf"}] if $c->{player_related};

my $logohide=',hide: true' if $c->{player_logo_hide};
$extra.=qq[,logo: {file:"$c->{player_logo_url}", link:"$c->{player_logo_link}", position:"$c->{player_logo_position}", margin:"$c->{player_logo_padding}"$logohide}] if $c->{player_logo_url};

$extra.=qq[,autostart: 'viewable'] if $file->{autostart};

$extra.=",cast: {}" if $c->{player_chromecast};

$extra.=qq|,playbackRateControls: true, playbackRates: [$c->{player_playback_rates}]| if $c->{player_playback_rates};

if($file->{p2p} && $file->{hls_direct})
{
	if($c->{p2p_provider} eq 'streamroot')
	{
		$extra.=qq[,p2pConfig:{ streamrootKey: '$c->{streamroot_key}', contentId: '$file->{file_code}', cacheSize: '250', mobileBrowserEnabled: false }];
		$extra_html.='<script src="//cdn.streamroot.io/jw7-hlsjs-provider/stable/jw7-hlsjs-provider.js"></script>';
	}
	elsif($c->{p2p_provider} eq 'peer5')
	{
		$extra_html_pre.=qq|<script src="//cdn.vdosupreme.com/vdo.js?id=$c->{p2p_peer5_key}"></script>
 							 <script src="//cdn.vdosupreme.com/vdo.jwplayer8.plugin.js"></script>
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
	elsif($c->{p2p_provider} eq 'self')
	{
		# $extra_html_pre.=q|<script src="https://cdn.jsdelivr.net/npm/p2p-media-loader-core@latest/build/p2p-media-loader-core.min.js"></script> 
		# 				    <script src="/player/jw8/p2p-media-loader-hlsjs.min.js"></script>
		# 				    <!--script src="https://cdn.jsdelivr.net/npm/@hola.org/jwplayer-hlsjs@latest/dist/jwplayer.hlsjs.min.js"></script-->
		# 				    <script src="/player/jw8/jwplayer.hlsjs.min.js"></script>|;
		# https://github.com/Novage/p2p-media-loader/issues/174
		# https://github.com/Teranode/jw-provider
		# https://github.com/Chocobozzz/p2p-media-loader/tree/peertube
		# npm i @peertube/p2p-media-loader-hlsjs
		$extra_html_pre.=q| <script src="/player/jw8/p2p-media-loader-core.min.js"></script> 
						    <script src="/player/jw8/p2p-media-loader-hlsjs.min.js"></script>

						    <!--script src="https://cdn.jsdelivr.net/npm/p2p-media-loader-core@latest/build/p2p-media-loader-core.min.js"></script>
							<script src="https://cdn.jsdelivr.net/npm/p2p-media-loader-hlsjs@latest/build/p2p-media-loader-hlsjs.min.js"></script-->
						    
						    <!--script src="https://cdn.jsdelivr.net/npm/@hola.org/jwplayer-hlsjs@latest/dist/jwplayer.hlsjs.min.js"></script-->

						    <script src="/player/jw8/provider.hlsjs.js"></script>
						   |;
		#$extra_html.=q|<script src="https://cdn.jsdelivr.net/npm/hls.js@0.15.0-alpha.2.0.canary.6250/dist/hls.min.js"></script>|;
		#$extra_html.=q|<script src="https://cdn.jsdelivr.net/npm/hls.js@latest"></script>|;
		#$extra_html.=q|<script src="https://cdnjs.cloudflare.com/ajax/libs/hls.js/1.1.0/hls.min.js" crossorigin="anonymous" referrerpolicy="no-referrer"></script>|;
		
		# https://github.com/Novage/p2p-media-loader/blob/master/FAQ.md
		$js_code_pre.=qq|const p2pconfig = {
						  segments: {
						  	forwardSegmentCount:60,
						    swarmId: "$file->{file_real}"
						  },
						  loader:{
						  	trackerAnnounce: '$c->{p2p_self_tracker_url}',
						  	// how long to store the downloaded segments for P2P sharing
						    cachedSegmentExpiration:86400000,
						    // count of the downloaded segments to store for P2P sharing
						    cachedSegmentsCount:500,
						    // first 4 segments (priorities 0, 1, 2 and 3) are required buffer for stable playback
    						requiredSegmentsPriority:2,
						    // P2P will try to download only first 51 segment ahead of playhead position
						    p2pDownloadMaxPriority: 50,
						    // number of simultaneous downloads for P2P and HTTP methods
    						simultaneousP2PDownloads:20,
    						simultaneousHttpDownloads:2,
    						// enable mode, that try to prevent HTTP downloads on stream start-up
    						//httpDownloadInitialTimeout: 120000, // try to prevent HTTP downloads during first 2 minutes
    						//httpDownloadInitialTimeoutPerSegment: 17000, // try to prevent HTTP download per segment during first 17 seconds
    						// allow to continue aborted P2P downloads via HTTP
    						httpUseRanges: true,
    						
    						// each 1 second each of 10 segments ahead of playhead position gets 6% probability for random HTTP download
    						httpDownloadMaxPriority:9,
						    httpDownloadProbability:0.06,
						    httpDownloadProbabilityInterval: 1000,

						    // disallow randomly download segments over HTTP if there are no connected peers
						    httpDownloadProbabilitySkipIfNoPeers: true,
						  }	
						};
						var engine = new p2pml.hlsjs.Engine(p2pconfig);
						var loaded_http=0,loaded_p2p=0;
						engine.on("peer_connect", peer => console.log("p2p_peer_connect", peer.id, peer.remoteAddress));
						engine.on("peer_close", peerId => console.log("p2p_peer_close", peerId));
						engine.on("segment_loaded", function(segment, peerId){
							console.log(segment.data.byteLength+" bytes","p2p_segment_loaded from", peerId ? `peer \${peerId}` : "HTTP", segment.url);
							if(peerId)loaded_p2p+=segment.data.byteLength; else loaded_http+=segment.data.byteLength;
							console.log("Total HTTP:"+loaded_http+"  P2P:"+loaded_p2p); 
							}
						);
						//engine.on("segment_loaded", (segment, peerId) => console.log("p2p_segment_loaded from", peerId ? `peer \${peerId}` : "HTTP", segment.url));
						//engine.on("piece_bytes_downloaded", (method, size) => console.log("piece_bytes_downloaded ", method, size) );
						//engine.on("piece_bytes_downloaded", function(method, size){ 
						//	if(method=='http')loaded_http+=size; else loaded_p2p+=size;
						//	console.log("piece_bytes_downloaded ", method, size, "Total HTTP:"+loaded_http, "P2P:"+loaded_p2p); 
						//} );
						|;

		$extra.=qq[,hlsjsConfig: {
						liveSyncDurationCount: 3, // have at least 7 segments in queue
            			loader: engine.createLoaderClass(),
				}];

		# $js_code.=q|jwplayer_hls_provider.attach();
		# 			p2pml.hlsjs.initJwPlayer(player, {
		#                 liveSyncDurationCount: 7, // have at least 7 segments in queue
		#                 loader: engine.createLoaderClass()
		#             });|;
		$js_code.=q|const iid = setInterval(() => {
            console.log(player.hls);
            if (player.hls && player.hls.config) {
                clearInterval(iid);
                p2pml.hlsjs.initHlsJsPlayer(player.hls)
            }
        }, 200);|;
	}
}


$file->{player_img} ||= $file->{video_img_url};

$extra.=qq|,skin: {controlbar: {text:"$c->{player_color}", icons:"$c->{player_color}"}, timeslider:{progress:"$c->{player_color}"}, menus:{text:"$c->{player_color}"} },| if $c->{player_color};

#function jwp(a){return a.replace(/[a-zA-Z]/g, function(c){return String.fromCharCode((c <= "Z" ? 90 : 122) >= (c = c.charCodeAt(0) + 13) ? c : c - 26);})}
#$file->{direct_link} =~ tr/A-Za-z/N-ZA-Mn-za-m/;
#$file->{http_fallback} =~ tr/ab/ba/;
#var xch = {'a':'b','b':'a'}; var ctrans = /[ab]/g; function jvp(a){  return a.replace(ctrans, m => xch[m]); }

#height: "$file->{play_h}",
#aspectratio: "16:9",
#    primary:"flash",

my $code=<<ENP
$js_code_pre
  jwplayer("vplayer").setup({
    sources: [$sources_code],
    image: "$file->{player_img}",
    width: "100%", 
    height: "100%",
    stretching: "$c->{player_image_stretching}",
    duration: "$file->{vid_length}",
    aspectratio: "16:9",
    preload: '$c->{mp4_preload}',
    //displayPlaybackLabel: true,
    //horizontalVolumeSlider: true,
    //allowFullscreen: false,
    //"autoPause": { "viewability": true, "pauseAds": true },
    //skin: {controlbar: {text:"#6F6", icons:"#6F6"}, timeslider:{progress:"#6F6"}, menus:{text:"#6F6"} },
    //pipIcon: 'disabled',
    androidhls: "true"
    $tracks_code
    $extra
  });
$js_code
ENP
;

# https://easylist.to/easylist/easylist.txt
$extra_html.=qq[<script src="$c->{cdn_url}/js/dnsads.js?ads=1&AdType=1&cbrandom=2&clicktag=http"></script>] if $c->{adb_no_money};

	my $html=qq[$extra_html_pre<script type='text/javascript' src='$c->{cdn_url}/player/jw8/jwplayer.js?v=$c->{cdn_version_num}'></script>
                <script type="text/javascript">jwplayer.key="$c->{jw8_key}";</script>
                $extra_html
                <div id='vplayer' style="width:100%;height:100%;text-align:center;"><img src="$file->{player_img}" style="width:100%;height:100%;"></div>];

	return($html,$code);
}

1;
