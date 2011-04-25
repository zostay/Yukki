package Yukki::Web::Plugin::Spreadsheet;
use 5.12.1;
use Moose;

extends 'Yukki::Web::Plugin';

use Scalar::Util qw( blessed );
use Try::Tiny;
use Yukki::Error;

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
    my $row   = $ctx->stash->{'Spreadsheet.nextrow'}++;

    my ($name, $formula) = $arg =~ /^(?:(\w+):)?(.*)/;

    my $new_cell = $row . ($sheet->raw->{sheetattribs}{lastrow} + 1);

    $self->cell($ctx, $file, $name, $new_cell) if $name;

    return ($new_cell, $name, $formula);
}

sub cell {
    my ($self, $ctx, $file, $name, $new_cell) = @_;
    my $map = $ctx->stash->{'Spreadsheet.map'};
    $map->{ $file->repository_name }{ $file->full_path }{ $name } = $new_cell
        if defined $new_cell;
    return $map->{ $file->repository_name }{ $file->full_path }{ $name }; 
}

sub lookup_name {
    my ($self, $params) = @_;

    my $ctx  = $params->{context};
    my $file = $params->{file};
    my $name = $params->{name};

    if ($name =~ /!/) {
        my ($path, $name) = split /!/, $name, 2;

        my $repository_name;
        if ($path =~ /^(\w+):/) {
            ($repository_name, $path) = split /:/, $path, 2;
        }
        else {
            $repository_name = $file->repository_name;
        }

        my $other_repo = $self->model('Repository', { 
            name => $repository_name,
        });

        my $other_file = $other_repo->file({
            full_path => $path,
        });

        $self->load_spreadsheet($ctx, $other_file);

        return $self->cell($ctx, $other_file, $name);
    }

    my $cell = $self->cell($ctx, $file, $name);

    Yukki::Error->throw('unknown name') if not defined $cell;

    return $cell;
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
        if (blessed $_ and $_->isa('Yukki::Error')) {
            my $msg = $_->message;
            $sheet->execute("set $new_cell constant e#NAME?  $msg");
        }
        else {
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

sub load_spreadsheet {
    my ($self, $ctx, $file) = @_;
    Yukki::Error->throw('no such spreadsheet exists') unless $file->exists;
    $file->fetch_formatted($ctx);
}

1;
