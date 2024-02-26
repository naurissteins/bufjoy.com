package Module::Refresh;

use strict;
use vars qw( $VERSION %CACHE );

$VERSION = "0.17";

BEGIN {

    # Turn on the debugger's symbol source tracing
    $^P |= 0x10;

    eval 'sub DB::sub' if $] < 5.008007;
}

sub new {
    my $proto = shift;
    my $self = ref($proto) || $proto;
    $self->update_cache($_) for keys %INC;
    return ($self);
}

sub refresh {
    my $self = shift;

    return $self->new if !%CACHE;

    foreach my $mod ( sort keys %INC ) {
        $self->refresh_module_if_modified($mod);
    }
    return ($self);
}

sub refresh_module_if_modified {
    my $self = shift;
    return $self->new if !%CACHE;
    my $mod = shift;

    if (!$INC{$mod}) {
        return;
    } elsif ( !$CACHE{$mod} ) {
        $self->update_cache($mod);
    } 
    elsif ( $self->mtime( $INC{$mod} ) ne $CACHE{$mod} ) {
    #elsif ( $self->mtime( $INC{$mod} ) > $CACHE{$mod} && $self->mtime( $INC{$mod} )+2 < time ) {
        $self->refresh_module($mod);
    }

}

sub refresh_module {
    my $self = shift;
    my $mod  = shift;

    $self->unload_module($mod);

    local $@;
    eval { require $mod; 1 } or die $@;

    $self->update_cache($mod);

    return ($self);
}

sub unload_module {
    my $self = shift;
    my $mod  = shift;
    my $file = $INC{$mod};

    delete $INC{$mod};
    delete $CACHE{$mod};
    $self->unload_subs($file);

    return ($self);
}

sub mtime {
    #return join ' ', ( stat( $_[1] ) )[ 1, 7, 9 ];
    return ( stat( $_[1] ) )[ 9 ];
}

sub update_cache {
    my $self      = shift;
    my $module_pm = shift;

    $CACHE{$module_pm} = $self->mtime( $INC{$module_pm} );
}

sub unload_subs {
    my $self = shift;
    my $file = shift;

    foreach my $sym ( grep { index( $DB::sub{$_}, "$file:" ) == 0 }
        keys %DB::sub )
    {

        warn "Deleting $sym from $file" if ( $sym =~ /freeze/ );
        eval { undef &$sym };
        warn "$sym: $@" if $@;
        delete $DB::sub{$sym};
        { no strict 'refs';
            if ($sym =~ /^(.*::)(.*?)$/) {
                delete *{$1}->{$2};
            }
        } 
    }

    return $self;
}

# "Anonymize" all our subroutines into unnamed closures; so we can safely
# refresh this very package.
BEGIN {
    no strict 'refs';
    foreach my $sym ( sort keys %{ __PACKAGE__ . '::' } ) {
        next
            if $sym eq
            'VERSION';    # Skip the version sub, inherited from UNIVERSAL
        my $code = __PACKAGE__->can($sym) or next;
        delete ${ __PACKAGE__ . '::' }{$sym};
        *$sym = sub { goto &$code };
    }

}

1;
