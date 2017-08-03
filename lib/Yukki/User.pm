package Yukki::User;

use v5.24;
use utf8;
use Moo;

with 'Yukki::Role::Savable';

use Types::Standard qw( Str ArrayRef );
use Yukki::Types qw( LoginName );

use namespace::clean;

# ABSTRACT: Encapsulates Yukki users

=head1 SYNOPSIS

    use Yukki::User;

    my $user_file = $app->locate('user_path', 'bob');
    my $user = Yukki::User->load_yaml($user_file);

    say "login name: ", $user->login_name;
    say "password: ", $user->password;
    say "name: ", $user->name;
    say "email: ", $user->email;
    say "groups: ", join(', ', $user->groups->@*);

=head1 DESCRIPTION

Encapsulates the definition of a user object. Users are defined to provide information about the author of each change in the wiki.

=head1 ROLES

L<Yukki::Role::Savable>

=head1 ATTRIBUTES

=head2 login_name

This is the name the user uses to login.

=cut

has login_name => (
    is          => 'ro',
    isa         => LoginName,
    required    => 1,
);

=head2 password

This is the hashed password for the user.

=cut

has password => (
    is          => 'rw',
    isa         => Str,
    required    => 1,
);

=head2 name

This is the full name of the user, used as the author name on commits.

=cut

has name => (
    is          => 'rw',
    isa         => Str,
    required    => 1,
);

=head2 email

This is the email address of the user, used to uniquely identify the author in commits.

=cut

has email => (
    is          => 'rw',
    isa         => Str,
    required    => 1,
);

=head2 groups

This is the list of groups to which the user belongs.

=cut

has groups => (
    is          => 'ro',
    isa         => ArrayRef[Str],
    required    => 1,
    lazy        => 1,
    default     => sub { [] },
);

=head1 METHODS

=head2 groups_string

Returns the groups concatenated together into a single string.

=cut

sub groups_string { join ' ', shift->groups->@* }

=head2 savable_attributes

Returns the savable attributes.

=cut

sub savable_attributes {
    qw(
        login_name
        password
        name
        email
        groups
    )
}

1;
