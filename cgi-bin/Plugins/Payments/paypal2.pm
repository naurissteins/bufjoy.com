package Plugins::Payments::paypal2;
use Payments;
use base 'Payments';
use LWP::UserAgent;
use vars qw($ses $c);
use strict;


sub options {
	return {
		name=>'paypal2', title=>'PayPal2', account_field=>'paypal2_url', image=>'buy_paypal.gif', 
		s_fields=>[
			{title=>'PayPal2 domain', name=>'paypal2_url', type=>'text', comment=>'High Risk PayPal alternative'},
			{title=>'PayPal2 public key', name=>'paypal2_public_key', type=>'text', comment=>'contact SibSoft to register account'},
			{title=>'PayPal2 private key', name=>'paypal2_private_key', type=>'text'},
			]
		};
}

sub checkout {
	my ($self, $f) = @_;
	return if $f->{type} ne 'paypal2';
	my $plans = $ses->ParsePlans($c->{payment_plans}, 'hash');
	my $days = $plans->{$f->{amount}};

         print"Content-type:text/html\n\n";
print <<END
<HTML><BODY onLoad="document.FPP.submit();">
<center>
<Form method="POST" action="$c->{paypal2_url}" name="FPP">
<input type="hidden" name="public_key" value="$c->{paypal2_public_key}">
<input type="hidden" name="price" value="$f->{amount}">
<input type="hidden" name="invoice" value="$f->{id}">
<input type="hidden" name="item_name" value="Premium account">
<input type="hidden" name="item_number" value="123">
<input type="hidden" name="notify_url" value="$c->{site_url}/cgi-bin/ipn.cgi">
<input type="hidden" name="return" value="$c->{site_url}/?payment_complete=$f->{id}-0">
<input type="hidden" name="cancel_return" value="$c->{site_url}/?payment_failed=pp2">
<input type="submit" value="Redirecting to payment...">
</Form>
</center>
</BODY></HTML>
END
;

	exit;
}

sub error {
	print STDERR "$_[0]\n";
	print "Content-type: text/plain\n\n";
	exit;
}

sub verify {
	my ($self, $f) = @_;
	return if !$f->{security_data};

	error("Invalid status") 
		unless $f->{payment_status} eq 'Completed';

	error("Wrong txn_id value: $f->{txn_id}") 
		unless $f->{txn_id};

	require Digest::MD5;
	my $signature = Digest::MD5::md5_hex($f->{security_data}.$c->{paypal2_private_key});
	error( 'Bad pp2 signature!') 
		unless $signature eq $f->{security_hash};

	my $transaction = $ses->db->SelectRow("SELECT * FROM Transactions WHERE id=?",$f->{invoice}) || error( "Transaction not found paypal2: '$f->{invoice}'"  );

	error("Wrong amount value: $f->{price}") 
		if $f->{price} < $transaction->{amount};

	$ses->db->Exec("UPDATE Transactions SET txn_id=? WHERE id=?",$f->{txn_id}||'',$transaction->{id});

	return($transaction);
}

1;

