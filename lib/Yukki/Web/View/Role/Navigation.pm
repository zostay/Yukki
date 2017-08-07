package Yukki::Web::View::Role::Navigation;

use v5.24;
use Moo::Role;

use String::Errf qw( errf );

# ABSTRACT: Common page navigation tools for views

=head1 DESCRIPTION

The top and bottom page menus and breadcrumb are typically managed with similar
idioms in the various views. This avoid duplicate code in each.

=head1 REQUIRED METHODS

The implementor must provide each of the following:

=head2 standard_menu

    my @menu_items = $view->standard_menu;

Must return a list of hash references. Each hash reference should provide the following keys:

=over

=item action

This gives the short action name associated with this item.

=item label

This is the label to give the menu item. If not given the C<action> will be uesd with the first letter capitalized.

=item sort

This is a numeric value to use for sorting the menu item. If not given, the default used is 20.

=item href

This is URI to link to with this menu item. It may contains L<String::Errf>-style interpolations. The variables passed to L</page_navigation> will fill in here.

=back

=cut

requires 'standard_menu';

=head1 PROVIDED METHODS

=head2 page_navigation

    $view->page_navigation($ctx->response, $action, \%vars);

This will add navigation items using the menus returned by L</standard_menu>.

=cut

sub page_navigation {
    my ($self, $response, $this_action, $vars) = @_;

    for my $menu_item ($self->standard_menu) {
        next if $this_action eq $menu_item->{action};

        $response->add_navigation_item([ qw( page page_bottom ) ], {
            label => $menu_item->{label} // ucfirst $menu_item->{action},
            href  => errf($menu_item->{href}, $vars // {}),
            sort  => $menu_item->{sort} // 20,
        });
    }
}

1;
