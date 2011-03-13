package Yukki::Web::Controller::Page;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Controller';

use HTTP::Throwable::Factory qw( http_throw );

sub fire {
    my ($self, $ctx) = @_;

    # TODO Check access...
    warn "TODO CHECK ACCESS\n";

    given ($ctx->request->path_parameters->{action}) {
        when ('view') { $self->view_page($ctx) }
        when ('edit') { $self->edit_page($ctx) }
        default {
            http_throw('InternalServerError', { 
                show_stack_trace => 0,
                message          => 'Not yet implemented.',
            });
        }
    }
}

sub lookup_page {
    my ($self, $repo_name, $page) = @_;

    my $repository = $self->model('Repository', { name => $repo_name });

    my $final_part = shift @$page;
    my $filetype;
    if ($final_part =~ s/\.(?<filetype>[a-z0-9]+)$//) {
        $filetype = $+{filetype};
    }

    my $path = join '/', @$page, $final_part;
    return $repository->page({ path => $path, filetype => $filetype });
}

sub view_page {
    my ($self, $ctx) = @_;

    my $repo_name  = $ctx->request->path_parameters->{repository};
    my $path       = $ctx->request->path_parameters->{page};

    my $page    = $self->lookup_page($repo_name, $path);
    my $content = $page->fetch;

    my $body;
    if (not defined $content) {
        $body = $self->view('Page')->blank($ctx, { repository => $repo_name, page => $page->path });
    }

    else {
        $body = $self->view('Page')->view($ctx, { 
            repository => $repo_name,
            page       => $page->path, 
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

        $ctx->response->redirect(join '/', '/page/view', $repo_name, $page->path);
        return;
    }

    my $content = $page->fetch;

    $ctx->response->body( 
        $self->view('Page')->edit($ctx, { 
            repository => $repo_name,
            page       => $page->path, 
            content    => $content 
        }) 
    );
}

1;
