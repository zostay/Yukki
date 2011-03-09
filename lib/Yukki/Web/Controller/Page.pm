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

sub view_page {
    my ($self, $ctx) = @_;

    my $repository = $ctx->request->path_parameters->{repository};
    my $page       = $ctx->request->path_parameters->{page};

    my $content = $self->model('Page')->load($repository, $page);

    my $body;
    if (not defined $content) {
        $body = $self->view('Page')->blank($ctx, { repository => $repository, page => $page });
    }

    else {
        $body = $self->view('Page')->view($ctx, { content => $content });
    }

    $ctx->response->body($body);
}

sub edit_page {
    my ($self, $ctx) = @_;

    my $repository = $ctx->request->path_parameters->{repository};
    my $page       = $ctx->request->path_parameters->{page};

    if ($ctx->request->method eq 'POST') {
        my $new_content = $ctx->request->parameters->{yukkitext};
        my $comment     = $ctx->request->parameters->{comment};

        $self->model('Page')->save($repository, $page, {
            content => $new_content,
            comment => $comment,
        });

        $ctx->response->redirect(join '/', '/page/view', $repository, $page);
        return;
    }

    my $content = $self->model('Page')->load($repository, $page);

    $ctx->response->body( 
        $self->view('Page')->edit($ctx, { 
            page    => $page, 
            content => $content 
        }) 
    );
}

1;
