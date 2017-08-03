package Yukki::Model::Root;

use v5.24;
use utf8;
use Moo;

extends 'Yukki::Model';

use Type::Params qw( validate );
use Type::Utils;
use Types::Standard qw( Bool Maybe Str Dict slurpy );
use Types::URI qw( Uri );

use namespace::clean;

# ABSTRACT: model for accessing the git repositories

=head1 SYNOPSIS

    my $root = $app->model('Root');
    my $repository = $root->repository({ name => 'main' });

=head1 DESCRIPTION

This model contains method for performing actions related to the creation, deletion, and management of a set of git repositories as well as manipulating the configuration file. This model behaves as a singleton per L<Yukki> app.

This model will be used by various administrative features of scripts and the application. For the various methods that perform modifications to work, the tool performing the actions must have write access to the configuration and the directory containing the repositories.

=head1 EXTENDS

L<Yukki::Model>

=head1 METHODS

=head2 repository

    $repository = $root->repository($key);

This will construct and return a L<Yukki::Model::Repository> object. It's basically a synonym for:

    $repository = $app->model('Repository', { name => $key });

=cut

sub repository { shift->app->model('Repository', { name => shift }) }

=head2 attach_repository

    $root->attach_repository(%config);

Given the configuration for a repository, this will insert the configuration into the settings file. This will only insert a new configuration. It will not modify an existing one. For that you want L</edit_repository>.

This will create a new repository configuration file under L<Yukki::Settings/repo_path>. If a configuration with the same name already exists there or if one is defined within the C<YUKKI_CONFIG> file, this operation will fail.

The configuration to pass in is passed through to the constructor of L<Yukki::Settings::Repository>. You will also need to pass C<key> in, which is set to the key under which this repository will be saved.

=cut

sub attach_repository {
    my ($self, %opt) = @_;
    my $key = delete $opt{key}
        // die "missing key in attach_repository";

    my $repo = Yukki::Settings::Repository->new(\%opt);
    my $repo_file = $self->locate('repo_path', $key);

    if ($self->app->settings->repositories->{$key}) {
        die "repository with key '$key' is already defined in the master configuraiton file, cannot attach it again";
    }
    elsif (-e $self->locate('repo_path', $key)) {
        die "repository with key '$key' is already configured, cannot attach it again";
    }

    $repo_file->spew_utf8($repo->dump_yaml);
    return;
}

=head2 init_repository

    $repository = $root->init_repository(
        key    => $key,
        origin => $git_uri,
        init_from_settings => $init_from_settings_flag,
    );

This will initialize a new repository on disk. If C<origin> is given, the new repository will be cloned from there. If not, a new empty repository will be committed and then a single commit inserted containing an index stub.

Before calling this method, the L</attach_repository> method must be called first to configure it.

The C<init_from_settings> flag is set to a true value (default is false), then this will allow init of repositories found in L<Yukki::Settings>. This is intended for use by command-line tools only. Initializing C<YUKKI_CONFIG> defined repositories from the application is not advised.

=cut

sub init_repository {
    my ($self, $opt)
        = validate(\@_, class_type(__PACKAGE__),
            slurpy Dict[
                key    => Str,
                origin => Maybe[Uri],
                init_from_settings => Bool,
            ],
        );
    my ($key, $origin, $init_from_settings) = @{$opt}{qw(
        key origin init_from_settings
    )};

    my $repo_config = $self->app->settings->repositories->{$key};
    if ($repo_config && !$init_from_settings) {
        die "unable to initialize repository '$key' found in settings, please use the command-line tools";
    }

    elsif (!$repo_config) {
        my $repo_file = ''.$self->locate('repo_path', $key);
        $repo_config = Yukki::Settings::Repository->load_yaml(
            $repo_file->slurp_utf8
        );
    }

    die "repository '$key' not yet attached" if !$repo_config;

    my $repository = $self->repository($key);

    if ($origin) {
        $repository->clone_repository($origin);
    }
    else {
        $repository->initialize_repository;
    }
}

1;
