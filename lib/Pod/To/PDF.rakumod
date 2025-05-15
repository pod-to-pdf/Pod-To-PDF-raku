use Pod::To::Cairo;
unit class Pod::To::PDF:ver<0.1.7>
    is Pod::To::Cairo;

use Cairo;
use File::Temp;

has Str %!metadata;
has int32 @!outline-path;

submethod TWEAK(Str :$title, Str :$lang = 'en') {
    self.title = $_ with $title;
    self.surface.set_metadata(CAIRO_PDF_METADATA_CREATOR, "Raku {self.^name} v{self.^ver}");
}

sub apply-page-styling($style, *%props) {
    CATCH {
        when X::CompUnit::UnsatisfiedDependency {
            note "Ignoring --page-style argument; Please install CSS::Properties"
        }
    }
    my $css = (require ::('CSS::Properties')).new: :$style;
    %props{.key} = .value for $css.Hash;
}

method render(
    $class: $pod,
    Str :$save-as  is copy,
    Numeric:D :$width  is copy = 612,
    Numeric:D :$height is copy = 792,
    Numeric:D :$margin is copy = 20,
    Numeric   :$margin-left   is copy,
    Numeric   :$margin-right  is copy,
    Numeric   :$margin-top    is copy,
    Numeric   :$margin-bottom is copy,
    Bool :$index    is copy = True,
    Bool :$contents is copy = True,
    Bool :$page-numbers is copy,
    Bool :$verbose is copy,
    |c,
) {
    state %cache{Any};
    %cache{$pod} //= do {
        my Bool $show-usage;
        for @*ARGS {
            when /^'--page-numbers'$/  { $page-numbers = True }
            when /^'--/index'$/        { $index  = False }
            when /^'--verbose'$/       { $verbose  = True }
            when /^'--/'[toc|['table-of-']?contents]$/ { $contents  = False }
            when /^'--width='(\d+)$/   { $width  = $0.Int }
            when /^'--height='(\d+)$/  { $height = $0.Int }
            when /^'--margin='(\d+)$/  { $margin = $0.Int }
            when /^'--margin-top='(\d+)$/     { $margin-top = $0.Int }
            when /^'--margin-bottom='(\d+)$/  { $margin-bottom = $0.Int }
            when /^'--margin-left='(\d+)$/    { $margin-left = $0.Int }
            when /^'--margin-right='(\d+)$/   { $margin-right = $0.Int }
            when /^'--page-style='(.+)$/    {
                apply-page-styling(
                    $0.Str,
                    :$width, :$height,
                    :$margin-top, :$margin-bottom, :$margin-left, :$margin-right,
                           )
            }
            when /^'--save-as='(.+)$/  { $save-as = $0.Str }
            default {  $show-usage = True; note "ignoring $_ argument" }
        }
        note '(valid options are: --save-as= --page-numbers --width= --height= --margin[-left|-right|-top|-bottom]= --page-style= --/index --/contents)'
            if $show-usage;
        $save-as //= tempfile("POD6-****.pdf", :!unlink)[0];
        my Cairo::Surface::PDF $surface .= create($save-as, $width, $height);
        my $obj = $class.new: :$pod, :$surface, :$margin, :$margin-left, :$margin-right, :$margin-top, :$margin-bottom, :$contents, :$page-numbers, :$verbose, |c;
        $obj!build-index
            if $index && $obj.index;
        $surface.finish;
        $save-as;
    }
}

our sub pod2pdf(
    $pod,
    :$class = $?CLASS,
    Str() :$save-as = tempfile("POD6-****.pdf", :!unlink)[0],
    Numeric:D :$width  = 612,
    Numeric:D :$height = 792,
    Cairo::Surface::PDF :$surface = Cairo::Surface::PDF.create($save-as, $width, $height);
    Bool :$index = True,
    |c,
) is export {
    my $obj = $class.new(|c, :$pod, :$surface);
    $obj!build-index
        if $index && $obj.index;
    $surface;
}

sub categorize-alphabetically(%index) {
    my %alpha-index;
    for %index.sort(*.key.uc) {
        %alpha-index{.key.substr(0,1).uc}{.key} = .value;
    }
    %alpha-index;
}

method !add-terms(%index, :$level is copy = 1) {
    $level++;
    my constant $flags = CAIRO_PDF_OUTLINE_FLAG_ITALIC;

    for %index.sort(*.key.uc) {
        my $term = .key;
        my %kids = .value;
        my Hash @refs = .List with %kids<#refs>:delete;
        @refs[0] //= %();
        for @refs -> %link {
            self.add-toc-entry: $term, :$level, :$flags, |%link;
            $term = ' ';
        }

        self!add-terms(%kids, :$level) if %kids;
    }
}

method !build-index {
    self.add-toc-entry('Index', :level(1));
    my %idx := %.index;
    %idx .= &categorize-alphabetically
        if %idx > 64;
    self!add-terms(%idx);
}

