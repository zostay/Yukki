package Yukki::Web::Response;
use Moose;

use Plack::Response;

# ABSTRACT: the response to the client

=head1 DESCRIPTION

An abstraction around the HTTP response that is astonishingly similar to L<Plack::Response>. Call C<finalize> to get the final PSGI response.

=head1 ATTRIBUTES

=head2 response

This is the internal L<Plack::Response> object. Do not use.

Use the delegated methods instead:

  status headers body header content_type content_length content_encoding
  redirect location cookies finalize

=cut

has response => (
    is          => 'ro',
    isa         => 'Plack::Response',
    required    => 1,
    lazy_build  => 1,
    handles     => [ qw(
        status headers body header content_type content_length content_encoding
        redirect location cookies finalize
    ) ],
);

sub _build_response {
    my $self = shift;
    return Plack::Response->new(200, [ 'Content-type' => 'text/html' ]);
}

=head2 page_title

This is the title to give the page in the HTML.

=cut

has page_title => (
    is          => 'rw',
    isa         => 'Str',
    predicate   => 'has_page_title',
);

=head2 navigation 

This is the navigation menu to place in the page. This is an array of hashes. Each entry should look like:

  {
      label => 'Label',
      href  => '/link/to/somewhere',
      sort  => 50,
  }

A sorted list of items is retrieved using C<navigation_menu>. New items can be added with the C<add_navigation_item> and C<add_navigation_items> methods.

=cut

has navigation => (
    is          => 'rw',
    isa         => 'ArrayRef[HashRef]',
    required    => 1,
    default     => sub { [] },
    traits      => [ 'Array' ],
    handles     => {
        navigation_menu      => [ sort => sub { ($_[0]->{sort}//50) <=> ($_[1]->{sort}//50) } ],
        add_navigation_item  => 'push',
        add_navigation_items => 'push',
    },
);

1;
