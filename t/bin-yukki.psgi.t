#!/usr/bin/env perl
use 5.12.1;

use Test2::V0;
use Test::Script;

plan 1;

script_compiles('bin/yukki.psgi', 'yukki.psgi compiles');

