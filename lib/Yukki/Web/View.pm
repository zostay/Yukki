package Yukki::Web::View;
use 5.12.1;
use Moose;

use MooseX::Params::Validate;
use Path::Class;
use Scalar::Util qw( blessed reftype );
use Spreadsheet::Engine;
use Template::Semantic;
use Text::MultiMarkdown;
use Try::Tiny;
use XML::Twig;

# ABSTRACT: base class for Yukki::Web views

=head1 DESCRIPTION

This is the base class for all L<Yukki::Web> views.

=head1 ATTRIBUTES

=head2 app

This is the L<Yukki::Web> singleton.

=cut

has app => (
    is          => 'ro',
    isa         => 'Yukki::Web',
    required    => 1,
    weak_ref    => 1,
    handles     => 'Yukki::Role::App',
);

=head2 markdown

This is the L<Text::MultiMarkdown> object for rendering L</yukkitext>. Do not
use.

Provides a C<format_markdown> method delegated to C<markdown>. Do not use.

=cut

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
        heading_ids             => 0,
    );
}

=head2 semantic

This is the L<Template::Semantic> object that transforms the templates. Do not use.

=cut

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

=head1 METHODS

=head2 render_page

  my $document = $self->render_page({
      template => 'foo.html',
      context  => $ctx,
      vars     => { ... },
  });

This renders the given template and places it into the content section of the
F<shell.html> template.

The C<context> is used to render parts of the shell template.

The C<vars> are processed against the given template with L<Template::Semantic>.

=cut

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
        $main_title = 'Yukki - ' . $ctx->response->page_title;
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

    my @scripts = $self->app->settings->all_scripts;
    my @styles  = $self->app->settings->all_styles;

    my $b = sub { $ctx->rebase_url($_[0]) };

    return $self->render(
        template   => 'shell.html',
        vars       => {
            'head script.local' => [ map { { '@src'  => $b->($_) } } @scripts ],
            'head link.local'   => [ map { { '@href' => $b->($_) } } @styles ],
            '#messages'   => $messages,
            '.main-title' => $main_title,
            '#navigation .navigation' => [ map { 
                { 'a' => $_->{label}, 'a@href' => $b->($_->{href}) },
            } @nav_menu ],
            '#bottom-navigation .navigation' => [ map { 
                { 'a' => $_->{label}, 'a@href' => $b->($_->{href}) },
            } @nav_menu ],
            '#breadcrumb li' => [ map {
                { 'a' => $_->{label}, 'a@href' => $b->($_->{href}) },
            } $ctx->response->breadcrumb_links ],
            '#content'    => $self->render(template => $template, vars => $vars),
        },
    )->{dom}->toStringHTML;
}

=head2 render_links

  my $document = $self->render_links(\@navigation_links);

This renders a set of links using the F<links.html> template.

=cut

sub render_links {
    my ($self, $ctx, $links) = validated_list(\@_,
        context  => { isa => 'Yukki::Web::Context' },
        links    => { isa => 'ArrayRef[HashRef]' },
    );

    my $b = sub { $self->rebae_url($ctx, $_[0]) };

    return $self->render(
        template => 'links.html',
        vars     => {
            'li' => [ map {
                { 'a' => $_->{label}, 'a@href' => $b->($_->{href}) },
            } @$links ],
        },        
    );
}

=head2 render

  my $document = $self->render({
      template => 'foo.html',
      vars     => { ... },
  });

This renders the named template using L<Template::Semantic>. The C<vars> are
used as the ones passed to the C<process> method.

=cut

sub render {
    my ($self, $template, $vars) = validated_list(\@_,
        template   => { isa => 'Str', coerce => 1 },
        vars       => { isa => 'HashRef', default => {} },
    );
    
    my $template_file = $self->locate('template_path', $template);
    
    return $self->semantic->process($template_file, $vars);
}

=head2 has_format

  my $yes_or_no = $self->has_format($media_type);

Returns true if the named media type has a format plugin.

=cut

sub has_format {
    my ($self, $media_type) = @_;

    my @formatters = $self->app->formatter_plugins;
    for my $formatter (@formatters) {
        return 1 if $formatter->has_format($media_type);
    }

    return '';
}

=head2 format

  my $html = $self->format({
      context    => $ctx,
      repository => $repository,
      page       => $full_path,
      media_type => $media_type,
      content    => $content,
  });

Finds a formatter and renders the text as HTML. If no formatter exists, it returns C<undef>.

=cut

sub format {
    my ($self, $params) = @_;

    my $media_type = $params->{media_type};

    my $formatter;
    for my $plugin ($self->app->formatter_plugins) {
        return $plugin->format($params) if $plugin->has_format($media_type);
    }

    return;
}

1;
