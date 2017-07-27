package Yukki::Settings::Repository;

use v5.24;
use utf8;
use Moo;

with 'Yukki::Role::Savable';

use Types::Path::Tiny qw( Path );
use Types::Standard qw( ArrayRef Int Str );
use Yukki::Types qw( AccessLevel );

use namespace::clean;

# ABSTRACT: settings describing a wiki repository

=head1 DESCRIPTION

This class provides structure for describing a git repository used to back a Yukki workspace. These may either be defined as part of the main settings file for command-line managed repositories. App-managed repositories will be stored in a sub-directory, each configuration in its own file.

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

=head2 anonymous_access_level

This should be set to one of the following: read, write, or none. This settings decides how much access an anonymous user has when visiting your wiki.

=cut

has anonymous_access_level => (
    is          => 'ro',
    isa         => Yukki::Types::AccessLevel,
    required    => 1,
    default     => 'none',
);

=head2 read_groups

This may be set to the word "ANY" or the word "NONE" or to an array of group names.

If set to ANY, any logged user may read this repository. If set to NONE, read access is not granted to any logged user (though if C<anonymous_access_level> or C<write_groups> grant a user access, the user will be able to read the repository).

If an array of one or more group names are given, the users with any of those groups will be able to read the repository.

=cut

has read_groups => (
    is          => 'ro',
    isa         => Str|ArrayRef[Str],
    required    => 1,
    default     => 'NONE',
);

=head2 write_groups

THe possible values that may be set are identicl to C<read_groups>. This setting determines who has permission to edit pages and upload files to the repository.

=cut

has write_groups => (
    is          => 'ro',
    isa         => Str|ArrayRef[Str],
    required    => 1,
    default     => 'NONE',
);

=head1 METHODS

=head2 savable_attributes

The list of savable attributes.

=cut

sub savable_attributes {
    qw(
        repository
        site_page
        name
        default_page
        sort
        anonymous_access_level
        read_groups
        write_groups
    )
}

1;
