package Yukki::Web::Router::Route::Match;
use Moose;

extends 'Path::Router::Route::Match';

use List::MoreUtils qw( all );

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

        if (all { $mapping->{$_} ~~ $match->{$_} } keys %$match) {
            return $access_level;
        }
    }

    Yukki::Error->throw("no ACL found to match " . $self->path);
}

1;
