package Plugins::Payments::sibpay;
use Payments;
use base 'Payments';
use vars qw($ses $c);
use strict;

use LWP::UserAgent;
use Digest::SHA qw(sha256_hex);
use MIME::Base64 qw(encode_base64);
use JSON;

sub options
{
   return
   {
      name => 'sibpay', title  =>  'SibPay',
      account_field => 'sibpay_api_key',
      submethods => _get_submethods()||'',
      s_fields => [
         {title=>'Your SibPay API Key', name=>'sibpay_api_key', type=>'text', size => 32, comment => '<a href="https://sibsoft.net/merchant_service.html">[?]</a>'},
         {title=>'Your SibPay Secret Key', name=>'sibpay_secret', type=>'text', size => 16},
      ]
   };
}

sub checkout
{
   my ($self, $f) = @_;
   return if $f->{type} ne 'sibpay';

   my ($submethod) = grep { $_->{name} eq $f->{submethod} } @{ $self->options()->{submethods} };
   return $ses->message("No currency_code defined for $f->{submethod}") if !$submethod || !$submethod->{currency_code};

   return $self->_checkout_webmoney($f) if $f->{submethod} eq 'webmoney';
   return $self->_checkout_crypto({ %$f, currency_code => $submethod->{currency_code} });
}

sub verify {
   my ($self, $f) = @_;
   return if !$f->{sbpay_method};

   my $transaction = $ses->db->SelectRow("SELECT * FROM Transactions WHERE id=?",$f->{ext_order_id}) || die("Transaction not found: '$f->{ext_order_id}'");

   my @keys = sort(grep { $_ ne 'signature' } keys(%$f));
   my $payload = join('', map { $f->{$_} } @keys);
   my $sign = sha256_hex($payload . $c->{sibpay_secret});

   die("Wrong signature") if $sign ne $f->{signature};
   die("Wrong status") if $f->{status} ne 'OK';

   $f->{txn_id} = $f->{txid};
   $f->{out} = 'OK';

   return $transaction;
}

sub _checkout_webmoney
{
   my ($self, $f) = @_;
   my $ua = LWP::UserAgent->new();
   my $res = $ua->post('http://mypremium.store', {
      op => 'wm_checkout',
      api_key => $c->{sibpay_api_key},
      usd_amount => $f->{amount},
      ext_order_id => $f->{id},
      target_currency => 'WMZ',
      api_ver => '1.1',
   });

   return $ses->message("Failed while requesting: " . $res->status_line) if $res->code != 200;
   my $ret = JSON::decode_json($res->decoded_content);
   return $ses->message("Failed to create transaction: $ret->{error}") if($ret->{error});

	print"Content-type:text/html\n\n";
	print <<END
		<HTML><BODY onLoad="document.F1.submit();">
		<Form method="POST" action="https://merchant.wmtransfer.com/lmi/payment.asp" name="F1">
		<input type="hidden" name="LMI_PAYEE_PURSE" value="$ret->{LMI_PAYEE_PURSE}">
		<input type="hidden" name="LMI_PAYMENT_AMOUNT" value="$f->{amount}">
		<input type="hidden" name="LMI_PAYMENT_DESC" value="$c->{item_name}">
		<input type="hidden" name="LMI_PAYMENT_NO" value="$ret->{LMI_PAYMENT_NO}">
		<input type="hidden" name="LMI_SUCCESS_URL" value="$c->{site_url}/?payment_complete=$f->{id}-0">
		<input type="hidden" name="LMI_FAIL_URL" value="$c->{site_url}">
		<input type="submit" value="Loading..." style="background:#fff; border:0;">
		</Form>
		</BODY></HTML>
END
;
}

sub _checkout_crypto
{
   my ($self, $f) = @_;

   my $ua = LWP::UserAgent->new();
   my $res = $ua->post('http://mypremium.store', {
      op => 'create_invoice',
      api_key => $c->{sibpay_api_key},
      usd_amount => $f->{amount},
      ext_order_id => $f->{id},
      gen_qr_code => 1,
      target_currency => $f->{currency_code},
   });

   return $ses->message("Failed while requesting: " . $res->status_line) if $res->code != 200;

   print STDERR "Received from MPS: ", $res->decoded_content, "\n";
   my $ret = JSON::decode_json($res->decoded_content);
   return $ses->message("Failed to create transaction: $ret->{error}") if($ret->{error});

   my ($submethod) = grep { $_->{name} eq $f->{submethod} } @{ $self->_get_submethods() };

   return $ses->PrintTemplate("buy_bitcoin.html",
            %$ret,
            id => $f->{id},
            usr_id => $ses->getUserId,
            site_url => $c->{site_url},
            currency_name => $submethod->{title},
            product_name => $f->{product_name} || "$c->{site_name} Premium Account");
}

sub _get_submethods
{
   my $list = [
      { name => 'bitcoin',     title => 'Bitcoin',      image => 'buy_btc.png',      listed_reseller => '1', currency_code => 'BTC' },
      { name => 'bitcoincash', title => 'Bitcoin Cash', image => 'buy_bch.png',      listed_reseller => '1', currency_code => 'BCH' },
      { name => 'litecoin',    title => 'Litecoin',     image => 'buy_ltc.png',      listed_reseller => '1', currency_code => 'LTC' },
      { name => 'ethereum',    title => 'Ethereum',     image => 'buy_eth.png',      listed_reseller => '1', currency_code => 'ETH' },
   ];

   push @$list, { name => 'webmoney',    title => 'Webmoney',     image => 'buy_webmoney.gif', listed_reseller => '1', currency_code => 'WMZ' }
      if !$c->{webmoney_merchant_id};

   return $list;
}

1;
