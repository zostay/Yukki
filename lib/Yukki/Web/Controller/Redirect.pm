package Yukki::Web::Controller::Redirect;

use v5.24;
use utf8;
use Moo;

use Yukki::Error qw( http_throw );

# ABSTRACT: Simple controller for handling internal redirects

=head1 DESCRIPTION

Simple controller for handling internal redirects.

=head1 METHODS

=head2 fire

When fired, performs the requested redirect.

=cut

sub fire {
    my ($self, $ctx) = @_;

    my $redirect = $ctx->request->path_parameters->{redirect};

    http_throw("no redirect URL named") unless $redirect;

    http_throw("Go to $redirect.", {
        status   => 'MovedPermanently',
        location => $redirect,
    });
}

1;
