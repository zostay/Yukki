package Yukki::Web::View::Page;
use Moose;

extends 'Yukki::Web::View';

# ABSTRACT: render HTML for viewing and editing wiki pages

=head1 DESCRIPTION

Renders wiki pages.

=head1 METHODS

=head2 blank

Renders a page that links to the edit page for this location. This helps you
create the links.

=cut

sub blank {
    my ($self, $ctx, $vars) = @_;

    my $link = "/page/edit/$vars->{repository}/$vars->{page}";

    $ctx->response->page_title($vars->{title});

    return $self->render_page(
        template => 'page/blank.html',
        context  => $ctx,
        vars     => {
            '#yukkiname'        => $vars->{page},
            '#create-page@href' => $link,
        },
    );
}

=head2 view

Renders a page as a view.

=cut

sub view {
    my ($self, $ctx, $vars) = @_;

    $ctx->response->page_title($vars->{title});

    my $html = $self->yukkitext({
        page       => $vars->{page},
        repository => $vars->{repository},
        yukkitext  => $vars->{content},
    });

    $ctx->response->add_navigation_item({
        label => 'Edit',
        href  => join('/', '/page/edit', $vars->{repository}, $vars->{page}),
    });

    return $self->render_page(
        template => 'page/view.html',
        context  => $ctx,
        vars     => {
            '#yukkitext' => \$html,
        },
    );
}

=head2 edit

Renders the editor for a page.

=cut

sub edit {
    my ($self, $ctx, $vars) = @_;

    $ctx->response->page_title($vars->{title});

    $ctx->response->add_navigation_item({
        label => 'View',
        href  => join('/', '/page/view', $vars->{repository}, $vars->{page}),
    });

    my $html = $self->yukkitext({
        page       => $vars->{page},
        repository => $vars->{repository},
        yukkitext  => $vars->{content},
    });

    my %attachments;
    if (@{ $vars->{attachments} }) {
        %attachments = (
            '#attachments-list@class' => 'attachment-list',
            '#attachments-list'       => $self->attachments($vars->{attachments}),
        );
    }

    return $self->render_page(
        template => 'page/edit.html',
        context  => $ctx,
        vars     => {
            '#yukkiname'              => $vars->{page},
            '#yukkitext'              => $vars->{content} // '',
            '#preview-yukkitext'      => \$html,
            %attachments,
        },
    );
}

=head2 attachments

Renders the attachments table.

=cut

sub attachments {
    my ($self, $attachments) = @_;

    return $self->render(
        template   => 'page/attachments.html',
        vars       => {
            '.file' => [ map { +{
                './@id'     => $_->file_id,
                '.filename' => $_->file_name,
                '.size'     => $_->formatted_file_size,
                '.action'   => $self->attachment_links($_),
            } } @$attachments ],
        },
    );
}

=head2 attachment_links

Renders the links listed in the action column of the attachments table.

=cut

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

=head2 preview

Renders a preview of an edit in progress.

=cut

sub preview {
    my ($self, $ctx, $vars) = @_;

    my $html = $self->yukkitext({
        page       => $vars->{page},
        repository => $vars->{repository},
        yukkitext  => $vars->{content},
    });

    return $html;
}

1;
