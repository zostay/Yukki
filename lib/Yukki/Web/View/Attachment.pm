package Yukki::Web::View::Attachment;
use 5.12.1;
use Moose;

extends 'Yukki::Web::View';

# ABSTRACT: View for attachment forms

=head1 DESCRIPTION

Handles the display of attachment forms.

=head1 METHODS

=head2 rename

Show the rename form for attachments.

=cut

sub rename {
    my ($self, $ctx, $vars) = @_;
    my $file = $vars->{file};

    $ctx->response->page_title($vars->{title});

    return $self->render_page(
        template => 'attachment/rename.html',
        context  => $ctx,
        vars     => {
            '#yukkiname'           => $vars->{page},
            '#yukkiname_new@value' => $vars->{page},
        },
    );
}


