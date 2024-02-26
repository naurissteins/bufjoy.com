package PluginsBase::Payments::BitcoinLike;
use strict;
use Payments;
use base 'Payments';
use XFileConfig;
use LWP::UserAgent;
use Digest::SHA qw(sha256_hex);
use MIME::Base64 qw(encode_base64);
use JSON;
no strict 'refs';

sub checkout {
   my ($self, $f) = @_;
   return if $f->{type} ne $self->options()->{name};

   my $ua = LWP::UserAgent->new();
   my $res = $ua->post('http://mypremium.store', {
      op => 'create_invoice',
      api_key => $c->{sibpay_api_key},
      usd_amount => $f->{amount},
      ext_order_id => $f->{id},
      gen_qr_code => 1,
      target_currency => $self->options()->{currency_code},
   });

   return $self->ses()->message("Failed while requesting: " . $res->status_line) if $res->code != 200;

   print STDERR "Received from MPS: ", $res->decoded_content, "\n";
   my $ret = JSON::decode_json($res->decoded_content);
   return $self->ses()->message("Failed to create transaction: $ret->{error}") if($ret->{error});

   return $self->ses()->PrintTemplate("buy_bitcoin.html",
            %$ret,
            id => $f->{id},
            usr_id => $self->ses()->getUserId,
            site_url => $c->{site_url},
            currency_name => $self->options()->{title},
            product_name => $f->{product_name} || "$c->{site_name} Premium Account");
}

sub verify {
   my ($self, $f) = @_;
   return if !$f->{sbpay_method};
   return if $f->{currency_code} ne $self->options()->{currency_code};

   my $transaction = $self->db()->SelectRow("SELECT * FROM Transactions WHERE id=?",$f->{ext_order_id}) || die("Transaction not found: '$f->{ext_order_id}'");

   my @keys = sort(grep { $_ ne 'signature' } keys(%$f));
   my $payload = join('', map { $f->{$_} } @keys);
   my $sign = sha256_hex($payload . $c->{sibpay_secret});

   die("Wrong signature") if $sign ne $f->{signature};
   die("Wrong status") if $f->{status} ne 'OK';

   $f->{txn_id} = $f->{txid};
   $f->{out} = 'OK';

   return $transaction;
}

# Quick-and-dirty hacks to retrieve session and database variables
# from a subclass
sub ses { ${ shift() . "::ses" } }
sub db { ${ shift() . "::db" } }

1;
