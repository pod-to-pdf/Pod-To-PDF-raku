TITLE
=====



Pod::To::PDF - Pod to PDF renderer

Description
-----------

Renders Pod to PDF documents via Cairo.

Usage
-----

From command line:

    $ raku --doc=PDF lib/to/class.rakumod | xargs evince

From Raku:

```raku
use Pod::To::PDF;
use Cairo;

=NAME
foobar.pl

=head2 SYNOPSIS
=code foobar.pl <options> files ...

my Cairo::Surface::PDF $pdf = pod2pdf($=pod);
$pdf.finish();
```

Exports
-------

    class Pod::To::PDF;
    sub pod2pdf; # See below

From command line:

```shell
$ raku --doc=PDF lib/to/class.rakumod | xargs xpdf
```

From Raku code, the `pod2pdf` function returns a [Cairo::Surface::PDF](Cairo::Surface::PDF) object which can be further manipulated, or finished to complete rendering.

```raku
use Pod::To::PDF;
use Cairo;

=NAME
foobar.raku

=SYNOPSIS
    foobarraku <options> files ...

my Cairo::Surface::PDF $pdf = pod2pdf($=pod);
$pdf.finish();
```

pod2pdf() Options
-----------------

**`Str() :$file`**

A filename for the output PDF file.

**`Cairo::Surface::PDF :$surface`**

A surface to render to

**`UInt:D :$width, UInt:D :$height`**

The page size in points (there are 72 points per inch).

**`UInt:D :$margin`**

The page margin in points

**`Hash @fonts`**

By default, Pod::To::PDF loads system fonts via L<FontConfig>. This option can be used to preload selected fonts.

```raku
use Pod::To::PDF;
use Cairo;
my @fonts = (
    %(:file<fonts/Raku.otf>),
    %(:file<fonts/Raku-Bold.otf>, :bold),
    %(:file<fonts/Raku-Italic.otf>, :italic),
    %(:file<fonts/Raku-BoldItalic.otf>, :bold, :italic),
    %(:file<fonts/Raku-Mono.otf>, :mono),
);

my Cairo::Surface::PDF $pdf = pod2pdf($=pod, :@fonts, :file<out.pdf>);
$pdf.finish();
```

Each font entry should have a `file` entry and various combinations of `bold`, `italic` and `mono` flags. Note that `mono` is used to render code blocks. 

**`:!contents`**

Disables Table of Contents generation.

