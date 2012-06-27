package Yukki::Model::User;
use Moose;

extends 'Yukki::Model';

use Yukki::Types qw( LoginName );

use Path::Class;
use MooseX::Params::Validate;
use MooseX::Types::Path::Class;
use YAML qw( LoadFile );

# ABSTRACT: lookup users

=head1 SYNOPSIS

  my $users = $app->model('User');
  my $user  = $users->find('bob');

  my $login_name = $user->{login_name};
  my $password   = $user->{password};
  my $name       = $user->{name};
  my $email      = $user->{email};
  my @groups     = @{ $user->{groups} };

=head1 DESCRIPTION

Read access to the current list of authorized users.

=head1 METHODS

=head2 find

  my $user = $users->find($login_name);

Returns a hash containing the information related to a specific user named by login name.

=cut

sub find {
    my ($self, $login_name) = validated_list(\@_,
        login_name => { isa => LoginName },
    );

    my $user_file = $self->locate('user_path', $login_name);
    if (-e $user_file) {
        return LoadFile($user_file);
    }

    return;
}

1;
