package Yukki::Web::Controller::Login;
use 5.12.1;
use Moose;

with 'Yukki::Web::Controller';

use Yukki::Error qw( http_throw );

# ABSTRACT: shows the login page and handles login

=head1 DESCRIPTION

Shows the login page and handles login.

=head1 METHODS

=head2 fire

Routes page reqquests to L</show_login_page>, submit requests to L</check_login_submission>, and exit requests to L</logout>.

=cut

sub fire {
    my ($self, $ctx) = @_;

    my $res;
    given ($ctx->request->path_parameters->{action}) {
        when ('page')   { $self->show_login_page($ctx) }
        when ('submit') { $self->check_login_submission($ctx) }
        when ('exit')   { $self->logout($ctx) }
        default         { http_throw('That login action does not exist.', {
            status => 'NotFound',
        }) }
    }
}

=head2 show_login_page

Calls L<Yukki::Web::View::Login/page> to display the login page.

=cut

sub show_login_page {
    my ($self, $ctx) = @_;

    $ctx->response->body( $self->view('Login')->page($ctx) );
}

=head2 check_password

Checks that the user's password is valid.

=cut

sub check_password {
    my ($self, $user, $password) = @_;

    return scalar $self->app->hasher->validate(
        $user->{password}, 
        $password,
    );
}

=head2 check_login_submission

Authenticates a user login.

=cut

sub check_login_submission {
    my ($self, $ctx) = @_;
    
    my $login_name = $ctx->request->body_parameters->{login_name};
    my $password   = $ctx->request->body_parameters->{password};

    my $user = $self->model('User')->find(login_name => $login_name);

    if (not ($user and $self->check_password($user, $password))) {
        $ctx->add_errors('no such user or you typed your password incorrectly');
    }

    if ($ctx->has_errors) {
        $self->show_login_page($ctx);
        return;
    }

    else {
        $ctx->session->{user} = $user;

        $ctx->response->redirect($ctx->rebase_url('page/view/main'));
        return;
    }
}

=head2 logout

Expires the session, causing logout.

=cut

sub logout {
    my ($self, $ctx) = @_;

    $ctx->session_options->{expire} = 1;
    $ctx->response->redirect($ctx->rebase_url('page/view/main'));
}

1;
