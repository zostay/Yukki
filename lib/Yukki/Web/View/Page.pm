package Yukki::Web::View::Page;
use Moose;

extends 'Yukki::Web::View';

sub blank {
    my ($self, $ctx, $vars) = @_;

    my $link = "/page/edit/$vars->{repository}/$vars->{page}";

    return $self->render_page(
        template => 'page/blank.html',
        context  => $ctx,
        vars     => {
            '#yukkiname'        => $vars->{page},
            '#create-page@href' => $link,
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

    return $self->render_page(
        template => 'page/view.html',
        context  => $ctx,
        vars     => {
            '#yukkitext' => \$html,
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

    my %attachments;
    if (@{ $params->{attachments} }) {
        %attachments = (
            '#attachments-list@class' => 'attachment-list',
            '#attachments-list'       => $self->attachments($params->{attachments}),
        );
    }

    return $self->render_page(
        template => 'page/edit.html',
        context  => $ctx,
        vars     => {
            '#yukkiname'              => $params->{page},
            '#yukkitext'              => $params->{content} // '',
            '#preview-yukkitext'      => \$html,
            %attachments,
        },
    );
}

sub attachments {
    my ($self, $attachments) = @_;

    return $self->render(
        template   => 'page/attachments.html',
        vars       => {
            '.file' => [ map { +{
                './@id'     => $_->object_id,
                '.filename' => $_->file_name,
                '.size'     => $_->formatted_file_size,
                '.action'   => $self->attachment_links($_),
            } } @$attachments ],
        },
    );
}

sub attachment_links {
    my ($self, $attachment) = @_;

    my @links;

    push @links, { 
        label => 'View',
        href  => join('/', '/attachment', 'view', 
                 $attachment->repository_name, 
                 $attachment->full_path),
    } if $attachment->media_type ne 'application/octet';

    push @links, {
        label => 'Download',
        href  => join('/', '/attachment', 'download',
                 $attachment->repository_name,
                 $attachment->full_path),
    };

    return $self->render_links(links => \@links);
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
