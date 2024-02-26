package DataBaseImpl;
use strict;
use DBI;
use XFileConfig;

sub new{
  my ($class, %opts) = @_;
  my $self={ dbh=>undef, %opts };
  $self->{$_} ||= $c->{$_} for qw(db_name db_host db_login db_passwd);
  bless $self,$class;

  $self->{'exec'}=$self->{'select'}=$self->{'memcached_hit'}=0;
  return $self;
}

sub inherit{
  my $class = shift;
  my $dbh   = shift;
  my $self={ dbh=>undef };
  bless $self,$class;
  $self->{dbh} = $dbh;
  return $self;
}


sub dbh
{
  my $self=shift;
  $self->InitDB unless $self->{dbh};
  return $self->{dbh};
}

sub InitDB
{
  my $self=shift;
  $self->{dbh}=DBI->connect("DBI:mysql:database=$c->{'db_name'};host=$self->{'db_host'};mysql_multi_statements=0;mysql_auto_reconnect=1",$c->{'db_login'},$c->{'db_passwd'}) || die ("Can't connect to Mysql server.");
  $self->Exec("SET NAMES 'utf8'");
}

sub DESTROY
{
  shift->UnInitDB();
}

sub UnInitDB{
  my $self=shift;
  if($self->{dbh})
  {
    if($self->{locks})
    {
          $self->Unlock();
    }
    $self->{dbh}->disconnect;
  }
  $self->{dbh}=undef;
}

sub Exec
{
  my $self=shift;
  $self->dbh->do(shift,undef,@_) || die"Can't exec:\n".$self->dbh->errstr;
  $self->{'exec'}++;
}

sub SelectOne
{
  my $self=shift;
  my $res = $self->dbh->selectrow_arrayref(shift,undef,@_);
  die"Can't execute select:\n".$self->dbh->errstr if $self->dbh->err;
  $self->{'select'}++;
  return $res->[0];
};

sub SelectRow
{
  my $self=shift;
  my $res = $self->dbh->selectrow_hashref(shift,undef,@_);
  die"Can't execute select:\n".$self->dbh->errstr if $self->dbh->err;
  $self->{'select'}++;
  return $res;
}

sub Select
{
  my $self=shift;
  my $query = shift;
  my $res = $self->dbh->selectall_arrayref( $query, { Slice=>{} }, @_ );
  die"Can't execute select:\n".$self->dbh->errstr if $self->dbh->err;
  $self->{'select'}++;
  return undef if $#$res==-1;
  return $res;
}

sub SelectARef
{
   my $self = shift;
   my $data = $self->Select(@_);
   return [] unless $data;
   return [$data] unless ref($data) eq 'ARRAY';
   return $data;
}

sub getLastInsertId
{
  return shift->{ dbh }->{'mysql_insertid'};
}

sub SelectARefCached
{
    my ($self,@data) = @_;

    my $expire = $data[0]=~/^\d+$/ ? shift(@data) : $c->{memcached_expire};
    return $self->_SelectARefCached('',$expire,@data);
}

sub SelectOneCached
{
    my ($self,@data) = @_;

    return (values %{ $self->SelectARefCached(@data)->[0] })[0];
}

sub SelectRowCached
{
    my ($self,@data) = @_;

    return $self->SelectARefCached(@data)->[0];
}

sub SelectARefCachedKey
{
    my ($self,$key,$expire,@data) = @_;

    return $self->_SelectARefCached($key.$c->{dl_key},$expire,@data);
}

sub SelectRowCachedKey 

{
	my ($self,$key,$expire,@data) = @_;

	return $self->_SelectARefCached($key.$c->{dl_key},$expire,@data)->[0];
  
}

sub _SelectARefCached
{
    my ($self,$key,$expire,@data) = @_;

    $expire ||= $c->{memcached_expire};

    return $self->SelectARef(@data) unless $c->{m_u};

    unless($key)
    {
        require Digest::SHA1;
        require Encode;
        $key = Digest::SHA1::sha1_hex(Encode::encode_utf8(join(' ',$c->{dl_key},@data)), '');
    }
    
    my $res = $self->cacheDB->get($key);
    if($res)
    {
        $self->{'memcached_hit'}++;
        return($res);
    }
    else
    {
        $res = $self->SelectARef(@data);
        $self->cacheDB->set($key, $res, $expire);
        return($res);
    }
}

sub cacheDB
{
    my ($self) = @_;
    return unless $c->{m_u};
    unless($self->{memd})
    {
        require Cache::Memcached;
        $self->{memd} = new Cache::Memcached {
                'servers' => [ $c->{memcached_address} ],
        };
    }
    return $self->{memd};
}

sub PurgeCache
{
    my ($self,$key) = @_;
    return unless $c->{m_u};
    
    $self->cacheDB->delete($key.$c->{dl_key});
}


1;                                                           
