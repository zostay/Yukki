#!/usr/bin/env perl
use strict;
use warnings;

use lib 't/lib';
use Test::More;
use HTTP::Request::Common;
use Plack::Test;
use File::Temp qw( tempdir );
use Yukki::Test;
use URI;

yukki_setup;
yukki_add_user(
    username => 'bob',
    password => 'bob', # Too cliche?
    fullname => 'Bob Bobson',
    email    => 'bob@example.com',
    groups   => [ 'bob', 'bobdog' ],
);

yukki_git_init('yukki');
yukki_git_init('main');

my $app = require "bin/yukki.psgi";
ok $app, 'got an app';
is ref $app, 'CODE', 'got a code';

test_psgi
    app => $app,
    client => sub {
        my $cb = shift;

        my $res = $cb->(GET "/");
        like $res->content, qr{Yukki software}, 'got something back';

        $res = $cb->(POST "/login/submit", [
            login_name => 'bob',
            password   => 'bob',
        ]);

        is $res->code, 302, 'got main wiki redirect';
        my $loc = URI->new($res->header('Location'));
        is $loc->path, '/page/view/main', 'redirect goes where we expect';

        $res = $cb->(GET "/page/view/main");

        like $res->content, qr{<title class="main-title">Main</title>}, 'got to the main wiki page';
    };

done_testing;
