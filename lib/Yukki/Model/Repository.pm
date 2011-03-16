package Yukki::Model::Repository;
use Moose;

extends 'Yukki::Model';

use Yukki::Model::Page;

use Git::Repository;
use Path::Class;
use MooseX::Types::Path::Class;

has name => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
);

has repository_settings => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
    lazy        => 1,
    default     => sub { 
        my $self = shift;
        $self->app->settings->{repositories}{$self->name};
    },
);

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
    return $self->locate_dir('repository_path', $repo_settings->{repository});
}

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

has branch => (
    is          => 'ro',
    isa         => 'Str',
    required    => 1,
    lazy_build  => 1,
);

sub _build_branch {
    my $self = shift;
    $self->repository_settings->{branch} // 'refs/heads/master';
}

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
            my ($old_mode, $old_type, $old_object_id, $old_page) = split /\s+/, $line;

            if ($old_page eq $name) {
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

sub make_blob {
    my ($self, $name, $content) = @_;

    return $self->git->run('hash-object', '-t', 'blob', '-w', '--stdin', '--path', $name, 
        { input => $content });
}

sub make_blob_from_file {
    my ($self, $name, $filename) = @_;

    return $self->git->run('hash-object', '-t', 'blob', '-w', '--path', $name, $filename);
}

sub find_root {
    my ($self) = @_;

    my $old_tree_id;
    my @ref_info = $self->git->run('show-ref', $self->branch);
    REF: for my $line (@ref_info) {
        my ($object_id, $name) = split /\s+/, $line;

        if ($name eq $self->branch) {
            $old_tree_id = $object_id;
            last REF;
        }
    }

    return $old_tree_id;
}

sub commit_tree {
    my ($self, $old_tree_id, $new_tree_id, $comment) = @_;

    return $self->git->run('commit-tree', $new_tree_id, '-p', $old_tree_id, { input => $comment });
}

sub update_root {
    my ($self, $old_commit_id, $new_commit_id) = @_;
    $self->git->command('update-ref', $self->branch, $new_commit_id, $old_commit_id);
}

sub find_path {
    my ($self, $path) = @_;

    my $object_id;
    my @files = $self->git->run('ls-tree', $self->branch, $path);
    FILE: for my $line (@files) {
        my ($mode, $type, $id, $name) = split /\s+/, $line;

        if ($name eq $path) {
            $object_id = $id;
            last FILE;
        }
    }

    return $object_id;
}

sub show {
    my ($self, $object_id) = @_;
    return $self->git->run('show', $object_id);
}

sub fetch_size {
    my ($self, $path) = @_;

    my @files = $self->git->run('ls-tree', '-l', $self->branch, $path);
    FILE: for my $line (@files) {
        my ($mode, $type, $id, $size, $name) = split /\s+/, $line;
        return $size if $name eq $path;
    }

    return;
}

sub list_pages {
    my ($self, $path) = @_;
    my @pages;

    my @files = $self->git->run('ls-tree', $self->branch, $path . '/');
    FILE: for my $line (@files) {
        my ($mode, $type, $id, $name) = split /\s+/, $line;

        my $filetype;
        if ($name =~ s/\.(?<filetype>[a-z0-9]+)$//) {
            $filetype = $+{filetype};
        }

        push @pages, $self->page({ path => $name, filetype => $filetype });
    }

    return @pages;
}

sub page {
    my ($self, $params) = @_;

    Yukki::Model::Page->new(
        %$params,
        app        => $self->app,
        repository => $self,
    );
}

1;
