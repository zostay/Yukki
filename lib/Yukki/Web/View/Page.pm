package Yukki::Web::View::Page;
use Moose;

extends 'Yukki::Web::View';

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

    my $html = $self->yukkitext({
        page       => $params->{page},
        repository => $params->{repository},
        yukkitext  => $params->{content},
    });

    $ctx->response->add_navigation_item({
        label => 'Edit',
        href  => join('/', '/page/edit', $params->{repository}, $params->{page}),
    });

    return $self->render(
        in_wrapper => 1,
        template   => 'page/view.html',
        context    => $ctx,
        actions    => {
            '#yukkitext' => sub { \$html },
        },
    );
}

sub edit {
    my ($self, $ctx, $params) = @_;

    $ctx->response->add_navigation_item({
        label => 'View',
        href  => join('/', '/page/view', $params->{repository}, $params->{page}),
    });

    my $html = $self->yukkitext({
        page       => $params->{page},
        repository => $params->{repository},
        yukkitext  => $params->{content},
    });

    return $self->render(
        in_wrapper => 1,
        template   => 'page/edit.html',
        context    => $ctx,
        actions    => {
            '#yukkiname'    => sub { $params->{page} },
            '#yukkitext'    => sub { $params->{content} || '' },
            '#preview-yukkitext' => sub { \$html },
            '#attachments-list'  => sub {
                if (@{ $params->{attachments} }) {
                    $self->render(
                        in_wrapper => 0,
                        to_string  => 0,
                        template   => 'page/attachments.html',
                        context    => $ctx,
                        actions    => {
                            'tbody' => [ map {
                                $self->render(
                                    in_wrapper => 0,
                                    to_string  => 0,
                                    template   => 'page/attachment_row.html',
                                    context    => $ctx,
                                    actions    => {
                                        '.filename' => $_->file_name,
                                        '.size'     => $_->formatted_file_size,
                                    },
                                );
                            } @{ $params->{attachments} } ],
                        },
                    );
                }
            },
        },
    );
}

sub preview {
    my ($self, $ctx, $params) = @_;

    my $html = $self->yukkitext({
        page       => $params->{page},
        repository => $params->{repository},
        yukkitext  => $params->{content},
    });

    return $html;
}

1;
