#!/usr/bin/perl
use v5.24;

use lib 't/lib';
use Yukki::Test;

use Test2::V0;

use ok('Yukki');

yukki_setup;
yukki_git_init('main');

my $app = Yukki->new;
my $repo = $app->model('Repository', { name => 'main' });

my $file = $repo->file({
    path     => 'home',
    filetype => 'yukki',
});

is $file->path, 'home', 'home.yukki path is home';
is $file->filetype, 'yukki', 'home.yukki filetype is yukki';
is $file->repository, $repo, 'has a repo';
is $file->full_path, 'home.yukki', 'home.yukki full_path is home.yukki';
is $file->file_name, 'home.yukki', 'home.yukki file_name is home.yukki';
like $file->file_id, qr/^[a-f0-9]{40}$/, 'home.yukki file_id looks like a SHA';
like $file->object_id, qr/^[a-f0-9]{40}$/, 'home.yukki object_id looks like a SHA';
is $file->title, 'Main', 'home.yukki title is Main';
is $file->file_size, 119, 'default home.yukki has the expected number of bytes';
is $file->formatted_file_size, 119, 'formatted_bytes outputs as expected too';

done_testing;
