package Yukki::Web::View::Login;
use Moose;

extends 'Yukki::Web::View';

sub page {
    my ($self, $ctx) = @_;
    return $self->render(
        in_wrapper => 1,
        template   => 'login/page.html', 
        context    => $ctx,
    );
}

1;
