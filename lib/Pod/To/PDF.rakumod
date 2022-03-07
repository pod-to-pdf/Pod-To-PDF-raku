use Pod::To::Cairo;
unit class Pod::To::PDF:ver<0.0.9>
    is Pod::To::Cairo;

use Cairo;
use File::Temp;

has Str %!metadata;
has int32 @!outline-stack;

submethod TWEAK(Str :$title, Str :$lang = 'en') {
    self.title = $_ with $title;
    self.surface.set_metadata(CAIRO_PDF_METADATA_CREATOR, "Raku {self.^name} v{self.^ver}");
}

method render(
    $class: $pod,
    :$pdf-file = tempfile("POD6-****.pdf", :!unlink)[0],
    UInt:D :$width  = 612,
    UInt:D :$height = 792,
    |c,
) {
    state %cache{Any};
    %cache{$pod}{$width~'x'~$height} //= do {
        my Cairo::Surface::PDF $surface .= create($pdf-file, $width, $height);
        $class.new(:$pod, :$surface, |c);
        $surface.finish;
        $pdf-file;
    }
}

our sub pod2pdf(
    $pod,
    :$class = $?CLASS,
    Str() :$pdf-file = tempfile("POD6-****.pdf", :!unlink)[0],
    UInt:D :$width  = 612,
    UInt:D :$height = 792,
    Cairo::Surface::PDF :$surface = Cairo::Surface::PDF.create($pdf-file, $width, $height);
    |c,
) is export {
    $class.new(|c, :$pod, :$surface);
    $surface;
}

method add-toc-entry(Str:D $Title, Str :$dest!, UInt:D :$level! ) {
    my Str $name = $Title.subst(/\s+/, ' ', :g); # Tidy a little
    @!outline-stack.pop while @!outline-stack >= $level;
    my int32 $parent-id = $_ with @!outline-stack.tail;
    while @!outline-stack < $level-1 {
        # e.g. jump from =head1 to =head3
        # need to insert missing entries
        my $flags = CAIRO_PDF_OUTLINE_FLAG_OPEN;
        $parent-id = $.surface.add_outline: :$parent-id, :$dest, :$flags;
        @!outline-stack.push: $parent-id;
    }
    my uint32 $toc-id = $.surface.add_outline: :$parent-id, :$name, :$dest;
    @!outline-stack.push: $toc-id;
}

subset PodMetaType of Str where 'title'|'subtitle'|'author'|'name'|'version';
constant %PdfMetaData =  (
    :title(CAIRO_PDF_METADATA_TITLE),
    :author(CAIRO_PDF_METADATA_AUTHOR),
    :subtitle(CAIRO_PDF_METADATA_SUBJECT),
);

method !build-metadata-title {
    my @title = $_ with %!metadata<title>;
    with %!metadata<name> {
        @title.push: '-' if @title;
        @title.push: $_;
    }
    @title.push: 'v' ~ $_ with %!metadata<version>;
    @title.join: ' ';
}

method !set-metadata(PodMetaType $key, $value) {

    %!metadata{$key} = $value;

    my UInt $pdf-key =  $key ~~ 'title'|'version'|'name'
       ?? %PdfMetaData<title>
       !! %PdfMetaData{$key};

    my $pdf-value = $pdf-key == %PdfMetaData<title>
        ?? self!build-metadata-title()
        !! $value;

    self.surface.set_metadata($pdf-key, $pdf-value);
}

multi method metadata(PodMetaType $t) is rw {
    Proxy.new(
        FETCH => { %!metadata{$t} },
        STORE => -> $, Str:D() $v {
            self!set-metadata($t, $v);
        }
    )
}

multi method metadata { %!metadata.clone }

=begin pod
=TITLE Pod::To::PDF
=SUBTITLE  Render Pod to PDF via Cairo

=begin Usage

From command line:

    $ raku --doc=PDF lib/to/class.rakumod | xargs evince

From Raku:
    =begin code :lang<raku>
    use Pod::To::PDF;
    use Cairo;

    =NAME
    foobar.pl

    =head2 SYNOPSIS
    =code foobar.pl <options> files ...

    my Cairo::Surface::PDF $pdf = pod2pdf($=pod);
    $pdf.finish();
    =end code
=end Usage

=begin Exports

    class Pod::To::PDF;
    sub pod2pdf; # See below

From Raku code, the C<pod2pdf> function returns a L< Cairo::Surface::PDF> object which can
be further manipulated, or finished to complete rendering.
=end Exports

=begin Description

This module renders Pod to PDF documents via Cairo.

The generated PDF has a table of contents and is tagged for
accessibility and testing purposes.

It uses HarfBuzz for font shaping and glyph selection
and FontConfig for system font loading.
=end Description

=begin Subroutines
=head3 sub pod2pdf()
=begin code :lang<raku>
sub pod2pdf(
    Pod::Block $pod
) returns Cairo::Surface::PDF;
=end code

=head4 pod2pdf() Options

=defn Str() :$pdf-file
A filename for the output PDF file.

=defn Cairo::Surface::PDF :$surface
A surface to render to

=defn UInt:D :$width, UInt:D :$height
The page size in points (there are 72 points per inch).

=defn UInt:D :$margin
The page margin in points

=defn Hash :@fonts
By default, Pod::To::PDF loads system fonts via FontConfig. This option can be used to preload selected fonts.
=begin code :lang<raku>
use Pod::To::PDF;
use Cairo;
my @fonts = (
    %(:file<fonts/Raku.ttf>),
    %(:file<fonts/Raku-Bold.ttf>, :bold),
    %(:file<fonts/Raku-Italic.ttf>, :italic),
    %(:file<fonts/Raku-BoldItalic.ttf>, :bold, :italic),
    %(:file<fonts/Raku-Mono.ttf>, :mono),
);

my Cairo::Surface::PDF $pdf = pod2pdf($=pod, :@fonts, :pdf-file<out.pdf>);
$pdf.finish();
=end code
Each font entry should have a `file` entry and various
combinations of `bold`, `italic` and `mono` flags. Note
that `mono` is used to render code blocks and inline code.

=defn Str :%metadata

This can be used to preset values for C<title>, C<subtitle>,
C<name>, C<author> or C<version>.

This is an alternative to, and will override C<=TITLE>, C<=SUBTITLE>,
C<=NAME>, C<=AUTHOR> or C<=VERSION> directives.

Note: All of these are options are provided for compatibility, however
only C<=TITLE> and C<=AUTHOR> are directly supported in PDF metadata.

=defn `:!contents`
Disables Table of Contents generation.
=end Subroutines

=begin Installation

This module's dependencies include L<HarfBuzz|https://harfbuzz-raku.github.io/HarfBuzz-raku/>, L<Font::FreeType|https://pdf-raku.github.io/Font-FreeType-raku/>, L<FontConfig|https://raku.land/zef:dwarring/FontConfig> and L<Cairo|https://raku.land/github:timo/Cairo>, which further depend on native C<harfbuzz>, C<freetype6>, C<fontconfig> and C<cairo> libraries.

Please check these module's installation instructions.
=end Installation

=begin Testing

Note that installation of the L<PDF::Tags::Reader> module enables structural testing. 

For example, to test this module from source.

=begin code
$ git clone https://github.com/dwarring/Pod-To-PDF-raku
$ cd Pod-To-PDF-raku
$ zef install PDF::Tags::Reader # enable structural tests
$ zef APP::Prove6
$ zef --deps-only install .
$ prove6 -I .
=end code

=end Testing
=end pod
