package Yukki;
use Moose;

use MooseX::Types::Path::Class;
use Path::Class;

=head1 NAME

Yukki - Yet Uh-nother wiki

=head1 DESCRIPTION

This is intended to be the simplest, stupidest wiki on the planet. It uses git for versioning and it is perfectly safe to clone this repository and push and pull and all that jazz to maintain this wiki in multiple places.

=head1 WHY?

I wanted a Perl-based, MultiMarkdown-supporting wiki that I could take sermon notes and personal study notes for church and Bible study and such. However, I'm offline at church, so I want to do this from my laptop and sync it up to the master wiki when I get home. That's it.

Does it suit your needs? I don't really care, but if I've shared this on the CPAN or the GitHub, then I'm offering it to you in case you might find it useful WITHOUT WARRANTY. If you want it to suit your needs, bug me by email at C<< hanenkamp@cpan.org >> and send me patches.

=cut

has settings => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
);

sub _build_root { file($0)->parent->parent }

sub view { die 'not implemented here' }

sub controller { die 'not implemented here' }

sub model {
    my ($self, $name) = @_;
    my $class_name = join '::', 'Yukki::Model', $name;
    Class::MOP::load_class($class_name);
    return $class_name->new(app => $self);
}

sub locate {
    my ($self, $base, @extra_path) = @_;

    my $base_path = $self->settings->{$base};
    if ($base_path !~ m{^/}) {
        return file($self->settings->{root}, $base_path, @extra_path);
    }
    else {
        return file($base_path, @extra_path);
    }
}

with qw( Yukki::Role::App );

1;
