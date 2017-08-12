package Yukki::Web::Controller::Page;

use v5.24;
use utf8;
use Moo;

with 'Yukki::Web::Controller';

use FormValidator::Tiny qw( :all );
use Try::Tiny;
use Types::Standard qw( Int );
use Yukki::Error qw( http_throw );

use namespace::clean;

# ABSTRACT: controller for viewing and editing pages

=head1 DESCRIPTION

Controller for viewing and editing pages

=head1 METHODS

=head2 fire

On a view request routes to L</view_page>, edit request to L</edit_page>, preview request to L</preview_page>, and attach request to L</upload_attachment>.

=cut

sub fire {
    my ($self, $ctx) = @_;

    my $action = $ctx->request->path_parameters->{action};
    if    ($action eq 'view')    { $self->view_page($ctx) }
    elsif ($action eq 'edit')    { $self->edit_page($ctx) }
    elsif ($action eq 'history') { $self->view_history($ctx) }
    elsif ($action eq 'diff')    { $self->view_diff($ctx) }
    elsif ($action eq 'preview') { $self->preview_page($ctx) }
    elsif ($action eq 'attach')  { $self->upload_attachment($ctx) }
    elsif ($action eq 'rename')  { $self->rename_page($ctx) }
    elsif ($action eq 'remove')  { $self->remove_page($ctx) }
    else {
        http_throw('That page action does not exist.', {
            status => 'NotFound',
        });
    }
}

=head2 repo_name_and_path

This is a helper for looking up the repository name and path for the request.

=cut

sub repo_name_and_path {
    my ($self, $ctx) = @_;

    my $repo_name  = $ctx->request->path_parameters->{repository};
    my $path       = $ctx->request->path_parameters->{page};

    if (not defined $path) {
        my $repo = $self->model('Root')->repository($repo_name);
        my $repo_config = $repo->repository_settings;

        my $path_str = $repo_config->default_page;

        $path = [ split m{/}, $path_str ];
    }

    return ($repo_name, $path);
}

=head2 lookup_page

Given a repository name and page, returns a L<Yukki::Model::File> for it.

=cut

sub lookup_page {
    my ($self, $repo_name, $page, $r) = @_;
    $r ||= 'HEAD';

    my $repository = $self->model('Repository', { name => $repo_name });

    my $final_part = pop @$page;
    my $filetype;
    if ($final_part =~ s/\.(?<filetype>[a-z0-9]+)$//) {
        $filetype = $+{filetype};
    }

    my $path = join '/', @$page, $final_part;
    return $repository->file({ path => $path, filetype => $filetype, revision => $r });
}

=head2 view_page

Tells either L<Yukki::Web::View::Page/blank> or L<Yukki::Web::View::Page/view>
to show the page.

=cut

sub view_page {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $r    = $ctx->request->query_parameters->{r};
    my $page = $self->lookup_page($repo_name, $path, $r);

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    my $body;
    if (not $page->exists) {
        my @files = $page->list_files;

        $body = $self->view('Page')->blank($ctx, {
            title      => $page->file_name,
            breadcrumb => $breadcrumb,
            repository => $repo_name,
            page       => $page->full_path,
            files      => \@files,
        });
    }

    else {
        $body = $self->view('Page')->view($ctx, {
            title      => $page->title,
            breadcrumb => $breadcrumb,
            repository => $repo_name,
            page       => $page->full_path,
            file       => $page,
        });
    }

    $ctx->response->body($body);
}

=head2 edit_page

Displays or processes the edit form for a page using.

=cut

validation_spec edit_page => [
    yukkitext => [
        trim => 0,
        required => 1,
    ],
    yukkitext_position => [
        optional => 1,
        must => Int,
        into => '+',
    ],
    comment => [
        optional => 1,
    ],
];

sub edit_page {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $page = $self->lookup_page($repo_name, $path);

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    my ($p, $err);
    if ($ctx->request->method eq 'POST') {
        ($p, $err) = validate_form edit_page => $ctx->request->body_parameters;

        if (!$err) {
            my $new_content = $p->{yukkitext};
            my $position    = $p->{yukkitext_position} // 0;
            my $comment     = $p->{comment};

            if (my $user = $ctx->session->{user}) {
                $page->author_name($user->{name});
                $page->author_email($user->{email});
            }

            $page->store({
                content => $new_content,
                comment => $comment,
            });

            $ctx->response->redirect(join '/', '/page/edit', $repo_name, $page->full_path, '?yukkitext_position='.$position);
            return;
        }

        else {
            my @errors;
            push @errors, "comment is required"
                if $err->{comment};
            push @errors, "please try again"
                if $err->{yukkitext_position};
            push @errors, "wiki content is required"
                if $err->{yukkitext};

            $ctx->add_errors(@errors);
        }
    }

    my @attachments = grep { $_->filetype ne 'yukki' } $page->list_files;
    my $position = $ctx->request->parameters->{yukkitext_position} // -1;

    $ctx->response->body(
        $self->view('Page')->edit($ctx, {
            title       => $page->title,
            breadcrumb  => $breadcrumb,
            repository  => $repo_name,
            page        => $page->full_path,
            position    => $position,
            file        => $page,
            attachments => \@attachments,
        })
    );
}

=head2 rename_page

Displays the rename page form.

=cut

