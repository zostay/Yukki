#!/usr/bin/env perl

use v5.24;

use lib 't/lib';
use Test2::V0;
use HTTP::Cookies;
use HTTP::Request::Common;
use Plack::Test;
use Yukki::Test;
use URI;

yukki_setup;
yukki_add_user(
    username => 'bob',
    password => 'bob',
    fullname => 'Bob Bobson',
    email    => 'bob@example.com',
    groups   => [ 'bob', 'bobdog' ],
);

yukki_git_init('yukki');
yukki_git_init('main');

my $app = require "bin/yukki.psgi";
my $host = "http://127.0.0.1";
my $jar = HTTP::Cookies->new;

test_psgi
    app => $app,
    client => sub {
        my $cb = shift;
        my ($res, $req);

        $req = GET "$host/page/edit/main/home.yukki";
        $res = $cb->($req);
        like $res->content, qr/\bPlease login\b/, 'without cookie, asked to login on edit page';

        $res = $cb->(POST "$host/login/submit", [
            login_name => 'bob',
            password   => 'bob',
        ]);

        is $res->code, '302', 'got redirect';
        my $loc = URI->new($res->header('Location'));
        is $loc->path, '/page/view/main', 'redirect goes to main page';

        $jar->extract_cookies($res);

        $req = GET "$host/page/view/main";
        $jar->add_cookie_header($req);
        $res = $cb->($req);
        like $res->content, qr/\bMain - Yukki\b/, 'got the main wiki home page';
        like $res->content, qr/\bBob Bobson\b/, 'confirm login worked';

        $req = GET "$host/page/edit/main/home.yukki";
        $jar->add_cookie_header($req);
        $res = $cb->($req);
        like $res->content, qr/<textarea\b/, 'got a wiki edit page';
    };

done_testing;
