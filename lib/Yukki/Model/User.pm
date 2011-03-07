package Yukki::Model::User;
use Moose;

extends 'Yukki::Model';

use Yukki::Types qw( LoginName );

use Path::Class;
use MooseX::Params::Validate;
use MooseX::Types::Path::Class;
use YAML qw( LoadFile );

sub find {
    my ($self, $login_name) = validated_list(\@_,
        login_name => { isa => LoginName },
    );

    my $user_file = $self->locate('user_path', $login_name);
    return LoadFile($user_file);
}

1;
