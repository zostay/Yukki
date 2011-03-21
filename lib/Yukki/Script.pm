package Yukki::Script;
use 5.12.1;
use Moose;

extends 'Yukki';

use Yukki::Error;

use MooseX::Types::Path::Class;

has config_file => (
    is          => 'ro',
    isa         => 'Path::Class::Dir',
    required    => 1,
    coerce      => 1,
    lazy_build  => 1,
);

sub _build_config_file {
    my $self = shift;

    Yukki::Error->throw("Please make YUKKI_CONFIG point to your configuraiton file.\n");
        unless defined $ENV{YUKKI_CONFIG};

    Yukki::Error->throw("No configuration found at $ENV{YUKKI_CONFIG}. Please set YUKKI_CONFIG to the correct location.\n")
        unless -f $ENV{YUKKI_CONFIG};

    return $ENV{YUKKI_CONFIG};
}

has '+settings' => (
    lazy_build  => 1,
);

sub _build_settings {
    my $self = shift;
    LoadFile($self->config_file);
}

1;
