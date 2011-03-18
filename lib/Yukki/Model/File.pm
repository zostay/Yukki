package Yukki::Model::File;
use 5.12.1;
use Moose;

extends 'Yukki::Model';

use Number::Bytes::Human qw( format_bytes );
use LWP::MediaTypes qw( guess_media_type );

has path => (
    is         => 'ro',
    isa        => 'Str',
    required   => 1,
);

has filetype => (
    is         => 'ro',
    isa        => 'Maybe[Str]',
    required   => 1,
    default    => 'yukki',
);

has repository => (
    is         => 'ro',
    isa        => 'Yukki::Model::Repository',
    required   => 1,
    handles    => {
        'make_blob'           => 'make_blob',
        'make_blob_from_file' => 'make_blog_from_file',
        'find_root'           => 'find_root',
        'branch '             => 'branch',
        'show'                => 'show',
        'make_tree'           => 'make_tree',
        'commit_tree'         => 'commit_tree',
        'update_root'         => 'update_root',
        'find_path'           => 'find_path',
        'list_files'          => 'list_files',
        'fetch_size'          => 'fetch_size',
        'repository_name'     => 'name',
    },
);

sub full_path {
    my $self = shift;

    my $full_path;
    given ($self->filetype) {
        when (defined) { $full_path = join '.', $self->path, $self->filetype }
        default        { $full_path = $self->path }
    }

    return $full_path;
}

sub file_name {
    my $self = shift;
    my $full_path = $self->full_path;
    my ($file_name) = $full_path =~ m{([^/]+)$};
    return $file_name;
}

sub object_id {
    my $self = shift;
    return $self->find_path($self->full_path);
}

sub file_size {
    my $self = shift;
    return $self->fetch_size($self->full_path);
}

sub formatted_file_size {
    my $self = shift;
    return format_bytes($self->file_size);
}

sub media_type {
    my $self = shift;
    return guess_media_type($self->full_path);
}

sub store {
    my ($self, $params) = @_;
    my $path = $self->full_path;

    my (@parts) = split m{/}, $path;
    my $blob_name = $parts[-1];

    my $object_id;
    if ($params->{content}) {
        $object_id = $self->make_blob($blob_name, $params->{content});
    }
    elsif ($params->{filename}) {
        $object_id = $self->make_blob_from_file($blob_name, $params->{filename});
    }
    Yukki::Error->throw("unable to create blob for $path") unless $object_id;

    my $old_tree_id = $self->find_root;
    Yukki::Error->throw("unable to locate original tree ID for ".$self->branch)
        unless $old_tree_id;

    my $new_tree_id = $self->make_tree($old_tree_id, \@parts, $object_id);
    Yukki::Error->throw("unable to create the new tree containing $path\n")
        unless $new_tree_id;

    my $commit_id = $self->commit_tree($old_tree_id, $new_tree_id, $params->{comment});
    Yukki::Error->throw("unable to commit the new tree containing $path\n")
        unless $commit_id;

    $self->update_root($old_tree_id, $commit_id);
}

sub exists {
    my $self = shift;

    my $path = $self->full_path;
    return $self->find_path($path);
}

sub fetch {
    my $self = shift;

    my $path = $self->full_path;
    my $object_id = $self->find_path($path);

    return unless defined $object_id;

    return $self->show($object_id);
}

1;
