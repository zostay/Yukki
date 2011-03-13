#!/usr/bin/env perl
use strict;
use warnings;

use Plack::App::File;
use Plack::Builder;
use YAML qw( LoadFile );

use Yukki::Web;

my $config_file = $ENV{YUKKI_CONFIG};
die "please make YUKKI_CONFIG point to the configuration file\n" 
    unless $config_file;

my $settings = LoadFile($config_file);

my $server = Yukki::Web->new( settings => $settings );
my $app = sub {
    my $env = shift;
    return $server->dispatch($env);
};

builder {
    mount "/style"  => Plack::App::File->new( root => $server->locate_dir('static_path', 'style') );
    mount "/script" => Plack::App::File->new( root => $server->locate_dir('static_path', 'script') );

    mount "/"       => builder { 
        enable 'Session';

        $app;
    };
};
