#!/usr/bin/env perl
use strict;
use warnings;

use Plack::App::File;
use Plack::Builder;
use YAML qw( LoadFile );

use Yukki::Web;

my $server = Yukki::Web->new;
my $app = sub {
    my $env = shift;
    return $server->dispatch($env);
};

builder {
    mount "/style"    => Plack::App::File->new( root => $server->locate_dir('static_path', 'style') );
    mount "/script"   => Plack::App::File->new( root => $server->locate_dir('static_path', 'script') );
    mount "/template" => Plack::App::File->new( root => $server->locate_dir('static_path', 'template') );

    mount "/"       => builder { 
        enable 'Session';

        $app;
    };
};
