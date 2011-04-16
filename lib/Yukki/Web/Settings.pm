package Yukki::Web::Settings;
use 5.12.1;
use Moose;

extends 'Yukki::Settings';

# ABSTRACT: provides structure and validation to web settings in yukki.conf

=head1 DESCRIPTION

L<Yukki::Web> needs a few additional settings.

=head1 ATTRIBUTES

=head2 template_path

THis is the folder where Yukki will find templates under the C<root>. The default is F<root/template>.

=cut

has template_path => (
    is          => 'ro',
    isa         => 'Path::Class::Dir',
    required    => 1,
    coerce      => 1,
    default     => 'root/template',
);

=head2 static_path

This is the folder where Yukki will find the static files to serve for your application.

=cut

has static_path => (
    is          => 'ro',
    isa         => 'Path::Class::Dir',
    required    => 1,
    coerce      => 1,
    default     => 'root',
);

=head2 scripts

=head2 styles

This is a list of the JavaScript and CSS files, respectively, to load into the
shell template. If not set, the defaults are:

  scripts:
      - /script/lib/jquery/jquery.js
      - /script/lib/jquery/jquery-ui.js
      - /script/lib/plupload/gears_init.js
      - /script/lib/plupload/plupload.full.min.js
      - /script/lib/sha1/sha1.js
      - /script/yukki.js

  styles:
      - /style/yukki.css
      - /style/lib/jquery/jquery.css

As you can see, these are full paths and may be given as paths to foreign hosts.
In order to keep Yukki working in good order, you will probaby want to include
at least the scripts listed above.

=cut

has scripts => (
    is          => 'ro',
    isa         => 'ArrayRef[Str]',
    required    => 1,
    default     => sub { 
        [ qw(
            /script/lib/jquery/jquery.js
            /script/lib/jquery/jquery-ui.js
            /script/lib/plupload/gears_init.js
            /script/lib/plupload/plupload.full.min.js
            /script/lib/sha1/sha1.js
            /script/yukki.js
        ) ]
    },
    traits      => [ 'Array' ],
    handles     => {
        all_scripts => 'elements',
    },
);

has styles => (
    is          => 'ro',
    isa         => 'ArrayRef[Str]',
    required    => 1,
    default     => sub { 
        [ qw(
            /style/yukki.css
            /style/lib/jquery/jquery.css
        ) ]
    },
    traits      => [ 'Array' ],
    handles     => {
        all_styles => 'elements',
    },
);

1;
