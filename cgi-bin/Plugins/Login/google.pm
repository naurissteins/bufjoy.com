package Plugins::Login::google;
use base 'Login';
use Net::OAuth2::Profile::WebServer;
use JSON;
use XFileConfig;

$userinfo_url = 'https://www.googleapis.com/oauth2/v1/userinfo';
$result_fields{usr_social_id} = 'id';
$result_fields{usr_login} = 'email';
$result_fields{usr_email} = 'email';
$result_fields{picture} = 'picture';

$oauth = Net::OAuth2::Profile::WebServer->new( client_id => $c->{google_app_id},
		client_secret => $c->{google_app_secret},
		access_token_url => "https://accounts.google.com/o/oauth2/token",
		authorize_url => "https://accounts.google.com/o/oauth2/auth",
		scope => 'https://www.googleapis.com/auth/userinfo.email',
		redirect_uri => "$c->{site_url}/?op=register_ext&method=google",
		);

