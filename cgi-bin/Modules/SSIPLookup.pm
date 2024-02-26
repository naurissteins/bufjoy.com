package SSIPLookup;
use strict;
use 5.008008;
use integer;
use Carp;
use Socket qw/ inet_ntop inet_pton AF_INET /;

BEGIN {
# IPv4 address from dotted-quad to integer
# Choose manual implementation on Windows where inet_pton() is not available
    if('MSWin32' eq $^O) {
        *_dq2int = sub { ## no critic (Subroutines::RequireArgUnpacking)
            my @oct = split /\./, $_[0];
            4 == @oct or croak "address must be in dotted-quad form, is `$_[0]'";
            my $ip = 0;
            foreach(@oct) {
                $_ <= 255 and $_ >= 0
                    or croak "invalid component `$_' in address `$_[0]'";
                $ip = $ip<<8 | $_;
            }
            return $ip;
        };
    } else {
        *_dq2int = sub { unpack 'N', inet_pton(AF_INET, shift) };
    }
}

sub new { bless [], shift }

sub add {
	my ($self, $cidr, $val) = @_;

    defined $val or croak "can't store an undef";

	my ($net, $bits) = $cidr =~ m{ ^ ([.[:digit:]]+) / (\d+) $ }ox;
    defined $net and defined $bits or croak 'CIDR syntax error: use <address>/<netbits>';
    my $intnet = _dq2int($net) or return;
	$self->_add($intnet,$bits,$val);
}

sub add_range {
    my ($self, $range, $val) = @_;

    defined $val or croak "can't store an undef";

    my ($start, $end, $crud) = split /\s*-\s*/, $range;
    croak 'must have exactly one hyphen in range'
        if(defined $crud or not defined $end);

    $self->add_num_range(_dq2int($start), _dq2int($end), $val);
}

sub add_num { ## no critic (Subroutines::RequireArgUnpacking)
    # my ($self,$ip,$bits,$val) = @_;
	# Just call the recursive adder for now but allow for changes in object
    # representation ($self != $n)
    defined $_[3] or croak "can't store an undef";
	_add(@_);
}

sub add_num_range {
    my ($self, $start, $end, $val) = @_;
    my @chunks;

    $start > $end
        and croak sprintf "start > end in range %s--%s", _int2dq($start), _int2dq($end);

    _do_chunk(\@chunks, $start, $end, 31, 0);
    $self->add_num(@$_, $val) for(@chunks);
}

sub lookup {
	my ($self, $addr) = @_;

    # Make sure there is no network spec tacked onto $addr
    $addr =~ s!/.*!!;
	$self->_lookup(_dq2int($addr));
}


=head2 lookup_num

Arguments: C<$address>

Return Value: value assoiated with this address or C<undef>

Like C<lookup()> but accepts the address in integer form.

=cut

sub lookup_num { shift->_lookup($_[0]) } ## no critic (Subroutines::RequireArgUnpacking)

=head2 to_hash

Arguments: none

Return Value: C<$hashref>

Returns a hash representation of the tree with keys being CIDR-style network
addresses.

=cut

sub to_hash2 {
	my ($self) = @_;
	my %result;
	$self->_walk(0, 0, sub {
            my $net = _int2dq($_[0]) . '/' . $_[1];
            if(defined $result{$net}) {
                confess("internal error: network $net mapped to $result{$net} already!\n");
            } else {
                $result{$net} = $_[2];
            }
        }
    );
	return \%result;
}

sub clear {
    my $self = shift;
    undef @$self;
}

# Walk through a subtree and insert a network
sub _add {
	my ($node, $addr, $nbits, $val) = @_;
    my ($bit, $checksub);
    my @node_stack;

    DESCEND:
    while(1) {
	    $bit = $addr & 0x80000000 ? 1 : 0;
        $addr <<= 1;

        if(__PACKAGE__ ne ref $node) {
            return 1 if($val eq $node); # Compatible entry (tried to add a subnet of one already in the tree)
            croak "incompatible entry, found `$node' trying to add `$val'";
        }
        last DESCEND unless --$nbits;
        if(defined $node->[$bit]) {
            $checksub = 1;
        } else {
            $node->[$bit] ||= bless([], __PACKAGE__);
            $checksub = 0;
        }
        push @node_stack, \$node->[$bit];
        $node = $node->[$bit];
    }
    
    $checksub
        and defined $node->[$bit]
        and __PACKAGE__ eq ref $node->[$bit]
        and _add_check_subtree($node->[$bit], $val);

    $node->[$bit] = $val;

    # Take care of potential mergers into the previous node (if $node[0] == $node[1])
    not @node_stack
        and defined $node->[$bit ^ 1]
        and $node->[$bit ^ 1] eq $val
        and croak 'merging two /1 blocks is not supported yet';
    while(1) {
        $node = pop @node_stack;
        last unless(
            defined $node
                and defined $$node->[0]
                and defined $$node->[1]
                and $$node->[0] eq $$node->[1]
        );
        $$node = $val;
    }
}

