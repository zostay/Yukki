package Yukki::Web::Controller::Page;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Controller';

use HTTP::Throwable::Factory qw( http_throw );

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

sub view_page {
    my ($self, $ctx) = @_;

    my $repo_name  = $ctx->request->path_parameters->{repository};
    my $path       = $ctx->request->path_parameters->{page};

    my $page    = $self->lookup_page($repo_name, $path);
    my $content = $page->fetch;

    my $body;
    if (not defined $content) {
        $body = $self->view('Page')->blank($ctx, { 
            repository => $repo_name, 
            page       => $page->full_path,
        });
    }

    else {
        $body = $self->view('Page')->view($ctx, { 
            title      => $page->title,
            repository => $repo_name,
            page       => $page->full_path, 
            content    => $content,
        });
    }

    $ctx->response->body($body);
}

sub edit_page {
    my ($self, $ctx) = @_;

    my $repo_name = $ctx->request->path_parameters->{repository};
    my $path      = $ctx->request->path_parameters->{page};

    my $page = $self->lookup_page($repo_name, $path);

    if ($ctx->request->method eq 'POST') {
        my $new_content = $ctx->request->parameters->{yukkitext};
        my $comment     = $ctx->request->parameters->{comment};

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
            repository  => $repo_name,
            page        => $page->full_path, 
            content     => $content,
            attachments => \@attachments,
        }) 
    );
}

sub preview_page {
    my ($self, $ctx) = @_;

    my $repo_name = $ctx->request->path_parameters->{repository};
    my $path      = $ctx->request->path_parameters->{page};

    my $page = $self->lookup_page($repo_name, $path);

    my $content = $ctx->request->body_parameters->{yukkitext};

    $ctx->response->body(
        $self->view('Page')->preview($ctx, { 
            title      => $page->title,
            repository => $repo_name,
            page       => $page->full_path,
            content    => $content,
        })
    );
}

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

1;
