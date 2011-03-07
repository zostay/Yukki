package Yukki::Web::Controller;
use Moose;

has app => (
    is          => 'ro',
    isa         => 'Yukki::Web',
    required    => 1,
    weak_ref    => 1,
    handles     => 'Yukki::Role::App',
);

sub fire { die 'not implemented here' }

1;
