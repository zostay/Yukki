package Yukki::Web::View;
use 5.12.1;
use Moose;

use MooseX::Params::Validate;
use Path::Class;
use Scalar::Util qw( blessed reftype );
use Template::Semantic;
use Text::MultiMarkdown;
use XML::Twig;

has app => (
    is          => 'ro',
    isa         => 'Yukki::Web',
    required    => 1,
    weak_ref    => 1,
    handles     => 'Yukki::Role::App',
);

has markdown => (
    is          => 'ro',
    isa         => 'Text::MultiMarkdown',
    required    => 1,
    lazy_build  => 1,
    handles     => {
        'format_markdown' => 'markdown',
    },
);

sub _build_markdown {
    Text::MultiMarkdown->new(
        markdown_in_html_blocks => 1,
    );
}

has semantic => (
    is          => 'ro',
    isa         => 'Template::Semantic',
    required    => 1,
    lazy_build  => 1,
);

sub _build_semantic { 
    my $self = shift;

    my $semantic = Template::Semantic->new;

    # TODO Maybe nice to have?
    # $semantic->define_filter(markdown => sub { \ $self->format_markdown($_) });
    # $semantic->define_filter(yukkitext => sub { \ $self->yukkitext($_) });

    return $semantic;
}

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
                warn "PLAIN REPLACE: ", $node->sprint, "\n";
                $_->delete for $node->children;
                warn "PLAIN PASTE: ", $node_like, "\n";
                XML::Twig::Elt->new('#PCDATA', $node_like)->paste($node);
            }); 
        }

        when (ref eq 'SCALAR') {
            @nodes = (sub {
                my $node = shift;
                warn "SCALAR REPLACE: ", $node->sprint, "\n";
                $_->delete for $node->children;

                my $xml = XML::Twig->new;
                $xml->parse($$node_like);
                warn "SCALAR PASTE: ", $xml->root->sprint, "\n";
                $xml->root->paste($node);
            });
        }

        when (ref eq 'CODE') {
            @nodes = ($node_like);
        }

        when (blessed $_ and $_->isa('XML::Twig::Elt')) { 
            @nodes = (sub { 
                my $node = shift;
                warn "ELT REPLACE: ", $node->sprint, "\n";
                $_->delete for $node->children;
                
                warn "ELT PASTING: ", $node->sprint, "\n";
                $node_like->paste($node);
            }) 
        }

        when (reftype $_ eq 'HASH') {
            @nodes = (sub {
                my $node = shift;
                while (my ($name, $value) = each %$node_like) {
                    if ($name eq '_content') {
                        warn "HASH _CONTENT REPLACE ", $node->sprint, "\n";
                        $_->delete for $node->children;

                        my (@subnodes) = $self->node_constructors($value);
                        for my $constructor (@subnodes) {
                            warn "SUBNODE START\n";
                            $constructor->($node);
                            warn "SUBNODE END\n";
                        }
                        warn "HASH _CONTENT REPLACED ", $node->sprint, "\n";
                    }
                    else {
                        warn "HASH REPLACE ATTR $name\n";
                        $node->set_att($name, $value);
                        warn "HASH REPLACED ATTR $name: ", $node->sprint, "\n";
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

sub render_page {
    my ($self, $template, $ctx, $vars) = validated_list(\@_,
        template   => { isa => 'Str', coerce => 1 },
        context    => { isa => 'Yukki::Web::Context' },
        vars       => { isa => 'HashRef', default => {} },
    );

    my $messages = $self->render(
        template => 'messages.html', 
        vars     => {
            '.error'   => [ map { +{ '.' => $_ } } $ctx->list_errors   ],
            '.warning' => [ map { +{ '.' => $_ } } $ctx->list_warnings ],
            '.info'    => [ map { +{ '.' => $_ } } $ctx->list_info     ],
        },
    );

    my $main_title;
    if ($ctx->response->has_page_title) {
        $main_title = $ctx->response->page_title . ' - Yukki';
    }
    else {
        $main_title = 'Yukki';
    }

    return $self->render(
        template   => 'shell.html',
        vars       => {
            '#messages'   => $messages,
            '.main-title' => $main_title,
            '.navigation' => [ map { 
                { 'a' => $_->{label}, 'a@href' => $_->{href} },
            } $ctx->response->navigation_menu ],
            '#content'    => $self->render(template => $template, vars => $vars),
        },
    );
}

sub render_links {
    my ($self, $links) = validated_list(\@_,
        links    => { isa => 'ArrayRef[HashRef]' },
    );

    return $self->render(
        template => 'links.html',
        vars     => {
            'li' => [ map {
                { 'a' => $_->{label}, 'a@href' => $_->{href} },
            } @$links ],
        },        
    );
}

sub render {
    my ($self, $template, $vars) = validated_list(\@_,
        template   => { isa => 'Str', coerce => 1 },
        vars       => { isa => 'HashRef', default => {} },
    );
    
    my $template_file = $self->locate('template_path', $template);

    return $self->semantic->process($template_file, $vars);
}

#sub render {
#    my ($self, $template, $ctx, $actions, $in_wrapper, $to_string) = validated_list(\@_,
#        template   => { isa => 'Str', coerce => 1 },
#        context    => { isa => 'Yukki::Web::Context' },
#        actions    => { isa => 'HashRef', default => {} },
#        in_wrapper => { isa => 'Bool', default => 0 },
#        to_string  => { isa => 'Bool', default => 1 },
#    );
#
#    my $template_file = $self->locate('template_path', $template);
#
#    my $document = XML::Twig->new;
#    $document->parsefile($template_file);
#
#    while (my ($path, $replacement) = each %$actions) {
#        my @nodes = $self->select_nodes($document, $path);
#        $self->replace_nodes($replacement, $ctx, @nodes);
#    }
#
#    if ($in_wrapper) {
#        my $nav = sub {
#            my $nav = $_;
#            sub {
#                my $node = shift;
#                my $a = $node->first_descendant('a');
#                $a->set_att(href => $nav->{href});
#                $a->set_text($nav->{label});
#            };
#        };
#
#        return $self->render(
#            in_wrapper => 0,
#            to_string  => $to_string,
#            template   => 'shell.html',
#            context    => $ctx,
#            actions    => {
#                '#messages'  => sub {
#                    $self->render(
#                        in_wrapper => 0,
#                        to_string  => 0,
#                        template   => 'messages.html',
#                        context    => $ctx,
#                        actions    => {
#                            '.error'      => [ $ctx->list_errors   ],
#                            '.warning'    => [ $ctx->list_warnings ],
#                            '.info'       => [ $ctx->list_info     ],
#                        },
#                    );
#                },
#                '.main-title' => sub {
#                    if ($ctx->response->has_page_title) {
#                        return $ctx->response->page_title . ' - Yukki';
#                    }
#                    else {
#                        return 'Yukki';
#                    }
#                },
#                '.navigation' => [ map { $nav->() } $ctx->response->navigation_menu ],
#                '#content' => $document->root,
#            },
#        );
#    }
#    elsif ($to_string) {
#        return $document->sprint;
#    }
#    else {
#        return $document->root;
#    }
#}

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
            ([\w/.\-]+) \s*     # link/to/page is mandatory

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

    return '<div>' . $self->format_markdown($yukkitext) . '</div>';
}

1;
