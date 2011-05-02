package Yukki::Error::PSGI;
use Moose::Role;

around as_psgi => sub {
    my $next = shift; # not used
    my ($self, $env) = @_;
    my $body    = $self->body($env);
    my $headers = $self->build_headers($body, $env);
    [ $self->status_code, $headers, [ defined $body ? $body : () ] ];
};

1;
