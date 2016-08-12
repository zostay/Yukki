package Yukki::Web::View;

use v5.24;
use Moose;

use File::Slurp qw( read_file );
use MooseX::Params::Validate;
use Path::Class;
use Scalar::Util qw( blessed reftype );
use Spreadsheet::Engine;
use Template::Pure;
use Text::MultiMarkdown;
use Try::Tiny;

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

=head2 messages_template

This is the template used to render info, warning, and error messages to the page.

=cut

has messages_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_messages_template',
);

sub _build_messages_template {
    my $self = shift;
    return $self->prepare_template(
        template   => 'messages.html',
        directives => [
            '.error'   => {
                'error<-errors' => [
                    '.' => 'error',
                ],
            },
            '.warning' => {
                'warning<-warnings' => [
                    '.' => 'warning',
                ],
            },
            '.info'    => {
                'one_info<-info' => [
                    '.' => 'one_info',
                ],
            },
        ],
    );
}

has _page_templates => (
    is          => 'ro',
    isa         => 'HashRef',
    required    => 1,
    default     => sub { +{} },
);

=head2 links_template

This is the template object used to render links.

=cut

has links_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_links_template',
);

sub _build_links_template {
    my $self = shift;
    $self->prepare_template(
        template   => 'links.html',
        directives => [
            'link<-links' => [
                'a'      => 'link.label',
                'a@href' => 'link.href',
                sub {
                    my ($t, $a, $vars) = @_;
                    $vars->{ctx}->rebase_url($vars->{link}{href});
                },
            ],
        ],
    );
}

=head1 METHODS

=head2 page_template

  my $template = $self->page_template('default');

Returns the template used to render pages for the given style name.

=cut

sub page_template {
    my ($self, $which) = @_;

    return $self->_page_templates->{ $which }
        if $self->_page_templates->{ $which };

    my $view = $which // 'default';
    my $view_args = $self->app->settings->page_views->{ $view }
                 // { template => 'shell.html' };
    $view_args->{directives} //= [];

    my %menu_vars = map {
        my $menu_name = $_;
        "#nav-$menu_name .navigation" => {
            "menu_item<-$menu_name" => [
                'a'      => 'menu_item.label',
                'a@href' => 'menu_item.href',
            ],
        },
    } @{ $self->app->settings->menu_names };

    return $self->_page_templates->{ $which } = $self->prepare_template(
        template   => $view_args->{template},
        directives => [
            $view_args->{directives}->@*,
            'head script.local' => {
                'script<-scripts' => [
                    '@src' => 'script',
                ],
            },
            'head link.local'   => {
                'link<-links' => [
                    '@href' => 'link',
                ],
            },
            '#messages'   => 'messages | encoded_string',
            'title'       => 'main_title',
            '.masthead-title' => 'title',
            %menu_vars,
            '#breadcrumb li' => {
                'crumb<-breadcrumb' => [
                    'a'      => 'crumb.label',
                    'a@href' => 'crumb.href',
                ],
            },
            '#content'    => 'content | encoded_string',
        ],
    );
}

=head2 prepare_template

  my $template = $self->prepare_template({
      template   => 'foo.html',
      directives => { ... },
  });

This prepares a template for later rendering.

The C<template> is the name of the template file to use.

The C<directives> are the L<Template::Pure> directives to apply data given at render time to modify the template to create the output.

=cut

sub prepare_template {
    my ($self, $template, $directives) = validated_list(\@_,
        template   => { isa => 'Str', coerce => 1 },
        directives => { isa => 'ArrayRef' },
    );

    my $template_content = read_file(
        $self->app->locate_dir('template_path', $template)
    );

    return Template::Pure->new(
        template   => $template_content,
        directives => $directives,
    );
}

=head2 render_page

  my $document = $self->render_page({
      template => 'foo.html',
      context  => $ctx,
      vars     => { ... },
  });

This renders the given template and places it into the content section of the
F<shell.html> template.

The C<context> is used to render parts of the shell template.

The C<vars> are processed against the given template with L<Template::Pure>.

=cut

