package Yukki::Web::Request;
use Moose;

use Plack::Request;

=head1 NAME

Yukki::Web::Request - Yukki request descriptor

=cut

has env => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
);

has request => (
    is          => 'ro',
    isa         => 'Plack::Request',
    required    => 1,
    lazy_build  => 1,
    handles     => [ qw(
        address remote_host method protocol request_uri path_info path script_name scheme
        secure body input session session_options logger cookies query_parameters
        body_parameters parameters content raw_body uri base user headers uploads
        content_encoding content_length content_type header referer user_agent param
        upload new_response
    ) ],
);

sub _build_request {
    my $self = shift;
    return Plack::Request->new($self->env);
}

has path_parameters => (
    is          => 'rw',
    isa         => 'HashRef',
    required    => 1,
    default     => sub { +{} },
);

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

