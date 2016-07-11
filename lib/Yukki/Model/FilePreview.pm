package Yukki::Model::FilePreview;
use v5.24;
use Moose;

extends 'Yukki::Model::File';

# ABSTRACT: a sub-class of the File model for handling previews

=head1 DESCRIPTION

This is a sub-class of L<Yukki::Model::File> that replaces the C<fetch> method with one that loads the content from a scalar attribute.

=head1 ATTRIBUTES

=head2 content

This is the content the file should have in the preview.

=cut

has content => (
    is          => 'rw',
    isa         => 'Str',
    required    => 1,
);

=head2 position

The position in the text for the caret.

=cut

has position => (
    is          => 'rw',
    isa         => 'Int',
    required    => 1,
    default     => -1,
);

=head1 METHODS

=head2 fetch

Returns the value of L</content>.

=cut

override fetch => sub {
    my $self = shift;
    return $self->content;
};

=head2 fetch_formatted

Same as in L<Yukki::Model::File>, except that the default position is L</position>.

=cut

override fetch_formatted => sub {
    my ($self, $ctx, $position) = @_;
    $position //= $self->position;
    return $self->SUPER::fetch_formatted($ctx, $position);
};

1;
