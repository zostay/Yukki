package Yukki::Web::Controller::Admin::Repository;

use v5.24;
use utf8;
use Moo;

with 'Yukki::Web::Controller';

use namespace::clean;

# ABSTRACT: controller for adminsitrator your repositories

=head1 DESCRIPTION

Controller for administrating the wiki repositories.

=head1 METHODS

=head2 fire

=cut

sub fire {
    my ($self, $ctx) = @_;

    my $action = $ctx->request->path_parameters->{action};

    if ($action eq 'list') { $self->list_repositories($ctx) }
    else {
        http_throw('No action found matching that URL.', {
            status => 'NotFound',
        });
    }
}

=head2 list_repositories

Displays a page listing repositories.

=cut

sub list_repositories {
    my ($self, $ctx) = @_;

    my $repos = $self->model('Root');
    my @repos = $repos->list_repositories;

    my $body = $self->view('Admin::Repository')->list($ctx, {
        repositories => \@repos,
    });

    $ctx->response->body($body);
}

1;
