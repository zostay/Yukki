package Yukki::Web::View::Admin::User;

use v5.24;
use utf8;
use Moo;

use Type::Utils;

use namespace::clean;

extends 'Yukki::Web::View';

# ABSTRACT: display user admin screens

=head1 DESCRIPTION

Shows user administration screens.

=cut

has list_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
    lazy        => 1,
    builder     => '_build_list_template',
);

sub _build_list_template {
    shift->prepare_template(
        template   => 'admin/user/list.html',
        directives => [
            '.user' => {
                'user<-users' => [
                    '.login_name' => 'user.login_name',
                    '.name'       => 'user.name',
                    '.email'      => 'user.email',
                    '.groups .group' => {
                        'group<-user.groups' => [
                            '.' => 'group',
                        ],
                    },
                ],
            },
        ],
    );
}

has edit_template => (
    is         => 'ro',
    isa        => class_type('Template::Pure'),
    lazy       => 1,
    builder    => '_build_edit_template',
);

sub _build_edit_template {
    shift->prepare_template(
        template   => 'admin/user/edit.html',
        directives => [
            '#login_name-input@type' => 'login_name_type',
            '#login_name@class' => 'login_name_display',
            '#login_name'  => 'user.login_name',
            '#name@value'  => 'user.name',
            '#email@value' => 'user.email',
        ],
    );
}

=head1 METHODS

=head2 page_navigation

Sets up page navigation menu for the user admin screens.

=cut

sub page_navigation {
    my ($self, $response, $this_action, $vars) = @_;

    for my $action (qw( add list )) {
        next if $action eq $this_action;

        $response->add_navigation_item([ qw( page page_bottom ) ] => {
            label => ucfirst $action,
            href  => join('/', 'admin/user', $action),
            sort  => 20,
        });
    }
}

=head2 list

Show the list of users.

=cut

sub list {
    my ($self, $ctx, $vars) = @_;

    $ctx->response->page_title("List Users");
    $self->page_navigation($ctx->response, 'list');

    return $self->render_page(
        template => $self->list_template,
        context  => $ctx,
        vars     => {
            users => $vars->{users},
        },
    );
}

=head2 edit

Show the user editor.

=cut

sub edit {
    my ($self, $ctx, $vars) = @_;

    if ($vars->{user}) {
        $ctx->response->page_title('Edit ' . $vars->{user}->login_name);
        $self->page_navigation($ctx->response, 'edit');
    }
    else {
        $ctx->response->page_title('Add User');
        $self->page_navigation($ctx->response, 'add');
    }

    my $user = $vars->{user} // +{
        login_name => '',
        name       => '',
        email      => '',
        groups     => [],
    };

    return $self->render_page(
        template => $self->edit_template,
        context  => $ctx,
        vars     => {
            user            => $user,
            login_name_display => defined $vars->{user} ? 'show' : 'hide',
            login_name_type => defined $vars->{user} ? 'hidden' : 'text',
        },
    );
}

1;
