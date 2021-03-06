package Yukki::Settings::Repository;

use v5.24;
use utf8;
use Moo;

extends 'Yukki::Settings::Privileges';

with 'Yukki::Role::Savable';

use Types::Path::Tiny qw( Path );
use Types::Standard qw( ArrayRef Int Str );
use Yukki::Types qw( AccessLevel );

use namespace::clean;

# ABSTRACT: settings describing a wiki repository

=head1 DESCRIPTION

This class provides structure for describing a git repository used to back a Yukki workspace. These may either be defined as part of the main settings file for command-line managed repositories. App-managed repositories will be stored in a sub-directory, each configuration in its own file.

=head1 ISA

L<Yukki::Settings::Privileges>

=head1 ROLES

L<Yukki::Role::Savable>

=head1 ATTRIBUTES

=head2 repository

This is required. This is the name of the git repository folder found under C<repository_path>.

=cut

has repository => (
    is          => 'ro',
    isa         => Path,
    required    => 1,
    coerce      => 1,
);

=head2 site_branch

This is the name of the branch that will contain the wiki's files. The default is C<refs/heads/master>. You could actually use the same git repository for multiple Yukki repositories by using different branches. If you want to do it that way for some reason. Unless you know what you're doing, you probably don't want to do that.

=cut

has site_branch => (
    is          => 'ro',
    isa         => Str,
    required    => 1,
    default     => 'refs/heads/master',
);

=head2 name

This is a human readable title for the repository.

=cut

has name => (
    is          => 'ro',
    isa         => Str,
    required    => 1,
);

=head2 default_page

This is the name of the main repository index.

=cut

has default_page => (
    is          => 'ro',
    isa         => Path,
    required    => 1,
    coerce      => 1,
    default     => 'home.yukki',
);

=head2 sort

This is the sort order the repository should take when being listed in menus. The default is 50. The value must be an integer.

=cut

has sort => (
    is          => 'ro',
    isa         => Int,
    required    => 1,
    default     => 50,
);

=head1 METHODS

=head2 savable_attributes

The list of savable attributes.

=cut

sub savable_attributes {
    qw(
        repository
        site_branch
        name
        default_page
        sort
        anonymous_access_level
        read_groups
        write_groups
    )
}

1;
