#!/usr/bin/env perl
use 5.12.1;

use Test::More tests => 6;
use Test::Script;
use File::Temp qw( tempdir );
use YAML qw( LoadFile );

$File::Temp::KEEP_ALL = 1 if $ENV{YUKKI_TEST_KEEP_FILES};

script_compiles('bin/yukki-setup', 'yukki-setup compiles');

my $tempdir = tempdir;
diag("TEMPDIR = $tempdir") if $ENV{YUKKI_TEST_KEEP_FILES};

script_runs([ 'bin/yukki-setup', "$tempdir/yukki-test" ], 
    'yukki-setup runs');

ok(-d "$tempdir/yukki-test", 'created the test directory');
ok(-f "$tempdir/yukki-test/etc/yukki.conf", 'created the yukki.conf');
ok(-f "$tempdir/yukki-test/root/template/shell.html", 
    'created the shell.html template');

my $data = LoadFile("$tempdir/yukki-test/etc/yukki.conf");
is($data->{root}, "$tempdir/yukki-test", 
    'yukki.conf has the expected root setting');
