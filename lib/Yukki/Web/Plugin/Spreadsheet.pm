package Yukki::Web::Plugin::Spreadsheet;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Plugin';

use Try::Tiny;

has format_helpers => (
    is          => 'ro',
    isa         => 'HashRef[Str]',
    required    => 1,
    default     => sub { +{
        '=' => 'spreadsheet_eval',
    } },
);

with 'Yukki::Web::Plugin::Role::FormatHelper';

sub initialize_context {
    my ($self, $ctx) = @_;

    $ctx->stash->{'Spreadsheet.sheet'}   //= Spreadsheet::Engine->new;
    $ctx->stash->{'Spreadsheet.map'}     //= {};
    $ctx->stash->{'Spreadsheet.nextrow'} //= 'A';
    $ctx->stash->{'Spreadsheet.nextcol'} //= {};

    return $ctx->stash->{'Spreadsheet.sheet'};
}

sub setup_spreadsheet {
    my ($self, $params) = @_;
    
    my $ctx  = $params->{context};
    my $file = $params->{file};
    my $arg  = $params->{arg};

    my $sheet = $ctx->stash->{'Spreadsheet.sheet'};
    my $map   = $ctx->stash->{'Spreadsheet.map'};
    my $row   = $ctx->stash->{'Spreadsheet.nextrow'}++;

    my ($name, $formula) = $arg =~ /^(?:(\w+):)?(.*)/;

    my $new_cell = $row . ($sheet->raw->{sheetattribs}{lastrow} + 1);

    $map->{ $file->full_path }{ $name } = $new_cell if $name;

    return ($new_cell, $name, $formula);
}

sub lookup_name {
    my ($self, $params) = @_;

    my $ctx  = $params->{context};
    my $map  = $ctx->stash->{'Spreadsheet.map'};
    my $file = $params->{file};
    my $name = $params->{name};

    Yukki::Error->throw('not yet implemented') if $name =~ /!/;
    Yukki::Error->throw('unknown name')
        if not exists $map->{ $file->full_path }{ $name };

    return $map->{ $name };
}

sub spreadsheet_eval {
    my ($self, $params) = @_;

    my $ctx         = $params->{context};
    my $plugin_name = $params->{plugin_name};
    my $file        = $params->{file};
    my $arg         = $params->{arg};

    my $sheet = $self->initialize_context($ctx);
   
    my ($new_cell, $name, $formula) = $self->setup_spreadsheet($params);

    my $error = 0;

    try {
        $formula =~ s/ \[ ([^\]]+) \] /
            $self->lookup_name({
                %$params, 
                name => $1,
            })
        /gex;
    }

    catch {
        $error++;
        when (/not yet implemented/i) {
            $sheet->execute("set $new_cell constant e#NYI!  Not yet implemented.");
        }
        when (/unknown name/i) {
            $sheet->execute("set $new_cell constant e#NAME?");
        }
        default {
            die $_;
        }
    };

    $sheet->execute("set $new_cell formula $formula") unless $error;
    $sheet->recalc;

    my $raw = $sheet->raw;
    my $attrs = defined $name ? qq[ id="spreadsheet-$name"] : '';
    my $value;
    if ($raw->{cellerrors}{ $new_cell }) {
        $attrs .= qq[ title="$arg (ERROR: $raw->{formulas}{ $new_cell })"]
                .  qq[ class="spreadsheet-cell error" ];
        $value  = $raw->{cellerrors}{ $new_cell };
    }
    else {
        $attrs .= qq[ title="$arg" class="spreadsheet-cell error" ];
        $value = $raw->{datavalues}{ $new_cell };
    }

    return qq[<span$attrs>$value</span>];
}

# sub load_spreadsheet {
#     my ($self, $param) = @_;
# 
#     my $repo_name  = $params->{repository};
#     my $page_name  = $params->{page};
#     my $variable   = $params->{variable};
# 
#     my $repository = $self->model(Repository => { name => $repo_name });
#     my $page       = $repository->file({ full_path => $page_name });
# 
#     ...
# }

1;
