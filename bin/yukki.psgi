#!/usr/bin/env plackup
use v5.24;
use utf8;


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
    mount "/style"    => Plack::App::File->new( root => $server->locate_dir('static_path', 'style') )->to_app;
    mount "/script"   => Plack::App::File->new( root => $server->locate_dir('static_path', 'script') )->to_app;
    mount "/template" => Plack::App::File->new( root => $server->locate_dir('static_path', 'template') )->to_app;

    mount "/"       => builder {
        enable $server->session_middleware;

        $app;
    };
};

# ABSTRACT: the Yukki web application
# PODNAME: yukki.psgi

=head1 SYNOPSIS

  yukki.psgi

=head1 DESCRIPTION

If you have L<Plack> installed, you should be able to run this script from the
command line to start a simple test server. It is not recommend that you use
this web server in production.

See L<Yukki::Manual::Installation>.

=head1 ENVIRONMENT

Normally, this script tries to find F<etc/yukki.conf> from the current working
directory. If no configuraiton file is found, it checks C<YUKKI_CONFIG> for the
path to this file.

=cut
