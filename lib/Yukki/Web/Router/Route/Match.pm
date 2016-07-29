package Yukki::Web::Router::Route::Match;

use v5.24;
use Moose;

extends 'Path::Router::Route::Match';

use List::MoreUtils qw( all any );
use Yukki::Error qw( http_throw );

# ABSTRACT: Matching with access controls

=head1 DESCRIPTION

This is a helper that include access control level checking.

=head1 EXTENDS

L<Path::Router::Route::Match>

=head1 METHODS

=head2 access_level

Evaluates the access control list against a particular path.

=cut

sub access_level {
    my $self = shift;

    my $mapping = $self->mapping;
    my $acl     = $self->route->acl;

    for my $rule (@$acl) {
        my ($access_level, $match) = @$rule;

        my $accepts = sub {
            my $key = shift;

            if (!ref $match->{$key}) {
                return $mapping->{$key} eq $match->{$key};
            }
            elsif (ref $match->{$key} eq 'CODE') {
                local $_ = $mapping->{$key};
                return $match->{$key}->($mapping->{$key});
            }
            elsif (ref $match->{$key} eq 'ARRAY') {
                return any { $mapping->{$key} eq $_ } $match->{$key}->@*;
            }
            else {
                die "unknown ACL authorization check type";
            }
        };

        if (all { $accepts->($_) } keys %$match) {
            return $access_level;
        }
    }

    http_throw("no ACL found to match " . $self->path);
}

__PACKAGE__->meta->make_immutable;
