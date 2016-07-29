package Yukki::Error;

use v5.24;
use Moose;

extends qw( HTTP::Throwable::Factory );

use Sub::Exporter -setup => {
    exports => [ qw< http_throw http_exception > ],
};

use Yukki::Web::View;

# ABSTRACT: Yukki's exception class

=head1 SYNOPSIS

  Yukki::Error->throw("Something really bad.", { ... });

=head1 DESCRIPTION

If you are familiar with L<HTTP::Throwable::Factory>, this is similar to that (and is based on that).

However, there are two differences. First, the error message is given primacy rather than exception type, so you can just use this to throw an exception:

    use Yukki::Error qw( http_throw );
    http_throw('something went wrong');

Since you almost always want your exception to be an internal server error of some kind, this makes more sense to me than having to write:

    use HTTP::Throwable::Factory qw( http_throw );
    http_throw(InternalServerError => {
        message => 'something went wrong',
    });

To specify the type of exception, us C<status>:

    use Yukki::Error qw( http_throw );
    http_throw('something was not found', {
        status => 'NotFound',
    });

The second difference is that all exceptions thrown by this factory inherit from L<Yukki::Error>, so this works:

    use Scalar::Util qw( blessed );
    use Try::Tiny;
    try { ... }
    catch {
        if (blassed $_ && $_->isa("Yukki::Error") {
            # we now this is an application error from Yukki
        }
    };

This makes it easy to know whether Yukki generated the exception or something else did.

=cut

sub base_class { 'Yukki::Error' }
sub extra_roles { 'Yukki::Error::Body' }

=head1 EXPORTS

=head2 http_exception

  my $error = http_exception('message', {
      status           => 'InternalServerError',
      show_stask_trace => 0,
  });

Creates a new exception object. Calls the constructor for L<Yukki:Error> and applied the L<HTTP::Throwable> status role needed (prior to construction actually).

=cut

sub http_exception {
    my ($name, $args) = @_;

    my %args = %{ $args // {} };
    my $status = delete $args{status} // 'InternalServerError';

    Yukki::Error->new_exception($status => {
        %args,
        message => "$name",
    });
}

=head2 http_throw

  http_throw('message', {
      status           => 'InternalServerError',
      show_stask_trace => 0,
  });

Constructs the exception (via L</http_exception>) and throws it.

=cut

sub http_throw {
    my ($name, $args) = @_;

    http_exception($name, $args)->throw;
}

sub BUILDARGS {
    my ($class, $args) = @_;
    $args;
}

=begin Pod::Coverage

    BUILDARGS
    base_class
    extra_roles

=end Pod::Coverage

=cut

{
    package Yukki::Error::Body;

    use Moose::Role;

=head1 METHODS

=head2 body

Renders the HTML body for the error.

=cut

    sub body {
        my ($self, $env) = @_;

        my $app  = $env->{'yukki.app'};
        my $view = Yukki::Web::View->new(app => $app);
        my $ctx  = Yukki::Web::Context->new(env => $env);

        my $template = $view->prepare_template(
            template   => 'error.html',
            directives => {
                '#error-page' => 'error_message',
            },
        );

        $ctx->response->page_title($self->reason);

        return $view->render_page(
            template => $template,
            context  => $ctx,
            vars     => {
                'error_message' => $self->message,
            },
        );
    }

=head2 body_headers

Setup the HTTP headers.

=cut

    sub body_headers {
        my ($self, $body) = @_;

        return [
            'Content-type'   => 'text/html',
            'Content-length' => length $body,
        ];
    }

}

__PACKAGE__->meta->make_immutable;

