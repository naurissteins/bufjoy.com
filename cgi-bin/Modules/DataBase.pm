package DataBase;

use strict;
use DBI;
use XFileConfig;
#use Digest::SHA qw(sha1_hex);
use DataBaseImpl;

sub new{
	my ($class) = @_;
	my $self = {};

	my @slaves = @{ $c->{db_slaves} || [] };
	$self->{master} = DataBaseImpl->new();
	$self->{slave} = @slaves ? DataBaseImpl->new(db_host => $slaves[int rand(@slaves)]||$c->{db_host}) : $self->{master};

	bless $self, $class;
}

sub master {
	return shift()->{master};
}

sub slave {
	return shift()->{slave};
}

sub SelectOne			{ shift()->slave()->SelectOne(@_) }
sub SelectOneCached		{ shift()->slave()->SelectOneCached(@_) }
sub SelectRow			{ shift()->slave()->SelectRow(@_) }
sub SelectRowCached		{ shift()->slave()->SelectRowCached(@_) }
sub Select				{ shift()->slave()->Select(@_) }
sub Uncache				{ shift()->slave()->Uncache(@_) }
sub SelectARef			{ shift()->slave()->SelectARef(@_) }
sub SelectARefCached	{ shift()->slave()->SelectARefCached(@_) }
sub SelectARefCachedKey	{ shift()->slave()->SelectARefCachedKey(@_) }
sub SelectRowCachedKey	{ shift()->slave()->SelectRowCachedKey(@_) }

sub Exec				{ shift()->master()->Exec(@_) }
sub getLastInsertId		{ shift()->master()->getLastInsertId(@_) }

sub cacheDB				{ shift()->master()->cacheDB() }
sub PurgeCache			{ shift()->master()->PurgeCache(@_) }

1;
