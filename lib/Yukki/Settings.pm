package Yukki::Settings;

use v5.24;
use utf8;
use Moo;

use Types::Path::Tiny qw( Path );
use Types::Standard qw( Str );
use Yukki::Settings::Repository;
use Yukki::Types qw( RepositoryMap YukkiSettingsAnonymous );

use namespace::clean;

# ABSTRACT: provides structure and validation to settings in yukki.conf

=head1 DESCRIPTION

This class provides structure for the main application configuration in L<Yukki>.

Yukki may fail to start unless your configuration is correct.

=head1 ATTRIBUTES

=head2 root

This is the wiki site directory. This should be the same folder that was given the F<yukki-setup> command. It works best if you make this an absolute path.

=cut

has root => (
    is          => 'ro',
    isa         => Path,
    required    => 1,
    coerce      => 1,
    default     => '.',
);

=head2 repository_path

This is the folder where Yukki will find the git repositories installed under C<root>. The default is F<root/repositories>.

=cut

has repository_path => (
    is          => 'ro',
    isa         => Path,
    required    => 1,
    coerce      => 1,
    default     => 'repositories',
);

=head2 user_path

This is the folder where the list of user files can be found.

=cut

has user_path => (
    is          => 'ro',
    isa         => Path,
    required    => 1,
    coerce      => 1,
    default     => 'var/db/users',
);

=head2 digest

This is the name of the digest algorithm to use to store passwords. See L<Digest> for more information. The default is "SHA-512".

N.B. If you change digest algorithms, old passwords saved with the old digest algorithm will continue to work as long as the old digest algorithm class is still installed.

=cut

has digest => (
    is          => 'ro',
    isa         => Str,
    required    => 1,
    default     => 'SHA-512',
);

=head2 anonymous

This is a section configuring anonymous user information.

=over

=item author_name

This is the name to use when an anonymous user makes a change to a wiki repository.

=item author_email

This is the email address to use when an anonymous user makes a change to a wiki repository.

=back

=cut

has anonymous => (
    is          => 'ro',
    isa         => YukkiSettingsAnonymous,
    required    => 1,
    coerce      => 1,
    default     => sub { Yukki::Settings::Anonymous->new },
);

=head2 repo_path

This is the folder where repository configuraiton files can be found. This path is intended for application managed repository configuration files. If you want to manage your repositories from the command-line instead, store the repository configurations under the C<repository> key in the main settings file.

=cut

has repo_path => (
    is          => 'ro',
    isa         => Path,
    required    => 1,
    coerce      => 1,
    default     => 'var/db/repos',
);

=head2 repositories

This is a section under which each repository is configured. The keys under here are the name found in the URL. It is also the name to use when running the F<yukki-git-init> and other repository-related commands.

Repository configurations may be stored either in the main Yukki configuration file under the C<repositories> key or as individual files located in the directory named in the C<repo_path> key. If a configuration is named in both places, the one in the main settings file will always be used.

Each repository configuration should provide the following configruation keys.

=cut

has repositories => (
    is          => 'ro',
    isa         => RepositoryMap,
    required    => 1,
    coerce      => 1,
);

{
    package Yukki::Settings::Anonymous;

    use Moo;
    use Types::Standard qw( Str );
    use Yukki::Types qw( EmailAddress );

    has author_name => (
        is          => 'ro',
        isa         => Str,
        required    => 1,
        default     => 'Anonymous',
    );

    has author_email => (
        is          => 'ro',
        isa         => EmailAddress,
        required    => 1,
        coerce      => 1,
        default     => 'anonymous@localhost',
    );
}

1;
