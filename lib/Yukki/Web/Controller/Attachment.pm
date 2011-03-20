package Yukki::Web::Controller::Attachment;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Controller';

use JSON;
use HTTP::Throwable::Factory qw( http_throw );

sub fire {
    my ($self, $ctx) = @_;

    given ($ctx->request->path_parameters->{action}) {
        when ('download') { $self->download_file($ctx) }
        when ('upload')   { $self->upload_file($ctx) }
        when ('view')     { $self->view_file($ctx) }
        default {
            http_throw('NotFound');
        }
    }
}

sub lookup_file {
    my ($self, $repo_name, $file) = @_;

    my $repository = $self->model('Repository', { name => $repo_name });

    my $final_part = pop @$file;
    my $filetype;
    if ($final_part =~ s/\.(?<filetype>[a-z0-9]+)$//) {
        $filetype = $+{filetype};
    }

    my $path = join '/', @$file, $final_part;
    return $repository->file({ path => $path, filetype => $filetype });
}

sub download_file {
    my ($self, $ctx) = @_;

    my $repo_name = $ctx->request->path_parameters->{repository};
    my $path      = $ctx->request->path_parameters->{file};

    my $file      = $self->lookup_file($repo_name, $path);

    $ctx->response->content_type('application/octet');
    $ctx->response->body([ scalar $file->fetch ]);
}

sub view_file {
    my ($self, $ctx) = @_;

    my $repo_name = $ctx->request->path_parameters->{repository};
    my $path      = $ctx->request->path_parameters->{file};

    my $file      = $self->lookup_file($repo_name, $path);

    $ctx->response->content_type($file->media_type);
    $ctx->response->body([ scalar $file->fetch ]);
}

sub upload_file {
    my ($self, $ctx) = @_;

    my $repo_name = $ctx->request->path_parameters->{repository};
    my $path      = $ctx->request->path_parameters->{file};

    my $file      = $self->lookup_file($repo_name, $path);
    
    my $upload = $ctx->request->uploads->{file};
    $file->store({
        filename => $upload->tempname,
        comment  => 'Uploading file ' . $upload->filename,
    });

    $ctx->response->content_type('application/json');
    $ctx->response->body(
        encode_json({
            viewable        => 1,
            repository_path => join('/', $repo_name, $file->full_path),
        })
    );
}

1;
