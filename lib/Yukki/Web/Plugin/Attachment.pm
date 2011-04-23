package Yukki::Web::Plugin::Attachment;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Plugin';

use URI::Escape qw( uri_escape );

has format_helpers => (
    is          => 'ro',
    isa         => 'HashRef[Str]',
    required    => 1,
    default     => sub { +{
        'attachment' => 'attachment_url',
    } },
);

with 'Yukki::Web::Plugin::Role::FormatHelper';

sub attachment_url {
    my ($self, $params) = @_;

    my $ctx = $params->{context};
    my $arg = $params->{arg};

    if ($arg =~ m{

            ^\s*

                (?: ([\w]+) : )?    # repository: is optional
                (.+)                # link/to/page is mandatory

            \s*$

            }x) {

        my $repository = $1 // $params->{repository};
        my $page       = $params->{page};
        my $link       = $2;

        $link =~ s/^\s+//; $link =~ s/\s+$//;

        $page =~ s{\.yukki$}{};
        $link = join "/", map { uri_escape($_) } split m{/}, $link;

        if ($link =~ m{^/}) {
            return $ctx->rebae_url("attachment/view/$repository$link");
        }
        else {
            return $ctx->rebase_url("attachment/view/$repository/$page/$link");
        }
    }

    return;
}

1;
