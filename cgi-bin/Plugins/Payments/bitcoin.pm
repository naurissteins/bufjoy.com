package Plugins::Payments::bitcoin;
use Payments;
use base 'Payments';
use vars qw($ses $c);
use strict;

### Deprecated, handled by sibpay.pm now

sub options
{
   return {};
}

sub checkout
{
   return;
}

sub verify
{
   return;
}

1;
