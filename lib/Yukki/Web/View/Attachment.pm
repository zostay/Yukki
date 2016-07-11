package Yukki::Web::View::Attachment;
use v5.24;
use Moose;

extends 'Yukki::Web::View';

# ABSTRACT: View for attachment forms

=head1 DESCRIPTION

Handles the display of attachment forms.

=cut

has rename_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_rename_template',
);

sub _build_rename_template {
    Yukki::Web::View->prepare_template(
        template   => 'attachment/rename.html',
        directives => [
            '#yukkiname'           => 'page',
            '#yukkiname_new@value' => 'page',
        ],
    );
}

has remove_template => (
    is          => 'ro',
    isa         => 'Template::Pure',
    lazy        => 1,
    builder     => '_build_remove_template',
);

sub _build_remove_template {
    Yukki::Web::View->prepare_template(
        template   => 'attachment/remove.html',
        directives => [
            '.yukkiname'          => 'page',
            '#cancel_remove@href' => 'return_link',
        ],
    );
}

=head1 METHODS

=head2 rename

Show the rename form for attachments.

=cut

sub rename {
    my ($self, $ctx, $vars) = @_;
    my $file = $vars->{file};

    $ctx->response->page_title($vars->{title});

    return $self->render_page(
        template => $self->rename_template,
        context  => $ctx,
        vars     => $vars,
    );
}

=head2 remove

Show the remove form for attachmensts.

=cut

sub remove {
    my ($self, $ctx, $vars) = @_;
    my $file = $vars->{file};

    $ctx->response->page_title($vars->{title});

    return $self->render_page(
        template => $self->remove_template,
        context  => $ctx,
        vars     => $vars,
    );
}

1;
