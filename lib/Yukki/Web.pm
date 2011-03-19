package Yukki::Web;
use Moose;

extends qw( Yukki );

use Yukki::Error;
use Yukki::Web::Context;
use Yukki::Web::Router;

use HTTP::Throwable::Factory qw( http_throw http_exception );
use Scalar::Util qw( blessed );
use Try::Tiny;

=head1 NAME

Yukki::Web - the Yukki web-server

=cut

has router => (
    is          => 'ro',
    isa         => 'Path::Router',
    required    => 1,
    lazy_build  => 1,
);

sub _build_router {
    my $self = shift;
    Yukki::Web::Router->new( app => $self );
}

sub component {
    my ($self, $type, $name) = @_;
    my $class_name = join '::', 'Yukki::Web', $type, $name;
    Class::MOP::load_class($class_name);
    return $class_name->new(app => $self);
}

sub controller { 
    my ($self, $name) = @_;
    return $self->component(Controller => $name);
}

sub view {
    my ($self, $name) = @_;
    return $self->component(View => $name);
}

sub dispatch {
    my ($self, $env) = @_;

    my $response;
    try {
        my $ctx = Yukki::Web::Context->new(env => $env);

        my $match = $self->router->match($ctx->request->path);

        http_throw('NotFound') unless $match;

        $ctx->request->path_parameters($match->mapping);

        if ($ctx->session->{user}) {
            $ctx->response->add_navigation_item({
                label => 'Sign out',
                href  => '/login/exit',
                sort  => 100,
            });
        }
        
        else {
            $ctx->response->add_navigation_item({
                label => 'Sign in',
                href  => '/login',
                sort  => 100,
            });
        }

        my $controller = $match->target;

        $controller->fire($ctx);
        $response = $ctx->response->finalize;
    }

    catch {
        if (blessed $_ and $_->isa('Moose::Object') and $_->does('HTTP::Throwable')) {
            $response = $_->as_psgi($env);
        }

        else {
            warn "ISE: $_";

            $response = http_exception('InternalServerError', {
                show_stack_trace => 0,
            })->as_psgi($env);
        }
    };

    return $response;
}

1;
