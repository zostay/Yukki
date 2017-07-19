package Yukki::Role::App;

use v5.24;
use utf8;
use Moo::Role;

requires qw(
    model
    view
    controller
    locate
    locate_dir
    check_access
);

# ABSTRACT: the role Yukki app-classes implement

=head1 DESCRIPTION

The L<Yukki> and L<Yukki::Web> classes fulfill this role.

=head1 REQUIRED METHODS

=head2 model

  my $obj = $self->model($name, \%params);

Given a name and an optional hash of parameters, return an instance of a
L<Yukki::Model>.

=head2 view

  my $obj = $self->view($name);

Given a name, return a view object.

=head2 controller

  my $obj = $self->controller($name);

Given a name, return a controller object.

=head2 locate

  my $file = $self->locate($base_path, @path_parts);

Given a configuration key in C<$base_path> and some C<@path_parts> to append,
return a L<Path::Class::File> representing that file under the Yukki
installation.

=head2 locate_dir

  my $dir = $self->locate_dir($base_path, @path_parts);

Given a configuration key in C<$base_path> and some C<@path_parts> to append,
return a L<Path::Class::Dir> representing that directory under the Yukki
installation.

=head2 check_access

  my $access_is_ok = $self->check_access({
      user       => $user,
      repository => $repository,
      needs      => $needs,
  });

The C<user> is optional. It should be an object returned from
L<Yukki::Model::User>. The C<repository> is required and should be the name of
the repository the user is trying to gain access to. The C<needs> is the access
level the user needs. It must be an L<Yukki::Types/AccessLevel>.

The method returns a true value if access should be granted or false otherwise.

=cut

1;
