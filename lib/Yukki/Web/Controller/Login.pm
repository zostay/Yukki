package Yukki::Web::Controller::Login;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Controller';

use HTTP::Throwable::Factory qw( http_throw );

sub fire {
    my ($self, $ctx) = @_;

    my $res;
    given ($ctx->request->path_parameters->{action}) {
        when ('page')   { $self->show_login_page($ctx) }
        when ('submit') { $self->check_login_submission($ctx) }
        when ('exit')   { $self->logout($ctx) }
        default         { http_throw('NotFound') }
    }
}

sub show_login_page {
    my ($self, $ctx) = @_;

    $ctx->response->body( $self->view('Login')->page($ctx) );
}

sub check_login_submission {
    my ($self, $ctx) = @_;
    
    my $login_name = $ctx->request->body_parameters->{login_name};
    my $password   = $ctx->request->body_parameters->{password};

    my $user = $self->model('User')->find(login_name => $login_name);

    $ctx->add_errors('no such user or you typed your password incorrectly') unless $user;

    if ($user and $user->{password} ne $password) {
        $ctx->add_errors('no such user or you typed your password incorrectly');
    }

    if ($ctx->has_errors) {
        $self->show_login_page($ctx);
        return;
    }

    else {
        $ctx->request->session->{user} = $user;

        $ctx->response->redirect('/page/view/main');
        return;
    }
}

sub logout {
    my ($self, $ctx) = @_;

    $ctx->request->session->expire;
    $ctx->response->redirect('/login');
}

1;
