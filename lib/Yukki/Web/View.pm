package Yukki::Web::View;
use 5.12.1;
use Moose;

use MooseX::Params::Validate;
use Path::Class;
use Scalar::Util qw( blessed reftype );
use Text::MultiMarkdown qw( markdown );
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

        when (ref $_ eq 'CODE') {
            @nodes = ($_);
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
            @nodes = map { $self->node_constructors($_) } @$node_like;
        }

        default {
            Yukki::Error->throw("unsure how to render '$_'");
        }
    }

    return @nodes;
}

sub replace_nodes {
    my ($self, $replacement, $context, @nodes) = @_;

    NODE: for my $node (@nodes) {
        warn $node->sprint;
        my $replacement = $replacement;
        $replacement = $replacement->($context, $node) if ref $replacement eq 'CODE';

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
    my ($self, $template, $ctx, $actions, $in_wrapper, $to_string) = validated_list(\@_,
        template   => { isa => 'Str', coerce => 1 },
        context    => { isa => 'Yukki::Web::Context' },
        actions    => { isa => 'HashRef', default => {} },
        in_wrapper => { isa => 'Bool', default => 0 },
        to_string  => { isa => 'Bool', default => 1 },
    );

    my $template_file = $self->locate('template_path', $template);

    my $document = XML::Twig->new;
    $document->parsefile($template_file);

    while (my ($path, $replacement) = each %$actions) {
        my @nodes = $self->select_nodes($document, $path);
        $self->replace_nodes($replacement, $ctx, @nodes);
    }

    if ($in_wrapper) {
        my $nav = sub {
            my $nav = $_;
            sub {
                my $node = shift;
                my $a = $node->first_descendant('a');
                $a->set_att(href => $nav->{href});
                $a->set_text($nav->{label});
            };
        };

        return $self->render(
            in_wrapper => 0,
            to_string  => $to_string,
            template   => 'shell.html',
            context    => $ctx,
            actions    => {
                '#messages'  => sub {
                    $self->render(
                        in_wrapper => 0,
                        to_string  => 0,
                        template   => 'messages.html',
                        context    => $ctx,
                        actions    => {
                            '.error'      => [ $ctx->list_errors   ],
                            '.warning'    => [ $ctx->list_warnings ],
                            '.info'       => [ $ctx->list_info     ],
                        },
                    );
                },
                '.main-title' => sub {
                    if ($ctx->response->has_page_title) {
                        return $ctx->response->page_title . ' - Yukki';
                    }
                    else {
                        return 'Yukki';
                    }
                },
                '.navigation' => [ map { $nav->() } $ctx->response->navigation_menu ],
                '#content' => $document->root,
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

sub yukkilink {
    my ($self, $params) = @_;

    my $repository = $params->{repository};
    my $link       = $params->{link};
    my $label      = $params->{label} // $link;

    ($repository, $link) = split /:/, 2 if $link =~ /:/;

    $label =~ s/^\s*//; $label =~ s/\s*$//;
    return qq{<a href="/page/view/$repository/$link">$label</a>};
}

sub yukkitext {
    my ($self, $params) = @_;

    my $repository = $params->{repository};
    my $yukkitext  = $params->{yukkitext};

    $yukkitext =~ s{ 
        \[\[ \s*                # [[ to start it

            (?: ([\w]+) : )?    # repository: is optional
            ([\w/.]+) \s*       # link/to/page is mandatory

            (?: \|              # | to split link from label
                ([^\]]+)        # a pretty label (needs trimming)
            )?                  # is optional

        \]\]                    # ]] to end
    }{ 
        $self->yukkilink({ 
            %$params, 
            
            repository => $1 // $repository, 
            link       => $2, 
            label      => $3,
        });
    }xeg;

    return '<div>' . markdown($yukkitext) . '</div>';
}

1;
