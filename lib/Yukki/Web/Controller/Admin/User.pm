package Yukki::Web::Controller::Admin::User;

use v5.24;
use utf8;
use Moo;

use Yukki::Error qw( http_throw );

with 'Yukki::Web::Controller';

use namespace::clean;

# ABSTRACT: controller for administering your wiki

=head1 DESCRIPTION

Controller for administering the wiki repositories and users.

=head1 METHODS

=head2 fire

=cut

sub fire {
    my ($self, $ctx) = @_;

    my $action = $ctx->request->path_parameters->{action};
    if ($action eq 'list')   { $self->list_users($ctx) }
    elsif ($action eq 'add') { $self->edit_user($ctx) }
    else {
        http_throw('No action found matching that URL.', {
            status => 'NotFound',
        });
    }
}

=head2 list_users

Displays a page listing user records.

=cut

sub list_users {
    my ($self, $ctx) = @_;

    my $users = $self->model('User');
    my @users = map { $users->find(login_name => $_) } $users->list;

    my $body = $self->view('Admin::User')->list($ctx, {
        users => \@users,
    });

    $ctx->response->body($body);
}

=head2 edit_user

Add or edit a user account.

=cut

sub edit_user {
    my ($self, $ctx) = @_;

    my $login_name = $ctx->request->path_parameters->{login_name};
    my $user;
    if (defined $login_name) {
        $user = $self->model('User')->find(login_name => $login_name);
    }

    my $body = $self->view('Admin::User')->edit($ctx, {
        user => $user,
    });

    $ctx->response->body($body);
}

1;
