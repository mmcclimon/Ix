use 5.20.0;
use warnings;
package Ix::DBIC::Processor;
# ABSTRACT: a role for Processors with DBIC schemas

use Moose::Role;
use experimental qw(signatures postderef);

use namespace::autoclean;

with 'Ix::Processor';

=head1 OVERVIEW

This is a Moose role for building L<Ix::Processor> objects with schemas. An
C<Ix::DBIC::Processor> requires two methods:

=for :list
* schema_class
* connect_info

=cut

requires 'schema_class';

requires 'connect_info';

=method get_database_defaults

Returns an arrayref of default strings to use for the database connection.
(These are eventually passed as the C<on_connect_do> argument to the schema's
C<connect> method.)

=cut

sub get_database_defaults ($self) {
  my @defaults = ( "SET TIMEZONE TO 'UTC'" );

  if ($self->can('database_defaults')) {
    push @defaults, $self->database_defaults;
  }

  return \@defaults;
}

=method schema_connection

Calls C<< $self->schema_class->connect >>. By default, this includes
C<auto_savepoint> and C<quote_names>.

=cut

sub schema_connection ($self) {
  $self->schema_class->connect(
    $self->connect_info,
    {
      on_connect_do  => $self->get_database_defaults,
      auto_savepoint => 1,
      quote_names    => 1,
    },
  );
}

1;
