package Yukki::Web::Router;
use Moose;

extends 'Path::Router';

=head1 NAME

Yukki::Web::Router - send requests to the correct controllers, yo

=cut

has app => (
    is          => 'ro',
    isa         => 'Yukki',
    required    => 1,
    weak_ref    => 1,
    handles     => 'Yukki::Role::App',
);

sub BUILD {
    my $self = shift;

    $self->add_route('login/?:action' => (
        defaults => {
            action => 'page',
        },
        validations => {
            action => qr/^(?:page|submit|exit)$/,
        },
        target => $self->controller('Login'),
    ));

    $self->add_route('logout' => (
        defaults => {
            action => 'exit',
        },
        target => $self->controller('Login'),
    ));

    $self->add_route('page/:action/:repository/?:page' => (
        defaults => {
            action     => 'view',
            repository => 'main',
            page       => 'home',
        },
        validations => {
            action     => qr/^(?:view|edit)$/,
            repository => qr/^[a-z0-9]+$/i,
            page       => qr/^[a-z0-9]+(?:\.[a-z0-9]+)*$/i,
        },
        target => $self->controller('Page'),
    ));
}

1;
