#!/usr/bin/env perl
use 5.12.1;

use Test2::V0;

use ok('Yukki::Error');
can_ok('Yukki::Error', 'throw');

done_testing;
