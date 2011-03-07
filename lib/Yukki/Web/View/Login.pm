package Yukki::Web::View::Login;
use Moose;

extends 'Yukki::Web::View';

sub page {
    my ($self, $req) = @_;
    return $self->render(
        in_wrapper => 1,
        template   => 'login/page.html', 
        request    => $req,
    );
}

1;
