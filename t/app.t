#!/usr/bin/env perl
use 5.12.1;

use Test::More tests => 7;
use Test::Exception;
use Test::Moose;

use Path::Class;

use_ok('Yukki');

my $app = Yukki->new;
isa_ok($app, 'Yukki');
does_ok($app, 'Yukki::Role::App');

throws_ok { $app->config_file } qr/make YUKKI_CONFIG point/, 'missing config location complains';

$ENV{YUKKI_CONFIG} = 't/test-site/etc/bad-yukki.conf';

throws_ok { $app->config_file} qr/no configuration found/i, 'missing config file complains';

delete $ENV{YUKKI_CONFIG};
chdir 't/test-site';

is($app->config_file, file(dir(), 'etc', 'yukki.conf'), 'config set by CWD works');

delete $app->{config_file};
chdir '../..';
$ENV{YUKKI_CONFIG} = 't/test-site/etc/yukki.conf';

is($app->config_file, file(dir(), 't', 'test-site', 'etc', 'yukki.conf'), 'config set by env works');
