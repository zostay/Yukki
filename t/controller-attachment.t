#!/usr/bin/env perl
use v5.24;

use Test2::V0;

use ok('Yukki::Web::Context');
use ok('Yukki::Web::Controller::Attachment');

my $mock_file = mock 'Yukki::Model::File' => (
    add_constructor => [new => 'hash'],
    add => [
        fetch => 'fake content',
    ],
);

my $mock_repo = mock 'Yukki::Model::Repository' => (
    add_constructor => [new => 'hash'],
    add => [
        file => sub { Yukki::Model::File->new },
    ],
);

my $mock_app = mock 'Yukki::Web' => (
    add_constructor => [new => 'hash'],
    add => [
        model => sub { Yukki::Model::Repository->new },
    ],
);
my $app = Yukki::Web->new;
isa_ok $app, 'Yukki::Web';

my $attachment = Yukki::Web::Controller::Attachment->new(
    app => $app,
);

{
    my $ctx = Yukki::Web::Context->new(
        env => {},
    );

    $ctx->request->path_parameters->{action} = 'invalid';

    like dies {
            $attachment->fire($ctx);
        },
        qr/attachment action does not exist/,
        'no action causes exception';
}

{
    my $ctx = Yukki::Web::Context->new(
        env => {},
    );

    $ctx->request->path_parameters->{action} = 'download';
    $ctx->request->path_parameters->{repository} = 'x';
    $ctx->request->path_parameters->{file} = ['y'];

    $attachment->fire($ctx);

    is $ctx->response->content_type, 'application/octet', 'CT for downloads';
    is $ctx->response->body, ['fake content'], 'response body contains expected content';
}

done_testing;
