package DBIx::Class::Storage::DBI::Replicated::Balancer::Random;

use Moo;
use Scalar::Util qw(looks_like_number);
with 'DBIx::Class::Storage::DBI::Replicated::Balancer';

=head1 NAME

DBIx::Class::Storage::DBI::Replicated::Balancer::Random - A 'random' Balancer

=head1 SYNOPSIS

This class is used internally by L<DBIx::Class::Storage::DBI::Replicated>.  You
shouldn't need to create instances of this class.

=head1 DESCRIPTION

Given a pool (L<DBIx::Class::Storage::DBI::Replicated::Pool>) of replicated
database's (L<DBIx::Class::Storage::DBI::Replicated::Replicant>), defines a
method by which query load can be spread out across each replicant in the pool.

=head1 ATTRIBUTES

This class defines the following attributes.

=head2 master_read_weight

A number greater than 0 that specifies what weight to give the master when
choosing which backend to execute a read query on. A value of 0, which is the
default, does no reads from master, while a value of 1 gives it the same
priority as any single replicant.

For example: if you have 2 replicants, and a L</master_read_weight> of C<0.5>,
the chance of reading from master will be C<20%>.

You can set it to a value higher than 1, making master have higher weight than
any single replicant, if for example you have a very powerful master.

=cut

has master_read_weight => (
  is => 'rw',
  isa => sub { ## Replaces Int
    die "weight must be a decimal greater than 0, not $_[0]"
      unless(looks_like_number($_[0]) and ($_[0] >= 0));
  },
  default => sub { 0 },
);

=head1 METHODS

This class defines the following methods.

=head2 next_storage

Returns an active replicant at random.  Please note that due to the nature of
the word 'random' this means it's possible for a particular active replicant to
be requested several times in a row.

=cut

sub next_storage {
  my $self = shift;
  my @replicants = $self->pool->active_replicants;

  if (not @replicants) {
    # will fall back to master anyway
    return;
  }

  my $master = $self->master;
  my $rnd = $self->_random_number(@replicants + $self->master_read_weight);

  return $rnd >= @replicants ? $master : $replicants[int $rnd];
}

sub _random_number {
  rand($_[1]);
}

=head1 AUTHOR

John Napiorkowski <john.napiorkowski@takkle.com>

=head1 LICENSE

You may distribute this code under the same terms as Perl itself.

=cut

1;
