package Yukki::Web::Controller::Admin::Repository;

use v5.24;
use utf8;
use Moo;

use FormValidator::Tiny ':all';
use Types::Standard qw( Int );

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
    elsif ($action eq 'add') { $self->add_repository($ctx) }
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

=head2 add_repository

Add a repository configuration.

=cut

sub _none_and_any_groups_are_special {
    my ($value) = @_;
    my @groups = @$value;
    if (@groups > 1 && any { $_ eq 'ANY' || $_ eq 'NONE' } @groups) {
        return (0, 'ANY or NONE must appear alone or not at all.');
    }
    else {
        return (1, '');
    }
}

validation_spec add_repository => [
    name => [
        required => 1,
        must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-', '.'),
        must => length_in_range('*', 50),
    ],
    title => [
        required => 1,
    ],
    branch => [
        required => 1,
        must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-', '.', '/'),
        must => length_in_range('*', 300),
    ],
    default_page => [
        required => 1,
        must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-', '.'),
        must => length_in_range('*', 100),
    ],
    sort => [
        required => 1,
        must => Int,
        with_error => 'Must be a number.',
        into => '+',
    ],
    anonymous_access_level => [
        required => 1,
        must => one_of(qw( none read write )),
    ],
    read_groups => [
        optional => 1,
        must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-'),
        into => split_by(qr/\s+/),
        must => \&_none_and_any_groups_are_special,
    ],
    write_groups => [
        optional => 1,
        must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-'),
        into => split_by(qr/\s+/),
        must => \&_none_and_any_groups_are_special,
    ],
];

=head2 add_repository

Screen for adding repository configuration.

=cut

sub add_repository {
    my ($self, $ctx) = @_;

    my %default = (
        branch       => 'refs/heads/master',
        default_page => 'home.yukki',
        sort         => '50',
        anonymous_access_level => 'none',
        read_groups  => 'NONE',
        write_groups => 'NONE',
    );

    my @breadcrumb = (
        {
            label => 'List',
            href  => '/admin/user/repository',
        },
    );

    my $body = $self->view('Admin::Repository')->edit($ctx, {
        form       => $ctx->request->body_parameters->as_hashref,
        default    => \%default,
        breadcrumb => \@breadcrumb,
    });

    $ctx->response->body($body);
}

1;
