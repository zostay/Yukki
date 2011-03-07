package Yukki::Web::View;
use 5.12.1;
use Moose;

use MooseX::Params::Validate;
use Path::Class;
use Scalar::Util qw( blessed reftype );
use XML::Twig;

has app => (
    is          => 'ro',
    isa         => 'Yukki::Web',
    required    => 1,
    weak_ref    => 1,
    handles     => 'Yukki::Role::App',
);

sub render {
    my ($self, $template, $req, $actions, $in_wrapper, $to_string) = validated_list(\@_,
        template   => { isa => 'Str', coerce => 1 },
        request    => { isa => 'Yukki::Web::Request' },
        actions    => { isa => 'HashRef', default => {} },
        in_wrapper => { isa => 'Bool', default => 0 },
        to_string  => { isa => 'Bool', default => 1 },
    );

    my $template_file = $self->locate('template_path', $template);

    my $document = XML::Twig->new;
    $document->parsefile($template_file);

    while (my ($path, $code) = each %$actions) {
        my @nodes;
        given ($path) {
            when (/^#(.*)$/)  { @nodes = ($document->elt_id($1)) }
            when (/^\.(.*)$/) { 
                @nodes = $document->root->descendants(sub { 
                    my $class = $_[0]->att('class');
                    defined $class and $class eq $1;
                });
            }
            default           { @nodes = $document->root->descendants($path) }
        }

        for my $node (@nodes) {
            my $result = $code->($req, $node);

            my $replacement_node;
            given ($result) {
                when (not ref) { $replacement_node = XML::Twig::Elt->new('#PCDATA', $_); }

                when (ref $_ eq 'SCALAR') {
                    my $xml = XML::Twig->new;
                    $xml->parse($$_);
                    $replacement_node = $xml->root;
                }

                when (blessed $_ and $_->isa('XML::Twig::Elt')) { $replacement_node = $_ }

                when (reftype $_ eq 'HASH') {
                    while (my ($name, $value) = each %$_) {
                        if ($name eq '_content') {
                            $node->inner_xml($value);
                        }
                        else {
                            $node->set_att($name, $value);
                        }
                    }
                }

                when (reftype $_ eq 'ARRAY') {
                    my $after_node = $node;

                    my $paste_node;
                    for my $result (@$_) {
                        when (not ref) {
                            $paste_node = XML::Path::Elt->new('#PCDATA', $_);
                        }
                        when (ref $_ eq 'SCALAR') {
                            my $xml = XML::Twig->new;
                            $xml->parse($$_);
                            $paste_node = $xml->root;
                        }
                        when (blessed $_ and $_->isa('XML::Twig::Elt')) {
                            $paste_node = $_;
                        }
                        when (reftype $_ eq 'HASH') {
                            my $paste_node = $node->copy;
                            while (my ($name, $value) = each %$_) {
                                if ($name eq '_content') {
                                    $paste_node->inner_xml($value);
                                }
                                else {
                                    $paste_node->set_att($name, $value);
                                }
                            }
                        }
                        default {
                            Yukki::Error->throw("unsure how to render '$_'");
                        }

                        $paste_node->paste(after => $after_node);
                        $after_node = $paste_node;
                    }

                    $node->cut;
                }
                default {
                    Yukki::Error->throw("unsure how to render '$_'");
                }
            }

            if ($replacement_node) {
                $_->delete for $node->children;
                $replacement_node->paste($node);
            }
        }
    }

    if ($in_wrapper) {
        return $self->render(
            in_wrapper => 0,
            to_string  => $to_string,
            template   => 'shell.html',
            request    => $req,
            actions    => {
                '#messages'  => sub {
                    $self->render(
                        in_wrapper => 0,
                        to_string  => 0,
                        template   => 'messages.html',
                        request    => $req,
                        actions    => {
                            '.error'   => sub { [ $req->list_errors   ] },
                            '.warning' => sub { [ $req->list_warnings ] },
                            '.info'    => sub { [ $req->list_info     ] },
                        },
                    );
                },
                '#content' => sub { $document->root },
            },
        );
    }
    elsif ($to_string) {
        return $document->sprint;
    }
    else {
        return $document->root;
    }
}

1;
