package Yukki;
use Moose;

use Yukki::Types qw( AccessLevel );

use MooseX::Params::Validate;
use MooseX::Types::Path::Class;
use Path::Class;
use YAML qw( LoadFile );

=head1 NAME

Yukki - Yet Uh-nother wiki

=head1 DESCRIPTION

This is intended to be the simplest, stupidest wiki on the planet. It uses git for versioning and it is perfectly safe to clone this repository and push and pull and all that jazz to maintain this wiki in multiple places.

For information on getting started see L<Yukki::Manual::Installation>.

=head1 WHY?

I wanted a Perl-based, MultiMarkdown-supporting wiki that I could take sermon notes and personal study notes for church and Bible study and such. However, I'm offline at church, so I want to do this from my laptop and sync it up to the master wiki when I get home. That's it.

Does it suit your needs? I don't really care, but if I've shared this on the CPAN or the GitHub, then I'm offering it to you in case you might find it useful WITHOUT WARRANTY. If you want it to suit your needs, bug me by email at C<< hanenkamp@cpan.org >> and send me patches.

=cut

has config_file => (
    is          => 'ro',
    isa         => 'Path::Class::File',
    required    => 1,
    coerce      => 1,
    lazy_build  => 1,
);

sub _build_config_file {
    my $self = shift;

    my $cwd_conf = file(dir(), 'etc', 'yukki.conf');
    if (not $ENV{YUKKI_CONFIG} and -f "$cwd_conf") {
        return $cwd_conf;
    }

    die("Please make YUKKI_CONFIG point to your configuration file.\n")
        unless defined $ENV{YUKKI_CONFIG};

    die("No configuration found at $ENV{YUKKI_CONFIG}. Please set YUKKI_CONFIG to the correct location.\n")
        unless -f $ENV{YUKKI_CONFIG};

    return $ENV{YUKKI_CONFIG};
}

has settings => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
    lazy_build  => 1,
);

sub _build_settings {
    my $self = shift;
    LoadFile(''.$self->config_file);
}

sub view { die 'not implemented here' }

sub controller { die 'not implemented here' }

sub model {
    my ($self, $name, $params) = @_;
    my $class_name = join '::', 'Yukki::Model', $name;
    Class::MOP::load_class($class_name);
    return $class_name->new(app => $self, %{ $params // {} });
}

sub _locate {
    my ($self, $type, $base, @extra_path) = @_;

    my $path_class = $type eq 'file' ? 'Path::Class::File'
                   : $type eq 'dir'  ? 'Path::Class::Dir'
                   : Yukki::Error->throw("unkonwn location type $type");

    my $base_path = $self->settings->{$base};
    if ($base_path !~ m{^/}) {
        return $path_class->new($self->settings->{root}, $base_path, @extra_path);
    }
    else {
        return $path_class->new($base_path, @extra_path);
    }
}

sub locate {
    my ($self, $base, @extra_path) = @_;
    $self->_locate(file => $base, @extra_path);
}

sub locate_dir {
    my ($self, $base, @extra_path) = @_;
    $self->_locate(dir => $base, @extra_path);
}

sub check_access {
    my ($self, $user, $repository, $needs) = validated_list(\@_,
        user       => { isa => 'Undef|HashRef', optional => 1 },
        repository => { isa => 'Str' },
        needs      => { isa => AccessLevel },
    );

    my $config = $self->settings->{repositories}{$repository}
              // {};

    my $read_groups  = $config->{read_groups}  // 'NONE';
    my $write_groups = $config->{write_groups} // 'NONE';

    my %access_level = (none => 0, read => 1, write => 2);
    my $has_access = sub {
        $access_level{$_[0] // 'none'} >= $access_level{$needs}
    };

    # Deal with anonymous users first. 
    return 1 if $has_access->($config->{anonymous_access_level});
    return '' unless $user;

    # Only logged users considered here forward.
    my @user_groups = @{ $user->{groups} // [] };

    for my $level (qw( read write )) {
        if ($has_access->($level)) {

            return 1 if $config->{"${level}_groups"} ~~ 'ANY';

            if (ref $config->{"${level}_groups"} eq 'ARRAY') {
                my @level_groups = @{ $config->{"${level}_groups"} };

                for my $level_group (@level_groups) {
                    return 1 if $level_group ~~ @user_groups;
                }
            }
            else {
                warn "weird value in ${level}_groups config for ",
                     "$repository settings";
            }
        }
    } 

    return '';
}

with qw( Yukki::Role::App );

1;
