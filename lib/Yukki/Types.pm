package Yukki::Types;
use Moose;

use MooseX::Types -declare => [ qw(
    LoginName AccessLevel
) ];

use MooseX::Types::Moose qw( Str );

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

1;
