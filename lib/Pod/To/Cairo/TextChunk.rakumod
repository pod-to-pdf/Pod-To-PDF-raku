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
has Complex $.flow = 0 + 0i;
has HarfBuzz::Font::Cairo:D $.font is required;
has TextDirection $.direction = 'ltr';
has Str $.text is required;
has @.overflow is rw is built;
has Pod::To::Cairo::Style $.style is rw handles <font-size leading space-width shape>;
has Bool $.verbatim;
has Cairo::Glyphs $!glyphs;

class Line {
    has $.x;
    has $.y;
    has $.x1 is rw = $!x;
    method width { $!x1 - $!x }
}
has Line @.lines is built;

submethod TWEAK(:$x!, :$y!) {
##    $!text ~= ' ' if $!flow.re > 0;
##    my $max-lines = ($!height / self.leading).Int;
    $!glyphs = self!layout: :$x, :$y;
}

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
method !layout(
    HarfBuzz::Shaper:D :$shaper = self!shaper,
    Numeric :x($x0) = 0e0, Numeric :y($y0) = 0e0,
    |c --> Cairo::Glyphs) {
    my int @nls = $!text.indices: "\n";
    my Cairo::Glyphs $layout .= new: :elems($shaper.buf.length - +@nls);
    my Cairo::cairo_glyph_t $cairo-glyph;
    my Num $x = $x0.Num + $!flow.re;
    my Num $y = $y0.Num + $!flow.im;
    my uint $nl = 0;
    @!lines = Line.new: :$x, :$y;
    my int $n = $shaper.elems;
    @nls.push: $!text.chars;
    my int $j = 0;
    my int $next-nl = @nls.shift;
    my \space = $!font.ft-face.glyph-index: ' ';
    my int $wb-i;
    my int $wb-j;
    my $glyph;
    my Bool $first-word = ! $!flow.re;
    my Bool $word-wrap;

    loop (my int $i = 0; $i < $n; $i++) {
        $glyph = $shaper[$i];
        if $glyph.cluster == $next-nl {
            $next-nl = @nls.shift;
            $nl++;
        }
        else {
            if $glyph.gid == space {
                if ($x - $x0) > $!width {
                    $word-wrap = True;
                }
                else {
                    $wb-i = $i + 1;
                    $wb-j = $j;
                }
                $first-word = False;
            }
            elsif $i == $n - 1 && $x > $!width && !$first-word {
                $word-wrap = True;
            }

            if $word-wrap {
                # word exceeds line length. backup this word and
                # restart on next line
                $nl ||= 1;
                $i = $wb-i;
                $j = $wb-j;
                $wb-i = $i + 1;
                $glyph = $shaper[$i];
                $word-wrap = False;
            }

            while $nl {
                $first-word = True;
                @!lines.tail.x1 = $x;
                $x = $x0.Num;
                $y += $.leading * $.font-size;
                $nl-- if $nl;
                @!lines.push: Line.new: :$x, :$y;
                $wb-i = 0;
            }

            $cairo-glyph = $layout[$j++];
            $cairo-glyph.index = $glyph.gid;
            $cairo-glyph.x = $x + $glyph.x-offset;
            $cairo-glyph.y = $y + $glyph.y-offset;
            $x += $glyph.x-advance;
        }
    }

    $layout.x-advance = $.width;
    $layout.y-advance = $y - $y0;

    @!lines.tail.x1 = $x;
    $!flow = ($x - $x0) + ($y - $y0)i;
    $layout;
}

method content-height { $!flow.im + $.font-size }

method print(:$ctx!) {
    my $elems = $!glyphs.elems;
    $ctx.set_font_size: $.font-size;
    $ctx.show_glyphs($!glyphs);
}

