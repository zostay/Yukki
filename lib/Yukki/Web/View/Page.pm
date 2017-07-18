package Yukki::Web::View::Page;

use v5.24;
use utf8;
use Moose;

extends 'Yukki::Web::View';

# ABSTRACT: render HTML for viewing and editing wiki pages

=head1 DESCRIPTION

Renders wiki pages.

=cut

has blank_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_blank_template',
);

sub _build_blank_template {
    shift->prepare_template(
        template   => 'page/blank.html',
        directives => [
            '#yukkiname'        => 'page',
            '#create-page@href' => 'link',
            '#file-list'        => 'attachments | encoded_string',
        ],
    );
}

has view_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_view_template',
);

sub _build_view_template {
    shift->prepare_template(
        template   => 'page/view.html',
        directives => [
            '#yukkitext' => 'html | encoded_string',
        ],
    );
}

has history_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_history_template',
);

sub _build_history_template {
    shift->prepare_template(
        template   => 'page/history.html',
        directives => [
            'form@action' => 'form_action',
            '.revision'   => {
                'rev<-revisions' => [
                    '.first-revision input@value'  => 'rev.object_id',
                    '.second-revision input@value' => 'rev.object_id',
                    '.date'                        => 'rev.time_ago',
                    '.author'                      => 'rev.author_name',
                    '.diffstat'                    => '+={rev.lines_added}/-={rev.lines_removed}',
                    '.comment'                     => 'rev.comment | default("(no comment)")',
                    '.first-revision input'        => sub {
                        my ($t, $input, $vars) = @_;
                        $input->attr(checked => 'checked')
                            if $vars->{index} == 2;
                    },
                    '.second-revision input'       => sub {
                        my ($t, $input, $vars) = @_;
                        $input->attr(checked => 'checked')
                            if $vars->{index} == 1;
                    },
                ],
            },
        ],
    );
}

has diff_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_diff_template',
);

sub _build_diff_template {
    shift->prepare_template(
        template   => 'page/diff.html',
        directives => [
            '#diff' => 'html | encoded_string',
        ],
    );
}

has edit_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_edit_template',
);

sub _build_edit_template {
    shift->prepare_template(
        template   => 'page/edit.html',
        directives => [
            '#yukkiname'                => 'page',
            '#yukkitext'                => 'source',
            '#yukkitext_position@value' => 'position',
            '#preview-yukkitext'        => 'html | encoded_string',
            '#attachments-list'         => 'attachments | encoded_string',
        ],
    );
}

has attachments_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_attachments_template',
);

sub _build_attachments_template {
    shift->prepare_template(
        template   => 'page/attachments.html',
        directives => [
            '.file' => {
                'file<-files' => [
                    '@id'       => 'file.file_id',
                    '.filename' => 'file.file_name | encoded_string',
                    '.size'     => 'file.file_size',
                    '.action'   => 'file.action | encoded_string',
                ],
            },
        ],
    );
}

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
        template => $self->blank_template,
        context  => $ctx,
        vars     => {
            page        => $vars->{page},
            link        => $link,
            attachments => $self->attachments($ctx, $vars->{files}),
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
        template => $self->view_template,
        context  => $ctx,
        vars     => {
            'html' => $html,
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
            'form_action' => join('/', '/page/diff', $vars->{repository}, $vars->{page}),
            'revisions'   => $vars->{revisions},
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

    my $html = $file->fetch_formatted($ctx);

    return $self->render_page(
        template => $self->diff_template,
        context  => $ctx,
        vars     => {
            html => $html,
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

    return $self->render_page(
        template => $self->edit_template,
        context  => $ctx,
        vars     => {
            page        => $vars->{page},
            source      => scalar $vars->{file}->fetch // '',
            position    => $vars->{position},
            html        => $html,
            attachments => $self->attachments($ctx, $vars->{attachments}),
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

    return $self->render(
        template   => $self->attachments_template,
        context    => $ctx,
        vars       => {
            files => @$attachments ? [ map {
                my @links = $self->attachment_links($ctx, $_);

                my %primary_link = %{ $links[0] };
                $primary_link{label} = $_->file_name;

                my $file_name = $self->render_links(
                    context => $ctx,
                    links   => [ \%primary_link ],
                );

                {
                    file_id   => $_->file_id,
                    file_name => $file_name,
                    file_size => $_->formatted_file_size,
                    action    => $self->render_attachment_links($ctx, \@links),
                }
            } @$attachments ] : undef,
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

__PACKAGE__->meta->make_immutable;
