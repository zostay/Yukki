package Yukki::Model::Page;
use Moose;

extends 'Yukki::Model';

use Git::Repository;

sub repository_settings {
    my ($self, $repository) = @_;
    return $self->app->settings->{repositories}{$repository};
}

sub save {
    my ($self, $repository, $page, $params) = @_;

    $page .= '.mkd';

    my $repo_settings = $self->repository_settings($repository);
    return unless defined $repo_settings;

    my $repo_dir = $self->locate('repository_path', $repo_settings->{repository});
    my $git = Git::Repository->new( git_dir => $repo_dir );

    my $object_id = $git->run('hash-object', '-t', 'blob', '-w', '--stdin', '--path', $page, 
        { input => $params->{content} });

    Yukki::Error->throw("unable to create blob for $page") unless $object_id;

    my $old_tree_id;
    my @ref_info = $git->run('show-ref', 'refs/heads/master');
    REF: for my $line (@ref_info) {
        my ($object_id, $name) = split /\s+/, $line;

        if ($name eq 'refs/heads/master') {
            $old_tree_id = $object_id;
            last REF;
        }
    }

    Yukki::Error->throw("unable to locate original tree ID for refs/heads/master")
        unless $old_tree_id;

    my $overwrite;
    my @new_tree;
    my @old_tree = $git->run('ls-tree', 'refs/heads/master');
    for my $blob (@old_tree) {
        my ($old_mode, $old_type, $old_object_id, $old_page) = split /\s+/, $blob;

        if ($old_page eq $page) {
            $overwrite++;
            push @new_tree, "$old_mode $old_type $object_id\t$page";
        }
        else {
            push @new_tree, $blob;
        }
    }
    
    push @new_tree, "100644 blob $object_id\t$page" unless $overwrite;

    my $new_tree_id = $git->run('mktree', { input => join "\n", @new_tree });

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
