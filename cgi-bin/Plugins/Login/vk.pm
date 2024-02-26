package Plugins::Login::vk;
use base 'Login';
use XFileConfig;
use Digest::MD5;

$oauth = Net::OAuth2::Profile::WebServer->new( client_id => $c->{vk_app_id}||'',
		client_secret => $c->{vk_app_secret}||'',
		access_token_url => "https://oauth.vk.com/access_token",
		authorize_url => "https://oauth.vk.com/authorize",
		scope => 'status,email',
		redirect_uri => "$c->{site_url}/?op=register_ext&method=vk",
		);

sub finish {
	my ($plg_name, $f) = @_;
	return if $f->{method} ne 'vk';
	my $access = $oauth->get_access_token($f->{code});
	#use Data::Dumper;
	#die Dumper($access);
        my $ret = {};
        $ret->{usr_social_id} = $ret->{usr_login} = "vk".$access->{NOA_attr}->{user_id};
        $ret->{usr_email} = $access->{NOA_attr}->{email}||'';

    my $res = $access->get("https://api.vk.com/method/users.get?access_token=$access->{NOA_access_token}&v=5.101&fields=photo_100,screen_name&user_ids=".$access->{NOA_attr}->{user_id});
    #die $res->decoded_content;
	my $usr = JSON::decode_json($res->decoded_content);
	$ret->{usr_login} = $usr->{response}->[0]->{screen_name};
	$ret->{photo_url} = $usr->{response}->[0]->{photo_100};
	#die "($ret->{usr_login})";
    return($ret);
}

1;
