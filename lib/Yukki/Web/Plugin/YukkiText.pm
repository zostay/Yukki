package Yukki::Web::Plugin::YukkiText;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Plugin';

use Text::MultiMarkdown;
use Try::Tiny;

has html_formatters => (
    is          => 'ro',
    isa         => 'HashRef[Str]',
    required    => 1,
    default     => sub { +{
        'text/yukki'    => 'yukkitext',
        'text/markdown' => 'markdown',
    } },
);

with 'Yukki::Web::Plugin::Role::Formatter';

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

=head2 yukkilink

Used to help render yukkilinks. Do not use.

=cut

sub yukkilink {
    my ($self, $params) = @_;

    my $ctx        = $params->{context};
    my $repository = $params->{repository};
    my $link       = $params->{link};
    my $label      = $params->{label};

    $link =~ s/^\s+//; $link =~ s/\s+$//;

    my ($repo_name, $local_link) = split /:/, $link, 2 if $link =~ /:/;
    if (defined $repo_name and defined $self->app->settings->{repositories}{$repo_name}) {
        $repository = $repo_name;
        $link       = $local_link;
    }
    
    # If we did not get a label, make the label into the link
    if (not defined $label) {
        ($label) = $link =~ m{([^/]+)$};

        $link =~ s{([a-zA-Z])'([a-zA-Z])}{$1$2}g; # foo's -> foos, isn't -> isnt
        $link =~ s{[^a-zA-Z0-9-_./]+}{-}g;
        $link =~ s{-+}{-}g;
        $link =~ s{^-}{};
        $link =~ s{-$}{};

        $link .= '.yukki';
    }

    my @base_name;
    if ($params->{page}) {
        $base_name[0] = $params->{page};
        $base_name[0] =~ s/\.yukki$//g;
    }

    $link = join '/', @base_name, $link if $link =~ m{^\./};
    $link =~ s{^/}{};
    $link =~ s{/\./}{/}g;

    $label =~ s/^\s*//; $label =~ s/\s*$//;

    my $b = sub { $ctx->rebase_url($_[0]) };

    my $file = $self->model('Repository', { name => $repository })->file({ full_path => $link });
    my $class = $file->exists ? 'exists' : 'not-exists';
    return qq{<a class="$class" href="}.$b->("page/view/$repository/$link").qq{">$label</a>};
}

=head2 yukkiplugin

Used to render plugged in markup. Do not use.

=cut

sub yukkiplugin {
    my ($self, $params) = @_;

    my $ctx         = $params->{context};
    my $plugin_name = $params->{plugin_name};
    my $arg         = $params->{arg};

    my $text;

    my @plugins = $self->app->format_helper_plugins;
    PLUGIN: for my $plugin (@plugins) {
        my $helpers = $plugin->format_helpers;
        if (defined $helpers->{ $plugin_name }) {
            $text = try {
                my $helper = $helpers->{ $plugin_name };
                $plugin->$helper({
                    context     => $ctx,
                    repository  => $params->{repository},
                    page        => $params->{page},
                    helper_name => $plugin_name,
                    arg         => $arg,
                });
            }
            
            catch {
                warn "Plugin Error: $_";
            };

            last PLUGIN if defined $text;
        }
    }

    $text //= "{{$plugin_name:$arg}}";
    return $text;
}

=head2 yukkitext

  my $html = $view->yukkitext({
      context    => $ctx,
      repository => $repository_name,
      page       => $page,
      content    => $yukkitext,
  });

Yukkitext is markdown plus some extra stuff. The extra stuff is:

  [[ main:/link/to/page.yukki | Link Title ]] - wiki link
  [[ /link/to/page.yukki | Link Title ]]      - wiki link
  [[ /link/to/page.yukki ]]                   - wiki link

  {{attachment:file.pdf}}                     - attachment URL

=cut

sub yukkitext {
    my ($self, $params) = @_;

    my $repository = $params->{repository};
    my $yukkitext  = $params->{content};

    # Yukki Links
    $yukkitext =~ s{ 
        (?<!\\)                 # \ will escape the link
        \[\[ \s*                # [[ to start it

            (?: ([\w]+) : )?    # repository: is optional
            ([^|\]]+) \s*       # link/to/page is mandatory

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

    # Handle escaped links, hide the escape
    $yukkitext =~ s{ 
        \\                      # \ will escape the link
        (\[\[ \s*               # [[ to start it

            (?: [\w]+ : )?      # repository: is optional
            [^|\]]+ \s*         # link/to/page is mandatory

            (?: \|              # | to split link from label
                [^\]]+          # a pretty label (needs trimming)
            )?                  # is optional

        \]\])                    # ]] to end
    }{$1}gx;

    # Yukki Plugins
    $yukkitext =~ s{
        (?<!\\)                 # \ will escape the plugin
        \{\{ \s*                # {{ to start it

            ([^:]+) :           # plugin_name: is required

            (.*?)               # plugin arguments

        \}\}                    # }} to end
    }{
        $self->yukkiplugin({
            %$params,

            plugin_name => $1,
            arg         => $2,
        });
    }xeg;

    # Handle the escaped plugin thing
    $yukkitext =~ s{
        \\                      # \ will escape the plugin
        (\{\{ \s*               # {{ to start it

            [^:]+ :             # plugin_name: is required

            .*?                 # plugin arguments

        \}\})                   # }} to end
    }{$1}xg;

    return '<div>' . $self->format_markdown($yukkitext) . '</div>';
}

1;
