#!/usr/bin/env perl
use strict;
use warnings;

use Test::More;
use HTTP::Request::Common;
use Plack::Test;
use File::Temp qw( tempdir );

my $tmp = tempdir( CLEANUP => 1 );

system(qw( perl bin/yukki-setup ), $tmp) == 0
    or die "cannot run yukki-setup: $!";

$ENV{YUKKI_CONFIG} = "$tmp/etc/yukki.conf";

#system(qw( bin/yukki-git-init

my $app = require "bin/yukki.psgi";
ok $app, 'got an app';
cmp_ok ref $app, 'CODE', 'got a code';

test_psgi
    app => $app,
    client => sub {
        my $cb = shift;

        my $res = $cb->(GET "/");
        like $res->content, qr{Yukki software}, 'got something back';
    };

done_testing;
