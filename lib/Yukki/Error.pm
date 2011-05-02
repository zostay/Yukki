package Yukki::Error;
use Moose;

extends 'Throwable::Error';

with 'HTTP::Throwable';

use Sub::Exporter::Util;
use Sub::Exporter -setup => {
    exports => [
        http_throw     => Sub::Exporter::Util::curry_method('throw'),
        http_exception => Sub::Exporter::Util::curry_method('new'),
    ],
};

use Yukki::Web::View;

use Moose::Util qw( apply_all_roles );

# ABSTRACT: Yukki's exception class

=head1 SYNOPSIS

  Yukki::Error->throw("Something really bad.", { ... });

=head1 DESCRIPTION

If you look at L<Throwable::Error>, you know what this is. Same thing, different
name.

=cut

has status => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    default     => 'InternalServerError',
);

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

sub BUILD {
    my $self = shift;

    my $status = $self->status;
    apply_all_roles($self, 
        "HTTP::Throwable::Role::Status::$status",
        'Yukki::Error::PSGI',
    );
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
