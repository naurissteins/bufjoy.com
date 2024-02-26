package TransmissionRPC;
use strict;
use LWP::UserAgent;
use JSON;

sub new {
   my ($class, $endpoint) = @_;
   my $self = {};
   $self->{ua} = LWP::UserAgent->new(agent => "TransmissionRPC", timeout => 5);
   $self->{endpoint} = $endpoint;
   $self->{session_id} = undef;
   bless $self, $class;
}

sub request {
   my ($self, $method, $args) = @_;

   my $request = {};
   $request->{method} = $method;
   $request->{arguments} = $args;
   my $res = $self->_request_impl($request);

   if($res->code() == 409) {
      $self->{session_id} = $res->header("X-Transmission-Session-Id");
      $res = $self->_request_impl($request);
   }
   my $rr = $res->decoded_content();
   return '' unless $rr=~/^\{/;
   my $ret = JSON::decode_json($rr);
   return $ret;
}

sub _request_impl {
   my ($self, $request) = @_;

   my $req = HTTP::Request->new(POST => $self->{endpoint});
   $req->content(encode_json($request));
   $req->header("X-Transmission-Session-Id" => $self->{session_id}) if $self->{session_id};
   return $self->{ua}->request($req);
}

1;
