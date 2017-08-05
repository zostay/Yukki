package Yukki::Web::View::Admin::Repository;

use v5.24;
use utf8;
use Moo;

use Type::Utils qw( class_type );

use namespace::clean;

extends 'Yukki::Web::View';

# ABSTRACT: display repository admin screens

=head1 DESCRIPTION

Shows repository admin screens.

=cut

has list_template => (
    is          => 'ro',
    isa         => class_type('Template::Pure'),
    lazy        => 1,
    builder     => '_build_list_template',
);

sub _build_list_template {
    shift->prepare_template(
        template   => 'admin/repository/list.html',
        directives => [
            '.repository' => {
                'repo<-repositories' => [
                    '.name' => 'repo.name',
                    '.title' => 'repo.repository_settings.name',
                    '.branch' => 'repo.repository_settings.site_branch',
                    '.default_page' => 'repo.repository_settings.default_page',
                ],
            },
        ],
    );
}

=head1 METHODS

=head2 list

=cut

sub list {
    my ($self, $ctx, $vars) = @_;

    $ctx->response->page_title('List Repositories');

    return $self->render_page(
        template => $self->list_template,
        context  => $ctx,
        vars     => {
            repositories => [
                sort { $a->repository_settings->name cmp $b->repository_settings->name }
                    @{ $vars->{repositories} }
            ],
        },
    );
}

1;
