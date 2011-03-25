package Yukki::Types;
use Moose;

use MooseX::Types -declare => [ qw(
    LoginName AccessLevel NavigationLinks
    BreadcrumbLinks
) ];

use MooseX::Types::Moose qw( Str Int ArrayRef Maybe );
use MooseX::Types::Structured qw( Dict );

# ABSTRACT: standard types for use in Yukki

=head1 SYNOPSIS

  use Yukki::Types qw( LoginName AccessLevel );

  has login_name => ( isa => LoginName );
  has access_level => ( isa => AccessLevel );

=head1 DESCRIPTION

A standard type library for Yukki.

=head1 TYPES

=head2 LoginName

This is a valid login name. Login names may only contain letters and numbers, as of this writing.

=cut

subtype LoginName,
    as Str,
    where { /^[a-z0-9]+$/ },
    message { "login name $_ must only contain letters and numbers" };

=head2 AccessLevel

This is a valid access level. This includes any of the following values:

  read
  write
  none

=cut

enum AccessLevel, qw( read write none );

=head2 NavigationLinks

THis is an array of hashes formatted like:

  {
      label => 'Label',
      href  => '/link/to/somewhere',
      sort  => 40,
  }

=cut

subtype NavigationLinks,
    as ArrayRef[
        Dict[
            label => Str,
            href  => Str,
            sort  => Maybe[Int],
        ],
    ];

=head2 BreadcrumbLinks

THis is an array of hashes formatted like:

  {
      label => 'Label',
      href  => '/link/to/somewhere',
  }

=cut

subtype BreadcrumbLinks,
    as ArrayRef[
        Dict[
            label => Str,
            href  => Str,
        ],
    ];

1;
