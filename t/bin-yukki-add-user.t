#!/usr/bin/env perl
use 5.12.1;

use File::Temp qw( tempdir );
use IPC::Run3;
use Probe::Perl;
use Test::More tests => 9;
use Test::Script;
use Try::Tiny;
use YAML qw( LoadFile );

$File::Temp::KEEP_ALL = 1 if $ENV{YUKKI_TEST_KEEP_FILES};

script_compiles('bin/yukki-add-user', 'yukki-add-user compiles');

my $tempdir = tempdir;
diag("TEMPDIR = $tempdir") if $ENV{YUKKI_TEST_KEEP_FILES};

script_runs([ 'bin/yukki-setup', "$tempdir/yukki-test" ], 
    'yukki-setup runs');

ok(-d "$tempdir/yukki-test", 'created the test directory');
ok(!-f "$tempdir/yukki-test/var/db/users/foo", 
    'the user we are about to create does not exist yet');

# I can't use script_runs() here because I need to send input
my $perl = Probe::Perl->find_perl_interpreter;

my $stdin  = qq[foo
secret
Foo Bar
foo\@bar.com
some_group
another_group
];
my $stdout = '';
my $stderr = '';

$ENV{YUKKI_CONFIG} = "$tempdir/yukki-test/etc/yukki.conf";
try { 
    my $rv = run3([ $perl, '-Mblib', 'bin/yukki-add-user' ], 
        \$stdin, \$stdout, \$stderr);

    my $exit   = $? ? ($? >> 8) : 0;
    my $ok     = !! ( $rv and $exit == 0 );

    is($exit, 0, 'bin/yukki-add-user exits normally');
    diag("$exit - $stdout - $stderr") unless $ok;
}

catch {
    fail($_);
};

ok(-f "$tempdir/yukki-test/var/db/users/foo",
    'the user file has been created');

my $user = LoadFile("$tempdir/yukki-test/var/db/users/foo");
my $password = delete $user->{password};
is_deeply($user, {
    login_name => 'foo',
    name       => 'Foo Bar',
    email      => 'foo@bar.com',
    groups     => [ 'some_group', 'another_group' ],
}, 'the user was created correctly');

use_ok('Yukki');
my $app = Yukki->new;
my $digest = $app->hasher;

ok(scalar $digest->validate($password, 'secret'), 'password is valid');
