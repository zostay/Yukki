package Yukki::Web::Controller::Redirect;
use 5.12.1;
use Moose;

use HTTP::Throwable::Factory qw( http_throw );

sub fire {
    my ($self, $ctx) = @_;

    my $redirect = $ctx->request->path_parameters->{redirect};

    Yukki::Error->throw("no redirect URL named") unless $redirect;

    http_throw('MovedPermanently', { location => $redirect });
}

1;
