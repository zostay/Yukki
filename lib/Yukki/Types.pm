package Yukki::Types;

use v5.24;

use Type::Library -base, -declare => qw(
    LoginName AccessLevel
    NavigationLinks NavigationMenuMap
    BaseURL BaseURLEnum BreadcrumbLinks RepositoryMap
    PluginConfig PluginList
    EmailAddress YukkiSettings
    YukkiWebSettings YukkiSettingsAnonymous
);
use Type::Utils qw( declare as where message coerce enum from via class_type );

use Types::Standard qw( Str Int ArrayRef Maybe HashRef Dict );
use Types::URI qw( Uri );

use Email::Address;
use List::Util qw( first );
use List::MoreUtils qw( all );

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

declare LoginName,
    as Str,
    where { /^[a-z0-9]+$/ },
    message { "login name $_ must only contain letters and numbers" };

=head2 AccessLevel

This is a valid access level. This includes any of the following values:

  read
  write
  none

=cut

enum AccessLevel, [qw( read write none )];

=head2 NavigationLinks

This is an array of hashes formatted like:

  {
      label => 'Label',
      href  => '/link/to/somewhere',
      sort  => 40,
  }

=cut

declare NavigationLinks,
    as ArrayRef[
        Dict[
            label => Str,
            href  => Str|Uri,
            sort  => Maybe[Int],
        ],
    ];

=head2 NavigationMenuMap

This is a hash of L</NavigationLinks>.

=cut

declare NavigationMenuMap,
    as HashRef[ NavigationLinks ];

=head2 BaseURL

This is either an absolute URL or the words C<SCRIPT_NAME> or C<REWRITE>.

=cut

enum BaseURLEnum, [qw( SCRIPT_NAME REWRITE )];

declare BaseURL, as BaseURLEnum|Uri;

coerce BaseURL,
    from Str,
    via {
        $_ !~ /^(?:SCRIPT_NAME|REWRITE)$/
            && URI->new($_)
    };

=head2 BreadcrumbLinks

This is an array of hashes formatted like:

  {
      label => 'Label',
      href  => '/link/to/somewhere',
  }

=cut

declare BreadcrumbLinks,
    as ArrayRef[
        Dict[
            label => Str,
            href  => Str,
        ],
    ];

=head2 RepositoryMap

This is a hash of L<Yukki::Settings::Repository> objects.

=cut

my $Repository = class_type 'Yukki::Settings::Repository';
declare RepositoryMap,
    as HashRef[$Repository];

coerce RepositoryMap,
    from HashRef,
    via {
        my $source = $_;
        +{
            map { $_ => Yukki::Settings::Repository->new($source->{$_}) }
                keys %$source
        }
    };

=head2 PluginConfig

A plugin configuration is an array of hashes. Each hash must have at least one key named "module" defined.

=cut

declare PluginConfig,
    as ArrayRef[HashRef],
    where { all { defined $_->{module} } @$_ };

=head2 PluginList

A plugin list is a loaded set of plugin objects.

=cut

my $Plugin = class_type 'Yukki::Web::Plugin';
declare PluginList,
    as ArrayRef[$Plugin],
    message {
        return 'It is not an array of objects.' unless ref $_ eq 'ARRAY';
        my $bad = first { not blessed $_ or not $_->isa('Yukki::Web::Plugin') }
                        @$_;
        $bad = blessed $bad if blessed $bad;
        return "It contains $bad, which is not a Yukki::Web::Plugin.";
    };

=head1 COERCIONS

In addition to the types above, these coercions are provided for other types.

=head2 EmailAddress

Coerces a C<Str> into an L<Email::Address>.

=cut

class_type EmailAddress, { class => 'Email::Address' };
coerce EmailAddress,
    from Str,
    via { (Email::Address->parse($_))[0] };

=head2 YukkiSettings

Coerces a C<HashRef> into this object by passing the value to the constructor.

=cut

class_type YukkiSettings, { class => 'Yukki::Settings' };
coerce YukkiSettings,
    from HashRef,
    via { Yukki::Settings->new($_) };

=head2 YukkiWebSettings

Coerces a C<HashRef> into a L<Yukki::Web::Settings>.

=cut

class_type YukkiWebSettings, { class => 'Yukki::Web::Settings' };
coerce YukkiWebSettings,
    from HashRef,
    via { Yukki::Web::Settings->new($_) };

=head2 YukkiSettingsAnonymous

Coerces a C<HashRef> into this object by passing the value to the constructor.

=cut

class_type YukkiSettingsAnonymous, { class => 'Yukki::Settings::Anonymous' };
coerce YukkiSettingsAnonymous,
    from HashRef,
    via { Yukki::Settings::Anonymous->new($_) };

1;
