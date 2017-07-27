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

=head1 METHODS

=head2 list

Show the list of users.

=cut

sub list {
    my ($self, $ctx, $vars) = @_;

    $ctx->response->page_title("List Users");

    return $self->render_page(
        template => $self->list_template,
        context  => $ctx,
        vars     => {
            users => $vars->{users},
        },
    );
}

1;
