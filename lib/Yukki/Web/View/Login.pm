package Yukki::Web::View::Login;
use v5.24;
use Moose;

extends 'Yukki::Web::View';

# ABSTRACT: show a login form

=head1 DESCRIPTION

Renders the login form.

=cut

has login_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_login_template',
);

sub _build_login_template {
    Yukki::Web::View->prepare_template(
        template   => 'login/page.html',
        directives => [
            'form@action' => 'login_submit_url',
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

__PACKAGE__->meta->make_immutable;
