package Yukki::Web::Controller::Login;

use v5.24;
use utf8;
use Moose;

with 'Yukki::Web::Controller';

use Email::Address;
use YAML qw( DumpFile );
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
    my $action = $ctx->request->path_parameters->{action};
    if    ($action eq 'page')    { $self->show_login_page($ctx) }
    elsif ($action eq 'submit')  { $self->check_login_submission($ctx) }
    elsif ($action eq 'profile') { $self->show_profile_page($ctx) }
    elsif ($action eq 'update')  { $self->update_profile($ctx) }
    elsif ($action eq 'exit')    { $self->logout($ctx) }
    else {
        http_throw('That login action does not exist.', {
            status => 'NotFound',
        })
    }
}

=head2 show_login_page

Calls L<Yukki::Web::View::Login/page> to display the login page.

=cut

sub show_login_page {
    my ($self, $ctx) = @_;

    $ctx->response->body( $self->view('Login')->page($ctx) );
}

=head2 show_profile_page

Calls L<Yukki::Web::View::Login/profile> to display the profile page.

=cut

sub show_profile_page {
    my ($self, $ctx, $name, $email) = @_;

    $ctx->response->body(
        $self->view('Login')->profile($ctx, $name, $email)
    );
}

=head2 update_profile

Validates the input user information and updates the user. Redirects the user back to the profile page.

=cut

sub update_profile {
    my ($self, $ctx) = @_;

    http_throw('You are not authorized to run this action.', {
        status => 'Forbidden',
    }) unless $ctx->session->{user};

    my $login_name   = $ctx->request->body_parameters->{login_name};

    unless ($login_name eq $ctx->session->{user}{login_name}) {
        $ctx->add_errors('Are you sure you are logged in as the correct user? Please make sure and try again.');
        $ctx->response->redirect('/profile');
        return;
    }

    my $name         = $ctx->request->body_parameters->{name};
    my $email        = $ctx->request->body_parameters->{email};

    $name  =~ s/^\s+//; $name  =~ s/\s+$//;
    $email =~ s/^\s+//; $email =~ s/\s+$//;

    my $invalid = 0;
    unless ($name =~ /\S+/) {
        $ctx->add_errors('name must contain at least one letter');
        $invalid++;
    }

    my @emails = Email::Address->parse($email);
    if (@emails != 1) {
        $ctx->add_errors('that does not appear to be an email address');
        $invalid++;
    }

    if ($invalid) {
        return $self->show_profile_page($ctx, $name, $email);
    }

    use DDP;

    my %user = $ctx->session->{user}->%*;
    p %user;
    $user{name}  = $name;
    $user{email} = $email;

    my $password_old = $ctx->request->body_parameters->{password_old};
    my $password_new = $ctx->request->body_parameters->{password_new};
    my $password_con = $ctx->request->body_parameters->{password_confirm};

    # Only activate password check/reset if they use it
    if (length $password_old) {
        my $okay = $self->check_password(
            $ctx->session->{user},
            $password_old,
        );

        unless ($okay) {
            $ctx->add_errors('the current password you entered is incorrect');
            return $self->show_profile_page($ctx, $name, $email);
        }

        if (length($password_new) == 0) {
            $ctx->add_errors('you must enter a new password');
            return $self->show_profile_page($ctx, $name, $email);
        }

        if ($password_old eq $password_new) {
            $ctx->add_errors('the new and old passwords you entered are the same');
            return $self->show_profile_page($ctx, $name, $email);
        }

        if ($password_new ne $password_con) {
            $ctx->add_errors('the new passwords you entered do not match');
            return $self->show_profile_page($ctx, $name, $email);
        }

        my $digest = $self->app->hasher;
        $digest->add($password_new);
        $user{password} = $digest->generate;
    }

    my $user_file = $self->app->locate('user_path', $login_name);
    chmod 0600, "$user_file";
    DumpFile("$user_file", \%user);
    chmod 0400, "$user_file";

    $ctx->session->{user} = \%user;

    $ctx->response->redirect('/profile');
    return;
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

__PACKAGE__->meta->make_immutable;
