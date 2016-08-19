use strict;
use warnings;
use experimental qw(postderef signatures);
package Bakesale::Schema::Result::Cookie;
use base qw/DBIx::Class::Core/;

__PACKAGE__->load_components(qw/+Ix::DBIC::Result/);

__PACKAGE__->table('cookies');

__PACKAGE__->ix_add_columns;

__PACKAGE__->ix_add_properties(
  type       => { data_type => 'text', },
  baked_at   => { data_type => 'datetime', is_optional => 1 },
  expires_at => { data_type => 'datetime', is_optional => 0 },
  delicious  => { data_type => 'string', is_optional => 0 },
);

__PACKAGE__->set_primary_key('id');

sub ix_type_key { 'cookies' }

sub ix_default_properties {
  return {
    baked_at => Ix::DateTime->now,
    expires_at => Ix::DateTime->now->add(days => 3),
    delicious => 'yes',
  };
}

sub ix_set_check ($self, $ctx, $arg) {
  # Tried to pass off a cake as a cookie? Throw everything out!
  if ($arg->{create} && ref $arg->{create} eq 'HASH') {
    for my $cookie (values $arg->{create}->%*) {
      if ($cookie->{type} && $cookie->{type} eq 'cake') {
        return $ctx->error(invalidArguments => {
          descriptoin => "A cake is not a cookie",
        });
      }
    }
  }

  return;
}

sub ix_update_check ($self, $ctx, $row, $arg) {
  # Can't make a half-eaten cookie into a new cookie
  if (
       $arg->{type}
    && $arg->{type} !~ /eaten/i
    && $row->type =~ /eaten/i
  ) {
    return $ctx->error(partyFoul => {
      description => "You can't pretend you haven't eaten a part of that coookie!",
    });

    return;
  }
}

sub ix_destroy_check ($self, $ctx, $row) {
  if ($row->type && $row->type eq 'immortal') {
    return $ctx->error(logicalFoul => {
      description => "You can't destroy an immortal cookie!",
    });
  }

  return;
}

1;
