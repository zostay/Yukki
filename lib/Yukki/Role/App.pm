package Yukki::Role::App;
use Moose::Role;

requires qw(
    model
    view
    controller
    locate
    locate_dir
);

1;
