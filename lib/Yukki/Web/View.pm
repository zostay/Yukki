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
    
    my @nav_menu = grep { 
        my $match = $self->app->router->match($_->{href});
        my $access_level_needed = $match->access_level;
        $self->check_access(
            user       => $ctx->session->{user},
            repository => $match->mapping->{repository} // '-',
            needs      => $access_level_needed,
        );
    } $ctx->response->navigation_menu;

    return $self->render(
        template   => 'shell.html',
        vars       => {
            '#messages'   => $messages,
            '.main-title' => $main_title,
            '#navigation .navigation' => [ map { 
                { 'a' => $_->{label}, 'a@href' => $_->{href} },
            } @nav_menu ],
            '#bottom-navigation .navigation' => [ map { 
                { 'a' => $_->{label}, 'a@href' => $_->{href} },
            } @nav_menu ],
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

sub yukkilink {
    my ($self, $params) = @_;

    my $repository = $params->{repository};
    my $link       = $params->{link};
    my $label      = $params->{label} // $link;

    ($repository, $link) = split /:/, 2 if $link =~ /:/;

    $label =~ s/^\s*//; $label =~ s/\s*$//;
    return qq{<a href="/page/view/$repository/$link">$label</a>};
}

sub yukkiplugin {
    my ($self, $params) = @_;

    my $plugin_name = $params->{plugin_name};
    my $arg         = $params->{arg};

    # TODO Not very pluggable yet
    return "{{$plugin_name:$arg}}" unless $plugin_name eq 'attachment';

    if ($arg =~ m{

            ^\s*

                (?: ([\w]+) : )?    # repository: is optional
                ([\w/.\-]+)         # link/to/page is mandatory

            \s*$

            }x) {

        my $repository = $1 // $params->{repository};
        my $page       = $params->{page};
        my $link       = $2;

        $page =~ s{\.yukki$}{};

        if ($link =~ m{^/}) {
            return "/attachment/view/$repository$link";
        }
        else {
            return "/attachment/view/$repository/$page/$link";
        }
    }
    
    return "{{$plugin_name:$arg}}";
}

sub yukkitext {
    my ($self, $params) = @_;

    my $repository = $params->{repository};
    my $yukkitext  = $params->{yukkitext};

    # Yukki Links
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

    # Yukki Plugins
    $yukkitext =~ s{
        \{\{ \s*                # {{ to start it

            ([\w]+) :           # plugin_name: is required

            (.*)                # plugin arguments

        \}\}                    # }} to end
    }{
        $self->yukkiplugin({
            %$params,

            plugin_name => $1,
            arg         => $2,
        });
    }xeg;

    return '<div>' . $self->format_markdown($yukkitext) . '</div>';
}

1;
