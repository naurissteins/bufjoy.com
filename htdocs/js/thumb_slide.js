var cx, cy, inter, th_url, bg_orig, ani_active, $active, $next;
var tile_x=5,tile_y=5;
var thumb_w=200, thumb_h=112;
var ani_delay=600;

function slideStart(aa)
{
    if(ani_active)return;
    $active = $(aa).find('div').eq(0);
    if($active.length==0)return;
    ani_active=1;
    bg_orig = $active.css('background-image');
    th_url = bg_orig+'';
    th_url = th_url.replace("_t","0000");
    th_url.match(/url\("?(.+?)"?\)/);
    var thurl2=RegExp.$1;
    $('<img />')
    .attr('src', thurl2)
    .on('load',function(){
        $('body').append( $(this).hide() );
        if(!ani_active)return;
        //$active.css('background-image',th_url).css('background-size',(thumb_w*tile_x)+'px '+(thumb_h*tile_y)+'px').css('background-position',0-thumb_w+'px 0px');
        $next = $active.clone(true);
        $active.css('z-index',3);
        $active.parent().prepend($next);
        cx=0, cy=0;
        if(inter)window.clearInterval(inter);
        inter = window.setInterval("slideNext()",ani_delay);
        $(this).remove();
    });
}
function slideNext()
{
    if(!ani_active)return;
    cx++;
    if(cx>=tile_x){ cx=0; cy++; }
    if(cy>=tile_y){ cy=0; }
    x = 0 - thumb_w*cx;
    y = 0 - thumb_h*cy;
    $next.css('background-image',th_url).css('background-size',(thumb_w*tile_x)+'px '+(thumb_h*tile_y)+'px').css('background-position',x+'px '+y+'px');
    $next.find('span').hide();
    $active.animate({opacity:0}, ani_delay-50, function(){
          $next.css('z-index',3);
	  $active.css('z-index',1).css('opacity',1);
	  var $x = $active;
	  $active = $next;
	  $next = $x;
      });
}
function slideStop()
{
    if(!ani_active)return;
    ani_active=0;
    $active.stop(true).css('background-image',bg_orig).css('background-position','').css('background-size','').css('z-index',3).css('opacity',4);
    $active.find('span').show();
    if($next && $next.length)$next.remove();
    window.clearInterval(inter);
}

$("a.video200:not(.noslides)").each(function(){
    $(this).mouseenter(function(){slideStart(this)});
    $(this).mouseleave(function(){slideStop()});
});
