package Yukki::Web::Context;
use Moose;

use Yukki::Web::Request;
use Yukki::Web::Response;

has env => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
);

has request => (
    is          => 'ro',
    isa         => 'Yukki::Web::Request',
    required    => 1,
    lazy        => 1,
    default     => sub { Yukki::Web::Request->new(env => shift->env) },
);

has response => (
    is          => 'ro',
    isa         => 'Yukki::Web::Response',
    required    => 1,
    lazy        => 1,
    default     => sub { Yukki::Web::Response->new },
);

has stash => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
    default     => sub { +{} },
);

# TODO Store these in a flash stash
for my $message_type (qw( errors warnings info )) {
    has $message_type => (
        is          => 'ro',
        isa         => 'ArrayRef[Str]',
        required    => 1,
        default     => sub { [] },
        traits      => [ 'Array' ],
        handles     => {
            "list_$message_type" => 'elements',
            "add_$message_type"  => 'push',
            "has_$message_type"  => 'count',
        },
    );
}

1;
