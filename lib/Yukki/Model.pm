package Yukki::Model;
use Moose;

has app => (
    is          => 'ro',
    isa         => 'Yukki',
    required    => 1,
    weak_ref    => 1,
    handles     => 'Yukki::Role::App',
);

1;
