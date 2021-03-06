package Yukki::Web::View::Page;

use v5.24;
use utf8;
use Moo;

use Type::Utils;

use namespace::clean;

extends 'Yukki::Web::View';

with 'Yukki::Web::View::Role::Navigation';

# ABSTRACT: render HTML for viewing and editing wiki pages

=head1 DESCRIPTION

Renders wiki pages.

=cut

has blank_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
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
    isa         => class_type('Template::Pure'),
    lazy        => 1,
    builder     => '_build_view_template',
);

sub _build_view_template {
    shift->prepare_template(
        template   => 'page/view.html',
        directives => [
            '#yukkitext' => 'html | encoded_string',
            '#revision'  => 'revision',
            '#file_date' => 'file_date',
        ],
    );
}

has history_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
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
                    '.first-revision input@value'  => 'rev.file.object_id',
                    '.second-revision input@value' => 'rev.file.object_id',
                    '.date a'                        => 'rev.file.time_ago',
                    '.date a@href'                 => '={rev.page_url}',
                    '.author'                      => 'rev.file.author_name',
                    '.diffstat'                    => '+={rev.file.lines_added}/-={rev.file.lines_removed}',
                    '.comment'                     => 'rev.file.comment | default("(no comment)")',
                ],
            },
            sub {
                my ($t, $dom, $data) = @_;
                $dom->at('.revision:nth-child(2) .first-revision input')->attr(checked => 1);
                $dom->at('.revision:nth-child(1) .second-revision input')->attr(checked => 1);
            },
        ],
    );
}

has diff_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
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
    isa         => class_type('Template::Pure'),
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

has rename_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
    lazy        => 1,
    builder     => '_build_rename_template',
);

sub _build_rename_template {
    shift->prepare_template(
        template   => 'page/rename.html',
        directives => [
            '#yukkiname'           => 'page',
            '#yukkiname_new@value' => 'page',
        ],
    );
}

has remove_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
    lazy        => 1,
    builder     => '_build_remove_template',
);

sub _build_remove_template {
    shift->prepare_template(
        template   => 'page/remove.html',
        directives => [
            '.yukkiname'          => 'page',
            '#cancel_remove@href' => 'return_link',
        ],
    );
}

has attachments_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
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

=head2 standard_menu

The standard navigation menu for pages.

=cut

sub standard_menu {
    return map {
        +{
            action => $_,
            href   => "page/$_/%{repository}s/%{page}s",
        },
    } qw( edit history rename remove );
}

=head2 page_navigation

Modifies page navigation to add custom page views to the menu.

=cut

after page_navigation => sub {
    my ($self, $response, $this_action, $vars) = @_;

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
};

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

    $ctx->add_info("This is a historical version of this page")
        if $file->revision ne 'HEAD'
           and $file->find_path($file->full_path)
                ne $file->object_id;

    my $rev8 = $file->revision;
    $rev8 = substr $rev8, 0, 8 if $file->revision ne 'HEAD';

    return $self->render_page(
        template => $self->view_template,
        context  => $ctx,
        vars     => {
            'html'      => $html,
            'revision'  => $rev8,
            'file_date' => $file->file_date('relative'),
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
        template => $self->history_template,
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
        template => $self->rename_template,
        context  => $ctx,
        vars     => {
            page => $vars->{page},
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

    return $self->render_confirmation(
        context   => $ctx,
        title     => "Remove $vars->{page}?",
        question  => "Are you sure that you wish to remove $vars->{page} from the repository?",
        yes_label => 'Remove Now',
        no_link   => $vars->{return_link},
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

1;
