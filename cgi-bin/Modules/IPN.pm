# The business logic for accepting money from users and affiliate program (premium upgrade, e.t.c.).
# It doesn't contains the payment engine specific things as it's handled by the Payment Gateways mod.
package IPN;
use strict;
use XFileConfig;
use XUtils;
use Data::Dumper qw(Dumper);

sub new {
	my ($class,$ses) = @_;
	my $self = { };
	$self->{ses} = $ses;
	$self->{db} = $ses->db;
	$self->{f} = $ses->f;
	$self->{plans} = $ses->ParsePlans($c->{payment_plans}, 'hash');
	bless $self, __PACKAGE__;
}

sub acceptResellersMoney {
	my ($self, $transaction, %opts) = @_;
	print STDERR "Adding $transaction->{amount} of money to reseller $transaction->{usr_id}\n";
	$self->{db}->Exec("UPDATE Users SET usr_money=usr_money+? WHERE usr_id=?",
			$transaction->{amount},
			$transaction->{usr_id});
	$self->finalize($transaction);
}

sub finalize {
	my ($self, $transaction) = @_;
	print STDERR "Marking the transaction as verified (id=$transaction->{id})\n";
	$self->setTransactionOpts($transaction, verified => 1, txn_id => $self->{f}->{txn_id});

	$self->{db}->Exec("INSERT INTO Stats
			SET paid=?, day=CURDATE()
						 ON DUPLICATE KEY UPDATE
							paid=paid+?",$transaction->{amount},$transaction->{amount});
}

sub chargeAff {
	# Change the $opts{amount} of affiliate money to $usr_id
	my ($self, $user, $amount, %opts) = @_;
	print STDERR "Charging usr_id=$user->{usr_id} with \$$amount (stats = $opts{stats})\n";
	use Data::Dumper qw(Dumper);
	#die(Dumper($user));
	return unless $user && $user->{usr_id};
	$self->{db}->Exec("UPDATE Users
			SET usr_money=usr_money+?
			WHERE usr_id=?", $amount, $user->{usr_id});
	$self->registerStats(usr_id => $user->{usr_id},
			amount => $amount,
			type => $opts{stats});
		  $self->{db}->Exec("INSERT INTO PaymentsLog
									SET usr_id_from=?,
									usr_id_to=?,
									type=?,
									amount=?,
									created=NOW()",
									$opts{usr_id_from},
									$user->{usr_id},
										  $opts{stats},
									$amount,
								) if $opts{usr_id_from};
		  return($amount);
}

sub getWebmaster {
	my ($self, $domain) = @_;
	my $website = $self->{db}->SelectRow("SELECT * FROM Websites WHERE domain=?", $domain);
	return($self->{db}->SelectRow("SELECT * FROM Users WHERE usr_id=?", $website->{usr_id})) if $website;
}

sub chargeAffs {
	# Charges all affs that's expecting a reward for $transaction
	my ($self, $transaction) = @_;

	# Is that a sale or rebill?
	my $prev_transaction = $self->{db}->SelectRow("SELECT *, TIMESTAMPDIFF(DAY, created, NOW()) AS elapsed
			FROM Transactions
			WHERE usr_id=?
			AND id!=?
			AND verified
			ORDER BY created DESC",
			$transaction->{usr_id},
			$transaction->{id});
	my $is_rebill = $prev_transaction && $prev_transaction->{elapsed} <= 31 ? 1 : 0;
	#my $stats = $is_rebill ? 'rebills' : 'sales';
	my $stats = 'sales';
	print STDERR "is_rebill=$is_rebill stats=$stats\n";
	$self->setTransactionOpts($transaction, rebill => $is_rebill);

	# ------ Charging uploader
	my $aff = $self->{db}->SelectRow("SELECT * FROM Users WHERE usr_id=?", $transaction->{aff_id});
	my $sale_aff_percent = $c->{sale_aff_percent};
	if($c->{m_y} && $aff) {
		$sale_aff_percent = $c->{"m_y_".lc($aff->{usr_profit_mode})."_$stats"};
		$sale_aff_percent = $aff->{"$stats\_aff_percent"} if $aff->{"$stats\_aff_percent"};
		print STDERR "Profit mode=$aff->{usr_profit_mode}, stats = $stats, aff percent = $sale_aff_percent";
	}
	my $profit_uploader = $self->chargeAff($aff, $transaction->{amount} * $sale_aff_percent / 100, stats => $stats)
		if $aff && $sale_aff_percent;

	# ------ Charging webmaster
	my $domain = $self->{ses}->getDomain($transaction->{ref_url});
	my $webmaster = $self->getWebmaster($domain);
	$self->setTransactionOpts($transaction, domain => $domain) if $webmaster;
	my $m_x_rate = $c->{m_x_rate};
	my $profit_webmaster = $self->chargeAff($webmaster, $transaction->{amount} * $m_x_rate / 100, stats => 'site')
		if $webmaster && $m_x_rate;

	# ------ Charging referrals
	my $aff1 = $self->{db}->SelectRow("SELECT * FROM Users WHERE usr_id=?", $aff->{usr_aff_id}) if $aff;
	my $aff2 = $self->{db}->SelectRow("SELECT * FROM Users WHERE usr_id=?", $webmaster->{usr_aff_id}) if $webmaster;

		  my $profit_aff1 = $profit_uploader * $c->{referral_aff_percent} / 100;
		  my $profit_aff2 = $profit_webmaster * $c->{referral_aff_percent} / 100;

		  $self->chargeAff($aff1, $profit_aff1, stats => 'refs', usr_id_from => $aff->{usr_id}) if $profit_aff1;
		  $self->chargeAff($aff2, $profit_aff2, stats => 'refs', usr_id_from => $webmaster->{usr_id}) if $profit_aff2;
}

sub registerStats {
	my ($self, %opts) = @_;

	my $subquery = ['', ''];
	$subquery = [
		"$opts{type}=1,",
		"$opts{type}=$opts{type}+1,",
	] if $opts{type} =~ /^(downloads|sales|rebills)$/;
	$subquery->[0] .= "profit_$opts{type}=?";
	$subquery->[1] .= "profit_$opts{type}=profit_$opts{type}+?";

	$self->{db}->Exec("INSERT INTO Stats2
			SET usr_id=?, day=CURDATE(),
			$subquery->[0]
			ON DUPLICATE KEY UPDATE
			$subquery->[1]
			",$opts{usr_id},$opts{amount},$opts{amount});
	1;
}

sub setTransactionOpts {
	# Alter stored transaction fields
	my ($self, $transaction, %opts) = @_;
	for(keys %opts) {
		$self->{db}->Exec("UPDATE Transactions SET $_=? WHERE id=?", $opts{$_}, $transaction->{id});
	}
}

sub createTransaction {
	my ($self, %opts) = @_;
	my $id = int(1+rand 9).join('', map {int(rand 10)} 1..9);
	$id = int scalar(rand(2**30)) if $opts{type} eq 'webmoney';
	$self->{db}->Exec("INSERT INTO Transactions SET id=?,
							 usr_id=?,
							 amount=?,
							 days=?,
							 ip=INET_ATON(?),
							 created=NOW(),
							 aff_id=?,
							 ref_url=?,
							 email=?,
							 verified=?",
						 $id,
						 $opts{usr_id},
						 $opts{amount},
						 $opts{days}||0,
						 $self->{ses}->getIP || $ENV{REMOTE_ADDR} || '0.0.0.0',
						 $opts{aff_id}||0,
						 $opts{referer}||'',
						 $opts{email}||'',
						 $opts{verified}||0,
						 );
	return ( $self->{db}->SelectRow("SELECT * FROM Transactions WHERE id=?", $id) );
}

sub getLatestTransaction {
	my ($self, %opts) = @_;
	my $transaction = $self->{db}->SelectRow("SELECT * FROM Transactions
			WHERE usr_id=?
			ORDER BY created DESC
			LIMIT 1",
			$opts{usr_id});
	return($transaction);
}

sub upgradePremium {
	my ($self, $transaction) = @_;

	# The user that had purchased th\u865a\u7121e premium
	my $user = $self->{db}->SelectRow("SELECT * FROM Users WHERE usr_id=?", $transaction->{usr_id} );

	my $aff = $self->{db}->SelectRow("SELECT * FROM Users WHERE usr_id=?", $transaction->{aff_id} );
	my $webmaster = $self->getWebmaster($transaction->{ref_url});

	my $days = $transaction->{days}||$self->{plans}->{$transaction->{amount}};
	die("No such plan: $transaction->{amount} $c->{currency_code}") if !$days;
	$user->{exp_sec} += $days*24*3600;
	$self->finalize($transaction);

	# Add premium days
	$self->{db}->Exec("UPDATE Users
            SET usr_premium_expire = GREATEST(usr_premium_expire, NOW()) + INTERVAL ? DAY,
                usr_disk_space = CASE
                                    WHEN ? = 9.99 THEN 1000
																		WHEN ? = 14.99 THEN 2000
																		WHEN ? = 19.99 THEN 3000
																		WHEN ? = 24.99 THEN 4000
                                    WHEN ? = 29.99 THEN 5000
                                    WHEN ? = 34.99 THEN 6000
                                    ELSE usr_disk_space
                                  END
            WHERE usr_id = ?",
			$days,
			$transaction->{amount},
			$transaction->{amount},
			$transaction->{amount},
			$transaction->{amount},
			$transaction->{amount},
			$transaction->{amount},
			$transaction->{usr_id} );

	$user = $self->{db}->SelectRow("SELECT * FROM Users WHERE usr_id=?", $transaction->{usr_id} );
	print STDERR  "New expire time is : $user->{usr_premium_expire}" ;

	$self->chargeAffs($transaction);
		  return($days);
}

1;
