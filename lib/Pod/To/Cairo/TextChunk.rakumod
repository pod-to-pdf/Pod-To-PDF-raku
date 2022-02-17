unit class Pod::To::Cairo::TextChunk;

use Text::FriBidi::Defs :FriBidiPar;
use Text::FriBidi::Line;
use Pod::To::Cairo::Style;
use HarfBuzz::Buffer;
use HarfBuzz::Raw::Defs :hb-direction;
use HarfBuzz::Font::Cairo;
use HarfBuzz::Shaper;
use Cairo;

subset TextDirection of Str where 'ltr'|'rtl';

has Numeric $.width;
has Numeric $.height;
has Complex $.cursor = 0 + 0i;
has HarfBuzz::Font::Cairo:D $.font is required;
has TextDirection $.direction = 'ltr';
has Str $.text is required;
has @.overflow is rw is built;
has Pod::To::Cairo::Style $.style is rw handles <font-size leading space-width shape>;
has Bool $.verbatim;
has UInt $.lines is built;

method !shaper {
    my UInt $direction = $!direction eq 'rtl'
        ?? FRIBIDI_PAR_RTL
        !! FRIBIDI_PAR_LTR;
    my Text::FriBidi::Line $line .= new: :$!text, :$direction;
    my HarfBuzz::Buffer() $buf = %( :text($line.Str), :direction(HB_DIRECTION_LTR));
    given $.font.shaping-font {
        .size = $.font-size;
        HarfBuzz::Shaper::Cairo.new: :$buf, :font($_);
    }
}

#| Return a set of Cairo compatible shaped glyphs
method !cairo-glyphs(
    HarfBuzz::Shaper:D :$shaper = self!shaper,
    Numeric :x($x0) = 0e0, Numeric :y($y0) = 0e0,
    |c --> Cairo::Glyphs) is export(:cairo-glyphs) {
    my int @nls = $!text.indices: "\n";
    my Cairo::Glyphs $cairo-glyphs .= new: :elems($shaper.buf.length - +@nls);
    my Cairo::cairo_glyph_t $cairo-glyph;
    my Num $x = $x0.Num + $!cursor.re;
    my Num $y = $y0.Num + $!cursor.im;
    my int $i = 0;
    my int $line = 0;
    my uint $nl = 0;
    $!lines = 0;

    @nls.push: $!text.chars + 1;

    for $shaper.shape -> $glyph {
        if $glyph.cluster >= @nls[$line] {
            $line++;
            $nl++;
        }
        else {
            while $nl || $x + $glyph.x-offset > $!width {
                $x = $x0.Num;
                $y += $.leading * $.font-size;
                $nl-- if $nl;
                $!lines++;
            }
            $cairo-glyph = $cairo-glyphs[$i++];
            $cairo-glyph.index = $glyph.gid;
            $cairo-glyph.x = $x + $glyph.x-offset;
            $cairo-glyph.y = $y + $glyph.y-offset;
            $x += $glyph.x-advance;
        }
    }

    $cairo-glyphs.x-advance = $.width;
    $cairo-glyphs.y-advance = $y - $y0;

    $!lines++ unless $x =~= $x0;
    $!cursor = ($x - $x0) + ($y - $y0)i;
    $cairo-glyphs;
}

method content-height { $!cursor.im + $.font-size }

method print(:$ctx!, :$x!, :$y!, Bool :$nl) {
    my $max-lines = ($!height / $.leading).Int;
    my Cairo::Glyphs $glyphs = self!cairo-glyphs: :$x, :$y;
    my $elems = $glyphs.elems;
    $ctx.set_font_size: $.font-size;
    $ctx.show_glyphs($glyphs);
}

