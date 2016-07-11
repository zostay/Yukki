package Yukki::Model;
use v5.24;
use Moose;

# ABSTRACT: Base class for model objects

=head1 DESCRIPTION

This is the base class used for model objects.

=head1 ATTRIBUTES

=head2 app

This is the L<Yukki> application instance.

=cut

has app => (
    is          => 'ro',
    isa         => 'Yukki',
    required    => 1,
    weak_ref    => 1,
    handles     => 'Yukki::Role::App',
);

1;
