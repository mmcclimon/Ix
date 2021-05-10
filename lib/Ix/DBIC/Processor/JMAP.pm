use 5.20.0;
package Ix::Processor::JMAP;
# ABSTRACT: do stuff with JMAP requests

use Moose::Role;
use experimental qw(lexical_subs signatures postderef);

use Params::Util qw(_HASH0);
use Safe::Isa;

use namespace::autoclean;

use Ix::JMAP::SentenceCollection;

with 'Ix::Processor::JMAP';

around handler_for => sub ($orig, $self, $method, @rest) {
  my $handler = $self->$orig($method, @rest);
  return $handler if $handler;

  my $h = $self->_dbic_handlers;
  return $h->{$method} if exists $h->{$method};

  return;
};

has _dbic_handlers => (
  is   => 'ro',
  lazy => 1,
  init_arg => undef,
  default => sub {
    my ($self) = @_;

    my %handler;

    my $source_reg = $self->schema_class->source_registrations;
    for my $moniker (keys %$source_reg) {
      my $rclass = $source_reg->{$moniker}->result_class;
      next unless $rclass->isa('Ixless::DBIC::Result');

      if (
        $rclass->can('ix_published_method_map')
        &&
        (my $method_map = $rclass->ix_published_method_map)
      ) {
        for (keys %$method_map) {
          my $method = $method_map->{$_};
          $handler{$_} = sub ($self, $ctx, $arg = {}) {
            $rclass->$method($ctx, $arg);
          };
        }
      }

      my $key = $rclass->ix_type_key;

      $handler{"$key/get"} = sub ($self, $ctx, $arg = {}) {
        $ctx->schema->resultset($moniker)->ix_get($ctx, $arg);
      };

      $handler{"$key/changes"} = sub ($self, $ctx, $arg = {}) {
        $ctx->schema->resultset($moniker)->ix_changes($ctx, $arg);
      };

      $handler{"$key/set"} = sub ($self, $ctx, $arg) {
        $ctx->schema->resultset($moniker)->ix_set($ctx, $arg);
      };

      if ($rclass->ix_query_enabled) {
        $handler{"$key/query"} = sub ($self, $ctx, $arg) {
          $ctx->schema->resultset($moniker)->ix_query($ctx, $arg);
        };
        $handler{"$key/queryChanges"} = sub ($self, $ctx, $arg) {
          $ctx->schema->resultset($moniker)->ix_query_changes($ctx, $arg);
        };
      }
    }

    return \%handler;
  }
);

1;
