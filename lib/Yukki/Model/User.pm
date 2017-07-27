package Yukki::Model::User;

use v5.24;
use utf8;
use Moo;

extends 'Yukki::Model';

use Yukki::Types qw( LoginName );
use Yukki::TextUtil qw( load_file );

use Type::Params qw( validate );
use Type::Utils;
use Types::Path::Tiny;
use Types::Standard qw( slurpy Dict );

use Yukki::User;

use namespace::clean;

# ABSTRACT: lookup users

=head1 SYNOPSIS

  my $users = $app->model('User');
  my $user  = $users->find('bob');

  my $login_name = $user->login_name;
  my $password   = $user->password;
  my $name       = $user->name;
  my $email      = $user->email;
  my @groups     = $user->groups->@*;

=head1 DESCRIPTION

Read access to the current list of authorized users.

=head1 METHODS

=head2 find

  my $user = $users->find(login_name => $login_name);

Returns a hash containing the information related to a specific user named by login name.

=cut

sub find {
    my ($self, $opt)
        = validate(\@_, class_type(__PACKAGE__),
            slurpy Dict[
                login_name => LoginName
            ],
        );
    my $login_name = $opt->{login_name};

    my $user_file = $self->locate('user_path', $login_name);
    if (-e $user_file) {
        return Yukki::User->load_yaml($user_file->slurp_utf8);
    }

    return;
}

1;
