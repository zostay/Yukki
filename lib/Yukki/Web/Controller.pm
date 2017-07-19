package Yukki::Web::Controller;

use v5.24;
use utf8;
use Moo::Role;

use Type::Utils;

# ABSTRACT: Base class for Yukki::Web controllers

=head1 DESCRIPTION

All L<Yukki::Web> controllers extend from here.

=head1 ATTRIBUTES

=head2 app

This is the L<Yukki::Web> application.

=cut

has app => (
    is          => 'ro',
    isa         => class_type('Yukki::Web'),
    required    => 1,
    weak_ref    => 1,
    handles     => 'Yukki::Role::App',
);

=head1 REQUIRED METHODS

=head2 fire

  $controller->fire($context);

Controllers must implement this method. This method will be given a
L<Yukki::Web::Context> to work with. It is expected to fill in the
L<Yukki::Web::Response> attached to that context or throw an exception.

=cut

requires 'fire';

1;
