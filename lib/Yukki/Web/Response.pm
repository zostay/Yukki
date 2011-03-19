package Yukki::Web::Response;
use Moose;

use Plack::Response;

has response => (
    is          => 'ro',
    isa         => 'Plack::Response',
    required    => 1,
    lazy_build  => 1,
    handles     => [ qw(
        status headers body header content_type content_length content_encoding
        redirect location cookies finalize
    ) ],
);

sub _build_response {
    my $self = shift;
    return Plack::Response->new(200, [ 'Content-type' => 'text/html' ]);
}

has page_title => (
    is          => 'rw',
    isa         => 'Str',
    predicate   => 'has_page_title',
);

has navigation => (
    is          => 'rw',
    isa         => 'ArrayRef[HashRef]',
    required    => 1,
    default     => sub { [] },
    traits      => [ 'Array' ],
    handles     => {
        navigation_menu      => [ sort => sub { ($_[0]->{sort}//50) <=> ($_[1]->{sort}//50) } ],
        add_navigation_item  => 'push',
        add_navigation_items => 'push',
    },
);

1;
