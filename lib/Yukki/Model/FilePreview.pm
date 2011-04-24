package Yukki::Model::FilePreview;
use 5.12.1;
use Moose;

extends 'Yukki::Model::File';

has content => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

override fetch => sub {
    my $self = shift;
    return $self->content;
};

1;
