package Yukki::Web::View::Login;

use v5.24;
use utf8;
use Moo;

use Type::Utils;

extends 'Yukki::Web::View';

# ABSTRACT: show a login form

=head1 DESCRIPTION

Renders the login form.

=cut

has login_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
    lazy        => 1,
    builder     => '_build_login_template',
);

sub _build_login_template {
    shift->prepare_template(
        template   => 'login/page.html',
        directives => [
            'form@action' => 'login_submit_url',
        ],
    );
}

has profile_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
    lazy        => 1,
    builder     => '_build_profile_template',
);

sub _build_profile_template {
    shift->prepare_template(
        template   => 'login/profile.html',
        directives => [
            'form@action'            => 'profile_submit_url',
            'input.login_name@value' => 'user.login_name',
            'div.login_name'         => 'user.login_name',
            '.name@value'            => 'name',
            '.email@value'           => 'email',
        ],
    );
}

=head1 METHODS

=head2 page

Renders the login page.

=cut

sub page {
    my ($self, $ctx) = @_;

    return $self->render_page(
        template   => $self->login_template,
        context    => $ctx,
        vars       => {
            'login_submit_url' => $ctx->rebase_url('login/submit'),
        },
    );
}

=head2 profile

Renders the user profile page.

=cut

sub profile {
    my ($self, $ctx, $name, $email) = @_;

    $ctx->response->page_title('Profile of ' . $ctx->session->{user}{name});

    return $self->render_page(
        template => $self->profile_template,
        context  => $ctx,
        vars     => {
            profile_submit_url => $ctx->rebase_url('profile/update'),
            user               => $ctx->session->{user},
            name               => $name // $ctx->session->{user}{name},
            email              => $email // $ctx->session->{user}{email},
        },
    );
}

1;
