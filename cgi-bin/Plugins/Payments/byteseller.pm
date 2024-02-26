package Plugins::Payments::byteseller;
use Payments;
use base 'Payments';
use vars qw($ses $c);
use Digest::SHA qw(sha512_hex);
use HTML::Entities;
use strict;

sub options {
   return {
      name=>'byteseller', title=>'Byteseller', account_field=>'byteseller_id', image=>'buy_cc1.png',
         s_fields=>[
            {title=>'Your Byteseller ID', name=>'byteseller_id', type=>'text', comment=>'optional'},
            {title=>'Your Byteseller API Password', name=>'byteseller_secret', type=>'text', comment=>'optional'},
            {title=>'Your Byteseller POST URL', name=>'byteseller_post_url', type=>'text', comment=>'optional'},
            {title=>'Byteseller subscriptions', name=>'byteseller_subscription', type=>'checkbox', comment=>'Enabled'},
            ],
      };
}

sub checkout {
   my ($self, $f) = @_;
   return if $f->{type} ne 'byteseller';

   my $plans = $ses->ParsePlans($c->{payment_plans}, 'hash');
   my $days = $f->{days}||$plans->{$f->{amount}};
   my $descr = "$c->{site_name} $days days premium $f->{amount} $c->{currency_code}";
   my $usr_id = $ses->getUserId if $ses->getUser;

   my $method = $c->{byteseller_subscription} ? 'create_subscription' : 'accept_payment';

   my $sign = sha512_hex(join('', 2, $method, $c->{byteseller_id},
      $f->{id},
      $f->{amount},
      $c->{currency_code},
      $c->{byteseller_subscription} ? $days  : '',  # subscription_period
      $c->{byteseller_subscription} ? '0'    : '',  # subscription_cycles
      $descr,
      $f->{email},
      $c->{byteseller_secret}));

   my $cc = $ses->{cgi_query}->cookie( -name => 'transaction_id', -value => "$f->{id}-$usr_id", -domain  => ".$ses->{domain}", -expires => '+1h');
   print $ses->{cgi_query}->header( -cookie => [$cc] , -type => 'text/html', -expires => '-1h', -charset => $c->{charset});

   my $form = <<BLOCK
 <input name="api_id" value="2" type="hidden" />
 <input name="method" value="$method" type="hidden" />
 <input name="subseller_id" value="$c->{byteseller_id}" type="hidden" />
 <input name="order_id" value="$f->{id}" type="hidden" />
 <input name="amount" value="$f->{amount}" type="hidden" maxlength="6" />
 <input name="currency" value="$c->{currency_code}" type="hidden" maxlength="6" />
 <input name="description" value="$descr" type="hidden" />
 <input name="signature" value="$sign" type="hidden"/>
 <input name="email" value="$f->{email}" type="hidden"/>
BLOCK
;

   if($c->{byteseller_subscription})
   {
      $form .= <<BLOCK
 <input name="subscription_period" value="$days" type="hidden"/>
 <input name="subscription_cycles" value="0" type="hidden"/>
BLOCK
;
   }

   print <<BLOCK
<HTML><BODY onLoad="document.F1.submit();">
<form name="F1" method="post" action="$c->{byteseller_post_url}" accept-charset="utf-8">
  $form
 <input value="Pay Now" type="submit">
</form>
</BODY>
</HTML>
BLOCK
;
   exit();
}

sub verify {
   my ($self, $f) = @_;
   return if !$f->{date};
   my $transaction = $ses->db->SelectRow("SELECT * FROM Transactions WHERE id=?",$f->{order_id}) || error( "Transaction not found: '$f->{order_id}'"  );
   error("Resubmitting detected") if $transaction->{verified} && $transaction->{txn_id} eq $f->{transaction_id};

   $f->{txn_id} = $f->{out} = $f->{transaction_id};

   my $sign = sha512_hex(join('', $f->{transaction_id}, $f->{subscription_id}, $c->{byteseller_id},
      $f->{order_id},
      $f->{amount},
      $f->{currency},
      $f->{subscription_period},
      $f->{subscription_cycles},
      $f->{is_test},
      $f->{payment_status}||$f->{status},
      $f->{subscription_status},
      $c->{byteseller_secret}));

   print STDERR "sign=$sign\n";

   sub error
   {
      print STDERR "$_[0]\n";
      print "Content-type: text/html\n\n$f->{transaction_id}\n";
      exit();
   }

   if(!$f->{transaction_id})
   {
      # Subscription status changed
      print "Content-type: text/html\n\nOK\n";
      exit();
   }

   error("Wrong signature") if $sign ne $f->{signature};
   error("Wrong status") if ($f->{payment_status}||$f->{status}) != 4;
   error("Wrong amount") if $f->{amount} != $transaction->{amount};


   return $transaction;
}

1;
