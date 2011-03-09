package Yukki::Web::View::Page;
use Moose;

extends 'Yukki::Web::View';

use Text::MultiMarkdown qw( markdown );

sub view {
    my ($self, $req, $params) = @_;

    my $markdown = '<div>' . markdown($params->{content}) . '</div>';

    return $self->render(
        in_wrapper => 1,
        template   => 'page/view.html',
        request    => $req,
        actions    => {
            '#yukkitext' => sub { \$markdown },
        },
    );
}

sub edit {
    my ($self, $req, $params) = @_;

    return $self->render(
        in_wrapper => 1,
        template   => 'page/edit.html',
        request    => $req,
        actions    => {
            '#yukkitext' => sub { $params->{content} },
        },
    );
}

1;
