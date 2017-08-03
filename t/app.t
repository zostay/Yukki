#!/usr/bin/env perl
use 5.12.1;

use Test2::V0;
use Test::Exception;

BEGIN { plan 59; }

use Path::Tiny;

use ok('Yukki');
use ok('Yukki::User');

my $app = Yukki->new;
isa_ok($app, 'Yukki');
DOES_ok($app, 'Yukki::Role::App');

throws_ok { $app->config_file } qr/make YUKKI_CONFIG point/, 'missing config location complains';

$ENV{YUKKI_CONFIG} = 't/test-site/etc/bad-yukki.conf';

throws_ok { $app->config_file } qr/no configuration found/i, 'missing config file complains';

delete $ENV{YUKKI_CONFIG};
chdir 't/test-site';

is($app->config_file, path('.', 'etc', 'yukki.conf'), 'config set by CWD works');

delete $app->{config_file};
chdir '../..';
$ENV{YUKKI_CONFIG} = 't/test-site/etc/yukki.conf';

is($app->config_file, path('.', 't', 'test-site', 'etc', 'yukki.conf'), 'config set by env works');

throws_ok { $app->view } qr/unimplemented/i, 'view is not implemented';
throws_ok { $app->controller } qr/unimplemented/i, 'controller is not implemented';

my $model = $app->model('User');
isa_ok($model, 'Yukki::Model::User');

my $dir = $app->locate_dir('repository_path', 'main.git');
isa_ok($dir, 'Path::Tiny');
is("$dir", "/tmp/repositories/main.git", 'locate_dir makes the right dir');

my $file = $app->locate('user_path', 'demo');
isa_ok($file, 'Path::Tiny');
is("$file", "/tmp/var/db/users/demo", 'locate makes the right file');

my $group1_user = Yukki::User->new(login_name => 'abc', password => 'a', name => 'a', email => 'a@example.com', groups => [ 'group1' ]);
my $group4_user = Yukki::User->new(login_name => 'bbc', password => 'a', name => 'b', email => 'b@example.com', groups => [ 'group4' ]);

is($app->check_access( user => undef, repository => 'noaccess', needs => 'none' ), 1);
is($app->check_access( user => undef, repository => 'noaccess', needs => 'read' ), '');
is($app->check_access( user => undef, repository => 'noaccess', needs => 'write' ), '');
is($app->check_access( user => $group1_user, repository => 'noaccess', needs => 'none' ), 1);
is($app->check_access( user => $group1_user, repository => 'noaccess', needs => 'read' ), '');
is($app->check_access( user => $group1_user, repository => 'noaccess', needs => 'write' ), '');

is($app->check_access( user => undef, repository => 'anonymousread', needs => 'none' ), 1);
is($app->check_access( user => undef, repository => 'anonymousread', needs => 'read' ), 1);
is($app->check_access( user => undef, repository => 'anonymousread', needs => 'write' ), '');
is($app->check_access( user => $group1_user, repository => 'anonymousread', needs => 'none' ), 1);
is($app->check_access( user => $group1_user, repository => 'anonymousread', needs => 'read' ), 1);
is($app->check_access( user => $group1_user, repository => 'anonymousread', needs => 'write' ), '');

is($app->check_access( user => undef, repository => 'anonymouswrite', needs => 'none' ), 1);
is($app->check_access( user => undef, repository => 'anonymouswrite', needs => 'read' ), 1);
is($app->check_access( user => undef, repository => 'anonymouswrite', needs => 'write' ), 1);
is($app->check_access( user => $group1_user, repository => 'anonymouswrite', needs => 'none' ), 1);
is($app->check_access( user => $group1_user, repository => 'anonymouswrite', needs => 'read' ), 1);
is($app->check_access( user => $group1_user, repository => 'anonymouswrite', needs => 'write' ), 1);

is($app->check_access( user => undef, repository => 'loggedread', needs => 'none' ), 1);
is($app->check_access( user => undef, repository => 'loggedread', needs => 'read' ), '');
is($app->check_access( user => undef, repository => 'loggedread', needs => 'write' ), '');
is($app->check_access( user => $group1_user, repository => 'loggedread', needs => 'none' ), 1);
is($app->check_access( user => $group1_user, repository => 'loggedread', needs => 'read' ), 1);
is($app->check_access( user => $group1_user, repository => 'loggedread', needs => 'write' ), '');

is($app->check_access( user => undef, repository => 'loggedwrite', needs => 'none' ), 1);
is($app->check_access( user => undef, repository => 'loggedwrite', needs => 'read' ), '');
is($app->check_access( user => undef, repository => 'loggedwrite', needs => 'write' ), '');
is($app->check_access( user => $group1_user, repository => 'loggedwrite', needs => 'none' ), 1);
is($app->check_access( user => $group1_user, repository => 'loggedwrite', needs => 'read' ), 1);
is($app->check_access( user => $group1_user, repository => 'loggedwrite', needs => 'write' ), 1);

is($app->check_access( user => undef, repository => 'groupaccess', needs => 'none' ), 1);
is($app->check_access( user => undef, repository => 'groupaccess', needs => 'read' ), '');
is($app->check_access( user => undef, repository => 'groupaccess', needs => 'write' ), '');
is($app->check_access( user => $group1_user, repository => 'groupaccess', needs => 'none' ), 1);
is($app->check_access( user => $group1_user, repository => 'groupaccess', needs => 'read' ), 1);
is($app->check_access( user => $group1_user, repository => 'groupaccess', needs => 'write' ), '');

is($app->check_access( user => undef, repository => 'groupaccess', needs => 'none' ), 1);
is($app->check_access( user => undef, repository => 'groupaccess', needs => 'read' ), '');
is($app->check_access( user => undef, repository => 'groupaccess', needs => 'write' ), '');
is($app->check_access( user => $group4_user, repository => 'groupaccess', needs => 'none' ), 1);
is($app->check_access( user => $group4_user, repository => 'groupaccess', needs => 'read' ), 1);
is($app->check_access( user => $group4_user, repository => 'groupaccess', needs => 'write' ), 1);

isa_ok($app->hasher, 'Crypt::SaltedHash');
is($app->hasher->{algorithm}, $app->settings->digest, 'hasher is using the proper algorithm');
