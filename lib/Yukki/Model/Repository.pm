package Yukki::Model::Repository;
use Moose;

extends 'Yukki::Model';

use Yukki::Model::File;

use Git::Repository;
use MooseX::Types::Path::Class;

# ABSTRACT: model for accessing objects in a git repository

=head1 SYNOPSIS

  my $repository = $app->model('Repository', { name => 'main' });
  my $file = $repository->file({ path => 'foo.yukki' });

=head1 DESCRIPTION

This model contains methods for performing all the individual operations
required to store files into and fetch files from the git repository. It
includes tools for building trees, commiting, creating blobs, fetching file
lists, etc.

=head1 EXTENDS

L<Yukki::Model>

=head1 ATTRIBUTES

=head2 name

This is the name of the repository. This is used to lookup the configuration for
the repository from the F<yukki.conf>.

=cut

has name => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

=head2 repository_settings

These are the settings telling this model where to find the git repository and
how to access it. It is loaded automatically using the L</name> to look up
information in the F<yukki.conf>.

=cut

has repository_settings => (
    is          => 'ro',
    isa         => 'Yukki::Settings::Repository',
    required    => 1,
    lazy        => 1,
    default     => sub { 
        my $self = shift;
        $self->app->settings->repositories->{$self->name};
    },
    handles     => {
        'title'  => 'name',
        'branch' => 'site_branch',
    },
);

=head2 repository_path

This is the path to the repository. It is located using the C<repository_path>
and C<repository> keys in the configuration.

=cut

has repository_path => (
    is          => 'ro',
    isa         => 'Path::Class::Dir',
    coerce      => 1,
    required    => 1,
    lazy_build  => 1,
);

sub _build_repository_path {
    my $self = shift;
    
    my $repo_settings = $self->repository_settings;
    return $self->locate_dir('repository_path', $repo_settings->repository);
}

=head2 git

This is a L<Git::Repository> object which helps us do the real work.

=cut

has git => (
    is          => 'ro',
    isa         => 'Git::Repository',
    required    => 1,
    lazy_build  => 1,
);

sub _build_git {
    my $self = shift;
    return Git::Repository->new( git_dir => $self->repository_path );
}

=head1 METHODS

=head2 author_name

This is the author name to use when making changes to the repository.

This is taken from the C<author_name> of the C<anonymous> key in the
configuration or defaults to "Anonymous".

=cut

sub author_name { shift->app->settings->anonymous->author_name }

=head2 author_email

This is the author email to use when making changes to the repository.

This is taken from teh C<author_email> of the C<anonymous> key in the
configuration or defaults to "anonymous@localhost".

=cut

sub author_email { shift->app->settings->anonymous->author_email }

=head2 make_tree

  my $tree_id = $repository->make_tree($old_tree_id, \@parts, $object_id);

This will construct one or more trees in the git repository to place the
C<$object_id> into the deepest tree. This starts by reading the tree found using
the object ID in C<$old_tree_id>. The first path part in C<@parts> is shifted
off. If an existing path is found there, that path will be replaced. If not, a
new path will be added. A tree object will be constructed for all byt he final
path part in C<@parts>.

When the final part is reached, that path will be placed into the final tree
as a blob using the given C<$object_id>.

This method will fail if it runs into a situation where a blob would be replaced
by a tree or a tree would be replaced by a blob. 

The method returns the object ID of the top level tree created.

=cut

sub make_tree {
    my ($self, $base, $tree, $blob) = @_;
    my @tree = @$tree;

    my ($mode, $type, $name);
    if (@$tree == 1) {
        $mode = '100644';
        $type = 'blob';
    }
    else {
        $mode = '040000';
        $type = 'tree';
    }
    $name = shift @tree;

    my $git = $self->git;

    my $overwrite;
    my @new_tree;
    if (defined $base) {
        my @old_tree = $git->run('ls-tree', $base);
        for my $line (@old_tree) {
            my ($old_mode, $old_type, $old_object_id, $old_file) = split /\s+/, $line, 4;

            if ($old_file eq $name) {
                $overwrite++;

                Yukki::Error->throw("cannot replace $old_type $name with $type")
                    if $old_type ne $type;

                if ($type eq 'blob') {
                    push @new_tree, "$mode $type $blob\t$name";
                }
                else {
                    my $tree_id = $self->make_tree($old_object_id, \@tree, $blob);
                    push @new_tree, "$mode $type $tree_id\t$name";
                }
            }
            else {
                push @new_tree, $line;
            }
        }
    }
    
    unless ($overwrite) {
        if ($type eq 'blob') {
            push @new_tree, "$mode $type $blob\t$name";
        }
        else {
            my $tree_id = $self->make_tree(undef, \@tree, $blob);
            push @new_tree, "$mode $type $tree_id\t$name";
        }
    }

    return $git->run('mktree', { input => join "\n", @new_tree });
}

