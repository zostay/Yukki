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

sub select_nodes {
    my ($self, $document, $path) = @_;

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

    return @nodes;
}

sub node_constructors {
    my ($self, $node_like) = @_;
    my @nodes;

    given ($node_like) {
        when (not ref) { 
            @nodes = (sub { 
                my $node = shift;
                $_->delete for $node->children;
                XML::Twig::Elt->new('#PCDATA', $node_like)->paste($node);
            }); 
        }

        when (ref $_ eq 'SCALAR') {
            @nodes = (sub {
                my $node = shift;
                $_->delete for $node->children;

                my $xml = XML::Twig->new;
                $xml->parse($$node_like);
                $xml->root->paste($node);
            });
        }

        when (blessed $_ and $_->isa('XML::Twig::Elt')) { 
            @nodes = (sub { 
                my $node = shift;
                $_->delete for $node->children;
                
                $node_like->paste($node);
            }) 
        }

        when (reftype $_ eq 'HASH') {
            @nodes = (sub {
                my $node = shift;
                while (my ($name, $value) = each %$_) {
                    if ($name eq '_content') {
                        $_->delete for $node->children;

                        my $xml = XML::Twig->new;
                        $xml->parse($value);
                        $xml->root->paste($node);
                    }
                    else {
                        $node->set_att($name, $value);
                    }
                }
            });
        }

        # Flattening is necessary and intentional
        when (reftype $_ eq 'ARRAY') {
            @nodes = map { $self->construct_node($_) } @$node_like;
        }

        default {
            Yukki::Error->throw("unsure how to render '$_'");
        }
    }

    return @nodes;
}

sub replace_nodes {
    my ($self, $replacement, $request, @nodes) = @_;

    NODE: for my $node (@nodes) {
        $replacement = $replacement->($request, $node) if ref $replacement eq 'CODE';

        next NODE unless defined $replacement;

        my @replacement_nodes = $self->node_constructors($replacement);

        my $after_node = $node;
        for my $node_constructor (@replacement_nodes) {
            my $new_node = $node->copy;
            $node_constructor->($new_node);
            $new_node->paste(after => $after_node);
            $after_node = $new_node;
        }

        $node->delete;
    }
}

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

    while (my ($path, $replacement) = each %$actions) {
        my @nodes = $self->select_nodes($document, $path);
        $self->replace_nodes($replacement, $req, @nodes);
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
                            '.navigation' => sub { [ $req->navigation    ] },
                            '.error'      => sub { [ $req->list_errors   ] },
                            '.warning'    => sub { [ $req->list_warnings ] },
                            '.info'       => sub { [ $req->list_info     ] },
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
