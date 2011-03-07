package Yukki::Role::App;
use Moose::Role;

requires qw(
    model
    view
    controller
    locate
);

1;
