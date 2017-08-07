package Yukki::Web::View::Admin::User;

use v5.24;
use utf8;
use Moo;

use Scalar::Util;
use Type::Utils;
use Yukki::TemplateUtil qw( field form_error );

use namespace::clean;

extends 'Yukki::Web::View';

with 'Yukki::Web::View::Role::Navigation';

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
                    '.action'     => 'user.action | encoded_string',
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
            map { form_error($_) } qw(
                login_name email name password groups
            ),

            '#login_name-input@type' => 'login_name_type',
            '#login_name@class' => 'login_name_display',
            '#login_name'  => field(['user.login_name', 'form.login_name']),
            '#login_name-input@value' => field(['user.login_name', 'form.login_name']),
            '#name@value'  => field(['user.name','form.name']),
            '#email@value' => field(['user.email','form.email']),
            '#user-groups@value' => field(['user.groups_string','form.groups']),
        ],
    );
}

has remove_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
    lazy        => 1,
    builder     => '_build_remove_template',
);

sub _build_remove_template {
    shift->prepare_template(
        template   => 'admin/user/remove.html',
        directives => [
            '.login_name'         => 'user.login_name',
            '#cancel_remove@href' => 'return_link',
        ],
    );
}

=head1 METHODS

=head2 standard_menu

Sets up page navigation menu for the user admin screens.

=cut

sub standard_menu {
    return map {
        +{
            action => $_,
            href   => "admin/user/$_",
        },
    } qw( add list );
}

=head2 list

Show the list of users.

=cut

sub list {
    my ($self, $ctx, $vars) = @_;

    $ctx->response->page_title("List Users");
    $self->page_navigation($ctx->response, 'list');

    my @users = map {
        my $user = $_;
        my $action = $self->render_links(
            context => $ctx,
            links   => [
                {
                    label => 'Edit',
                    href  => "/admin/user/edit/" . $user->login_name,
                },
                {
                    label => 'Remove',
                    href  => "/admin/user/remove/" . $user->login_name,
                }
            ],
        );

        {
            login_name => $user->login_name,
            name       => $user->name,
            email      => $user->email,
            groups     => $user->groups,
            action     => $action,
        }
    } @{ $vars->{users} // [] };

    return $self->render_page(
        template => $self->list_template,
        context  => $ctx,
        vars     => {
            users   => \@users,
        },
    );
}

=head2 edit

Show the user editor.

=cut

sub edit {
    my ($self, $ctx, $vars) = @_;

    my $user = $vars->{user};
    my $form = $vars->{form};

    if ($user) {
        $ctx->response->page_title('Edit ' . $user->login_name);
        $self->page_navigation($ctx->response, 'edit');
    }
    else {
        $ctx->response->page_title('Add User');
        $self->page_navigation($ctx->response, 'add');
    }

    $ctx->response->breadcrumb($vars->{breadcrumb});

    return $self->render_page(
        template => $self->edit_template,
        context  => $ctx,
        vars     => {
            form            => $form,
            user            => $user,
            login_name_display => defined $user ? 'show' : 'hide',
            login_name_type => defined $user ? 'hidden' : 'text',
            form_errors     => $vars->{form_errors},
        },
    );
}

=head2 remove

Displays the remove user confirmation page.

=cut

sub remove {
    my ($self, $ctx, $vars) = @_;

    $ctx->response->page_title($vars->{title});
    $ctx->response->breadcrumb($vars->{breadcrumb});

    $self->page_navigation($ctx->response, 'remove');

    my $login_name = $vars->{user}->login_name;
    return $self->render_confirmation(
        context   => $ctx,
        title     => "Remove $login_name?",
        question  => "Are you sure you wish to remove the user with login name $login_name?",
        yes_label => 'Remove Now',
        no_link   => $vars->{return_link},
    );
}

1;
