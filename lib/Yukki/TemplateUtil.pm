package Yukki::TemplateUtil;

use v5.24;
use utf8;

use Mojo::DOM58::Entities qw( html_escape );
use Try::Tiny;

use namespace::clean;

# ABSTRACT: Utiltiies that help make manipulating the DOM easier

=head1 DESCRIPTION

Tools for manipulating the DOM in specialized wasy inside of L<Template::Pure> templates.

=cut

use Sub::Exporter -setup => {
    exports => [ qw(
        field
        form_error
        mark_radio_checked
    ) ],
};

=head1 SUBROUTINES

=head2 field

    $view->prepare_template(
        template => 'admin/user/edit.html',
        directives => [
            ...
            '#email@value' => field(['user.email', 'form.email']),
            ...
        ],
    );

L<Template::Pure> is touchy about missing paths. This will make sure a field is
present so the template renders okay without requiring any additional
boilerplate. First argument is the name of the data path or paths to lookup.
Multiple paths may be passed using an array reference. The second value
(optional) is the default to use if that finds nothing. If no default is given,
the default default is an empty string.

=cut

sub field {
    my ($paths, $default) = @_;
    $paths = [$paths] unless ref $paths;

    sub {
        my ($template, $dom, $data) = @_;

        my $value;
        for my $path (@$paths) {
            $value = try {
                $template->data_at_path($data, $path);
            };
            return $value if defined $value;
        }

        return '';
    };
}

=head2 form_error

    $view->prepare_template(
        template => 'admin/user/edit.html',
        directives => [
            ...
            '#email' => form_error('email'),
            ...
        ],
    );

Appends content after an element to insert code to show field errors, if field
errors are set.

=cut

sub form_error {
    my ($data_path, $id) = @_;
    my $path = "form_errors.$data_path";
    my $id //= "#$data_path";

    sub {
        my ($template, $dom, $data) = @_;

        my $form_error = try {
            $template->data_at_path($data, $path);
        };
        return unless defined $form_error;

        my $error = join ' ', @$form_error;

        $dom->at($id)->append(
            qq[<div class="field-message error">]
            . html_escape($error)
            . qq[</div>]
        );
    };
}

=head2 mark_radio_checked

    $view->prepare_template(
        template => ...,
        directives => [
            ...,
            '#anonymous_access_level' => mark_radio_checked(
                'anonymous_access_level',
                'repository.anonymous_access_level',
                'form.anonymous_access_level',
            ),
        ],
    );

Returns a subroutine that will set a radio button to the given value.

    my @directives = mark_radio_checked($field_name, @data_paths);

The C<$field_name> gives the the C<name> attribute of the radios to try. The returned sub checks each C<@data_path> sequentially and ignores missing paths.

=cut

sub mark_radio_checked {
    my ($field_name, @data_paths) = @_;

    sub {
        my ($template, $dom, $data) = @_;

        my $value;
        for my $path (@data_paths) {
            $value = try {
                $template->data_at_path($data, $path);
            };
            last if defined $value;
        }

        return unless defined $value;

        $dom->at(
            qq/input[type=radio][name="$field_name"][value="$value"]/,
        )->attr(checked => 1);
    }
}

1;
