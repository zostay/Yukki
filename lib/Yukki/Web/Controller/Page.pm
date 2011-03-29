package Yukki::Web::Controller::Page;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Controller';

use HTTP::Throwable::Factory qw( http_throw );

# ABSTRACT: controller for viewing and editing pages

=head1 DESCRIPTION

Controller for viewing and editing pages

=head1 METHODS

=head2 fire

On a view request routes to L</view_page>, edit request to L</edit_page>, preview request to L</preview_page>, and attach request to L</upload_attachment>.

=cut

sub fire {
    my ($self, $ctx) = @_;

    given ($ctx->request->path_parameters->{action}) {
        when ('view')    { $self->view_page($ctx) }
        when ('edit')    { $self->edit_page($ctx) }
        when ('preview') { $self->preview_page($ctx) }
        when ('attach')  { $self->upload_attachment($ctx) }
        default {
            http_throw('NotFound');
        }
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
        my $repo_config 
            = $self->app->settings->repositories->{$repo_name};

        my $path_str = $repo_config->default_page;

        $path = [ split m{/}, $path_str ];
    }

    return ($repo_name, $path);
}

=head2 lookup_page

Given a repository name and page, returns a L<Yukki::Model::File> for it.

=cut

sub lookup_page {
    my ($self, $repo_name, $page) = @_;

    my $repository = $self->model('Repository', { name => $repo_name });

    my $final_part = pop @$page;
    my $filetype;
    if ($final_part =~ s/\.(?<filetype>[a-z0-9]+)$//) {
        $filetype = $+{filetype};
    }

    my $path = join '/', @$page, $final_part;
    return $repository->file({ path => $path, filetype => $filetype });
}

=head2 view_page

Tells either L<Yukki::Web::View::Page/blank> or L<Yukki::Web::View::Page/view>
to show the page.

=cut

sub view_page {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $page    = $self->lookup_page($repo_name, $path);
    my $content = $page->fetch;

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    my $body;
    if (not defined $content) {
        $body = $self->view('Page')->blank($ctx, { 
            title      => $page->file_name,
            breadcrumb => $breadcrumb,
            repository => $repo_name, 
            page       => $page->full_path,
        });
    }

    else {
        $body = $self->view('Page')->view($ctx, { 
            title      => $page->title,
            breadcrumb => $breadcrumb,
            repository => $repo_name,
            page       => $page->full_path, 
            content    => $content,
        });
    }

    $ctx->response->body($body);
}

=head2 edit_page

Displays or processes the edit form for a page using.

=cut

sub edit_page {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $page = $self->lookup_page($repo_name, $path);

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    if ($ctx->request->method eq 'POST') {
        my $new_content = $ctx->request->parameters->{yukkitext};
        my $comment     = $ctx->request->parameters->{comment};

        if (my $user = $ctx->session->{user}) {
            $page->author_name($user->{name});
            $page->author_email($user->{email});
        }

        $page->store({ 
            content => $new_content,
            comment => $comment,
        });

        $ctx->response->redirect(join '/', '/page/edit', $repo_name, $page->full_path);
        return;
    }

    my $content = $page->fetch;

    my @attachments = grep { $_->filetype ne 'yukki' } $page->list_files($page->path);

    $ctx->response->body( 
        $self->view('Page')->edit($ctx, { 
            title       => $page->title,
            breadcrumb  => $breadcrumb,
            repository  => $repo_name,
            page        => $page->full_path, 
            content     => $content,
            attachments => \@attachments,
        }) 
    );
}

=head2 preview_page

Shows the preview for an edit to a page using L<Yukki::Web::View::Page/preview>..

=cut

sub preview_page {
    my ($self, $ctx) = @_;

    my ($repo_name, $path) = $self->repo_name_and_path($ctx);

    my $page = $self->lookup_page($repo_name, $path);

    my $breadcrumb = $self->breadcrumb($page->repository, $path);

    my $content = $ctx->request->body_parameters->{yukkitext};

    $ctx->response->body(
        $self->view('Page')->preview($ctx, { 
            title      => $page->title,
            breadcrumb => $breadcrumb,
            repository => $repo_name,
            page       => $page->full_path,
            content    => $content,
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
