TITLE
=====

Pod::To::PDF

SUBTITLE
========

Render Pod to PDF via Cairo

Usage
=====

From command line:

    $ raku --doc=PDF lib/to/class.rakumod --save-as=class.pdf

From Raku:

```raku
use Pod::To::PDF;
use Cairo;

=NAME
foobar.pl

=head2 SYNOPSIS
=code foobar.pl <options> files ...

my Cairo::Surface::PDF $pdf = pod2pdf($=pod, :save-as<foobar.pdf>);
$pdf.finish();
```

### Command Line Options:

**--save-as=pdf-filename**



File-name for the PDF output file. If not given, the output will be saved to a temporary file. The file-name is echoed to `stdout`.

**--width=n**



Page width in points (default: 592)

**--height=n**



Page height in points (default: 792)

**--margin=n**



Page margin in points (default: 792)

Exports
=======

  * `class Pod::To::PDF;`

  * `sub pod2pdf; # See below`

From Raku code, the `pod2pdf` function returns a [Cairo::Surface::PDF](Cairo::Surface::PDF) object which can be further manipulated, or finished to complete rendering.

Description
===========

This module renders Pod to PDF documents via Cairo.

The generated PDF has a table of contents and is tagged for accessibility and testing purposes.

It uses HarfBuzz for font shaping and glyph selection and FontConfig for system font loading.

Subroutines
===========

### sub pod2pdf()

```raku
sub pod2pdf(
    Pod::Block $pod
) returns Cairo::Surface::PDF;
```

#### pod2pdf() Options

**`Str() :$save-as`**

A filename for the output PDF file.

**`Cairo::Surface::PDF :$surface`**

A surface to render to

**`UInt:D :$width, UInt:D :$height`**

The page size in points (there are 72 points per inch).

**`UInt:D :$margin`**

The page margin in points (default 20).

**`Hash :@fonts`**

By default, Pod::To::PDF loads system fonts via FontConfig. This option can be used to preload selected fonts.

```raku
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
```

Each font entry should have a `file` entry and various combinations of `bold`, `italic` and `mono` flags. Note that `mono` is used to render code blocks and inline code.

**`Str :%metadata`**

This can be used to preset values for `title`, `subtitle`, `name`, `author` or `version`.

This is an alternative to, and will override `=TITLE`, `=SUBTITLE`, `=NAME`, `=AUTHOR` or `=VERSION` directives.

Note: All of these are options are provided for compatibility, however only `=TITLE` and `=AUTHOR` are directly supported in PDF metadata.

**`:!contents`**

Disables Table of Contents generation.

**`:!index`**

Disable writing of a `Index` section to the table of contents.

**`:$linker`**

Provides a class or object to intercept and sanitise or rebase links. The class/object should provide a method `resolve-link` that accepts the target component of C<L<>> formatting codes and returns the actual link to be embedded in the PDF. The link is omitted, if the method returns an undefined value.

**`:%replace`**

Specify replacements for `R<>` placeholders in the POD. Replacement values should be simple strings (`Str`), Pod blocks (type `Pod::Block`), or a `List`. For example:

```raku
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
```

Installation
============

This module's dependencies include [HarfBuzz](https://harfbuzz-raku.github.io/HarfBuzz-raku/), [Font::FreeType](https://pdf-raku.github.io/Font-FreeType-raku/), [FontConfig](https://raku.land/zef:dwarring/FontConfig) and [Cairo](https://raku.land/github:timo/Cairo), which further depend on native `harfbuzz`, `freetype6`, `fontconfig` and `cairo` libraries.

Please check these module's installation instructions.

Testing
=======

Note that installation of the [PDF::Tags::Reader](PDF::Tags::Reader) module enables structural testing. 

For example, to test this module from source.

    $ git clone https://github.com/dwarring/Pod-To-PDF-raku
    $ cd Pod-To-PDF-raku
    $ zef install PDF::Tags::Reader # enable structural tests
    $ zef APP::Prove6
    $ zef --deps-only install .
    $ prove6 -I .

