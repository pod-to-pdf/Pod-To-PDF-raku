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
has $.margin = 20;
has $!tx = $!margin; # text-flow x
has $!ty = $!margin; # text-flow y
has UInt $!pad = 0;
has UInt $!page-num = 0;
has HarfBuzz::Font::Cairo %!fonts;
has HarfBuzz::Font::Cairo $!cur-font;
has Str $!cur-font-patt = '';

enum Tags ( :CODE<Code>, :Document<Document>, :Paragraph<P> );

has Cairo::Surface:D $.surface is required;
has Cairo::Context $.ctx .= new: $!surface;
has Pod::To::Cairo::Style $.style handles<font font-size leading line-height bold italic mono underline lines-before link> .= new: :$!ctx;

method read($pod) {
    $!ctx.tag: Document, {
        self.pod2pdf($pod);
    }
}

submethod TWEAK(:$pod) {
    self.read($_) with $pod;
}

method title { warn "ignoring title"; }

multi method pad(&codez) { $.pad; &codez(); $.pad}
multi method pad($!pad = 2) {}

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

method !style(&codez, Bool :$indent, Str :tag($name), Bool :$pad, |c) {
    temp $!style .= clone: |c;
    temp $!indent;
    $!indent += 1 if $indent;
    $.pad if $pad;
    my $rv := $name ?? $!ctx.tag($name, &codez) !! &codez();
    $.pad if $pad;
    $rv;
}

method !text-chunk(
    Str $text,
    :$width = $!surface.width - self!indent - 2*$!margin,
    :$height = $!surface.height - $!ty - $!margin,
    |c,
) {
    my $font := self!curr-font();
    ::('Pod::To::Cairo::TextChunk').new: :$text, :indent($!tx - $!margin), :$font, :$!style :$width, :$height, |c;
}

multi method say {
    $!tx = $!margin;
    $!ty += $.line-height;
}

multi method say($text) {
    self.print($text, :nl);
}
method print($text is copy, Bool :$nl) {
    self!pad-here;
    $text ~= "\n" if $nl && !$text.ends-with: "\n";
    my $chunk = self!text-chunk($text);
    my $x = $!tx + self!indent;
    my $y = $!ty;
    $chunk.print(:$!ctx, :$x, :$y);
    my \x0 = $!tx;
    my \y0 = $!ty;
    $!tx = $!margin + $chunk.cursor.re;
    $!ty += $chunk.cursor.im;
    ($chunk.content-height, '');
}
method !new-page {
    $!page-num++;
    $!surface.show_page unless $!page-num == 1;
    $!tx  = $!margin;
    $!ty  = $!margin;
}

method !heading(Str:D $Title, Level :$level = 2, :$underline = $level == 1) {
    self!style: :tag('H' ~ $level), :$underline, {
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

method !code(Str $code is copy, :$inline) {
    $code .= chomp;
    self!style: :mono, :indent(!$inline), :tag(CODE), {
        while $code {
            $.lines-before = min(+$code.lines, 3)
                unless $inline;
            $.font-size *= .8;
            my (\h, \overflow) = $.print: $code, :!reflow;
            $code = overflow;

            unless $inline {
                # draw code-block background
                my constant pad = 5;
                my $x0 = self!indent + $!margin;
                my $width = $!surface.width - $!margin - $x0;

                given $!ctx {
                    .save;
                    .rgba(0, 0, 0, 0.1);
                    .line_width = 1.0;
                    .rectangle($x0 - pad, $!ty - h - pad, $width + 2*pad, h + 2*pad);
                    .fill: :preserve;
                    .rgba(0, 0, 0, 0.25);
                    .stroke;
                    .restore;
                }
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Named $pod) {
    $.pad: {
        given $pod.name {
            when 'pod'  { $.pod2pdf($pod.contents)     }
            when 'para' {
                $.pod2pdf: $pod.contents;
            }
            when 'config' { }
            when 'nested' {
                self!style: :indent, {
                    $.pod2pdf: $pod.contents;
                }
            }
            default     {
                given $pod.name {
                    when 'TITLE' {
                        my Str $title = pod2text($pod.contents);
                        self.title //= $title;
                        $.pad: {
                            self!heading: $title, :level(1);
                        }
                    }
                    when 'SUBTITLE' {
                        $.pad: {
                            self!heading: pod2text($pod.contents), :level(2);
                        }
                    }
                    default {
                        warn "unrecognised POD named block: $_";
                        $.say($_);
                        $.pod2pdf($pod.contents);
                    }
                }
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Code $pod) {
    $.pad: {
        self!code: $pod.contents.join;
    }
}

multi method pod2pdf(Pod::Heading $pod) {
    $.pad: {
        my Level $level = min($pod.level, 6);
        self!heading( node2text($pod.contents), :$level);
    }
}

multi method pod2pdf(Pod::Block::Para $pod) {
    $.pad: {
        self!style: :tag(Paragraph), {
            $.pod2pdf($pod.contents);
        }
    }
}

multi method pod2pdf(Str $pod) {
    $.print($pod);
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
    pod2text($pod);
}

submethod DESTROY {
    .destroy for %!fonts.values;
}
