package Yukki::Error;
use Moose;

with qw( Throwable HTTP::Throwable MooseX::Traits );

use Sub::Exporter -setup => {
    exports => {
        http_throw     => \&throw_exception,
        http_exception => \&new_exception,
    },
};

use Yukki::Web::View;

# ABSTRACT: Yukki's exception class

=head1 SYNOPSIS

  Yukki::Error->throw("Something really bad.", { ... });

=head1 DESCRIPTION

If you look at L<Throwable::Error>, you know what this is. Same thing, different
name.

=cut

{
    package Yukki::Error::Fixup;
    use Moose::Role;

    around as_psgi => sub {
        my $next = shift; # not used
        my ($self, $env) = @_;
        my $body    = $self->body($env);
        my $headers = $self->build_headers($body, $env);
        [ $self->status_code, $headers, [ defined $body ? $body : () ] ];
    };
}

sub new_exception {
    my ($class, $name, $args) = @_;

    return sub {
        my ($message, $params) = @_;
        $params //= {};

        my $status = 'InternalServerError';
           $status = $params->{status} if defined $params->{status};

        return $class->with_traits(
            "HTTP::Throwable::Role::Status::$status",
            'Yukki::Error::Fixup',
        )->new($message, $params);
    };
}

sub throw_exception {
    my ($class, $name, $args) = @_;

    my $new_exception = new_exception($class, $name, $args);

    return sub {
        my $self = $new_exception->(@_);
        $self->throw;
    };
}

has status => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    default     => 'InternalServerError',
);

has '+status_code' => ( lazy => 1 );
has '+reason'      => ( lazy => 1 );

sub default_status_code { 500 }
sub default_reason { 'Internal Server Error' }

sub BUILDARGS {
    my ($class, $message, $args) = @_;
    $args //= {};

    return {
        %$args,
        message => $message,
    };
}

sub body {
    my ($self, $env) = @_;

    my $app  = $env->{'yukki.app'};
    my $view = Yukki::Web::View->new(app => $app);
    my $ctx  = Yukki::Web::Context->new(env => $env);

    $ctx->response->page_title($self->reason);

    return $view->render_page(
        template => 'error.html',
        context  => $ctx,
        vars     => {
            '#error-page' => $self->message,
        },
    );
}

sub body_headers {
    my ($self, $body) = @_;

    return [
        'Content-type'   => 'text/html',
        'Content-length' => length $body,
    ];
}

sub as_string {
    my $self = shift;
    return $self->message;
}

1;
