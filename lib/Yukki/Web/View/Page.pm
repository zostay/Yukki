package Yukki::Web::View::Page;
use Moose;

extends 'Yukki::Web::View';

use Text::MultiMarkdown qw( markdown );

sub blank {
    my ($self, $ctx, $vars) = @_;

    my $link = "/page/edit/$vars->{repository}/$vars->{page}";

    return $self->render(
        in_wrapper => 1,
        template   => 'page/blank.html',
        context    => $ctx,
        actions    => {
            '#yukkiname'   => sub { $vars->{page} },
            '#create-page' => sub { { href => $link } },
        },
    );
}

sub view {
    my ($self, $ctx, $params) = @_;

    my $markdown = '<div>' . markdown($params->{content}) . '</div>';

    return $self->render(
        in_wrapper => 1,
        template   => 'page/view.html',
        context    => $ctx,
        actions    => {
            '#yukkitext' => sub { \$markdown },
        },
    );
}

sub edit {
    my ($self, $ctx, $params) = @_;

    return $self->render(
        in_wrapper => 1,
        template   => 'page/edit.html',
        context    => $ctx,
        actions    => {
            '#yukkiname' => sub { $params->{page} },
            '#yukkitext' => sub { $params->{content} },
        },
    );
}

1;
