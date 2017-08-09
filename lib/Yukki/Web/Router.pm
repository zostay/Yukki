package Yukki::Web::Router;

use v5.24;
use utf8;
use Moo;

extends 'Path::Router';

use Yukki::Web::Router::Route;

use Types::Standard qw( ArrayRef Str );
use Type::Utils qw( class_type declare as where );
use List::Util qw( all );
use Yukki::Types qw( LoginName );

use namespace::clean;

# ABSTRACT: send requests to the correct controllers, yo

=head1 DESCRIPTION

This maps incoming paths to the controllers that should be used to handle them.
This is based on L<Path::Router>, but adds "slurpy" variables.

=head1 EXTENDS

L<Path::Router>

=head1 ATTRIBUTES

=head2 route_class

Defaults to L<Yukki::Web::Router::Route>.

=head2 inline

This is turned off because inline slurpy routing is not implemented.

=cut

# Add support for slurpy variables, inline off because I haven't written the match
# generator function yet.
has '+route_class' => ( default => 'Yukki::Web::Router::Route' );
has '+inline'      => ( default => 0 );

=head2 app

This is the L<Yukki> handler.

=cut

has app => (
    is          => 'ro',
    isa         => class_type('Yukki'),
    required    => 1,
    weak_ref    => 1,
    handles     => 'Yukki::Role::App',
);

=head1 METHODS

=head2 BUILD

Builds the routing table used by L<Yukki::Web>.

=cut

sub BUILD {
    my $self = shift;

    $self->add_route('' => (
        defaults => {
            redirect => 'page/view/main',
        },
        acl => [
            [ none => { action => sub { 1 } } ],
        ],
        target => $self->controller('Redirect'),
    ));

    $self->add_route('login/?:action' => (
        defaults => {
            action => 'page',
        },
        validations => {
            action => qr/^(?:page|submit|exit)$/,
        },
        acl => [
            [ none => { action => sub { 1 } } ],
        ],
        target => $self->controller('Login'),
    ));

    $self->add_route('profile/?:action' => (
        defaults => {
            action => 'profile',
        },
        validations => {
            action => qr/^(?:profile|update)$/,
        },
        acl => [
            [ none => { action => sub { 1 } } ],
        ],
        target => $self->controller('Login'),
    ));

    $self->add_route('logout' => (
        defaults => {
            action => 'exit',
        },
        acl => [
            [ none => { action => 'exit' } ]
        ],
        target => $self->controller('Login'),
    ));

    $self->add_route('page/:action/:repository/*:page' => (
        defaults => {
            action     => 'view',
            repository => 'main',
        },
        validations => {
            action     => qr/^(?:view|edit|history|diff|preview|attach|rename|remove)$/,
            repository => qr/^[_a-z0-9]+$/i,
            page       => declare as ArrayRef[Str], where {
                all { /^[_a-z0-9-.]+(?:\.[_a-z0-9-]+)*$/i } @$_
            },
        },
        acl => [
            [ read  => { action => [ qw( view preview history diff ) ] } ],
            [ write => { action => [ qw( edit attach rename remove ) ]  } ],
        ],
        target => $self->controller('Page'),
    ));

    $self->add_route('attachment/:action/:repository/+:file' => (
        defaults => {
            action     => 'download',
            repository => 'main',
            file       => [ 'untitled.txt' ],
        },
        validations => {
            action     => qr/^(?:view|upload|download|rename|remove)$/,
            repository => qr/^[_a-z0-9]+$/i,
            file       => declare as ArrayRef[Str], where {
                all { /^[_a-z0-9-]+(?:\.[_a-z0-9-]+)*$/i } @$_
            },
        },
        acl => [
            [ read  => { action => [ qw( view download ) ] } ],
            [ write => { action => [ qw( upload rename remove ) ] } ],
        ],
        target => $self->controller('Attachment'),
    ));

    $self->add_route('admin/user/:action' => (
        defaults => {
            action  => 'list',
            special => 'admin_user',
        },
        validations => {
            action => qr/^(?:add|list)$/,
        },
        acl => [
            [ read => { action => [ qw( list ) ] } ],
            [ write => { action => [ qw( add ) ] } ],
        ],
        target => $self->controller('Admin::User'),
    ));

    $self->add_route('admin/user/:action/:login_name' => (
        defaults => {
            action  => 'edit',
            special => 'admin_user',
        },
        validations => {
            action     => qr/^(?:edit|remove)$/,
            login_name => LoginName,
        },
        acl => [
            [ write => { action => [ qw( edit remove ) ] } ],
        ],
        target => $self->controller('Admin::User'),
    ));

    $self->add_route('admin/repository/:action' => (
        defaults => {
            action  => 'list',
            special => 'admin_repository',
        },
        validations => {
            action => qr/^(?:add|list)$/,
        },
        acl => [
            [ read => { action => [ qw( list ) ] } ],
            [ write => { action => [ qw( add ) ] } ],
        ],
        target => $self->controller('Admin::Repository'),
    ));

    $self->add_route('admin/repository/:action/:repository' => (
        defaults => {
            special => 'admin_repository',
        },
        validations => {
            action => qr/^(?:initialize|kill)$/,
        },
        acl => [
            [ write => { action => [ qw( initialize kill ) ] } ],
        ],
        target => $self->controller('Admin::Repository'),
    ));
}

1;
