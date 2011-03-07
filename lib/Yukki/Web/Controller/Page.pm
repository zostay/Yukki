package Yukki::Web::Controller::Page;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Controller';

use Git::Repository;
use HTTP::Throwable::Factory qw( http_throw );

sub fire {
    my ($self, $req) = @_;

    # TODO Check access...
    warn "TODO CHECK ACCESS\n";

    my $response;
    given ($req->path_parameters->{action}) {
        when ('view') { $response = $self->view_page($req) }
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
    my $page       = join '.', $req->path_parameters->{page}, 'mkd';

    my $repo_settings = $self->app->settings->{repositories}{$repository};
    http_throw('NotFound') if not defined $repo_settings;

    my $repo_dir = $self->locate('repository_path', $repo_settings->{repository});
    my $git = Git::Repository->new( git_dir => $repo_dir );

    my $object_id;
    my @files = $git->run('ls-tree', 'refs/heads/master', $page);
    FILE: for my $line (@files) {
        my ($mode, $type, $id, $name) = split /\s+/, $line;

        if ($name eq $page) {
            $object_id = $id;
            last FILE;
        }
    }

    my $content = $git->run('show', $object_id);

    my $res = $req->new_response(200);
    $res->content_type('text/html');
    $res->body( $self->view('Page')->view($req, { content => $content }) );

    return $res;
}

1;
