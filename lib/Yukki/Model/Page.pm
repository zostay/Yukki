package Yukki::Model::Page;
use Moose;

extends 'Yukki::Model';

use Git::Repository;

sub repository_settings {
    my ($self, $repository) = @_;
    return $self->app->settings->{repositories}{$repository};
}

sub git {
    my ($self, $repository) = @_;

    my $repo_settings = $self->repository_settings($repository);
    return unless defined $repo_settings;

    my $repo_dir = $self->locate('repository_path', $repo_settings->{repository});
    return Git::Repository->new( git_dir => $repo_dir );
}

sub make_tree {
    my ($self, $git, $base, $tree, $blob) = @_;
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
                    my $tree_id = $self->make_tree($git, $old_object_id, \@tree, $blob);
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
            my $tree_id = $self->make_tree($git, undef, \@tree, $blob);
            push @new_tree, "$mode $type $tree_id\t$name";
        }
    }

    return $git->run('mktree', { input => join "\n", @new_tree });
}

sub make_blob {
    my ($self, $git, $name, $content) = @_;

    return $git->run('hash-object', '-t', 'blob', '-w', '--stdin', '--path', $name, 
        { input => $content });
}

sub find_root {
    my ($self, $git) = @_;

    my $old_tree_id;
    my @ref_info = $git->run('show-ref', 'refs/heads/master');
    REF: for my $line (@ref_info) {
        my ($object_id, $name) = split /\s+/, $line;

        if ($name eq 'refs/heads/master') {
            $old_tree_id = $object_id;
            last REF;
        }
    }

    return $old_tree_id;
}

sub save {
    my ($self, $repository, $page, $params) = @_;

    $page .= '.' . ($params->{filetype} || 'yukki');

    my $git = $self->git($repository);
    return unless $git;

    my (@parts) = split m{/}, $page;
    my $blob_name = $parts[-1];

    my $object_id = $self->make_blob($git, $blob_name, $params->{content});
    Yukki::Error->throw("unable to create blob for $page") unless $object_id;

    my $old_tree_id = $self->find_root($git);
    Yukki::Error->throw("unable to locate original tree ID for refs/heads/master")
        unless $old_tree_id;

    my $new_tree_id = $self->make_tree($git, $old_tree_id, \@parts, $object_id);
    Yukki::Error->throw("unable to create the new tree containing $page\n")
        unless $new_tree_id;

    my $commit_id = $git->run('commit-tree', $new_tree_id, '-p', $old_tree_id, 
        { input => $params->{comment} });

    Yukki::Error->throw("unable to commit the new tree containing $page\n")
        unless $commit_id;

    $git->command('update-ref', 'refs/heads/master', $commit_id, $old_tree_id);
}

sub load {
    my ($self, $repository, $page) = @_;
    $page .= '.mkd';

    my $repo_settings = $self->repository_settings($repository);
    return unless defined $repo_settings;

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

    return unless defined $object_id;

    return $git->run('show', $object_id);
}

1;
