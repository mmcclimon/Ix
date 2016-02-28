use 5.20.0;
package Ix::App;

use Moose::Role;
use experimental qw(signatures postderef);

use JSON;
use Plack::Request;

use namespace::autoclean;

has json_codec => (
  is => 'ro',
  default => sub {
    JSON->new->utf8->pretty->allow_blessed->convert_blessed->canonical
  },
  handles => {
    encode_json => 'encode',
    decode_json => 'decode',
  },
);

requires 'connect_info';

has processor => (
  is => 'ro',
  required => 1,
);

sub app ($self) {
  return sub ($env) {
    my $req = Plack::Request->new($env);

    my $ctx = $self->processor->get_context({
      accountId => 1,
      connect_info => $self->connect_info,
    });

    my $content = $req->raw_body;
    my $calls   = $self->decode_json( $content );
    my $result  = $ctx->process_request( $calls );

    return [
      200,
      [ 'Content-Type', 'application/json' ],
      [ $self->encode_json($result) ],
    ];
  }
}

1;
