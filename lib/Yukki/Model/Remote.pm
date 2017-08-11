package Yukki::Model::Remove;

use v5.24;
use utf8;
use Moo;

use Type::Utils;
use Types::Standard qw( Str );

use namespace::clean;

extends 'Yukki::Model';

# ABSTRACT: model repsenting a repository remote

=head1 SYNOPSIS

    my $repository = $app->model('Repository', { repository => 'main' });
    my $remote = $repository->remove('origin');
    $remote->pull;
    $remove->push;

=head1 DESCRIPTION

Tools for working with remote repositories.

=head1 EXTENDS

L<Yukki::Model>

=head1 ATTRIBUTES

=head2 name

This is the local alias name given to the remote repository.

=cut

has name => (
    is          => 'ro',
    isa         => Str,
    required    => 1,
);

=head2 repository

This is the L<Yukki::Model::Repository> the remote is assicated with.

=cut

has repository => (
    is          => 'ro',
    isa         => class_type('Yukki::Model::Repository'),
    required    => 1,
    handles     => [ qw(
        remote_config
        update_remote_config
        remove_remote_config
        fetch_remote
    ) ],
);

=head1 METHODS

=head2 remote_url

    $remote->remote_url($url);
    my $url = $remote->remote_url;

This returns the remote URL for this remote repository. If passed a URL, this will update the URL associated with this remote.

=cut

sub remote_url {
    my ($self, $url) = @_;

    if (defined $url) {
        $self->update_remote_config($self->name, $url);
    }

    return $self->remote_config->{ $self->name };
}

=head2 pull

    my @conflicts = $remote->pull;

This will fetch data from a remote repository into the current and then attempt to bring those changes into the repository's site branch from the branch with the same name in the remote repository. This will perform a fast-forward merge if possible. If not, it will perform a rebase, which will take any local changes and try to apply them after the remote changes. If that does not work, it will attempt a merge.

On success, it will return an empty list, indicating that it was able to perform the pull operation. If it failed, it will return a list of file names.

=cut



1;