=head2 make_blob

  my $object_id = $repository->make_blob($name, $content);

This creates a new file blob in the git repository with the given name and the
file contents.

=cut

sub make_blob {
    my ($self, $name, $content) = @_;

    return $self->git->run('hash-object', '-t', 'blob', '-w', '--stdin', '--path', $name, 
        { input => $content });
}

=head2 make_blob_from_file

  my $object_id = $repository->make_blob_from_file($name, $filename);

This is identical to L</make_blob>, except that the contents are read from the
given filename on the local disk.

=cut

sub make_blob_from_file {
    my ($self, $name, $filename) = @_;

    return $self->git->run('hash-object', '-t', 'blob', '-w', '--path', $name, $filename);
}

=head2 find_root

  my $tree_id = $repository->find_root;

This returns the object ID for the tree at the root of the L</branch>.

=cut

sub find_root {
    my ($self) = @_;

    my $old_tree_id;
    my @ref_info = $self->git->run('show-ref', $self->branch);
    REF: for my $line (@ref_info) {
        my ($object_id, $name) = split /\s+/, $line, 2;

        if ($name eq $self->branch) {
            $old_tree_id = $object_id;
            last REF;
        }
    }

    return $old_tree_id;
}

=head2 commit_tree

  my $commit_id = $self->commit_tree($old_tree_id, $new_tree_id, $comment);

This takes an existing tree commit (generally found with L</find_root>), a new
tree to replace it (generally constructed by L</make_tree>) and creates a
commit using the given comment.

The object ID of the committed ID is returned.

=cut

sub commit_tree {
    my ($self, $old_tree_id, $new_tree_id, $comment) = @_;

    return $self->git->run(
        'commit-tree', $new_tree_id, '-p', $old_tree_id, { 
            input => $comment,
            env   => {
                GIT_AUTHOR_NAME  => $self->author_name,
                GIT_AUTHOR_EMAIL => $self->author_email,
            },
        },
    );
}

=head2 update_root

  $self->update_root($old_tree_id, $new_tree_id);

Given a old commit ID and a new commit ID, this moves the HEAD of the L</branch>
so that it points to the new commit. This is called after L</commit_tree> has
setup the commit.

=cut

sub update_root {
    my ($self, $old_commit_id, $new_commit_id) = @_;
    $self->git->command('update-ref', $self->branch, $new_commit_id, $old_commit_id);
}

=head2 find_path

  my $object_id = $self->find_path($path);

Given a path within the repository, this will find the object ID of that tree or
blob at that path for the L</branch>.

=cut

sub find_path {
    my ($self, $path) = @_;

    my $object_id;
    my @files = $self->git->run('ls-tree', $self->branch, $path);
    FILE: for my $line (@files) {
        my ($mode, $type, $id, $name) = split /\s+/, $line, 4;

        if ($name eq $path) {
            $object_id = $id;
            last FILE;
        }
    }

    return $object_id;
}

=head2 show

  my $content = $repository->show($object_id);

Returns the contents of the blob for the given object ID.

=cut

sub show {
    my ($self, $object_id) = @_;
    return $self->git->run('show', $object_id);
}

=head2 fetch_size

  my $bytes = $repository->fetch_size($path);

Returns the size, in bites, of the blob at the given path.

=cut

sub fetch_size {
    my ($self, $path) = @_;

    my @files = $self->git->run('ls-tree', '-l', $self->branch, $path);
    FILE: for my $line (@files) {
        my ($mode, $type, $id, $size, $name) = split /\s+/, $line, 5;
        return $size if $name eq $path;
    }

    return;
}

=head2 list_files

  my @files = $repository->list_files($path);

Returns a list of L<Yukki::Model::File> objects for all the files found at
C<$path> in the repository.

=cut

sub list_files {
    my ($self, $path) = @_;
    my @files;

    my @tree_files = $self->git->run('ls-tree', $self->branch, $path . '/');
    FILE: for my $line (@tree_files) {
        my ($mode, $type, $id, $name) = split /\s+/, $line, 4;

        next unless $type eq 'blob';

        my $filetype;
        if ($name =~ s/\.(?<filetype>[a-z0-9]+)$//) {
            $filetype = $+{filetype};
        }

        push @files, $self->file({ path => $name, filetype => $filetype });
    }

    return @files;
}

=head2 file

  my $file = $repository->file({ path => 'foo', filetype => 'yukki' });

Returns a single L<Yukki::Model::File> object for the given path and filetype.

=cut

sub file {
    my ($self, $params) = @_;

    Yukki::Model::File->new(
        %$params,
        app        => $self->app,
        repository => $self,
    );
}

1;
