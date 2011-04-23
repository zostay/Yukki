package Yukki::Web::Plugin::Spreadsheet;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Plugin';

has yukkitext_helpers => (
    is          => 'ro',
    isa         => 'HashRef[Str]',
    required    => 1,
    default     => sub { +{
        '=' => 'spreadsheet_eval',
    } },
);

with 'Yukki::Web::Plugin::Role::YukkiTextHelper';

sub spreadsheet_eval {
    my ($self, $params) = @_;

    my $ctx         = $params->{context};
    my $plugin_name = $params->{plugin_name};
    my $arg         = $params->{arg};

    $ctx->stash->{'SpreadSheet.sheet'} //= Spreadsheet::Engine->new;
    $ctx->stash->{'SpreadSheet.map'}   //= {};

    my $sheet = $ctx->stash->{'SpreadSheet.sheet'};
    my $map   = $ctx->stash->{'SpreadSheet.map'};

    my ($name, $formula) = $arg =~ /^(?:(\w+):)?(.*)/;

    my $new_cell = 'A' . ($sheet->raw->{sheetattribs}{lastrow} + 1);

    $map->{ $name } = $new_cell if $name;

    my $error = 0;
    my $lookup_name = sub {
        my $name = shift; 

        if ($name =~ /!/) {
            $error++;
            $sheet->execute(qq[set $new_cell constant e#NYI!  Not yet implemented.]);
            return '';
        }

        if (not exists $map->{ $name }) {
            $error++;
            $sheet->execute(qq[set $new_cell constant e#NAME?]);
            return '';
        }

        return $map->{ $name };
    };

    $formula =~ s/\[([^\]]+)\]/$lookup_name->($1)/gex;

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
