package Yukki::Error;
use Moose;

extends 'Throwable::Error';

# ABSTRACT: Yukki's exception class

=head1 SYNOPSIS

  Yukki::Error->throw("Something really bad.");

=head1 DESCRIPTION

If you look at L<Throwable::Error>, you know what this is. Same thing, different
name.

=cut

1;
