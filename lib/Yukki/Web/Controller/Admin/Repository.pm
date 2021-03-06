package Yukki::Web::Controller::Admin::Repository;

use v5.24;
use utf8;
use Moo;

use FormValidator::Tiny ':all';
use Types::Standard qw( Int );
use Yukki::Error qw( http_throw );

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
    elsif ($action eq 'initialize') { $self->initialize_repository($ctx) }
    elsif ($action eq 'remove') { $self->remove_repository($ctx) }
    elsif ($action eq 'kill') { $self->kill_repository($ctx) }
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

sub _unbox_none_and_any {
    my ($value) = @_;
    my @groups = @$value;
    if (@groups == 1 && ($groups[0] eq 'ANY' || $groups[0] eq 'NONE')) {
        return $groups[0];
    }
    else {
        return $value;
    }
}

validation_spec add_repository => [
    name => [
        required => 1,
        must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-', '.'),
        must => length_in_range(3, 50),
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
        into => \&_unbox_none_and_any,
    ],
    write_groups => [
        optional => 1,
        must => limit_character_set('a-z', 'A-Z', '0-9', '_', '-'),
        into => split_by(qr/\s+/),
        must => \&_none_and_any_groups_are_special,
        into => \&_unbox_none_and_any,
    ],
];

=head2 add_repository

Screen for adding repository configuration.

=cut

sub add_repository {
    my ($self, $ctx) = @_;

    my $form_errors;
    if ($ctx->request->method eq 'POST') {
        my $repo_params;
        ($repo_params, $form_errors)
            = validate_form add_repository => $ctx->request->body_parameters;

        if (!defined $form_errors) {
            $self->model('Root')->attach_repository(
                key          => $repo_params->{name},
                repository   => "$repo_params->{name}.git",
                site_branch  => $repo_params->{branch},
                name         => $repo_params->{title},
                default_page => $repo_params->{default_page},
                sort         => $repo_params->{sort},
                anonymous_access_level => $repo_params->{anonymous_access_level},
                read_groups  => $repo_params->{read_groups},
                write_groups => $repo_params->{write_groups},
            );

            $ctx->add_info("Saved $repo_params->{name}.");

            $ctx->response->redirect('/admin/repository/list');
            return;
        }
    }

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
        form        => $ctx->request->body_parameters->as_hashref,
        form_errors => $form_errors,
        default     => \%default,
        breadcrumb  => \@breadcrumb,
    });

    $ctx->response->body($body);
}

=head2 initialize_repository

Triggers repository initialization.

=cut

sub initialize_repository {
    my ($self, $ctx) = @_;

    my $repo_name = $ctx->request->path_parameters->{repository};
    my $repo = $self->model('Root')->repository($repo_name);

    http_throw("Repository named $repo_name does not exist.", {
        status => 'NotFound',
    }) unless $repo;

    my $confirmed = $ctx->request->body_parameters->{confirmed};
    if ($ctx->request->method eq 'POST' && $confirmed) {
        $self->model('Root')->init_repository(
            key => $repo_name,
        );

        $ctx->add_info("Initialized repository named ".$repo->title.".");
        $ctx->response->redirect('/admin/repository/list');
        return;
    }

    my @breadcrumb = (
        {
            label => 'List',
            href  => 'admin/repository/list',
        }
    );

    my $body = $self->view('Admin::Repository')->initialize($ctx, {
        title => 'Initialize ' . $repo->title,
        repo  => $repo,
        breadcrumb => \@breadcrumb,
        return_link => $ctx->rebase_url('admin/repository/list'),
    });

    $ctx->response->body($body);
}

=head2 kill_repository

Deletes a git repository.

=cut

sub kill_repository {
    my ($self, $ctx) = @_;

    my $repo_name = $ctx->request->path_parameters->{repository};
    my $repo = $self->model('Root')->repository($repo_name);

    http_throw("Repository named $repo_name does not exist.", {
        status => 'NotFound',
    }) unless $repo;

    if (!$repo->repository_exists) {
        $ctx->add_warnings('Repository '.$repo->title.' has no storage associated with it.');
        $ctx->response->redirect('/admin/repository/list');
        return;
    }

    my $confirmed = $ctx->request->body_parameters->{confirmed};
    if ($ctx->request->method eq 'POST' && $confirmed) {
        $self->model('Root')->kill_repository(
            key => $repo_name,
        );

        $ctx->add_info('Killed repository named '.$repo->title.', it is now safe to reinitialize or remove.');
        $ctx->response->redirect('/admin/repository/list');
        return;
    }

    my @breadcrumb = (
        {
            label => 'List',
            href  => 'admin/repository/list',
        },
    );

    my $body = $self->view('Admin::Repository')->kill_it_with_fire($ctx, {
        title => 'Kill ' . $repo->title,
        repo  => $repo,
        breadcrumb => \@breadcrumb,
        return_link => $ctx->rebase_url('admin/repository/list'),
    });

    $ctx->response->body($body);
}

=head2 remove_repository

Removes a repository configuration.

=cut

sub remove_repository {
    my ($self, $ctx) = @_;

    my $repo_name = $ctx->request->path_parameters->{repository};
    my $repo = $self->model('Root')->repository($repo_name);

    http_throw("Repository named $repo_name does not exist.", {
        status => 'NotFound',
    }) unless $repo;

    if ($repo->is_master_repository) {
        $ctx->add_warnings('Repository '.$repo->title.' cannot be removed in app. Please use the command-line tools.');
        $ctx->response->redirect('/admin/repository/list');
        return;
    }

    my $confirmed = $ctx->request->body_parameters->{confirmed};
    if ($ctx->request->method eq 'POST' && $confirmed) {
        $self->model('Root')->detach_repository(
            key => $repo_name,
        );

        $ctx->add_info('Removed repository configuration.');
        $ctx->response->redirect('/admin/repository/list');
        return;
    }

    my @breadcrumb = (
        {
            label => 'List',
            href  => 'admin/repository/list',
        },
    );

    my $body = $self->view('Admin::Repository')->remove($ctx, {
        title => 'Remove ' . $repo->title,
        repo  => $repo,
        breadcrumb => \@breadcrumb,
        return_link => $ctx->rebase_url('admin/repository/list'),
    });

    $ctx->response->body($body);
}

1;
