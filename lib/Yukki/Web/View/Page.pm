package Yukki::Web::View::Page;
use 5.12.1;
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
    $ctx->response->breadcrumb($vars->{breadcrumb});

    return $self->render_page(
        template => 'page/blank.html',
        context  => $ctx,
        vars     => {
            '#yukkiname'        => $vars->{page},
            '#create-page@href' => $link,
            '#file-list'        => $self->attachments($ctx, $vars->{files}),
        },
    );
}

=head2 page_navigation

Sets up the page navigation menu.

=cut

sub page_navigation {
    my ($self, $response, $this_action, $vars) = @_;

    for my $action (qw( edit history rename remove )) {
        next if $action eq $this_action;

        $response->add_navigation_item([ qw( page page_bottom ) ] => {
            label => ucfirst $action,
            href  => join('/', 'page', $action, $vars->{repository}, $vars->{page}),
            sort  => 20,
        });
    }

    for my $view_name (keys %{ $self->app->settings->page_views }) {
        my $view_info = $self->app->settings->page_views->{$view_name};

        next if $view_info->{hide};

        my $args = "?view=$view_name";
           $args = '' if $view_name eq 'default';

        $response->add_navigation_item([ qw( page page_bottom ) ] => {
            label => $view_info->{label},
            href  => join('/', 'page/view', $vars->{repository}, $vars->{page})
                   . $args,
            sort  => $view_info->{sort},
        });
    }
}

=head2 view

Renders a page as a view.

=cut

sub view {
    my ($self, $ctx, $vars) = @_;
    my $file = $vars->{file};

    $ctx->response->page_title($vars->{title});
    $ctx->response->breadcrumb($vars->{breadcrumb});

    my $html = $file->fetch_formatted($ctx, -1);

    $self->page_navigation($ctx->response, 'view', $vars);

    return $self->render_page(
        template => 'page/view.html',
        context  => $ctx,
        vars     => {
            '#yukkitext' => \$html,
        },
    );
}

=head2 history

Display the history for a page.

=cut

sub history {
    my ($self, $ctx, $vars) = @_;

    $ctx->response->page_title($vars->{title});
    $ctx->response->breadcrumb($vars->{breadcrumb});

    $self->page_navigation($ctx->response, 'history', $vars);

    my $i = 0;
    return $self->render_page(
        template => 'page/history.html',
        context  => $ctx,
        vars     => {
            'form@action' => join('/', '/page/diff', $vars->{repository}, $vars->{page}),
            '.revision'   => [
                map { 
                    my $r = {
                        '.first-revision input@value'  => $_->{object_id},
                        '.second-revision input@value' => $_->{object_id},
                        '.date'                        => $_->{time_ago},
                        '.author'                      => $_->{author_name},
                        '.diffstat'                    => sprintf('+%d/-%d', 
                            $_->{lines_added}, $_->{lines_removed},
                        ),
                        '.comment'                     => $_->{comment} || '(no comment)',
                    }; 

                    my $checked = sub { shift->setAttribute(checked => 'checked'); \$_ };

                    $r->{'.first-revision  input'} = $checked if $i == 1;
                    $r->{'.second-revision input'} = $checked if $i == 0;

                    $i++;

                    $r;
                } @{ $vars->{revisions} }
            ],
        },
    );
}

=head2 diff

Display a diff for a file.

=cut

sub diff {
    my ($self, $ctx, $vars) = @_;
    my $file = $vars->{file};

    $ctx->response->page_title($vars->{title});
    $ctx->response->breadcrumb($vars->{breadcrumb});

    $self->page_navigation($ctx->response, 'diff', $vars);

    my $diff = '';
    for my $chunk (@{ $vars->{diff} }) {
        given ($chunk->[0]) {
            when (' ') { $diff .= $chunk->[1] }
            when ('+') { $diff .= sprintf '<ins markdown="1">%s</ins>', $chunk->[1] }
            when ('-') { $diff .= sprintf '<del markdown="1">%s</del>', $chunk->[1] }
            default { warn "unknown chunk type $chunk->[0]" }
        }
    }

    my $html = $file->fetch_formatted($ctx);

    return $self->render_page(
        template => 'page/diff.html',
        context  => $ctx,
        vars     => {
            '#diff' => \$html,
        },
    );
}

=head2 edit

Renders the editor for a page.

=cut

