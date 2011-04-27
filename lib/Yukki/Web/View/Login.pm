package Yukki::Web::View::Login;
use Moose;

extends 'Yukki::Web::View';

# ABSTRACT: show a login form

=head1 DESCRIPTION

Renders the login form.

=head1 METHODS

=head2 page

Renders the login page.

=cut

sub page {
    my ($self, $ctx) = @_;

    return $self->render_page(
        template   => 'login/page.html', 
        context    => $ctx,
        vars       => {
            'form@action' => $ctx->rebase_url('login/submit'),
        },
    );
}

1;
