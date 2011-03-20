package Yukki::Web::Router::Route::Match;
use Moose;

extends 'Path::Router::Route::Match';

use List::MoreUtils qw( all );

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
