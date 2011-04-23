package Yukki::Web::Plugin::Role::YukkiTextHelper;
use 5.12.1;
use Moose::Role;

=head1 NAME

Yukki::Web::Plugin::Role::YukkiTextHelper - interface for quick yukkitext helpers

=head1 SYNOPSIS

  package MyPlugins::LowerCase;
  use 5.12.1;
  use Moose;

  extends 'Yukki::Web::Plugin';

  has yukkitext_helpers => (
      is          => 'ro',
      isa         => 'HashRef[Str]',
      default     => sub { +{
          'lc' => 'lc_helper',
      } },
  );

  with 'Yukki::Web::Plugin::Role::YukkiTextHelper';

  sub lc_helper { 
      my ($self, $params) = @_;
      return lc $params->{arg};
  }

=head1 DESCRIPTION

This role defines the interface for quick yukkitext helpers. Each plugin implementing this role may provide code references for embedding content in yukkitext using a special C<{{...}}> notation.

=head1 REQUIRED METHODS

An implementor must provide the following methods.

=head2 yukkitext_helpers

This must return a reference to hash mapping quick helper names to method names that may be called to handle them.

The names may be any text that does not contain a colon (":").

The methods will be called with the following parameters:

=over

=item context

The curent L<Yukki::Web::Context> object.

=item repository

The name of the current repository.

=item page

The path to the current page of that repository.

=item helper_name

The helper name the user used.

=item arg

The string argument passed to it.

=back

When called the method must return a scalar value to insert into the page. This is generally a string and may include any markup that should be added to the page.

If the method throws and exception or returns C<undef> or something other than a scalar, the yukkitext formatter will include the original C<{{...}}> string as-is.

=cut

requires qw( yukkitext_helpers );

1;
