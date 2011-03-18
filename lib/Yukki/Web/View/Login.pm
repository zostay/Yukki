package Yukki::Web::View::Login;
use Moose;

extends 'Yukki::Web::View';

sub page {
    my ($self, $ctx) = @_;

    return $self->render_page(
        template   => 'login/page.html', 
        context    => $ctx,
    );
}

1;
