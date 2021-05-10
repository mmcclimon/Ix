use 5.20.0;
use warnings;
package Ix::AccountState;
# ABSTRACT: bookkeeping for JMAP state strings

use Moose;
use MooseX::StrictConstructor;
use experimental qw(signatures postderef);
extends 'Ix::AccountState';

use namespace::clean;

=head1 OVERVIEW

This class is responsible for keeping track of JMAP state strings for an
account. Every L<Ix::DBIC::Result> row has associated accountId,
modSeqCreated, and modSeqChanged columns. The state strings for these object
types are tracked in a separate table, which is represented by an
L<Ix::DBIC::StatesResult> rclass.

When modifying a result row, the context object calls out to an AccountState
object to fill in modSeqCreated or modSeqChanged attributes, and to ensure
that the modseqs in the states table are modified as needed.

=attr context

=attr account_type

=attr accountId

=cut

sub schema ($self) { $self->context->schema }

has _state_rows => (
  is   => 'ro',
  isa  => 'HashRef',
  lazy => 1,
  init_arg => undef,
  default  => sub ($self) {
    my @rows = $self->schema->resultset('State')->search({
      accountId => $self->accountId,
    });

    my %map = map {; $_->type => $_ } @rows;
    return \%map;
  },
);

has _pending_states => (
  is  => 'rw',
  init_arg => undef,
  default  => sub {  {}  },
);

sub _pending_state_for ($self, $type) {
  return $self->_pending_states->{$type};
}

=method state_for($type)

Returns the current state for a given type.

=cut

sub state_for ($self, $type) {
  my $pending = $self->_pending_state_for($type);
  return $pending if defined $pending;
  return "0" unless my $row = $self->_state_rows->{$type};
  return $row->highestModSeq;
}

=method lowest_modseq_for($type)

=method highest_modseq_for($type)

These methods are accessors for the relevant fields in the states row for
C<$type>.

=cut

sub lowest_modseq_for ($self, $type) {
  my $row = $self->_state_rows->{$type};
  return $row->lowestModSeq if $row;
  return 0;
}

sub highest_modseq_for ($self, $type) {
  my $row = $self->_state_rows->{$type};
  return $row->highestModSeq if $row;
  return 0;
}

=method ensure_state_bumped($type)

This is called internally by L<Ix::DBIC::ResultSet> to bump the state for a
given type. Internally, this keeps track of pending states and ensures that
the state is only bumped once per transaction.

=cut

sub ensure_state_bumped ($self, $type) {
  return if defined $self->_pending_state_for($type);
  $self->_pending_states->{$type} = $self->next_state_for($type);
  return;
}

=method next_state_for($type)

This is used by L<Ix::DBIC::ResultSet> to fill in modSeqCreated or
modSeqChanged values on result rows. It returns the current state + 1 if no
changes are pending, and the pending state if one exists.

=cut

sub next_state_for ($self, $type) {
  my $pending = $self->_pending_state_for($type);
  return $pending if $pending;

  my $row = $self->_state_rows->{$type};
  return $row ? $row->highestModSeq + 1 : 1;
}

sub _save_states ($self) {
  my $rows = $self->_state_rows;
  my $pend = $self->_pending_states;
  my $did_states = {};

  for my $type (keys %$pend) {
    if (my $row = $rows->{$type}) {
      $row->update({ highestModSeq => $pend->{$type} });
    } else {
      my $row = $self->schema->resultset('State')->create({
        accountId => $self->accountId,
        type      => $type,
        highestModSeq => $pend->{$type},
        lowestModSeq  => 0,
      });

      $rows->{$type} = $row;
    }

    $did_states->{$type} = delete $pend->{$type};
  }

  return $did_states;
}

1;
