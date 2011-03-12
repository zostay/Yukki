package Yukki::Web::Router::Route;
use Moose;

extends 'Path::Router::Route';

use List::MoreUtils qw( any );

sub is_component_slurpy {
    my ($self, $component) = @_;
    $component =~ /^[+*]:/;
}

sub is_component_optional {
    my ($self, $component) = @_;
    $component =~ /^[?*]:/;
}

sub is_component_variable {
    my ($self, $component) = @_;
    $component =~ /^[?*+]?:/;
}

sub get_component_name {
    my ($self, $component) = @_;
    my ($name) = ($component =~ /^[?*+]?:(.*)$/);
    return $name;
}

sub has_slurpy_match {
    my $self = shift;
    return any { $self->is_component_slurpy($_) } reverse @{ $self->components };
}

sub match {
    my ($self, $parts) = @_;

    return unless (
        @$parts >= $self->length_without_optionals &&
        ($self->has_slurpy_match || @$parts <= $self->length)
    );

    my @parts = @$parts; # for shifting

    my $mapping = $self->has_defaults ? $self->create_default_mapping : {};

    for my $c (@{ $self->components }) {
        unless (@parts) {
            die "should never get here: " .
                "no \@parts left, but more required components remain"
                if ! $self->is_component_optional($c);
            last;
        }

        my $part;
        if ($self->is_component_slurpy($c)) {
            $part = [ @parts ];
            @parts = ();
        }
        else {
            $part = shift @parts;
        }

        if ($self->is_component_variable($c)) {
            my $name = $self->get_component_name($c);

            if (my $v = $self->has_validation_for($name)) {
                return unless $v->check($part);
            }

            $mapping->{$name} = $part;
        }

        else {
            return unless $c eq $part;
        }
    }

    return Path::Router::Route::Match->new(
        path    => join('/', @$parts),
        route   => $self,
        mapping => $mapping,
    );
}

1;