sub render_page {
    my ($self, $template, $ctx, $vars) = validated_list(\@_,
        template   => { isa => 'Template::Pure' },
        context    => { isa => 'Yukki::Web::Context' },
        vars       => { isa => 'HashRef', default => {} },
    );

    my $messages = $self->render(
        template => $self->messages_template,
        context  => $ctx,
        vars     => {
            errors   => $ctx->has_errors   ? [ $ctx->list_errors   ] : undef,
            warnings => $ctx->has_warnings ? [ $ctx->list_warnings ] : undef,
            info     => $ctx->has_info     ? [ $ctx->list_info     ] : undef,
        },
    );

    my ($main_title, $title);
    if ($ctx->response->has_page_title) {
        $title      = $ctx->response->page_title;
        $main_title = $ctx->response->page_title . ' - Yukki';
    }
    else {
        $title = $main_title = 'Yukki';
    }

    my %menu_vars = map {
        $_ => $self->available_menu_items($ctx, $_)
    } @{ $self->app->settings->menu_names };

    my @scripts = $self->app->settings->all_scripts;
    my @styles  = $self->app->settings->all_styles;

    my $view      = $ctx->request->parameters->{view} // 'default';

    $vars->{'head script.local'} //= [];
    $vars->{'head link.local'}   //= [];

    return $self->render(
        template => $self->page_template($view),
        context  => $ctx,
        vars     => {
            $vars->%*,
            scripts      => [
                map { $ctx->rebase_url($_) }
                    @scripts,
                    $vars->{'head script.local'}->@*,
            ],
            links        => [
                map { $ctx->rebase_url($_) }
                    @styles,
                    $vars->{'head link.local'}->@*,
            ],
            'messages'   => $messages,
            'main_title' => $main_title,
            'title'      => $title,
            %menu_vars,
            'breadcrumb' => $ctx->response->has_breadcrumb ? [
                map {
                    +{
                        %$_,
                        href => $ctx->rebase_url($_->{href}),
                    }
                } $ctx->response->breadcrumb_links
            ] : undef,
            'content'    => $self->render(
                template => $template,
                context  => $ctx,
                vars     => $vars,
            ),
        },
    );
}

=head2 available_menu_items

  my @items = $self->available_menu_items($ctx, 'menu_name');

Retrieves the navigation menu from the L<Yukki::Web::Response> and purges any links that the current user does not have access to.

=cut

sub available_menu_items {
    my ($self, $ctx, $name) = @_;

    my @items = grep {
        my $url = $_->{href}; $url =~ s{\?.*$}{};

        my $match = $self->app->router->match($url);
        return unless $match;
        my $access_level_needed = $match->access_level;
        $self->check_access(
            user       => $ctx->session->{user},
            repository => $match->mapping->{repository} // '-',
            needs      => $access_level_needed,
        );
    } $ctx->response->navigation_menu($name);

    return @items ? \@items : undef;
}

=head2 render_links

  my $document = $self->render_links($ctx, \@navigation_links);

This renders a set of links using the F<links.html> template.

=cut

sub render_links {
    my ($self, $ctx, $links) = validated_list(\@_,
        context  => { isa => 'Yukki::Web::Context' },
        links    => { isa => 'ArrayRef[HashRef]' },
    );

    return $self->render(
        template => $self->links_template,
        context  => $ctx,
        vars     => {
            links => [
                map {
                    {
                        'a'      => $_->{label},
                        'a@href' => $_->{href},
                    },
                } @$links ],
        },
    );
}

=head2 render

  my $document = $self->render({
      template => $template,
      vars     => { ... },
  });

This renders the given L<Template::Pure>. The C<vars> are
used as the ones passed to the C<process> method.

=cut

sub render {
    my ($self, $template, $ctx, $vars) = validated_list(\@_,
        template   => { isa => 'Template::Pure' },
        context    => { isa => 'Yukki::Web::Context' },
        vars       => { isa => 'HashRef', default => {} },
    );

    my %vars = (
        %$vars,
        ctx  => $ctx,
        view => $self,
    );

    return $template->render($vars);
}

__PACKAGE__->meta->make_immutable;
