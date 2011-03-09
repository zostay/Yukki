package Yukki::Web::Controller::Page;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Controller';

use HTTP::Throwable::Factory qw( http_throw );

sub fire {
    my ($self, $req) = @_;

    # TODO Check access...
    warn "TODO CHECK ACCESS\n";

    my $response;
    given ($req->path_parameters->{action}) {
        when ('view') { $response = $self->view_page($req) }
        when ('edit') { $response = $self->edit_page($req) }
        default {
            http_throw('InternalServerError', { 
                show_stack_trace => 0,
                message          => 'Not yet implemented.',
            });
        }
    }

    return $response->finalize;
}

sub view_page {
    my ($self, $req) = @_;

    my $repository = $req->path_parameters->{repository};
    my $page       = $req->path_parameters->{page};

    my $content = $self->model('Page')->load($repository, $page);

    my $body;
    if (not defined $content) {
        $body = $self->view('Page')->blank($req, { repository => $repository, page => $page });
    }

    else {
        $body = $self->view('Page')->view($req, { content => $content });
    }

    my $res = $req->new_response(200);
    $res->content_type('text/html');
    $res->body($body);

    return $res;
}

sub edit_page {
    my ($self, $req) = @_;

    my $repository = $req->path_parameters->{repository};
    my $page       = $req->path_parameters->{page};

    if ($req->method eq 'POST') {
        my $new_content = $req->parameters->{yukkitext};
        my $comment     = $req->parameters->{comment};

        $self->model('Page')->save($repository, $page, {
            content => $new_content,
            comment => $comment,
        });

        my $response = $req->new_response;
        $response->redirect(join '/', '/page/view', $repository, $page);
        return $response;
    }

    my $content = $self->model('Page')->load($repository, $page);

    my $res = $req->new_response(200);
    $res->content_type('text/html');
    $res->body( $self->view('Page')->edit($req, { page => $page, content => $content }) );

    return $res;
}

1;