method add-toc-entry(Str:D $Title, UInt:D :$level! is copy, *%link ) {
    my Str $name = $Title.subst(/\s+/, ' ', :g); # Tidy a little
    $level++ unless $level;
    @!outline-path.pop while @!outline-path >= $level;
    @!outline-path.push: 0 while  @!outline-path < $level;
    my int32 $parent-id = @!outline-path.reverse.first({$_}) || 0;
    my $toc-id = $.surface.add_outline: :$parent-id, :$name, |%link;
    
    @!outline-path[$level-1] = $toc-id;
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

    =code $ raku --doc=PDF lib/To/Class.rakumod --save-as=To-Class.pdf

From Raku:
    =begin code :lang<raku>
    use Pod::To::PDF;
    use Cairo;

    =NAME
    foobar.pl

    =head2 SYNOPSIS
    =code foobar.pl <options> files ...

    my Cairo::Surface::PDF $pdf = pod2pdf($=pod, :save-as<foobar.pdf>);
    $pdf.finish();
    =end code
=end Usage

=head3 Command Line Options:

=defn --save-as=pdf-filename

File-name for the PDF output file. If not given, the
output will be saved to a temporary file. The file-name
is echoed to C<stdout>.

=defn --width=n

Page width in points (default: 592)

=defn --height=n

Page height in points (default: 792)

=defn --margin=n --margin-left=n --margin-right=n --margin-top=n --margin-bottom=n

Page margin in points (default: 20)

=defn --/toc

Disable table of contents

=defn --/index

Disable index of terms

=defn --page-numbers

Add page numbers (bottom right)

=defn --page-style

=begin code :lang<raku>
-raku --doc=PDF::Lite lib/to/class.rakumod --page-style='margin:10px 20px; width:200pt; height:500pt" --save-as=class.pdf
=end code

Perform CSS C<@page> like styling of pages. At the moment, only margins (C<margin>, C<margin-left>, C<margin-top>, C<margin-bottom>, C<margin-right>) and the page C<width> and C<height> can be set. The optional [CSS::Properties](https://css-raku.github.io/CSS-Properties-raku/) module needs to be installed to use this option.

=begin Exports

=item C<class Pod::To::PDF;>
=item C<sub pod2pdf; # See below>

From Raku code, the C<pod2pdf> function returns a L< Cairo::Surface::PDF> object which can
be further manipulated, or finished to complete rendering.
=end Exports

=begin Description

This module does simple rendering of Pod to PDF documents via Cairo.

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

=defn `Str() :$save-as`
A filename for the output PDF file.

=defn `Cairo::Surface::PDF :$surface`
A surface to render to

=defn `UInt:D :$width, UInt:D :$height`
The page size in points (there are 72 points per inch).

=defn `UInt:D :$margin`
The page margin in points (default 20).

=defn `Hash :@fonts`
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

my Cairo::Surface::PDF $pdf = pod2pdf($=pod, :@fonts, :save-as<out.pdf>);
$pdf.finish();
=end code
Each font entry should have a `file` entry and various
combinations of `bold`, `italic` and `mono` flags. Note
that `mono` is used to render code blocks and inline code.

=defn `Str :%metadata`
This can be used to preset values for `title`, `subtitle`,
`name`, `author` or `version`.

This is an alternative to, and will override C<=TITLE>, C<=SUBTITLE>,
C<=NAME>, C<=AUTHOR> or C<=VERSION> directives.

Note: All of these are options are provided for compatibility, however
only C<=TITLE> and C<=AUTHOR> are directly supported in PDF metadata.

=defn `:!contents`
Disables Table of Contents generation.

=defn `:!index`
Disable writing of a `Index` section to the table of contents.

=defn `:$linker`
Provides a class or object to intercept and sanitise or rebase links. The class/object
should provide a method `resolve-link` that accepts the target component
of C<L<>> formatting codes and returns the actual link to be embedded in the PDF. The link is omitted, if the method returns an undefined value.

=defn `:%replace`
Specify replacements for `R<>` placeholders in the POD. Replacement
values should be simple strings (`Str`), Pod blocks (type `Pod::Block`), or a `List`. For example:

=begin code :lang<raku>
use Pod::To::PDF;
my $title = 'Sample Title';
my Str() $date = now.Date;
my $author = 'David Warring';
my $description = "sample Pod with replaced content";
my %replace = :$date, :$title, :$author, :$description;
my $renderer = pod2pdf($=pod, :%replace, :save-as<replace-example.pdf>);
$renderer.finish(); 

=begin pod
=TITLE R<title>
=AUTHOR R<author>
=DATE R<date>
=head2 Description
=para R<description>;
=end pod
=end code

=end Subroutines

=begin Installation

This module's dependencies include L<HarfBuzz|https://harfbuzz-raku.github.io/HarfBuzz-raku/>, L<Font::FreeType|https://pdf-raku.github.io/Font-FreeType-raku/>, L<FontConfig|https://raku.land/zef:dwarring/FontConfig> and L<Cairo|https://raku.land/github:timo/Cairo>, which further depend on native C<harfbuzz>, C<freetype6>, C<fontconfig> and C<cairo> libraries.

Please check these module's installation instructions.
=end Installation

=begin Testing

Note that installation of the L<PDF::Tags::Reader> module enables structural testing. 

For example, to test this module from source.

=begin code
$ git clone https://github.com/pod-to-pdf/Pod-To-PDF-raku
$ cd Pod-To-PDF-raku
$ zef install PDF::Tags::Reader # enable structural tests
$ zef APP::Prove6
$ zef --deps-only install .
$ prove6 -I .
=end code

=end Testing
=end pod
