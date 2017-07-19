package Yukki;

use v5.24;
use utf8;
use Moo;

use Class::Load;

use Yukki::Settings;
use Yukki::TextUtil qw( load_file );
use Yukki::Types qw( AccessLevel YukkiSettings );
use Yukki::Error qw( http_throw );

use Crypt::SaltedHash;
use List::MoreUtils qw( any );
use Type::Params qw( validate );
use Type::Utils;
use Types::Standard qw( Dict HashRef Str Undef slurpy );
use Path::Tiny;
use Types::Path::Tiny qw( Path );

use namespace::clean;

# ABSTRACT: Yet Uh-nother wiki

=head1 DESCRIPTION

This is intended to be the simplest, stupidest wiki on the planet. It uses git for versioning and it is perfectly safe to clone this repository and push and pull and all that jazz to maintain this wiki in multiple places.

For information on getting started see L<Yukki::Manual::Installation>.

=head1 WITH ROLES

=over

=item *

L<Yukki::Role::App>

=back

=head1 ATTRIBUTES

=head2 config_file

This is the name of the configuraiton file. The application will try to find it in F<etc> within the current working directory first. If not there, it will check the C<YUKKI_CONFIG> environment variable.

=cut

has config_file => (
    is          => 'ro',
    isa         => Path,
    required    => 1,
    coerce      => 1,
    lazy        => 1,
    builder     => '_build_config_file',
);

sub _build_config_file {
    my $self = shift;

    my $cwd_conf = path('.', 'etc', 'yukki.conf');
    if (not $ENV{YUKKI_CONFIG} and -f "$cwd_conf") {
        return $cwd_conf;
    }

    die("Please make YUKKI_CONFIG point to your configuration file.\n")
        unless defined $ENV{YUKKI_CONFIG};

    die("No configuration found at $ENV{YUKKI_CONFIG}. Please set YUKKI_CONFIG to the correct location.\n")
        unless -f $ENV{YUKKI_CONFIG};

    return $ENV{YUKKI_CONFIG};
}

=head2 settings

This is the configuration loaded from the L</config_file>.

=cut

has settings => (
    is          => 'ro',
    isa         => YukkiSettings,
    required    => 1,
    coerce      => 1,
    lazy        => 1,
    builder     => '_build_settings',
);

sub _build_settings {
    my $self = shift;
    load_file($self->config_file)
}

=head1 METHODS

=head2 view

  my $view = $app->view('Page');

Not implemented in this class. See L<Yukki::Web>.

=cut

sub view { ... }

=head2 controller

  my $controller = $app->controller('Page');

Not implemented in this class. See L<Yukki::Web>.

=cut

sub controller { ... }

=head2 model

  my $model = $app->model('Repository', { repository => 'main' });

Returns an instance of the requested model class. The parameters are passed to
the instance constructor.

=cut

sub model {
    my ($self, $name, $params) = @_;
    my $class_name = join '::', 'Yukki::Model', $name;
    Class::Load::load_class($class_name);
    return $class_name->new(app => $self, %{ $params // {} });
}

=head2 locate

  my $file = $app->locate('user_path', 'test_user');

The first argument is the name of the configuration directive naming the path.
It may be followed by one or more path components to be tacked on to the end.

Returns a L<Path::Tiny> for the file.

=cut

sub _locate {
    my ($self, $type, $base, @extra_path) = @_;

    my $base_path = $self->settings->$base;
    if ($base_path !~ m{^/}) {
        return path($self->settings->root, $base_path, @extra_path);
    }
    else {
        return path($base_path, @extra_path);
    }
}

sub locate {
    my ($self, $base, @extra_path) = @_;
    $self->_locate(file => $base, @extra_path);
}

=head2 locate_dir

  my $dir = $app->locate_dir('repository_path', 'main.git');

The arguments are identical to L</locate>, but returns a L<Path::Tiny> for
the given file.

=cut

sub locate_dir {
    my ($self, $base, @extra_path) = @_;
    $self->_locate(dir => $base, @extra_path);
}

=head2 check_access

  my $access_is_ok = $app->check_access({
      user       => $user,
      repository => 'main',
      needs      => 'read',
  });

The C<user> is optional. It should be an object returned from
L<Yukki::Model::User>. The C<repository> is required and should be the name of
the repository the user is trying to gain access to. The C<needs> is the access
level the user needs. It must be an L<Yukki::Types/AccessLevel>.

The method returns a true value if access should be granted or false otherwise.

=cut

sub check_access {
    my ($self, $opt)
        = validate(\@_, class_type(__PACKAGE__),
            slurpy Dict[
                user       => Undef|HashRef,
                repository => Str,
                needs      => AccessLevel,
            ]);
    my ($user, $repository, $needs) = @{$opt}{qw( user repository needs )};

    # Always grant none
    return 1 if $needs eq 'none';

    my $config = $self->settings->repositories->{$repository};

    return '' unless $config;

    my $read_groups  = $config->read_groups;
    my $write_groups = $config->write_groups;

    my %access_level = (none => 0, read => 1, write => 2);
    my $has_access = sub {
        $access_level{$_[0] // 'none'} >= $access_level{$needs}
    };

    # Deal with anonymous users first.
    return 1 if $has_access->($config->anonymous_access_level);
    return '' unless $user;

    # Only logged users considered here forward.
    my @user_groups = @{ $user->{groups} // [] };

    for my $level (qw( read write )) {
        if ($has_access->($level)) {

            my $groups = "${level}_groups";

            return 1 if $config->$groups eq 'ANY';

            if (ref $config->$groups eq 'ARRAY') {
                my @level_groups = @{ $config->$groups };

                for my $level_group (@level_groups) {
                    return 1 if any { $_ eq $level_group } @user_groups;
                }
            }
            elsif ($config->$groups ne 'NONE') {
                warn "weird value ", $config->$groups,
                    " in $groups config for $repository settings";
            }
        }
    }

    return '';
}

=head2 hasher

Returns a message digest object that can be used to create a cryptographic hash.

=cut

sub hasher {
    my $self = shift;

    return Crypt::SaltedHash->new(algorithm => $self->settings->digest);
}

with qw( Yukki::Role::App );

=head1 WHY?

I wanted a Perl-based, MultiMarkdown-supporting wiki that I could take sermon notes and personal study notes for church and Bible study and such. However, I'm offline at church, so I want to do this from my laptop and sync it up to the master wiki when I get home. That's it.

Does it suit your needs? I don't really care, but if I've shared this on the CPAN or the GitHub, then I'm offering it to you in case you might find it useful WITHOUT WARRANTY. If you want it to suit your needs, bug me by email at C<< hanenkamp@cpan.org >> and send me patches.

=cut

1;
