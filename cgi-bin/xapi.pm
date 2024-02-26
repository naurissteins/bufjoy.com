package xapi;

use strict;
use lib '.';
use XFileConfig;
use Sibsoft::Filter50864_6;
use SecTetx;
use Session;
use JSON;
use XUtils;

	# Status Codes:
	# 200: Everything is OK. Request succeeded
	# 400: Bad request (e.g. wrong parameters)
	# 403: Permission denied (wrong api login/key, action on a file which does not belong to you, ...)
	# 404: File not found
	# 409: Conflict
	# 451: Unavailable For Legal Reasons

my ($ses,$f,$db, $user);

sub run
{
	my ($query,$dbc) = @_;

	$ses = Session->new($query,$dbc);
	$ses->{fast_cgi} = $c->{fast_cgi};

	$f = $ses->f;
	$f->{op}||='';
	$db ||= $ses->db;

	$f->{key}=$f->{api_key} if !$f->{key} && $f->{api_key};

	my ($usr_id,$api_key) = $f->{key}=~/^(\d+)(\w{16})$/;
	return out({"status"=>400, msg=>"Invalid key"}) unless $usr_id && $api_key;

	$user = $db->SelectRow("SELECT *, UNIX_TIMESTAMP(usr_premium_expire)-UNIX_TIMESTAMP() as exp_sec FROM Users WHERE usr_id=? AND usr_api_key=?",$usr_id,$api_key);
	return out({"status"=>403, msg=>"Wrong auth"}) unless $user && logged($user);
	$user->{premium} = $user->{exp_sec}>0 ? 1 : 0;
	$ses->{user} = $user;
	$ses->loadUserData();
	return out({"status"=>403, msg=>"API not enabled for your account"}) unless $ses->checkModSpecialRights('m_6');

	$f->{op} = "$1_$2" if $ENV{REQUEST_URI}=~/api\/(\w+)\/(\w+)/i;

	if($f->{op}=~/^(file_clone|file_direct_link|file_delete)$/)
	{
		if($c->{m_6_users_spec} eq 'premium' && !$user->{premium})
		{
			return out({"status"=>403, msg=>"API special allowed for premium only"});
		}
		elsif($c->{m_6_users_spec} eq 'special' && !$db->SelectOneCached("SELECT value FROM UserData WHERE usr_id=? AND name='usr_api_spec'",$user->{usr_id}))
		{
			return out({"status"=>403, msg=>"API special not enable for your account"});
		}
	}

	my $sub={
		account_info	=> \&AccountInfo,
		account_stats	=> \&AccountStats,
		upload_url		=> \&UploadURL,
		upload_server	=> \&UploadServer,
		file_clone 		=> \&Clone,
		file_info 		=> \&FileInfo,
		file_edit	 	=> \&FileEdit,
		file_direct_link=> \&FileDirectLink,
		file_list		=> \&FileList,
		folder_list 	=> \&FolderList,
		folder_edit		=> \&FolderEdit,
		folder_create 	=> \&FolderCreate,
		folder_delete	=> \&FolderDelete,
		file_dmca		=> \&FileDMCA,
		file_encodings 	=> \&FileEncodings,
		file_url_uploads=> \&FileURLUploads,
		file_url_actions=> \&FileURLActions,
		file_delete		=> \&FileDelete,
		file_deleted	=> \&FileDeleted,
		regen_screenlist=> \&RegenScreenlist,
		upload_sub		=> \&UploadSub,
		adm_delete 		=> \&AdminDelete,
		adm_user_add	=> \&AdminUserAdd,
	}->{ $f->{op} };

	if($sub)
	{
		if($c->{m_6_req_limit_day})
		{
			$user->{api_requests} = $db->SelectOne("SELECT value FROM StatsMisc 
													WHERE usr_id=? 
													AND day=CURDATE() 
													AND name='api'",$user->{usr_id})||0;
			return out({"status"=>403, msg=>"Requests limit reached: $c->{m_6_req_limit_day} per day"}) if $user->{api_requests}>=$c->{m_6_req_limit_day};
			$db->Exec("INSERT INTO StatsMisc 
						SET usr_id=?, 
						day=CURDATE(), 
						name='api', 
						value=1 
						ON DUPLICATE KEY UPDATE value=value+1",$user->{usr_id});
		}
		if($c->{m_6_req_limit_min})
		{
			$user->{api_requests_min} = $ses->checkEventRate($user->{usr_id}, 'api', $c->{m_6_req_limit_min});
			return out({"status"=>403, msg=>"Requests limit reached: $c->{m_6_req_limit_min} per min"}) if $user->{api_requests_min} >= $c->{m_6_req_limit_min};
		}
		
		return &$sub;
	}
	else
	{
		return out({"status"=>400, msg=>"Invalid operation"});
	}
}

sub UploadURL
{
	$user->{usr_id}=$f->{usr_id} if $f->{usr_id} && $user->{usr_adm};
	$c->{queue_url_max} = $user->{premium} ? $c->{queue_url_max_prem} : $c->{queue_url_max_reg};
	return out({"status"=>400, "msg"=>"You have reached max URLs limit: $c->{queue_url_max}"}) if $c->{queue_url_max} && $db->SelectOne("SELECT COUNT(*) FROM QueueUpload WHERE usr_id=?",$user->{usr_id})>=$c->{queue_url_max};
	return out({"status"=>400, "msg"=>"This URL already in upload queue"}) if $db->SelectOne("SELECT url FROM QueueUpload WHERE url=?",$f->{url});
	my $code = randchar(12);
	while($db->SelectOne("SELECT file_id FROM Files WHERE file_code=? OR file_real=?",$code,$code))
	{
		$code = randchar(12);
	}

	my $folder = $db->SelectRow("SELECT * FROM Folders WHERE usr_id=? AND fld_id=?", $user->{usr_id}, $f->{fld_id}) if $f->{fld_id}=~/^\d+$/;
	my $fld_id = $folder ? $folder->{fld_id} : 0;

	require URI::Escape;
	$f->{url} = URI::Escape::uri_unescape($f->{url});
	require HTML::Entities;
	HTML::Entities::decode_entities($f->{url});
	$f->{url}=~s/[\`\|\>\<\"]+//g;
	$f->{url}=~s/\&\&//g;
	$f->{url}=~s/(base64|xvideos|youtube)//gi;
	$f->{url}=~s/^\s+//g;
	$f->{url}=~s/\s+$//g;
	$f->{url}=~s/[\0\"]+//g;

	$f->{cat_id}=~s/\D+//g;
	$f->{file_public}=~s/\D+//g;
	$f->{file_adult}=~s/\D+//g;
	my @extras;
	for('cat_id','file_public','file_adult','tags')
	{
		push @extras, "$_=$f->{$_}" if $f->{$_};
	}

	$db->Exec("INSERT INTO QueueUpload 
				SET usr_id=?, 
				url=?, 
				file_code=?, 
				fld_id=?,
				premium=?, 
				extras=?,
				ip=INET_ATON(?),
				created=NOW()", 
				$user->{usr_id}, 
				$f->{url}, 
				$code, 
				$fld_id, 
				$user->{premium}, 
				join("\n",@extras), 
				$ses->getIP 
			);
	return out({"status"=>200, "msg"=>"OK", result=>{"filecode"=>$code} });
}

sub AdminDelete
{
    return out({"status"=>403, msg=>"Access denied"}) unless $user->{usr_adm};
    my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{file_code});
    return out({"status"=>404, msg=>"No file"}) unless $file;
    $ses->DeleteFile($file);
    return out({"status"=>200, msg => "OK"});
}

sub Clone
{
    return out({"status"=>403, "msg"=>"This function not allowed in API"}) unless $c->{m_6_clone};
    my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{file_code});
    return out({"status"=>404, "msg"=>"No file"}) unless $file;
	$f->{file_title} = $ses->SecureStr($f->{file_title});
    $file->{file_title}=$f->{file_title} if $f->{file_title};
    my $code = $ses->cloneFile($file,$f->{fld_id});
    return out({ "status"=>200, "msg"=>"OK", "result"=>{"filecode"=>$code,"url"=>"$c->{site_url}/$code"} });
}

sub FileDMCA
{
   $f->{last} = 24*30 unless $f->{last}=~/^\d+$/;
   my $list = $db->SelectARef("SELECT *, UNIX_TIMESTAMP(del_time)-UNIX_TIMESTAMP() as del_in
   								FROM FilesDMCA d, Files f 
   								WHERE d.usr_id=? 
   								AND d.file_id=f.file_id 
   								AND created > NOW()-INTERVAL ? HOUR
   								ORDER BY del_time", $user->{usr_id}, $f->{last});
   my @arr;
   for(@$list)
   {
     push @arr, { file_code=>$_->{file_code}, del_time=>$_->{del_time}, del_in_sec=>$_->{del_in} };
   }
   return out({"status"=>200, "msg"=>"OK", result => \@arr});
}

###########

sub out
{
   my $data = shift;
   $data->{server_time} = sprintf("%d-%02d-%02d %02d:%02d:%02d", $ses->getTime() );
   $data->{requests_available} = $c->{m_6_req_limit_day}-$user->{api_requests}-1 if $c->{m_6_req_limit_day};
   $data->{requests_available} = $c->{m_6_req_limit_min}-$user->{api_requests_min}-1 if $c->{m_6_req_limit_min};
   $data->{requests_available}=0 if $data->{requests_available}<0;
   print"Content-type:application/json; charset=utf-8\n\n".JSON::to_json($data);
}

sub randchar
{ 
   my @range = ('0'..'9','a'..'z');
   my $x = int scalar @range;
   join '', map $range[rand $x], 1..shift||1;
}sub logged {return $c->{m_6}?1:0;}

sub FileInfo
{
  my @list = grep{/^\w{12}$/} split /,/, $f->{file_code};
  return out({"status"=>400, "msg"=>"Invalid file codes"}) unless @list;
  @list = splice @list, 0, 50;
  my $codes = join ',', map{qq['$_']} @list;
  my $list = $db->SelectARef("SELECT f.*, d.del_time 
				FROM Files f
				LEFT JOIN FilesDMCA d ON d.file_id=f.file_id
				WHERE file_code IN ($codes) 
				LIMIT 100");
  my $hh;
  $hh->{$_->{file_code}}=$_ for @$list;
  my @arr;
  for my $code (@list)
  {
    if($hh->{$code})
    {
      my $status = 200;
      $status=451 if $hh->{$code}->{del_time};
      $ses->genThumbURLs($hh->{$code});
      my $x = { status 		=> $status, 
      			canplay 	=> canPlay($hh->{$code}),
      			};
      $x->{$_} = $hh->{$code}->{$_} 
      	for qw(	file_code
      			file_title
      			file_views_full
      			file_views
      			file_created
      			file_last_download
      			file_length
      			player_img
      			cat_id
      			file_fld_id
      			file_public
				file_adult
				file_premium_only
      			);
      my $tags = $db->SelectARef("SELECT * FROM Tags t, Tags2Files t2f WHERE t2f.file_id=? AND t2f.tag_id=t.tag_id", $hh->{$code}->{file_id} );
      $x->{tags} = join ', ', map{$_->{tag_value}} @$tags;
      push @arr, $x;
    }
    else
    {
      push @arr, {status=>404, file_code=>$code};
    }
  }
  return out({"status"=>200, "msg"=>"OK", result => \@arr});
}

sub FolderList
{
  my $folder = $db->SelectRow("SELECT * FROM Folders WHERE fld_id=? AND usr_id=?", $f->{fld_id}, $user->{usr_id} ) if $f->{fld_id};
  return out({"status"=>403, "msg"=>"Folder not exist or not yours"}) if !$folder && $f->{fld_id};
  $folder->{fld_id}=0 unless $folder;
  
  my $result;

  my $fld_list = $db->SelectARef("SELECT * FROM Folders WHERE usr_id=? AND fld_parent_id=?", $user->{usr_id}, $folder->{fld_id});
  my @folders;
  for(@$fld_list)
  {
    push @folders, {fld_id=>$_->{fld_id}, name=>$_->{fld_name}, code=>$_->{fld_code}};
  }
  $result->{folders} = \@folders;

  if($f->{files})
  {
  	my $list = $db->SelectARef("SELECT * FROM Files WHERE usr_id=? AND file_fld_id=? ORDER BY file_created DESC", $user->{usr_id}, $folder->{fld_id});
  	my $files = processFilesList($list);
  	$result->{files} = $files;
  }

  return out({"status"=>200, "msg"=>"OK", result => $result });
}

sub canPlay
{
    my ($file) = @_;
    for(@{$c->{quality_letters}})
    {
    	return 1 if $file->{"file_size_$_"};
    }
    return 1 if $file->{file_size_o} && $file->{file_spec_o}=~/(h264|mp4|aac|mp3|m4a|wav|flac)/i;
    return 0;
}

sub FolderEdit
{
   return out({"status"=>400, msg=>"Folder id required"}) unless $f->{fld_id}=~/^\d+$/;
   my $user_filter="AND usr_id=$user->{usr_id}" unless $user->{usr_adm};
   my $folder = $db->SelectRow("SELECT * FROM Folders WHERE fld_id=? $user_filter", $f->{fld_id} );
   return out({"status"=>403, "msg"=>"Folder not exist"}) unless $folder;
   $f->{name} = $ses->SecureStr($f->{name}) if $f->{name};
   $f->{descr} = $ses->SecureStr($f->{descr}) if $f->{descr};
   $f->{parent_id} =~ s/\D+//g;
   return out({"status"=>400, msg=>"Invalid folder name"}) if defined $f->{name} && length($f->{name})<2;
   return out({"status"=>400, msg=>"Invalid parent folder id"}) if $f->{parent_id}==$f->{fld_id};
   return out({"status"=>400, msg=>"Invalid parent folder id"}) if $f->{parent_id} && !$db->SelectOne("SELECT fld_id FROM Folders WHERE fld_id=? $user_filter",$f->{parent_id});
   $f->{name}  = $folder->{fld_name} unless defined $f->{name};
   $f->{descr} = $folder->{fld_descr} unless defined $f->{descr};
   $f->{parent_id} = $folder->{fld_parent_id} unless defined $f->{parent_id};
   $db->Exec("UPDATE Folders 
   				SET fld_name=?,
   					fld_descr=?,
   					fld_parent_id=?
   				WHERE fld_id=? 
   				LIMIT 1", 
   				$f->{name}, 
   				$f->{descr},
   				$f->{parent_id},
   				$folder->{fld_id});

   return out({"status"=>200, "msg"=>"OK", result=>'true' });
}

sub FolderDelete
{
	return out({"status"=>400, msg=>"Folder id required"}) unless $f->{fld_id}=~/^\d+$/;
	my $user_filter="AND usr_id=$user->{usr_id}" unless $user->{usr_adm};
	my $folder = $db->SelectRow("SELECT * FROM Folders WHERE fld_id=? $user_filter", $f->{fld_id} );
	return out({"status"=>403, "msg"=>"Folder not exist"}) unless $folder;
	return out({"status"=>403, "msg"=>"Folder have files inside"}) if $db->SelectOne("SELECT COUNT(*) FROM Files WHERE file_fld_id=?",$folder->{fld_id});
	return out({"status"=>403, "msg"=>"Folder have sub-folders inside"}) if $db->SelectOne("SELECT COUNT(*) FROM Folders WHERE fld_parent_id=?",$folder->{fld_id});
	$db->Exec("DELETE FROM Folders WHERE fld_id=?",$folder->{fld_id});
	return out({"status"=>200, msg => "OK"});
}

sub FileEdit
{
	my @fields = qw(file_title
					file_descr
					file_public
					file_adult
					file_premium_only
					cat_id
					file_fld_id
					);
	my (@keys, @values);
	$f->{file_title} = $ses->SecureStr($f->{file_title});
    $f->{file_descr} = $ses->SecureStr($f->{file_descr});
    for(qw(file_public file_adult file_premium_only))
    {
    	$f->{$_} = $f->{$_} ? 1 : 0 if defined $f->{$_};
    }
	return out({"status"=>400, msg=>"Invalid file name"}) if defined $f->{title} && length($f->{title})>=2;
	return out({"status"=>400, msg=>"Invalid cat_id"}) if defined $f->{cat_id} && !$db->SelectOne("SELECT cat_id FROM Categories WHERE cat_id=?",$f->{cat_id});
	for(@fields)
    {
        if(defined $f->{$_})
        {
            my $value = $f->{$_};
            next if $value=~/[\>\<\"\0]+/;
            push @keys, "$_ = ?";
            push @values, $value;
        }
    }
    my $codes = join "','", grep{/^\w{12}$/} split /,/, $f->{file_code};
    my $user_filter="AND usr_id=$user->{usr_id}" unless $user->{usr_adm};
    $db->Exec("UPDATE Files SET ".join(',',@keys)." WHERE file_code IN ('$codes') $user_filter", @values) if @keys && $codes;

    my $files = $db->SelectARef("SELECT * FROM Files WHERE file_code IN ('$codes')");
    for(@$files)
    {
    	$db->Exec("DELETE FROM Tags2Files WHERE file_id=?",$_->{file_id});
    	XUtils::addTagsToFile( $ses->db, $f->{tags}, $_->{file_id} );
    }

	return out({"status"=>200, "msg"=>"OK", result=>'true' });
}

sub FileEncodings
{
	my $user_filter="AND q.usr_id=$user->{usr_id}" unless $user->{usr_adm};
	my $code_filter="AND f.file_real='$f->{file_code}'" if $f->{file_code}=~/^\w{12}$/;
	my $list = $db->SelectARef("SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(q.updated) as updated2 
				FROM QueueEncoding q, Files f 
				WHERE q.file_id=f.file_id
				$user_filter
				$code_filter
				ORDER BY status DESC, started DESC");
	my @arr;
	for(@$list)
	{
		$_->{status}='STUCK' if $_->{status} eq 'ENCODING' && $_->{updated2} > 300;
		push @arr, { file_code=>$_->{file_real}, quality=>$_->{quality}, title=>$_->{file_title}, status=>$_->{status}, progress=>int($_->{progress}/100),  link=>$ses->makeFileLink($_) };
	}

	return out({"status"=>200, "msg"=>"OK", result=>\@arr });
}

sub FileURLUploads
{
	my $user_filter="AND usr_id=$user->{usr_id}" unless $user->{usr_adm};
	my $code_filter="AND file_code='$f->{file_code}'" if $f->{file_code}=~/^\w{12}$/;
	my $list = $db->SelectARef("SELECT *, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(q.updated) as updated2 
								FROM QueueUpload q
								WHERE 1
								$user_filter
								$code_filter
								ORDER BY status DESC, started DESC");
	my @arr;
	for(@$list)
	{
		$_->{status}='STUCK' if $_->{status} eq 'WORKING' && $_->{updated2} > 300;
		push @arr, { file_code=>$_->{file_code}, remote_url=>$_->{url}, fld_id=>$_->{fld_id}, status=>$_->{status}, progress=>int($_->{progress}/100) };
	}

	return out({"status"=>200, "msg"=>"OK", result=>\@arr });
}

sub FileDirectLink
{
	return out({"status"=>403, "msg"=>"This function not allowed in API"}) unless $c->{m_6_direct};
	my $file = $ses->getFileRecord($f->{file_code});
	unless($file)
	{
		return out({"status"=>200,"msg"=>"uploading"}) if $db->SelectOne("SELECT id FROM QueueUpload WHERE file_code=?",$f->{file_code});
		return out({"status"=>404,"msg"=>"no file"});
	}
	$ses->genThumbURLs($file);
	my $s = { player_img => $file->{player_img}, file_length => $file->{file_length} };
	if($f->{q}=~/^\w$/)
	{
		$s = $file->{"file_size_$f->{q}"} ? genDirectLink($file,$f->{q},'v.mp4') : "";
	}
	else
	{
		my @arr;
		for my $q (@{$c->{quality_letters}},'o')
		{
			push @arr, {name=>$q, size=>$file->{"file_size_$q"}, url=>$ses->genDirectLink($file,$q,"$file->{file_code}_$q.mp4")} if $file->{"file_size_$q"};
		}
		# push @arr, {name=>'p', size=>$file->{file_size_p}, url=>$ses->genDirectLink($file,'p','v.mp4')} if $file->{file_size_p};
		$s->{versions} = \@arr;
	}
	if($c->{m_r} && $f->{hls})
	{
		my ($play,$playprem) = $ses->getPlayVersions($file);
		$s->{hls_direct} = $ses->genHLSLink($file, $play);
	}
	return out({"status"=>200, "msg"=>"OK", result=>$s });
}

sub makeURLSet
{
  my (@l) = @_;
  my $i=0;
  for my $k (0..length($l[0]))
  {
     for (1..$#l){
      $i=$k if substr($l[0],$k,1) ne substr($l[$_],$k,1);
     }
     last if $i;
  }
  my $pre = substr($l[0],0,$i);
  substr($_,0,$i)='' for @l;
  return ($pre,@l);
}

sub genDirectLink
{
	my ( $file, $quality, $fname, $hash_only )=@_;

	my $dx = sprintf("%05d",($file->{file_real_id}||$file->{file_id})/$c->{files_per_folder});
	my $watch_speed = $c->{"watch_speed_$quality"} || $c->{watch_speed_h} || $c->{watch_speed_n};
	if($c->{"watch_speed_auto_$quality"} && $file->{file_length})
	{
		$watch_speed = int 1.4*$file->{"file_size_$quality"}/$file->{file_length}/1024;
	}
	my $speed = $file->{host_transfer_speed} || $c->{server_transfer_speed} || 25000; # KB, 25000 = 250 mbit/s

	my ($ip1,$ip) = ('0.0','0.0');

	my $expire = 6*60*60; # 6 hours
	my $time = time;
	require Digest::SHA;
	my $token = Digest::SHA::hmac_sha256_base64("$ip1|$time|$expire|$file->{file_real}|$quality|$speed", $c->{dl_key});
	$token=~tr/\+\//\-\_/;
	return $token if $hash_only;

	$fname||="v.mp4";

	return "$file->{srv_htdocs_url}/v/$file->{disk_id}/$dx/$file->{file_real}_$quality/$fname?t=$token&s=$time&e=$expire&f=$file->{file_id}&sp=$speed&i=$ip";
}

sub AccountInfo
{
	my $storage_used = $user->{usr_disk_used};
	$c->{disk_space} = $user->{premium} ? $c->{disk_space_prem} : $c->{disk_space_reg};
	my $storage_max = 1024**3 * ($user->{usr_disk_space} || $c->{disk_space});
	my $data = {	email			=> $user->{usr_email},
					login			=> $user->{usr_login},
					balance			=> $user->{usr_money},
					premium			=> $user->{premium},
					premium_expire	=> $user->{usr_premium_expire},
					storage_used	=> $storage_used,
					storage_left	=> $storage_max ? $storage_max - $storage_used : 'unlimited',
					files_total		=> $user->{usr_files_used},
				};
	return out({"status"=>200, "msg"=>"OK", result=>$data });
}

sub FolderCreate
{
   return out({"status"=>400, msg=>"You have can't have more than 10000 folders"}) if $db->SelectOne("SELECT COUNT(*) FROM Folders WHERE usr_id=?",$user->{usr_id})>=10000;
   my $fld_parent_id = $db->SelectOne("SELECT fld_id FROM Folders WHERE fld_id=? AND usr_id=?", $f->{parent_id}, $user->{usr_id} ) if $f->{parent_id};
   return out({"status"=>403, "msg"=>"Parent folder not exist or not yours"}) if $f->{parent_id} && !$fld_parent_id;
   $f->{name} = $ses->SecureStr($f->{name});
   $f->{descr} = $ses->SecureStr($f->{descr});
   return out({"status"=>400, msg=>"Invalid folder name"}) unless $f->{name} && length($f->{name})>=2;
   my $code = $ses->randchar(10);
   while($db->SelectOne("SELECT fld_id FROM Folders WHERE fld_code=?",$code)){$code = $ses->randchar(10);}
   $db->Exec("INSERT INTO Folders SET usr_id=?, fld_parent_id=?, fld_name=?, fld_descr=?, fld_code=?", $user->{usr_id}, $fld_parent_id||0, $f->{name}, $f->{descr}||'', $code);
   my $fld_id = $db->getLastInsertId;
   return out({"status"=>200, "msg"=>"OK", result=>{fld_id => $fld_id} });
}

sub FileDelete
{
    return out({"status"=>403, "msg"=>"This function not allowed in API"}) unless $c->{m_6_delete};
    return out({"status"=>403, "msg"=>"File Delete disabled by your account options"}) if $user->{usr_no_file_delete};
    my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=? AND usr_id=?",$f->{file_code},$user->{usr_id});
    return out({"status"=>404, msg=>"No file"}) unless $file;
    $ses->DeleteFile($file);
    return out({"status"=>200, msg => "OK"});
}

sub FileDeleted
{
	$f->{last} = 24*30 unless $f->{last}=~/^\d+$/;
	my $files = $db->SelectARef("SELECT f.*, UNIX_TIMESTAMP()-UNIX_TIMESTAMP(file_deleted) as ago
                                 FROM FilesTrash f 
                                 WHERE f.usr_id=?
                                 AND hide=0
                                 AND cleaned=0
                                 AND file_deleted > NOW()-INTERVAL ? HOUR
                                 ORDER BY file_deleted DESC",$user->{usr_id},$f->{last});
	my @list;
	for(@$files)
	{
		my $delby='me' if $_->{del_by}==$user->{usr_id};
		$delby||='admin' if $_->{del_by};
		$delby||='expired';
		push @list, {	file_code	=> $_->{file_code},
						title		=> $_->{file_title},
						deleted		=> $_->{file_deleted},
						deleted_ago_sec => $_->{ago},
						deleted_by	=> $delby,
					};
	}
	return out({"status"=>200, "msg"=>"OK", result=>\@list });
}

sub processFilesList
{
	my ($list) = @_;
	my @files;
	for(@$list)
	{
	$ses->genThumbURLs($_);
	push @files, {  file_code=>$_->{file_code}, 
					fld_id=>$_->{file_fld_id}, 
					title=>$_->{file_title}, 
					uploaded=>$_->{file_created}, 
					length => $_->{file_length},
					public => $_->{file_public},
					views => $_->{file_views},
					link => $ses->makeFileLink($_), 
					canplay => canPlay($_),
					thumbnail => $_->{video_thumb_url},
				};
	}
	return \@files;
}

sub FileList
{
  my $folder = $db->SelectRow("SELECT * FROM Folders WHERE fld_id=? AND usr_id=?", $f->{fld_id}, $user->{usr_id} ) if $f->{fld_id};
  my @filters;
  push @filters,"file_fld_id=$folder->{fld_id}" if $folder;
  push @filters,"file_fld_id=0" if $f->{fld_id} eq 0;
  push @filters,"file_public=$f->{public}" if $f->{public}=~/^0|1$/;
  push @filters,"file_adult=$f->{adult}" if $f->{adult}=~/^0|1$/;
  push @filters,"file_premium_only=$f->{premium_only}" if $f->{premium_only}=~/^0|1$/;
  push @filters,"file_created>'$f->{created}'" if $f->{created}=~/^\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d$/;
  push @filters,"file_created>NOW()-INTERVAL $f->{created} MINUTE" if $f->{created}=~/^\d+$/;
  #$f->{title} = $ses->{cgi_query}->param('title') if $f->{title};
  push @filters,qq|file_title LIKE "%$f->{title}%"| if $f->{title} && $f->{title}!~/[\"\0\n\r]+/;
  my $filter_str = ' AND '.join(' AND ', @filters) if @filters;
  $f->{page}=~s/\D+//;
  $f->{per_page}=~s/\D+//;
  $f->{per_page}=1000 if $f->{per_page}>1000;
  $f->{per_page}||=100;
  my $list = $db->SelectARef("SELECT * FROM Files 
  								WHERE usr_id=? 
  								$filter_str 
  								ORDER BY file_created DESC".$ses->makePagingSQLSuffix($f->{page},$f->{per_page}), $user->{usr_id});
  my $total = $db->SelectOneCached("SELECT COUNT(*) FROM Files 
  								WHERE usr_id=? 
  								$filter_str 
  								", $user->{usr_id});

  my $files = processFilesList($list);

  return out({	"status"=>200, 
  				"msg"=>"OK", 
  				result => {
  					results			=> scalar(@$files), 
  					results_total	=> int $total, 
  					pages			=> @$files ? int(0.990+$total/scalar(@$files)) : 0,
  					files			=> $files
  				} 
  			});
}

sub UploadServer
{
	my $type_filter = $user->{premium} ? "AND srv_allow_premium=1" : "AND srv_allow_regular=1";
	my $logic = {'space'=>'srv_disk','round'=>'srv_last_upload','random'=>'RAND()'}->{$c->{next_upload_server_logic}};
	my $extra1;
	if($c->{next_upload_server_logic} eq 'encodings')
	{
	    $extra1.=",(SELECT COUNT(*) FROM QueueEncoding q WHERE q.srv_id=s.srv_id AND q.error='') as eq";
	    $logic="eq";
	}
	my $server = $db->SelectRow("SELECT s.*, 
	                            CASE srv_type WHEN 'UPLOADER' THEN 3 WHEN 'STORAGE' THEN 2 END as type
	                            $extra1
	                            FROM Servers s
	                            WHERE srv_status='ON' 
	                            AND srv_disk <= srv_disk_max
	                            $type_filter
	                            ORDER BY type DESC, $logic 
	                            LIMIT 1");
	return out({"status"=>200, "msg"=>"No servers available for uploads", result=>{} }) unless $server;
    $server->{srv_cgi_url}=~s/\/cgi-bin//i;
	return out({"status"=>200, "msg"=>"OK", result=>"$server->{srv_cgi_url}/upload/$server->{disk_id}" });
}

sub AccountStats
{
   $f->{last}=~s/\D+//g;
   $f->{last}||=7;
   my @d1 = $ses->getTime(time-$f->{last}*24*3600);
   $d1[2]='01';
   my @d2 = $ses->getTime();
   my $day1 = $f->{date1}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date1} : "$d1[0]-$d1[1]-$d1[2]";
   my $day2 = $f->{date2}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{date2} : "$d2[0]-$d2[1]-$d2[2]";
   my $list2 = $db->SelectARefCached("SELECT *, DATE_FORMAT(day,'%e') as day2
                                     FROM Stats2
                                     WHERE usr_id=?
                                     AND day>=?
                                     AND  day<=?
                                     ORDER BY day",$user->{usr_id},$day1,$day2);
   return out({"status"=>200, "msg"=>"Not enough reports data", result=>{} }) if $#$list2<0;
   my @arr;
   for my $x (@$list2)
   {
   		my $y={};
   		$y->{profit_total} = sprintf("%.05f",$x->{profit_views}+$x->{profit_sales}+$x->{profit_refs}+$x->{profit_site});
   		$y->{$_}=$x->{$_} for qw(day views views_prem views_adb downloads sales profit_views profit_sales profit_refs profit_site refs);
   		push @arr, $y;
   }
   return out({"status"=>200, "msg"=>"OK", result=>\@arr });
}

sub AdminUserAdd
{
	# /user/add?key=XXX&login=&password=&email=&premium=30&pay_info=&pay_type=&money=&notes=
	return out({"status"=>403, "msg"=>"Not admin account"}) unless $user->{usr_adm};
	return out({"status"=>409, "msg"=>"User with this login already exist"}) if $db->SelectOne("SELECT usr_id FROM Users WHERE usr_login=?",$f->{login});
	return out({"status"=>409, "msg"=>"User with this email already exist"}) if $db->SelectOne("SELECT usr_id FROM Users WHERE usr_email=?",$f->{email});
	return out({"status"=>400, "msg"=>"Password should be at least 5 chars"}) if length($f->{password}) < 5;
	$f->{premium}=0 unless $f->{premium}=~/^(\d+|\d\d\d\d-\d\d-\d\d)$/;
	$f->{premium}||=0;
	my $premium = $f->{premium}=~/^\d\d\d\d-\d\d-\d\d$/ ? $f->{premium} : "NOW()+INTERVAL $f->{premium} DAY";
	$db->Exec("INSERT INTO Users 
                    SET usr_login=?, 
                        usr_password=?, 
                        usr_email=?,
                        usr_created=NOW(), 
                        usr_premium_expire=$premium,
                        usr_pay_email=?,
                        usr_pay_type=?,
                        usr_money=?,
                        usr_notes=?", 
               $f->{login}, 
               $ses->genPasswdHash($f->{password}), 
               $f->{email}||'', 
               $f->{pay_info}||'',
               $f->{pay_type}||'',
               $f->{money}||0,
               $f->{notes}||'',
               );
	my $usr_id = $db->getLastInsertId;
	return out({"status"=>200, "msg"=>"OK", result=>$usr_id });
}

sub RegenScreenlist
{
       return out({"status"=>400, msg=>"Screenlist mod disabled"}) unless $c->{m_x};
       my $codes = join ',', map{"'$_'"} grep{/^\w{12}$/} split(/,/, $f->{file_code});
       return out({"status"=>400, msg=>"Invalid file codes"}) unless $codes;

       my $user_filter="AND usr_id=$user->{usr_id}" unless $user->{usr_adm};
       my $files = $db->SelectARef("SELECT f.*, s.srv_id, s.disk_id 
                                    FROM Files f, Servers s 
                                    WHERE file_code IN ($codes)
                                    $user_filter
                                    AND f.srv_id=s.srv_id");
	   return out({"status"=>400, msg=>"Max files number is 20"}) if @$files>20;
       my %h;
       push @{$h{$_->{srv_id}}}, $_  for @$files;
       for my $srv_id (keys %h)
       {
           my $list = join ':', map{ "$_->{disk_id}-$_->{file_real_id}-$_->{file_real}-$_->{file_length}-$_->{file_name}" } @{$h{$srv_id}};
           my $res = $ses->api2($srv_id, {op=>'rescreen',list=>$list});
           #$ses->message("API ERROR:$res") unless $res eq 'OK';
           $db->Exec("UPDATE Files SET file_screenlist=1 WHERE file_real_id IN (".join(',', map{$_->{file_real_id}}@{$h{$srv_id}} ).")");
       }
       return out({ "status"=>200, "msg"=>"OK", "files"=> $#$files+1 });
}

sub UploadSub
{
	return out({"status"=>400, msg=>"Invalid lang"}) unless $f->{sub_lang}=~/^\w+$/i;
	my $file = $db->SelectRow("SELECT * FROM Files WHERE file_code=?",$f->{file_code});
	return out({"status"=>400, msg=>"No file"}) unless $file;
	return out({"status"=>403, msg=>"Not your file"}) if $user->{usr_id}!=$file->{usr_id};

	my $ext;
	my $data;
	if($f->{sub_file})
	{
		($ext) = $f->{sub_file}=~/\.(srt|vtt)$/i;
		$ses->message("Not captions file") unless $ext;
		my $fh = $ses->{cgi_query}->upload( 'sub_file' ) || $ses->message("Error saving sub: ".$ses->{cgi_query}->cgi_error());
		$data = join '', <$fh>;
	}
	elsif($f->{sub_url})
	{
		($ext) = $f->{sub_url}=~/\.(srt|vtt)$/i;
		$ext||='vtt';
		require LWP::UserAgent;
		my $lwp = LWP::UserAgent->new;
		$data = $lwp->get( $f->{sub_url} )->content;
	}
	else
	{
		return out({"status"=>400, msg=>"Subtitle data not found required"});
	}
	$ext = lc $ext;

	if( $c->{srt_max_size_kb} && length($data) > $c->{srt_max_size_kb}*1024 )
	{
		return out({"status"=>400, msg=>"Max subtitle size is $c->{srt_max_size_kb}KB"});
	}

	if( $data=~/\<\?php/i )
	{
		return out({"status"=>400, msg=>"Invalid file format"});
	}

	if($ext eq 'srt' && $c->{srt_convert_to_vtt})
	{
		$data=~s/\r//gs;
		$data=~s/^\D+\d\n//;
		$data=~s/(\d\d:\d\d:\d\d),(\d\d\d)/$1\.$2/gi;
		$data="WEBVTT\n\n$data";
		$data=~s/\n\d+\n/\n/gs;
	}

	my $dx = sprintf("%05d",$file->{file_real_id}/$c->{files_per_folder});
	my $res = $ses->api2($file->{srv_id},
				{
					op			=> 'srt_upload',
					file_code	=> $file->{file_code},
					dx			=> $dx,
					language	=> $f->{sub_lang},
					data		=> $data,
				});
	return $ses->message("ERROR:$res") unless $res eq 'OK';

	my @arr = grep{$_ ne $f->{sub_lang}} split(/\|/, $file->{file_captions});
	$file->{file_captions} = join '|', ( @arr, $f->{sub_lang} );
	$db->Exec("UPDATE Files SET file_captions=? WHERE file_id=?", $file->{file_captions}, $file->{file_id});

	return out({ "status"=>200, "msg"=>"OK" });
}

sub FileURLActions
{
	if($f->{restart_errors})
	{
		$db->Exec("UPDATE QueueUpload
					SET status='PENDING',size_dl=0,error='',srv_id=0
					WHERE usr_id=$user->{usr_id}
					AND status='ERROR'");
	}
	if($f->{delete_errors})
	{
		$db->Exec("DELETE FROM QueueUpload
					WHERE usr_id=$user->{usr_id}
					AND status='ERROR'");
	}
	if($f->{delete_all})
	{
		$db->Exec("DELETE FROM QueueUpload
					WHERE usr_id=$user->{usr_id}");
	}
	if($f->{delete_code})
	{
		my $codes = join ',', map{"'$_'"} grep{/^\w{12}$/} split /,/, $f->{delete_code};
		my $user_filter="AND usr_id=$user->{usr_id}" unless $user->{usr_adm};
		$db->Exec("DELETE FROM QueueUpload
					WHERE file_code IN ($codes)
					$user_filter") if $codes;
	}
	return out({ "status"=>200, "msg"=>"OK" });
}

1;
