package Yukki::Web::Context;

use v5.24;
use utf8;
use Moo;

use Sub::Name qw( subname );
use Type::Utils;
use Types::Standard qw( ArrayRef HashRef Str );
use Types::URI qw( Uri );
use URI;
use Yukki::Web::Request;
use Yukki::Web::Response;

use namespace::clean;

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
    isa         => HashRef,
    required    => 1,
);

=head2 request

This is the L<Yukki::Web::Request> object representing the incoming request.

=cut

has request => (
    is          => 'ro',
    isa         => class_type('Yukki::Web::Request'),
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
    isa         => class_type('Yukki::Web::Response'),
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
    isa         => HashRef,
    required    => 1,
    default     => sub { +{} },
);

=head2 base_url

This is a L<URI> describing the base path to get to this Yukki wiki site. It is configured from the L<Yukki::Web::Settings/base_url> setting. The value of the setting will determine how this value is calculated or may set it explicitly.

=over

=item *

C<SCRIPT_NAME>. When C<base_url> is set to C<SCRIPT_NAME>, then the full path to the script name will be used as the base URL. This is the default and, generally, the safest option.

=item *

C<REWRITE>. The C<REWRITE> option takes a slightly different approach to building the base URL. It looks at the C<REQUEST_URI> and compares that to the C<PATH_INFO> and finds the common components. For example:

  PATH_INFO=/page/view/main
  REQUEST_URI=/yukki-site/page/view/main

this leads to a base URL of:

  /yukki-site

If C<PATH_INFO> is not a sub-path of C<REQUEST_URI>, this will fall back to the same solution as C<SCRIPT_NAME> above.

=item *

Anything else will be considered an absolute URL and used as the base URL.

=back

This may be used to construct redirects or URLs for links and form actions.

=cut

has base_url => (
    is          => 'rw',
    isa         => Uri,
    required    => 1,
    coerce      => 1,
    lazy        => 1,
    builder     => '_build_base_url',
);

sub _build_base_url {
    my $self = shift;

    my $base_url = $self->env->{'yukki.settings'}->base_url;
    if ($base_url eq 'SCRIPT_NAME') {
        return $self->request->base;
    }

    elsif ($base_url eq 'REWRITE') {
        my $path_info   = $self->env->{PATH_INFO};
        my $request_uri = $self->env->{REQUEST_URI};

        if ($request_uri =~ s/$path_info$//) {
            my $base_url = $self->request->uri;
            $base_url->path($request_uri);
            return $base_url->canonical;
        }

        return $self->request->base;
    }

    else {
        return URI->new($base_url);
    }
}

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
        isa         => ArrayRef[Str],
        required    => 1,
        default     => sub { [] },
    );

    no strict 'refs';

    *{__PACKAGE__ . "::list_$message_type"} = subname "list_$message_type", sub {
        my $self = shift;
        map { ucfirst "$_." } $self->$message_type->@*
    };

    *{__PACKAGE__ . "::add_$message_type"} = subname "add_$message_type", sub {
        my $self = shift;
        push $self->$message_type->@*, @_;
    };

    *{__PACKAGE__ . "::has_$message_type"} = subname "add_$message_type", sub {
        my $self = shift;
        scalar $self->$message_type->@*;
    };
}


=head1 METHODS

=head2 rebase_url

  my $url = $ctx->rebase_url($path);

Given a relative URL, this returns an absolute URL using the L</base_url>.

=cut

sub rebase_url {
    my ($self, $url) = @_;
    return URI->new($url)->abs($self->base_url);
}

=head2 list_errors

=head2 list_warnings

=head2 list_info

These methods return the list of errors, warnings, and info messages associated with the current flow.

=head2 add_errors

=head2 add_warnings

=head2 add_info

These methods add zero or more errors, warnings, and info messages to be associated with the current flow.

=head2 has_errors

=head2 has_warnings

=head2 has_info

These methods return a true value if there are any errors, warnings, or info messages associated with the current flow.

=cut

1;
