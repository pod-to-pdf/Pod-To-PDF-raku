unit class Pod::To::Cairo;

use Pod::To::Cairo::Style;
use Pod::To::Cairo::TextChunk;
use HarfBuzz::Font::Cairo;
use Cairo;
use FontConfig;
use Pod::To::Text;

subset Level of Int:D where 1..6;

has $.width = 512;
has $.height = 720;
has UInt $!indent = 0;
has $!tx = 0; # text-flow x
has $!ty = 0; # text-flow y
has $.margin = 20;
has UInt $!pad = 0;
has UInt $!page-num = 0;
has HarfBuzz::Font::Cairo %!fonts;
has HarfBuzz::Font::Cairo $!cur-font;
has Str $!cur-font-patt = '';

has Cairo::Surface:D $.surface is required;
has Cairo::Context $.ctx .= new: $!surface;
has Pod::To::Cairo::Style $.style handles<font font-size leading line-height bold italic mono underline lines-before link> .= new: :$!ctx;

method read($pod) {
    self.pod2pdf($pod);
}

multi method pad(&codez) { $.pad; &codez(); $.pad}
multi method pad($!pad = 2) { }

method !pad-here {
    $.say for ^$!pad;
    $!pad = 0;
}

method !curr-font {
    given $!style.pattern -> FontConfig $patt {
        my $key := $patt.Str;
        unless $key eq $!cur-font-patt {
            $!cur-font = %!fonts{$key} //= do {
                my Str:D $file = $patt.match.file;
                HarfBuzz::Font::Cairo.new: :$file;
            }
            $!cur-font-patt = $key;
            $!ctx.set_font_face: $!cur-font.cairo-font;
        }
        $!cur-font;
    }
}

method !style(&codez, Bool :$indent, Bool :$pad, |c) {
    temp $!style .= clone: |c;
    temp $!indent;
    $!indent += 1 if $indent;
    $pad ?? $.pad(&codez) !! &codez();
}

method !text-chunk(
        Str $text,
        :$width = $!surface.width - self!indent - 2*$!margin,
        :$height = $!surface.height - $!ty - $!margin,
        |c) {
    my $font := self!curr-font();
    ::('Pod::To::Cairo::TextChunk').new: :$text, :indent($!tx), :$font, :$!style :$width, :$height, |c;
}

multi method say {
    $!tx = 0;
    $!ty += $.line-height;
}

multi method say($text) {
    self.print($text, :nl);
}
method print($text, Bool :$nl) {
    warn "STUB!";
    my $chunk = self!text-chunk($text); # not used yet
    $chunk.print(:$!ctx, :$!tx, :$!ty, :$nl);
}
method !new-page {
    $!page-num++;
    $!ctx.show_page unless $!page-num == 1;
    $!tx  = 0;
    $!ty  = 0;
}

method !heading(Str:D $Title, Level :$level = 2, :$underline = $level == 1) {
    self!style: :$underline, {
        my constant HeadingSizes = 20, 16, 13, 11.5, 10, 10;
        $.font-size = HeadingSizes[$level - 1];
        if $level == 1 {
            self!new-page;
        }
        elsif $level == 2 {
            $.lines-before = 3;
        }

        if $level < 5 {
            $.bold = True;
        }
        else {
            $.italic = True;
        }

        @.say($Title);
    }
}

multi method pod2pdf(Pod::Heading $pod) {
    $.pad: {
        my Level $level = min($pod.level, 6);
        self!heading( node2text($pod.contents), :$level);
    }
}

multi method pod2pdf(List:D $_) {
    $.pod2pdf($_) for .List;
}

multi method pod2pdf($pod) {
    warn "fallback render of {$pod.WHAT.raku}";
    $.say: pod2text($pod);
}

method !indent { 10 * $!indent; }

sub node2text($pod) {
    warn "stub";
    pod2text($pod);
}

submethod DESTROY {
    .destroy for %!fonts.values;
}
