#!/usr/bin/env perl
use 5.12.1;

use Test::More tests => 1;
use Test::Script;

script_compiles('bin/yukki-add-user', 'yukki-add-user compiles');