# Check an existing subtree for incompatible values. Returns false and sets the
# package-global error string if there was a problem.
sub _add_check_subtree {
    my ($root, $val) = @_;

    eval {
        $root->_walk(0, 0, sub {
                my $oldval = $_[2];
                $val == $oldval or die $oldval; ## no critic (ErrorHandling::RequireCarping)
            }
        );
        1;
    } or do {
        $@ and croak "incompatible entry, found `$@' trying to add `$val'";
    };
    return 1;
}

sub _lookup {
	my ($node, $addr) = @_;
    my $bit;

    while(1) {
        $bit = ($addr & 0x80000000) >> 31;
        defined $node->[$bit] or return;
        __PACKAGE__ ne ref $node->[$bit] and return $node->[$bit];
        $node = $node->[$bit];
        $addr <<= 1;
    }
}

# IPv4 address from integer to dotted-quad
sub _int2dq { inet_ntop(AF_INET, pack 'N', shift) }

# Convert a CIDR block ($addr, $bits) into a range of addresses ($lo, $hi)
# sub _cidr2rng { ( $_[0], $_[0] | ((1 << $_[1]) - 1) ) }

# Walk the tree in depth-first LTR order
sub _walk {
	my ($node, $addr, $bits, $cb) = @_;
	my ($l, $r);
    my @node_stack = ($node, $addr, $bits);
    #print "================== WALK ==================: ", join(':',caller),"\n"; 
    while(@node_stack) {
        ($node, $addr, $bits) = splice @node_stack, -3; # pop 3 elems
        #print "LOOP: stack size ".(@node_stack/3)."\n";
        if(__PACKAGE__ eq ref $node) {
            ($l, $r) = @$node;
            ++$bits;

            # Check left side
            #$addr &= ~(1 << 31-$bits);
            if(__PACKAGE__ eq ref $l) {
                #defined $r and print "L: pushing right node=$r, bits=$bits\n";
                defined $r and push @node_stack, ($r, $addr | 1 << 32-$bits, $bits);
                #print "L: pushing left  node=$l, bits=$bits\n";
                push @node_stack, ($l, $addr, $bits);
                #printf "L: addr=%032b (%s)\n", $addr, _int2dq($addr);
                next; # Short-circuit back to loop w/o checking $r!
            } else {
                #defined $l and printf "L: CALLBACK (%s/%d) => %s\n", _int2dq($addr), $bits, $l;
                defined $l and $cb->($addr, $bits, $l);
            }
        } else {
            # There was a right-side leaf node on the stack that will end up in
            # the "else" branch below
            #print "Found leftover right leaf $node\n";
            $r = $node;
        }

        # Check right side
        $addr |= 1 << 32-$bits;
        if(__PACKAGE__ eq ref $r) {
            #print "R: pushing right node=$r, bits=$bits\n";
            push @node_stack, ($r, $addr, $bits);
            #printf "R: addr=%032b (%s)\n", $addr, _int2dq($addr);
        } else {
            #defined $r and printf "R: CALLBACK (%s/%d) => %s\n", _int2dq($addr), $bits, $r;
            defined $r and $cb->($addr, $bits, $r);
        }
    }
}

sub walk { $_[0]->_walk(0, 0, $_[1]) }

# Split a chunk into a minimal number of CIDR blocks.
sub _do_chunk {
    my ($chunks, $start, $end, $ix1, $ix2) = @_;
    my ($prefix, $xor);

    # Find common prefix.  After that, the bit indicated by $ix1 is 0 for $start
    # and 1 for $end. A split a this point guarantees the longest suffix.
    $xor = $start ^ $end;
    --$ix1 until($xor & 1 << $ix1 or -1 == $ix1);
    $prefix = $start & ~((1 << ($ix1+1)) - 1);

    $ix2++ while($ix2 <= $ix1
            and not ($start & 1 << $ix2)
            and     ($end   & 1 << $ix2));

    # Split if $fbits and $lbits disagree on the length of the chunk.
    if ($ix2 <= $ix1) {
        _do_chunk($chunks, $start,              $prefix | ((1<<$ix1) - 1), $ix1, $ix2);
        _do_chunk($chunks, $prefix | (1<<$ix1), $end,                      $ix1, $ix2);
    } else {
        push @$chunks, [ $prefix, 31-$ix1 ];
    }
}

1;
