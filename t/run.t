#!/usr/bin/env perl
use strict;
use warnings;

use lib 't/lib';
use Test::More;
use HTTP::Request::Common;
use Plack::Test;
use File::Temp qw( tempdir );
use Yukki::Test;

yukki_setup;

#system(qw( bin/yukki-git-init

my $app = require "bin/yukki.psgi";
ok $app, 'got an app';
is ref $app, 'CODE', 'got a code';

test_psgi
    app => $app,
    client => sub {
        my $cb = shift;

        my $res = $cb->(GET "/");
        like $res->content, qr{Yukki software}, 'got something back';
    };

done_testing;
