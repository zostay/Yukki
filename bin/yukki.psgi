#!/usr/bin/env perl
use strict;
use warnings;

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
    enable 'Session';

    $app;
};
