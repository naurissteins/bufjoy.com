package Plugins::Login::twitter;
use Net::Twitter::Lite;
use XFileConfig;

$oauth = Net::Twitter::Lite->new(consumer_key    => $c->{twit_consumer1},
                                       consumer_secret => $c->{twit_consumer2} );

# Unlike other login methods, Twitter users OAuth 1.0. Hence the methods are overriden.

sub get_auth_url {
	my ($plg_name, $f) = @_;
	return if $f->{method} ne 'twitter';
	$oauth->get_authorization_url(callback => "$c->{site_url}/?op=register_ext&method=twitter");
}

sub finish {
	my ($self, $f) = @_;
	return if $f->{method} ne 'twitter';
	use Data::Dumper qw(Dumper);
	$oauth->request_token( $f->{oauth_token} );
	$oauth->request_token_secret( $f->{oauth_token} );
	my($access_token, $access_token_secret, $user_id, $screen_name)
	= $oauth->request_access_token(	verifier => $f->{oauth_verifier} );
	return( {
		usr_social_id => $user_id,
		usr_login => $screen_name,
		usr_email => '',

		# Additional fields to enable m_w posting
		access_token => $access_token,
		access_token_secret => $access_token_secret,
	});
}

1;