sub edit {
    my ($self, $ctx, $vars) = @_;
    my $file = $vars->{file};

    $ctx->response->page_title($vars->{title});
    $ctx->response->breadcrumb($vars->{breadcrumb});

    my $html = $file->fetch_formatted($ctx, $vars->{position});

    $self->page_navigation($ctx->response, 'edit', $vars);

    my %attachments;
    if (@{ $vars->{attachments} }) {
        %attachments = (
            '#attachments-list@class' => 'attachment-list',
            '#attachments-list'       => $self->attachments($ctx, $vars->{attachments}),
        );
    }

    return $self->render_page(
        template => 'page/edit.html',
        context  => $ctx,
        vars     => {
            '#yukkiname'                => $vars->{page},
            '#yukkitext'                => scalar $vars->{file}->fetch // '',
            '#yukkitext_position@value' => $vars->{position},
            '#preview-yukkitext'        => \$html,
            %attachments,
        },
    );
}

=head2 rename

Renders the rename form for a page.

=cut

sub rename {
    my ($self, $ctx, $vars) = @_;
    my $file = $vars->{file};

    $ctx->response->page_title($vars->{title});
    $ctx->response->breadcrumb($vars->{breadcrumb});

    $self->page_navigation($ctx->response, 'rename', $vars)
        unless $ctx->request->path_parameters->{file};

    return $self->render_page(
        template => 'page/rename.html',
        context  => $ctx,
        vars     => {
            '#yukkiname'                => $vars->{page},
            '#yukkiname_new@value'      => $vars->{page},
        },
    );
}

=head2 remove

Renders the remove confirmation page.

=cut

sub remove {
    my ($self, $ctx, $vars) = @_;
    my $file = $vars->{file};

    $ctx->response->page_title($vars->{title});
    $ctx->response->breadcrumb($vars->{breadcrumb});

    $self->page_navigation($ctx->response, 'remove', $vars)
        unless $ctx->request->path_parameters->{file};

    return $self->render_page(
        template => 'page/remove.html',
        context  => $ctx,
        vars     => {
            '.yukkiname'          => $vars->{page},
            '#cancel_remove@href' => $vars->{return_link},
        },
    );
}

=head2 attachments

Renders the attachments table.

=cut

sub attachments {
    my ($self, $ctx, $attachments) = @_;

    my @files = map { 
        my @links = $self->attachment_links($ctx, $_);

        my %primary_link = %{ $links[0] };
        $primary_link{label} = $_->file_name;

        my $file_name = $self->render_links(
            context => $ctx, 
            links   => [ \%primary_link ],
        );

        +{
            './@id'     => $_->file_id,
            '.filename' => $file_name,
            '.size'     => $_->formatted_file_size,
            '.action'   => $self->render_attachment_links($ctx, \@links),
        };
    } @$attachments;

    return $self->render(
        template   => 'page/attachments.html',
        vars       => {
            '.file' => \@files,
        },
    );
}

=head2 attachment_links

=cut

sub attachment_links {
    my ($self, $ctx, $attachment) = @_;

    my @links;

    if ($attachment->has_format) {
        push @links, { 
            label => 'View',
            href  => join('/', 'page', 'view', 
                    $attachment->repository_name, 
                    $attachment->full_path),
        };
    }
    else {
        push @links, { 
            label => 'View',
            href  => join('/', 'attachment', 'view', 
                    $attachment->repository_name, 
                    $attachment->full_path),
        } if $attachment->media_type ne 'application/octet';

        push @links, {
            label => 'Download',
            href  => join('/', 'attachment', 'download',
                    $attachment->repository_name,
                    $attachment->full_path),
        };
    }

    push @links, {
        label => 'Rename',
        href  => join('/', 'attachment', 'rename',
                $attachment->repository_name,
                $attachment->full_path),
    };

    push @links, {
        label => 'Remove',
        href  => join('/', 'attachment', 'remove',
                $attachment->repository_name,
                $attachment->full_path),
    };

    return @links;
}

=head2 render_attachment_links

Renders the links listed in the action column of the attachments table.

=cut

sub render_attachment_links {
    my ($self, $ctx, $links) = @_;
    return $self->render_links(context => $ctx, links => $links);
}

=head2 preview

Renders a preview of an edit in progress.

=cut

sub preview {
    my ($self, $ctx, $vars) = @_;
    my $file = $vars->{file};

    my $html = $file->fetch_formatted($ctx);

    return $html;
}

1;
