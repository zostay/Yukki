package Yukki::Settings::Privileges;

use v5.24;
use utf8;
use Moo;

use Types::Standard qw( ArrayRef Str );
use Yukki::Types qw( AccessLevel );

use namespace::clean;

# ABSTRACT: settings describing privileges

=head1 DESCRIPTION

This just encapsultate privilege requirements to do certain actions.

=head1 ATTRIBUTES

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

1;

