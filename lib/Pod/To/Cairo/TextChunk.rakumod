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

has Numeric $.width = Inf;
has Numeric $.height = Inf;
has Complex $.flow = 0 + 0i;
has Complex $.start = $!flow;
has HarfBuzz::Font::Cairo:D $.font is required;
has TextDirection $.direction = 'ltr';
has Str $.text is required;
has Str $.overflow is built;
has Pod::To::Cairo::Style $.style is rw handles <font-size leading space-width shape>;
has Bool $.verbatim;
has Cairo::Glyphs $!glyphs;
has UInt $.glyph-elems;
has Numeric:D $.x = 0;
has Numeric:D $.y = 0;

class Line is rw {
    has $.x;
    has $.y;
    has $.x1 = $!x;
    method width { $!x1 - $!x }
}
has Line @.lines is built;

submethod TWEAK {
    self.layout;
}

method clone {
    given callsame() {
        .layout();
        $_;
    }
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

#| layout Cairo compatible shaped glyphs
method layout(
    HarfBuzz::Shaper:D :$shaper = self!shaper,
    |c --> Cairo::Glyphs) {
    my int @nls = $!text.indices: "\n";
    my int $n = $shaper.elems;
    $!glyphs .= new: :elems($n - +@nls);
    my Cairo::cairo_glyph_t $cairo-glyph;
    my Num $x = $!x.Num + $!start.re;
    my Num $y = $!y.Num + $!start.im;
    my uint $nl = 0;
    @!lines = Line.new: :$x, :$y;
    @nls.push: $!text.chars;
    my int $j = 0;
    my int $next-nl = @nls.shift;
    my \space = $!font.ft-face.glyph-index: ' ';
    my int $wb-i;
    my int $wb-j;
    my Bool $first-word = ! $!flow.re;

    layup:
    loop (my int $i = 0; $i < $n; $i++) {
        my $glyph = $shaper[$i];
        if $glyph.cluster == $next-nl {
            $next-nl = @nls.shift;
            $nl++;
        }
        else {
            if $glyph.gid == space {
                $first-word = False;
                $wb-i = $i + 1;
                $wb-j = $j;
            }
            elsif ($x - $!x) > $!width && !$first-word {
                # word exceeds line length. back-out this word and
                # restart on next line
                $nl ||= 1;
                $i = $wb-i;
                $j = $wb-j;
                $wb-i = $i + 1;
                $glyph = $shaper[$i];
            }

            while $nl {
                @!lines.tail.x1 = $x;
                my $dy = $.leading * $.font-size;
                if $y + $dy - $!y > $!height {
                    $!overflow = $!text.substr($glyph.cluster);
                    last layup;
                }
                $first-word = True;
                $x = $!x.Num;
                $y += $dy;
                $nl-- if $nl;
                @!lines.push: Line.new: :$x, :$y;
                $wb-i = 0;
            }

            $cairo-glyph = $!glyphs[$j++];
            $cairo-glyph.index = $glyph.gid;
            $cairo-glyph.x = $x + $glyph.x-offset;
            $cairo-glyph.y = $y + $glyph.y-offset;
            $x += $glyph.x-advance;
        }
    }

    $!glyph-elems = $j;
    $!glyphs.x-advance = $.width;
    $!glyphs.y-advance = $y - $!y;

    @!lines.tail.x1 = $x;
    $!flow = ($x - $!x) + ($y - $!y)i;
    $!glyphs;
}

method content-height { $!flow.im + $.font-size }
method content-width  { @!lines>>.x1.max - $!x }

method !translate($dx, $dy) {
    for 0 ..^ $!glyphs.elems {
        given $!glyphs[$_] {
            .x += $dx;
            .y += $dy;
        }
    }
    for @!lines {
        .x  += $dx;
        .x1 += $dx;
        .y  += $dy
    }
    $!x += $dx;
    $!y += $dy;
}

method print(:$ctx!, :$x = $!x, :$y = $!y) {
    self!translate($x - $!x, $y - $!y)
        unless $x =~= $!x && $y =~= $!y;

    $ctx.set_font_size: $.font-size;
    $ctx.show_glyphs($!glyphs, $!glyph-elems);
}

