#!/usr/bin/perl
use strict;
use lib '.';
use XFileConfig;
use Session;
use CGI::Carp qw(fatalsToBrowser);

my $ses = Session->new();
my $db = $ses->db;

my $design;
if($ARGV[0]=~/^(\d+)$/)
{
  $design = $1;
  $ses->{cookies}->{design} = $design;
}

$|++;
print"Content-type:text/html\n\n";

### Categories ###
my $cath;
require SecTett;
my $clist = $db->SelectARef("SELECT * FROM Categories ORDER BY cat_num");
my $srv_ip = &SecTett::convertIP($ses,$c,$c->{srv_ip});
my $cx=1;
for my $x (@$clist)
{
    $x->{cat_name2} = $x->{cat_name};
    $x->{cat_name2}=~s/\s+/+/g;
    $cath->{$x->{cat_id}} = {cat_name=>$x->{cat_name}, cat_name2=>$x->{cat_name2}};
    $x->{img} = "$c->{site_url}/images/cat_$x->{cat_id}.jpg" if -f "$c->{site_path}/images/cat_$x->{cat_id}.jpg";
    $x->{img} ||= "$c->{site_url}/images/cat_$x->{cat_id}.png" if -f "$c->{site_path}/images/cat_$x->{cat_id}.png";
    $x->{img} ||= "$c->{site_url}/images/cat_default.png";
    if($cx++%3==0)
    {
      $x->{clear}=1;
      $cx=1;
    }
}
my $categories = $db->SelectARef("SELECT f.cat_id, c.cat_name, COUNT(*) as num 
                                  FROM Files f, Categories c
                                  WHERE f.cat_id>0
                                  AND f.file_public=1
                                  AND f.cat_id=c.cat_id
                                  GROUP BY f.cat_id 
                                  ORDER BY cat_parent_id, cat_num
                                  LIMIT 12");
for my $x (@$categories)
{
   $x->{cat_name2}=$cath->{$x->{cat_id}}->{cat_name2};
}
my $tmpl = $ses->CreateTemplate("categories.html");
$tmpl->param(categories => $categories);
open FILE, ">$c->{cgi_path}/Templates$design/static/categories.html";
print FILE $tmpl->output();
close FILE;
print"Categories done.<br>\n";

### Categories All ###
for my $x (@$clist)
{
  $x->{num} = $db->SelectOne("SELECT COUNT(*) FROM Files f WHERE f.file_public=1 AND f.cat_id=?",$x->{cat_id});
}
my $tmpl = $ses->CreateTemplate("categories_all.html");
$tmpl->param(categories => $clist);
open FILE, ">$c->{cgi_path}/Templates$design/static/categories_all.html";
print FILE $tmpl->output();
close FILE;
print"Categories All done.<br>\n";

### List Data Fields ###
my @list_menu;
for my $name (split /\s*\,\s*/, $c->{file_data_fields})
{
    my $list = $db->SelectARef("SELECT name, value, COUNT(*) as num 
                                FROM FilesData 
                                WHERE name=? 
                                GROUP BY value 
                                ORDER BY num DESC 
                                LIMIT 100",$name);
    my $name2 = lc $name;
    push @list_menu, {name=>$name,name2=>$name2,num=>$#$list+1};

    my $cx=1;
    for my $x (@$list)
    {
        $x->{value2} = lc $x->{value};
        $x->{value3} = $x->{value};
        $x->{value2}=~s/\s+/_/g;
        $x->{value3}=~s/\s+/+/g;
        $x->{name2} = $name2;
        $x->{img} = "$c->{site_url}/images/res/$x->{name2}_$x->{value2}.jpg" if -f "$c->{site_path}/images/res/$x->{name2}_$x->{value2}.jpg";
        $x->{img} ||= "$c->{site_url}/images/res/$x->{name2}_$x->{value2}.png" if -f "$c->{site_path}/images/res/$x->{name2}_$x->{value2}.png";
        $x->{img} ||= "$c->{site_url}/images/res/default.png";
        if($cx++%3==0)
        {
          $x->{clear}=1;
          $cx=1;
        }
    }

    my $tmpl = $ses->CreateTemplate("list_data.html");
    $tmpl->param(list => $list);
    open FILE, ">$c->{cgi_path}/Templates$design/static/list_data_$name2.html";
    print FILE $tmpl->output();
    close FILE;
}
print"Data fields done.<br>\n";

### List menu ###
my $tmpl = $ses->CreateTemplate("list_menu.html");
$tmpl->param(list => \@list_menu);
open FILE, ">$c->{cgi_path}/Templates$design/static/list_menu.html";
print FILE $tmpl->output();
close FILE;

### List News ###
my $newsa = $db->SelectARef("SELECT n.*, u.usr_avatar, u.usr_login, u.usr_channel_name, DATE_FORMAT(n.created,'%M %dth, %Y') as created_txt, COUNT(c.cmt_id) as comments
									FROM News n
									LEFT JOIN Comments c ON c.cmt_type = 2 AND c.cmt_ext_id = n.news_id
									LEFT JOIN Users u ON n.usr_id = u.usr_id
									WHERE n.created <= NOW()
									GROUP BY n.news_id
									ORDER BY n.created DESC LIMIT 3");

	for(@$newsa)
	{
		$_->{site_url} = $c->{site_url};
		$_->{link} = "n$_->{news_id}-$_->{news_title2}.html";
		$_->{news_text} =~s/\n/<br>/gs;
		$_->{news_text} =~s/\[cut\](.+)$//gse;
		$_->{enable_file_comments} = $c->{enable_file_comments};
		$_->{usr_channel_name}||=$_->{usr_login};
		# Extracting the first two letters of the usr_login
		if (defined $_->{usr_login} && length $_->{usr_login} >= 1) {
			$_->{usr_login_short} = substr($_->{usr_login}, 0, 1);
		} else {
			# Handle cases where usr_login is undefined or shorter than 2 characters
			$_->{usr_login_short} = $_->{usr_login} // '';
		}		
	}                  

my $tmpl = $ses->CreateTemplate("newsa.html");
$tmpl->param(newsa => $newsa);
open FILE, ">$c->{cgi_path}/Templates$design/static/newsa.html";
print FILE $tmpl->output();
close FILE;
print"News done.<br>\n";  

### Stats ###
my $total_users = $db->SelectOne("SELECT COUNT(*) FROM Users");
my $total_files = $db->SelectOne("SELECT COUNT(*) FROM Files");
my $used_total = $db->SelectOne("SELECT ROUND(SUM(srv_disk)/1073741824,2) FROM Servers");

my $tmpl = $ses->CreateTemplate("site_stats.html");
$tmpl->param(total_users => $total_users, total_files => $total_files, used_total => $used_total);
open FILE, ">$c->{cgi_path}/Templates$design/static/site_stats.html";
print FILE $tmpl->output();
close FILE;
print"Site Stats done.<br>\n";  


### Tags ###
my $tag_top = $db->SelectARef("SELECT tag_id, COUNT(*) as x FROM Tags2Files GROUP BY tag_id ORDER BY x DESC LIMIT 20");
my $tag_ids = join(',', map{$_->{tag_id}}@$tag_top ) || 0;
my $tags = $db->SelectARef("SELECT * FROM Tags WHERE tag_id IN ($tag_ids) ORDER BY RAND()");
for(@$tags)
{
   $_->{tag} = $_->{tag_value};
   $_->{tag}=~s/\s+/\+/g;
}
my $tmpl = $ses->CreateTemplate("tags.html");
$tmpl->param(tags => $tags);
open FILE, ">$c->{cgi_path}/Templates$design/static/tags.html";
print FILE $tmpl->output();
close FILE;
print"Tags done.<br>\n";

my $filter_public = "AND f.file_public=1" if $c->{search_public_only};

my $index_per_row=3;
if($c->{index_featured_on})
{
    ### Featured ###
    $c->{index_featured_num}||=1;
    my $filter_length_min = "AND file_length>=$c->{index_featured_min_length}" if $c->{index_featured_min_length}=~/^\d+$/;
    my $filter_length_max = "AND file_length<=$c->{index_featured_max_length}" if $c->{index_featured_max_length}=~/^\d+$/;
    my $featured = $db->SelectARef("SELECT f.*, s.*, u.usr_login as file_usr_login, TO_DAYS(CURDATE())-TO_DAYS(file_created) as created
                                     FROM (FilesFeatured ff, Files f, Servers s, Users u)
                                     WHERE ff.file_id=f.file_id
                                     AND f.srv_id=s.srv_id
                                     AND f.usr_id=u.usr_id
                                     AND (f.file_size_n>0 OR f.file_size_h>0 OR f.file_size_l>0 OR f.file_size_x>0)
                                     AND f.file_status='OK'
                                     $filter_length_min
                                     $filter_length_max
                                     $filter_public
                                     ORDER BY RAND()
                                     LIMIT $c->{index_featured_num}");
    my $cx;
    for(@$featured)
    {
       $_->{clear}=1 unless ++$cx % $index_per_row;
    }
    $ses->processVideoList($featured);
    
    my $tmpl = $ses->CreateTemplate("videos_list_index.html");
    $tmpl->param(title=>'<TMPL_VAR lng_index_featured_videos>', files => $featured);
    open FILE, ">$c->{cgi_path}/Templates$design/static/videos_featured.html";
    print FILE $tmpl->output() if $#$featured>-1;
    close FILE;
    print"Featured done.<br>\n";
}


if($c->{index_most_viewed_on})
{
    ### Most Viewed ###
    $c->{index_most_viewed_num}||=1;
    my $filter_length_min = "AND file_length>=$c->{index_most_viewed_min_length}" if $c->{index_most_viewed_min_length}=~/^\d+$/;
    my $filter_length_max = "AND file_length<=$c->{index_most_viewed_max_length}" if $c->{index_most_viewed_max_length}=~/^\d+$/;
    my $most = $db->SelectARef("SELECT f.*, s.*, u.usr_login as file_usr_login, TO_DAYS(CURDATE())-TO_DAYS(file_created) as created
                                FROM (Files f, Servers s, Users u)
                                WHERE f.file_created>NOW()-INTERVAL ? HOUR
                                AND f.srv_id=s.srv_id
                                AND f.usr_id=u.usr_id
                                AND (f.file_size_n>0 OR f.file_size_h>0 OR f.file_size_l>0 OR f.file_size_x>0)
                                AND f.file_status='OK'
                                $filter_length_min
                                $filter_length_max
                                $filter_public
                                ORDER BY file_views DESC
                                LIMIT $c->{index_most_viewed_num}",$c->{index_most_viewed_hours}||1);
    my $cx;
    for(@$most)
    {
       $_->{clear}=1 unless ++$cx % $index_per_row;
    }
    $ses->processVideoList($most);
    
    my $tmpl = $ses->CreateTemplate("videos_list_index.html");
    $tmpl->param(title=>'<TMPL_VAR lng_index_most_viewed_videos>', files => $most);
    open FILE, ">$c->{cgi_path}/Templates$design/static/videos_most_viewed.html";
    print FILE $tmpl->output() if $#$most>-1;
    close FILE;
    print"Most Viewed done.<br>\n";
}


### Most Rated ###
if($c->{index_most_rated_on})
{
    $c->{index_most_rated_num}||=1;
    my $filter_length_min = "AND file_length>=$c->{index_most_rated_min_length}" if $c->{index_most_rated_min_length}=~/^\d+$/;
    my $filter_length_max = "AND file_length<=$c->{index_most_rated_max_length}" if $c->{index_most_rated_max_length}=~/^\d+$/;
    my $most = $db->SelectARef("SELECT f.*, s.*, u.usr_login as file_usr_login, TO_DAYS(CURDATE())-TO_DAYS(file_created) as created
                                FROM (Files f, Servers s, Users u)
                                WHERE f.file_created>NOW()-INTERVAL ? HOUR
                                AND f.srv_id=s.srv_id
                                AND f.usr_id=u.usr_id
                                AND (f.file_size_n>0 OR f.file_size_h>0 OR f.file_size_l>0 OR f.file_size_x>0)
                                AND f.file_status='OK'
                                $filter_length_min
                                $filter_length_max
                                $filter_public
                                ORDER BY file_rating DESC
                                LIMIT $c->{index_most_rated_num}",$c->{index_most_rated_hours}||1);
    my $cx;
    for(@$most)
    {
       $_->{clear}=1 unless ++$cx % $index_per_row;
    }
    $ses->processVideoList($most);
    
    my $tmpl = $ses->CreateTemplate("videos_list_index.html");
    $tmpl->param(title=>'<TMPL_VAR lng_index_most_rated_videos>', files => $most);
    open FILE, ">$c->{cgi_path}/Templates$design/static/videos_most_rated.html";
    print FILE $tmpl->output() if $#$most;
    close FILE;
    print"Most Rated done.<br>\n";
}


### Just Added ###
if($c->{index_just_added_on})
{
    $c->{index_just_added_num}||=1;
    my $filter_length_min = "AND file_length>=$c->{index_just_added_min_length}" if $c->{index_just_added_min_length}=~/^\d+$/;
    my $filter_length_max = "AND file_length<=$c->{index_just_added_max_length}" if $c->{index_just_added_max_length}=~/^\d+$/;
    my $files = $db->SelectARef("SELECT f.*, s.*, u.usr_login as file_usr_login, TO_DAYS(CURDATE())-TO_DAYS(file_created) as created
                                FROM (Files f, Servers s, Users u)
                                WHERE 1
                                AND f.srv_id=s.srv_id
                                AND f.usr_id=u.usr_id
                                AND (f.file_size_n>0 OR f.file_size_h>0 OR f.file_size_l>0 OR f.file_size_x>0)
                                AND f.file_status='OK'
                                $filter_length_min
                                $filter_length_max
                                $filter_public
                                ORDER BY file_created DESC
                                LIMIT $c->{index_just_added_num}");
    my $cx;
    for(@$files)
    {
       $_->{clear}=1 unless ++$cx % $index_per_row;
    }
    $ses->processVideoList($files);
    
    my $tmpl = $ses->CreateTemplate("videos_list_index.html");
    $tmpl->param(title=>'<TMPL_VAR lng_index_just_added>', files => $files);
    open FILE, ">$c->{cgi_path}/Templates$design/static/videos_just_added.html";
    print FILE $tmpl->output() if $#$files>-1;
    close FILE;
    print"Just Added done.<br>\n";
}

if($c->{index_live_streams_on})
{
	$c->{index_live_streams_num}||=9;
	my $list = $db->SelectARef("SELECT *, UNIX_TIMESTAMP(NOW())-UNIX_TIMESTAMP(started) as file_length,
    							(SELECT COUNT(*) FROM Stream2IP i WHERE i.stream_id=s.stream_id AND i.created>NOW()-INTERVAL 60 SECOND) as watchers
								FROM (Streams s, Users u, Hosts h)
								WHERE s.stream_live=1
								AND s.usr_id=u.usr_id
								AND s.host_id=h.host_id
								ORDER BY s.started DESC
								LIMIT $c->{index_live_streams_num}");
	my $cx;
	for(@$list)
    {
		$_->{clear}=1 unless ++$cx % $index_per_row;
		$_->{extra_info}="$_->{watchers} watching";
		$_->{video_thumb_url} = "$_->{host_htdocs_url}/tmp/$_->{stream_code}.jpg";
		$_->{file_title_txt} = $_->{stream_title};
		$_->{download_link} = "$c->{site_url}/stream/$_->{stream_code}";
		$_->{file_length2} = sprintf("%02d:%02d:%02d",int($_->{file_length}/3600),int(($_->{file_length}%3600)/60),$_->{file_length}%60);
       	$_->{file_length2}=~s/^00:(\d\d:\d\d)$/$1/;
		$_->{no_views}=1;
		$_->{no_created}=1;
		$_->{extra_css}='noslides';
    }
    my $tmpl = $ses->CreateTemplate("videos_list_index.html");
	$tmpl->param(title => 'LIVE STREAMS', files => $list);
	open FILE, ">$c->{cgi_path}/Templates$design/static/videos_live.html";
	print FILE $tmpl->output() if $#$list>-1;
	close FILE;
	print"Live Streams done.<br>\n";
}

print"-----------------------<br>ALL DONE<br><br><a href='$c->{site_url}/adm?op=admin_servers'>Back to server management</a>";
