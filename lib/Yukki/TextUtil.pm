package Yukki::TextUtil;

use v5.24;
use utf8;

use Encode ();
use IO::Prompter ();
use Path::Tiny;
use YAML ();

use namespace::clean;

# ABSTRACT: Utilities to help make everything happy UTF-8

=head1 DESCRIPTION

Yukki aims at fully supporting UTF-8 in everything it does. Please report any bugs you find. This library exports tools used internally to help make sure that input is decoded from UTF-8 on the way in and encoded into UTF-8 on the way out.

=cut

use Sub::Exporter -setup => {
    exports => [ qw(
        dump_file
        load_file
        prompt
    ) ],
};

=head1 SUBROUTINES

=head2 dump_file

    dump_file($file, $data);

This is pretty much identical in purpose to L<YAML/DumpFile>, but encodes to UTF-8 on the way out.

=cut

sub dump_file {
    my ($file, $data) = @_;
    path($file)->spew_utf8(YAML::Dump($data));
}

=head2 load_file

    $data = load_file($file);

This is similar to L<YAML/LoadFile>, but decodes from UTF-8 while reading input.

=cut

sub load_file {
    my ($file) = @_;
    YAML::Load(path($file)->slurp_utf8);
}

=head2 prompt

    $value = prompt(...);

This is similar to L<IO::Prompter/prompt>, but decodes UTF-8 in the input.

=cut

sub prompt {
    Encode::decode('UTF-8', IO::Prompter::prompt(@_));
}

1;