sub rename_page {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $page = $self->lookup_page($repo_name, $path);

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    if ($ctx->request->method eq 'POST') {
        my $new_name = $ctx->request->parameters->{yukkiname_new};

        my $part = qr{[_a-z0-9-.]+(?:\.[_a-z0-9-]+)*}i;
        if ($new_name =~ m{^$part(?:/$part)*$}) {

            if (my $user = $ctx->session->{user}) {
                $page->author_name($user->{name});
                $page->author_email($user->{email});
            }

            $page->rename({
                full_path => $new_name,
                comment   => 'Renamed ' . $page->full_path . ' to ' . $new_name,
            });

            $ctx->response->redirect(join '/', '/page/edit', $repo_name, $new_name);
            return;

        }
        else {
            $ctx->add_errors('the new name must contain only letters, numbers, underscores, dashes, periods, and slashes');
        }
    }

    $ctx->response->body(
        $self->view('Page')->rename($ctx, {
            title       => $page->title,
            breadcrumb  => $breadcrumb,
            repository  => $repo_name,
            page        => $page->full_path,
            file        => $page,
        })
    );
}

=head2 remove_page

Displays the remove confirmation.

=cut

sub remove_page {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $page = $self->lookup_page($repo_name, $path);

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    my $confirmed = $ctx->request->body_parameters->{confirmed};
    if ($ctx->request->method eq 'POST' and $confirmed) {
        my $return_to = $page->parent // $page->repository->default_file;
        if ($return_to->full_path ne $page->full_path) {
            if (my $user = $ctx->session->{user}) {
                $page->author_name($user->{name});
                $page->author_email($user->{email});
            }

            $page->remove({
                comment   => 'Removing ' . $page->full_path . ' from repository.',
            });

            $ctx->response->redirect(join '/', '/page/view', $repo_name, $return_to->full_path);
            return;

        }

        else {
            $ctx->add_errors('you may not remove the top-most page of a repository');
        }
    }

    $ctx->response->body(
        $self->view('Page')->remove($ctx, {
            title       => $page->title,
            breadcrumb  => $breadcrumb,
            repository  => $repo_name,
            page        => $page->full_path,
            file        => $page,
            return_link => join('/', '/page/view', $repo_name, $page->full_path),
        })
    );
}

=head2 view_history

Displays the page's revision history.

=cut

sub view_history {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $page = $self->lookup_page($repo_name, $path);

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    my $page_url = $ctx->rebase_url(
        join('/', 'page/view', $repo_name, $page->full_path),
    );

    $ctx->response->body(
        $self->view('Page')->history($ctx, {
            title      => $page->title,
            breadcrumb => $breadcrumb,
            repository => $repo_name,
            page       => $page->full_path,
            revisions  => [ map {
                +{
                    page_url => "$page_url?r=".$_->{object_id},
                    file     => $_,
                }
            } $page->history ],
        })
    );
}

=head2 view_diff

Displays a diff of the page.

=cut

sub view_diff {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $page = $self->lookup_page($repo_name, $path);

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    my $r1 = $ctx->request->query_parameters->{r1};
    my $r2 = $ctx->request->query_parameters->{r2};

    try {

        my $diff = '';
        for my $chunk ($page->diff($r1, $r2)) {
            if    ($chunk->[0] eq ' ') { $diff .= $chunk->[1] }
            elsif ($chunk->[0] eq '+') { $diff .= sprintf '<ins markdown="1">%s</ins>', $chunk->[1] }
            elsif ($chunk->[0] eq '-') { $diff .= sprintf '<del markdown="1">%s</del>', $chunk->[1] }
            else { warn "unknown chunk type $chunk->[0]" }
        }

        my $file_preview = $page->file_preview(
            content => $diff,
        );

        $ctx->response->body(
            $self->view('Page')->diff($ctx, {
                title      => $page->title,
                breadcrumb => $breadcrumb,
                repository => $repo_name,
                page       => $page->full_path,
                file       => $file_preview,
            })
        );
    }

    catch {
        my $ERROR = $_;
        if ("$_" =~ /usage: git diff/) {
            http_throw 'Diffs will not work with git versions before 1.7.2. Please use a newer version of git. If you are using a newer version of git, please file a support issue.';
        }
        die $ERROR;
    };
}

=head2 preview_page

Shows the preview for an edit to a page using L<Yukki::Web::View::Page/preview>..

=cut

sub preview_page {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $page = $self->lookup_page($repo_name, $path);

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    my $content      = $ctx->request->body_parameters->{yukkitext};
    my $position     = $ctx->request->parameters->{yukkitext_position};
    my $file_preview = $page->file_preview(
        content  => $content,
        position => $position,
    );

    $ctx->response->body(
        $self->view('Page')->preview($ctx, {
            title      => $page->title,
            breadcrumb => $breadcrumb,
            repository => $repo_name,
            page       => $page->full_path,
            file       => $file_preview,
        })
    );
}

=head2 upload_attachment

This is a facade that wraps L<Yukki::Web::Controller::Attachment/upload>.

=cut

sub upload_attachment {
    my ($self, $ctx) = @_;

    my $repo_name = $ctx->request->path_parameters->{repository};
    my $path      = delete $ctx->request->path_parameters->{page};

    my $page = $self->lookup_page($repo_name, $path);

    my @file = split m{/}, $page->path;
    push @file, $ctx->request->uploads->{file}->filename;

    $ctx->request->path_parameters->{action} = 'upload';
    $ctx->request->path_parameters->{file}   = \@file;

    $self->controller('Attachment')->fire($ctx);
}

=head2 breadcrumb

Given the repository and path, returns the breadcrumb.

=cut

sub breadcrumb {
    my ($self, $repository, $path_parts) = @_;

    my @breadcrumb;
    my @path_acc;

    push @breadcrumb, {
        label => $repository->title,
        href  => join('/', '/page/view/', $repository->name),
    };

    for my $path_part (@$path_parts) {
        push @path_acc, $path_part;
        my $file = $repository->file({
            path     => join('/', @path_acc),
            filetype => 'yukki',
        });

        push @breadcrumb, {
            label => $file->title,
            href  => join('/', '/page/view', $repository->name, $file->full_path),
        };
    }

    return \@breadcrumb;
}

1;
