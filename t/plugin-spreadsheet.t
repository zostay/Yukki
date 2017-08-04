#!/usr/bin/env perl
use v5.24;

use Test2::V0;

use ok('Yukki::Web::Context');
use ok('Yukki::Web::Plugin::Spreadsheet');

my $mock_app = mock 'Yukki::Web' => (
    add_constructor => [new => 'hash'],
);

my $mock_file = mock 'Yukki::Model::File' => (
    add_constructor => [new => 'hash'],
    add => [
        fetch_formatted => '{=:1+1}',
        repository_name => 'main',
        full_path       => 'test.yukki',
    ],
);

my $app  = Yukki::Web->new;
my $file = Yukki::Model::File->new;
my $ctx  = Yukki::Web::Context->new( env => {} );
my $ss   = Yukki::Web::Plugin::Spreadsheet->new( app => $app );

my $output = $ss->spreadsheet_eval({
    context => $ctx,
    file    => $file,
    arg     => '1+1',
});

is $output, qq[<span title="1+1" class="spreadsheet-cell">2</span>],
    '1+1=2';

done_testing;
