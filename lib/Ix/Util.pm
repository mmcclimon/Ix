use 5.20.0;
package Ix::Util;

use experimental qw(signatures postderef);

use DateTime::Format::Pg;
use DateTime::Format::RFC3339;
use Safe::Isa;
use Scalar::Util qw(blessed);
use Data::GUID qw(guid_string);
use Package::Stash;
use Params::Util qw(_ARRAY0);
use JSON::MaybeXS qw(is_bool);

use Sub::Exporter -setup => {
  exports    => [ qw(parsedate parsepgdate differ ix_new_id splitquoted) ],
  collectors => [
    '$ix_id_re' => \'_export_ix_id_re',
  ],
};

sub _export_ix_id_re {
  my ($class, $value, $data) = @_;

  my $stash = Package::Stash->new($data->{into});
  # http://stackoverflow.com/questions/17146061/extract-guid-from-line-via-regular-expression-in-perl
  # For now, this is just a straight up guid
  $stash->add_symbol(
    '$ix_id_re',
    \qr/([a-f\d]{8}-[a-f\d]{4}-[a-f\d]{4}-[a-f\d]{4}-([a-f\d]){12})/an,
  );

  return 1;
}

my $pg = DateTime::Format::Pg->new();
my $rfc3339 = DateTime::Format::RFC3339->new();

sub ix_new_id { lc guid_string() }

sub parsepgdate ($str) {
  my $dt;
  return unless eval { $dt = $pg->parse_datetime($str) };

  bless $dt, 'Ix::DateTime';
}

sub parsedate ($str) {
  return unless $str =~ /Z\z/; # must be in zulu time
  return if $str =~ /\./; # no fractional seconds

  my $dt;
  return unless eval { $dt = $rfc3339->parse_datetime($str) };

  bless $dt, 'Ix::DateTime';
}

# Return true if two scalars differ as potential Ix property values.  This
# means:
# * definedness differs
# * not the same datetime
# * not the same is-ref (except for date; you can compare date obj + str)
# * string inequality for non-refs
# * boolean inequality for bools
# * not equivalent arrays
# * otherwise, throw exception

sub differ ($x, $y) {
  return 1 if defined $x xor defined $y;
  return unless defined $x;

  if ($x->$_isa('Ix::DateTime') || $y->$_isa('Ix::DateTime')) {
    return $x ne $y;
  }

  return 1 if ref $x xor ref $y;
  return $x ne $y if ! ref $x;

  return ($x xor $y) if is_bool($x) && is_bool($y);

  if (blessed $x || blessed $y) {
    Carp::croak("can't compare non-Boolean, non-DateTime objects with differ");
  }

  if (_ARRAY0($x) && _ARRAY0($y)) {
    return 1 if @$x != @$y;
    for (0 .. $#$x) {
      return 1 if differ($x->[$_], $y->[$_]);
    }
    return;
  }

  Carp::croak "can't compare two references with differ";
}

sub splitquoted ($str) {
  my @found;

  while ($str =~ /\S/) {
    $str =~ s/\A\s+//;

    my ($quote) = $str =~ /\A(["'])/;
    if ($quote && $str =~ s/\A$quote((?:[^$quote\\]++|\\.)*+)$quote//) {
      my $extract = $1;
      $extract =~ s/\\(.)/$1/g;
      push @found, $extract;
    } else {
      $str =~ s/\A(\S+)\s*//;
      push @found, $1;
    }
  }

  return @found;
}

package Ix::DateTime {

  use parent 'DateTime'; # should use DateTime::Moonpig

  use overload '""' => 'as_string';

  sub as_string ($self, @) {
    $rfc3339->format_datetime($self->clone->truncate(to => 'second'));
  }

  sub TO_JSON ($self) {
    $rfc3339->format_datetime($self->clone->truncate(to => 'second'));
  }
}

1;
