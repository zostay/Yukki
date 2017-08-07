package Yukki::Role::Savable;

use v5.24;
use utf8;
use Moo::Role;

use Scalar::Util qw( blessed );
use YAML qw( Dump Load );

# ABSTRACT: Provides a mechanism for YAML-izing objects

=head1 SYNOPSIS

    package Yukki::Things;
    use v5.24;
    use Moo;

    with 'Yukki::Role::Savable';

    has foo => ( is => 'ro' );
    has bar => ( is => 'ro' );

    sub savable_attributes { qw( foo bar ) }

    my $things = Yukki::Things->new(foo => 1, bar => 2);
    path('file.yaml')->spew_utf8($things->dump_yaml);

    my $things = Yukki::Things->load_yaml(path('file.yaml')->slurp_utf8);
    say $things->foo; #> 1
    say $things->bar; #> 2

=head1 DESCRIPTION

This is intended to provide L<Yukki> with a nice, neat way to save and load some configuration objects in a standard way.

=head1 REQUIRED METHODS

=head2 savable_attributes

    my @attr = $obj->savable_attributes;

Returns the list of attributes to save in the YAML.

=cut

requires 'savable_attributes';

=head1 METHODS

=head2 dump_yaml

    my $yaml_text = $obj->dump_yaml;

This converts the object to YAML and returns the ext.

=cut

sub dump_yaml {
    my $self = shift;

    my %output;
    for my $attr ($self->savable_attributes) {
        my $v = $self->$attr;
        if (blessed $v) {
            if ($v->can('does') && $v->does('Yukki::Role::Savable')) {
                $v = $v->dump_yaml;
            }
            else {
                $v = "$v";
            }
        }
        $output{ $attr } = $v;
    }

    return Dump(\%output);
}

=head2 load_yaml

    my $obj = $class->load_yaml($yaml_text);

This constructs a new class from the data loaded from the given YAML text.

=cut

sub load_yaml {
    my ($class, $yaml) = @_;

    my $input = Load($yaml);
    $class->new($input);
}

1;
