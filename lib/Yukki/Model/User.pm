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

=head2 set_password

    $users->set_password($user, $cleartext);

Given a password in cleartext, this will hash the password using the application's hasher. The second argument containing the cleartext password is optional. When omitted, the value returned by the C<password> accessor of the C<$user> object will be used instead.

=cut

sub set_password {
    my ($self, $user, $clear_password) = @_;
    $clear_password //= $user->password;

    my $digest = $self->app->hasher;
    $digest->add($clear_password);
    $user->password($digest->generate);

    return;
}

=head2 save

    $users->save($user, create_only => 1);

Writes a L<Yukki::User> object to the users database. If the C<create_only> flag is set, the method will fail with an exception when the user already exists.

=cut

sub save {
    my ($self, $user, %opt) = @_;

    my $user_file = $self->locate('user_path', $user->login_name);

    if ($opt{create_only} && $user_file->exists) {
        die "User ", $user->login_name, " already exists.";
    }

    $user_file->parent->mkpath;
    $user_file->chmod(0600) if $user_file->exists;
    $user_file->spew_utf8($user->dump_yaml);
    $user_file->chmod(0400);

    return;
}

=head2 delete

    $users->delete($user);

Given a L<Yukki::User>, this method deletes the user file for that object.

=cut

sub delete {
    my ($self, $user) = @_;

    my $user_file = $self->locate('user_path', $user->login_name);
    $user_file->remove if $user_file->is_file;

    return;
}

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
    if ($user_file->exists) {
        return Yukki::User->load_yaml($user_file->slurp_utf8);
    }

    return;
}

=head2 list

    my @names = $users->list;

Returns a list of login names for all users configured.

=cut

sub list {
    my $self = shift;

    my $user_dir = $self->locate('user_path');
    return map { $_->basename } $user_dir->children;
}

1;
