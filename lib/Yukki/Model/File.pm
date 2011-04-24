package Yukki::Model::File;
use 5.12.1;
use Moose;

extends 'Yukki::Model';

use Digest::SHA1 qw( sha1_hex );
use Number::Bytes::Human qw( format_bytes );
use LWP::MediaTypes qw( guess_media_type );
use Path::Class;

# ABSTRACT: the model for loading and saving files in the wiki

=head1 SYNOPSIS

  my $repository = $app->model('Repository', { repository => 'main' });
  my $file = $repository->file({
      path     => 'foobar',
      filetype => 'yukki',
  });

=head1 DESCRIPTION

Tools for fetching files from the git repository and storing them there.

=head1 EXTENDS

L<Yukki::Model>

=head1 ATTRIBUTES

=head2 path

This is the path to the file in the repository, but without the file suffix.

=cut

has path => (
    is         => 'ro',
    isa        => 'Str',
    required   => 1,
);

=head2 filetype

The suffix of the file. Defaults to "yukki".

=cut

has filetype => (
    is         => 'ro',
    isa        => 'Maybe[Str]',
    required   => 1,
    default    => 'yukki',
);

=head2 repository

This is the the L<Yukki::Model::Repository> the file will be fetched from or
stored into.

=cut

has repository => (
    is         => 'ro',
    isa        => 'Yukki::Model::Repository',
    required   => 1,
    handles    => {
        'make_blob'           => 'make_blob',
        'make_blob_from_file' => 'make_blob_from_file',
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
        'author_name'         => 'author_name',
        'author_email'        => 'author_email',
        'log'                 => 'log',
        'diff_blobs'          => 'diff_blobs',
    },
);

=head1 METHODS

=head2 BUILDARGS

Allows C<full_path> to be given instead of C<path> and C<filetype>.

=cut

sub BUILDARGS {
    my $class = shift;

    my %args;
    if (@_ == 1) { %args = %{ $_[0] }; }
    else         { %args = @_; }

    if ($args{full_path}) {
        my $full_path = delete $args{full_path};

        my ($path, $filetype) = $full_path =~ m{^(.*)(?:\.(\w+))?$};

        $args{path}     = $path;
        $args{filetype} = $filetype;
    }

    return \%args;
}

=head2 full_path

This is the complete path to the file in the repository with the L</filetype>
tacked onto the end.

=cut

sub full_path {
    my $self = shift;

    my $full_path;
    given ($self->filetype) {
        when (defined) { $full_path = join '.', $self->path, $self->filetype }
        default        { $full_path = $self->path }
    }

    return $full_path;
}

=head2 file_name

This is the base name of the file.

=cut

sub file_name {
    my $self = shift;
    my $full_path = $self->full_path;
    my ($file_name) = $full_path =~ m{([^/]+)$};
    return $file_name;
}

=head2 file_id

This is a SHA-1 of the file name in hex.

=cut

sub file_id {
    my $self = shift;
    return sha1_hex($self->file_name);
}

=head2 object_id

This is the git object ID of the file blob.

=cut

sub object_id {
    my $self = shift;
    return $self->find_path($self->full_path);
}

=head2 title

This is the title for the file. For most files this is the file name. For files with the "yukki" L</filetype>, the title metadata or first heading found in the file is used.

=cut

sub title {
    my $self = shift;

    if ($self->filetype eq 'yukki') {
        LINE: for my $line ($self->fetch) {
            if ($line =~ /:/) {
                my ($name, $value) = split m{\s*:\s*}, $line, 2;
                return $value if lc($name) eq 'title';
            }
            elsif ($line =~ /^#\s*(.*)$/) {
                return $1;
            }
            else {
                last LINE;
            }
        }
    }

    my $title = $self->file_name;
    $title =~ s/\.(\w+)$//g;
    return $title;
}

=head2 file_size

This is the size of the file in bytes.

=cut

sub file_size {
    my $self = shift;
    return $self->fetch_size($self->full_path);
}

=head2 formatted_file_size

This returns a human-readable version of the file size.

=cut

sub formatted_file_size {
    my $self = shift;
    return format_bytes($self->file_size);
}

=head2 media_type

This is the MIME type detected for the file.

=cut

sub media_type {
    my $self = shift;
    return guess_media_type($self->full_path);
}

=head2 store

  $file->store({ 
      content => 'text to put in file...', 
      comment => 'comment describing the change',
  });

  # OR
  
  $file->store({
      filename => 'file.pdf',
      comment  => 'comment describing the change',
  });

This stores a new version of the file, either from the given content string or a
named local file.

=cut

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

=head2 exists

Returns true if the file exists in the repository already.

=cut

sub exists {
    my $self = shift;

    my $path = $self->full_path;
    return $self->find_path($path);
}

=head2 fetch

  my $content = $self->fetch;
  my @lines   = $self->fetch;

Returns the contents of the file.

=cut

sub fetch {
    my $self = shift;

    my $path = $self->full_path;
    my $object_id = $self->find_path($path);

    return unless defined $object_id;

    return $self->show($object_id);
}

=head2 has_format

  my $yes_or_no = $self->has_format($media_type);

Returns true if the named media type has a format plugin.

=cut

sub has_format {
    my ($self, $media_type) = @_;

    my @formatters = $self->app->formatter_plugins;
    for my $formatter (@formatters) {
        return 1 if $formatter->has_format($media_type);
    }

    return '';
}

=head2 fetch_formatted

  my $html_content = $self->fetch_formatted($ctx);

Returns the contents of the file. If there are any configured formatter plugins for the media type of the file, those will be used to return the file.

=cut

sub fetch_formatted {
    my ($self, $ctx) = @_;

    my $media_type = $self->media_type;

    my $formatter;
    for my $plugin ($self->app->formatter_plugins) {
        return $plugin->format({
            context    => $ctx,
            file       => $self,
        }) if $plugin->has_format($media_type);
    }

    return $self->fetch;
}

=head2 history

  my @revisions = $self->history;

Returns a list of revisions. Each revision is a hash with the following keys:

=over

=item object_id

The object ID of the commit.

=item author_name

The name of the commti author.

=item date

The date the commit was made.

=item time_ago

A string showing how long ago the edit took place.

=item comment

The comment the author made about the comment.

=item lines_added

Number of lines added.

=item lines_removed

Number of lines removed.

=back

=cut

sub history {
    my $self = shift;
    return $self->log($self->full_path);
}

=head2 diff

  my @chunks = $self->diff('a939fe...', 'b7763d...');

Given two object IDs, returns a list of chunks showing the difference between two revisions of this path. Each chunk is a two element array. The first element is the type of chunk and the second is any detail for that chunk.

The types are:

    "+"    This chunk was added to the second revision.
    "-"    This chunk was removed in the second revision.
    " "    This chunk is the same in both revisions.
=cut

sub diff {
    my ($self, $object_id_1, $object_id_2) = @_;
    return $self->diff_blobs($self->full_path, $object_id_1, $object_id_2);
}

=head2 file_preview

  my $file_preview = $self->file_preview(
      content => $content,
  );

Takes this file and returns a L<Yukki::Model::FilePreview> object, with the file contents "replaced" by the given content.

=cut

sub file_preview {
    my ($self, %params) = @_;

    Class::MOP::load_class('Yukki::Model::FilePreview');
    return Yukki::Model::FilePreview->new(
        %params,
        app        => $self->app,
        repository => $self->repository,
        path       => $self->path,
    );
}

1;
