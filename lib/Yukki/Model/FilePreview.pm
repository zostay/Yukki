package Yukki::Model::FilePreview;
use 5.12.1;
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

=head1 METHODS

=head2 fetch

Returns the value of L</content>.

=cut

override fetch => sub {
    my $self = shift;
    return $self->content;
};

1;
