package Yukki::Web::Controller::Login;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Controller';

use HTTP::Throwable::Factory qw( http_throw );

sub fire {
    my ($self, $req) = @_;

    my $res;
    given ($req->path_parameters->{action}) {
        when ('page')   { $res = $self->show_login_page($req) }
        when ('submit') { $res = $self->check_login_submission($req) }
        when ('exit')   { $res = $self->logout($req) }
        default         { http_throw('NotFound') }
    }

    return $res->finalize;
}

sub show_login_page {
    my ($self, $req) = @_;

    my $res = $req->new_response(200);
    $res->content_type('text/html');
    $res->body( $self->view('Login')->page($req) );

    return $res;
}

sub check_login_submission {
    my ($self, $req) = @_;

    my $user = $self->model('User')->find(login_name => $req->body_parameters->{login_name});

    $req->add_errors('no such user or you typed your password incorrectly') unless $user;

    if ($user and $user->{password} ne $req->body_parameters->{password}) {
        $req->add_errors('no such user or you typed your password incorrectly');
    }

    if ($req->has_errors) {
        return $self->show_login_page($req);
    }

    else {
        $req->session->{user} = $user;

        my $res = $req->new_response;
        $res->redirect('/page/view/main');
        return $res;
    }
}

sub logout {
    my ($self, $req) = @_;

    $req->session->expire;

    my $res = $req->new_response;
    $res->redirect('/login');
    return $res;
}

1;
