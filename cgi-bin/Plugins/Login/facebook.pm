package Plugins::Login::facebook;
use base 'Login';
use Net::OAuth2::Profile::WebServer;
use JSON;
use XFileConfig;

$userinfo_url = 'https://graph.facebook.com/me?fields=id,email,name';
$result_fields{usr_social_id} = 'id';
$result_fields{usr_login} = 'email';
$result_fields{usr_email} = 'email';

$oauth = Net::OAuth2::Profile::WebServer->new( client_id => $c->{facebook_app_id}||'',
		client_secret => $c->{facebook_app_secret}||'',
		access_token_url => "https://graph.facebook.com/oauth/access_token",
		authorize_url => "https://graph.facebook.com/oauth/authorize",
		scope => 'email',
		redirect_uri => "$c->{site_url}/?op=register_ext&method=facebook",
		);
