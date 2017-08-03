package Yukki::Web::Controller::Admin::User;

use v5.24;
use utf8;
use Moo;

use Email::Valid;
use FormValidator::Tiny qw( :validation :predicates :filters );
use Yukki::Error qw( http_throw );
use Yukki::User;

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
    elsif ($action eq 'add') { $self->add_user($ctx) }
    elsif ($action eq 'edit') { $self->edit_user($ctx) }
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

=head2 add_user

Add a user account.

=cut

validation_spec add_user => [
    login_name => [
        required => 1,
        must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-'),
        must => length_in_range(3, 20),
    ],
    name => [
        required => 1,
        must => length_in_range(1, 200),
    ],
    email => [
        required => 1,
        must => length_in_range(1, 200),
        must => sub {
            (Email::Valid->address($_), 'Not a valid email address.')
        },
    ],
    password => [
        required => 1,
        must => length_in_range(8, 72),
    ],
    groups => [
        into      => split_by(qr/,/),
        each_into => trim(),
        each_must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-'),
    ],
];

sub add_user {
    my ($self, $ctx) = @_;

    my $form_errors;
    if ($ctx->request->method eq 'POST') {
        my $user_params;
        ($user_params, $form_errors)
            = validate_form add_user => $ctx->request->body_parameters;

        if (!defined $form_errors) {
            my $user = Yukki::User->new(
                login_name => $user_params->{login_name},
                password   => $user_params->{password},
                name       => $user_params->{name},
                email      => $user_params->{email},
                groups     => $user_params->{groups},
            );

            $self->model('User')->save($user);

            $ctx->add_info('Saved '.$user->login_name.'.');

            $ctx->response->redirect('/admin/user/list');
            return;
        }
    }

    my @breadcrumb = (
        {
            label => 'List',
            href  => '/admin/user/list',
        },
    );

    my $body = $self->view('Admin::User')->edit($ctx, {
        form        => $ctx->request->body_parameters->as_hashref,
        breadcrumb  => \@breadcrumb,
        form_errors => $form_errors,
    });

    $ctx->response->body($body);
}

=head2 edit_user

Edit a user account.

=cut

validation_spec edit_user => [
    name => [
        required => 1,
        must => length_in_range(1, 200),
    ],
    email => [
        required => 1,
        must => length_in_range(1, 200),
        must => sub {
            (Email::Valid->address($_), 'Not a valid email address.')
        },
    ],
    password => [
        must => length_in_range(8, 72),
    ],
    groups => [
        into      => split_by(qr/,/),
        each_into => trim(),
        each_must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-'),
    ],
];

sub edit_user {
    my ($self, $ctx) = @_;

    my $login_name = $ctx->request->path_parameters->{login_name};
    my $user = $self->model('User')->find(login_name => $login_name);

    my $form_errors;
    if ($ctx->request->method eq 'POST') {
        my $user_params;
        ($user_params, $form_errors)
            = validate_form edit_user => $ctx->request->body_parameters;

        if (!defined $form_errors) {
            $user->password($user_params->{password})
                if defined $user_params->{password};
            $user->name($user_params->{name});
            $user->email($user_params->{email});
            $user->groups->@* = $user_params->{groups}->@*;

            $self->model('User')->save($user);

            $ctx->add_info('Saved '.$user->login_name.'.');

            $ctx->response->redirect('/admin/user/list');
            return;
        }
    }

    my @breadcrumb = (
        {
            label => 'List',
            href  => '/admin/user/list',
        },
    );

    my $body = $self->view('Admin::User')->edit($ctx, {
        user        => $user,
        breadcrumb  => \@breadcrumb,
        form_errors => $form_errors,
    });

    $ctx->response->body($body);
}

1;
