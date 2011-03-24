package Yukki::Web::Context;
use Moose;

use Yukki::Web::Request;
use Yukki::Web::Response;

# ABSTRACT: request-response context descriptor

=head1 SYNOPSIS

  # Many components are handed a Context in $ctx...
  
  my $request = $ctx->request;
  my $session = $ctx->session;
  my $session_options = $ctx->session_options;
  my $response = $ctx->response;
  my $stash = $ctx->stash;

  $ctx->add_errors('bad stuff');
  $ctx->add_warnings('not so good stuff');
  $ctx->add_info('some stuff');

=head1 DESCRIPTION

This describes information about a single request-repsonse to be handled by the server.

=head1 ATTRIBUTES

=head2 env

This is the L<PSGI> environment. Do not use directly. This will probably be
renamed to make it more difficult to use directly in the future.

=cut

has env => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
);

=head2 request

This is the L<Yukki::Web::Request> object representing the incoming request.

=cut

has request => (
    is          => 'ro',
    isa         => 'Yukki::Web::Request',
    required    => 1,
    lazy        => 1,
    default     => sub { Yukki::Web::Request->new(env => shift->env) },
    handles     => [ qw( session session_options ) ],
);

=head2 response

This is the L<Yukki::Web::Response> object representing the response to send
back to the client.

=cut

has response => (
    is          => 'ro',
    isa         => 'Yukki::Web::Response',
    required    => 1,
    lazy        => 1,
    default     => sub { Yukki::Web::Response->new },
);

=head2 stash

This is a temporary stash of information. Use of this should be avoided when
possible. Global state like this (even if it only lasts for one request) should
only be used as a last resort.

=cut

has stash => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
    default     => sub { +{} },
);

=head2 errors

=head2 warnings

=head2 info

These each contain an array of errors.

The C<list_errors>, C<list_warnings>, and C<list_info> methods are provided to
return the values as a list.

The C<add_errors>, C<add_warnings>, and C<add_info> methods are provided to
append new messages.

The C<has_errors>, C<has_warnings>, and C<has_info> methods are provided to tell
you if there are any messages.

=cut

# TODO Store these in a flash stash
for my $message_type (qw( errors warnings info )) {
    has $message_type => (
        is          => 'ro',
        isa         => 'ArrayRef[Str]',
        required    => 1,
        default     => sub { [] },
        traits      => [ 'Array' ],
        handles     => {
            "list_$message_type" => 'elements',
            "add_$message_type"  => 'push',
            "has_$message_type"  => 'count',
        },
    );
}

1;
