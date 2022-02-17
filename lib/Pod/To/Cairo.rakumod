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
has Bool $.contents = True;
has int32 @outline-stack;

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

method !style(&codez, Bool :$indent, Str :tag($name) is copy, Bool :$pad, |c) {
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
    :$width = $!surface.width - self!indent - $!margin,
    :$height = $!surface.height - $!ty - $!margin,
    |c,
) {
    my $font := self!curr-font();
    my Complex $cursor = ($!tx - self!indent) + 0i;
    ::('Pod::To::Cairo::TextChunk').new: :$text, :$cursor, :$font, :$!style :$width, :$height, |c;
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
    my $x = self!indent;
    my $y = $!ty;
    if $.link {
        $!ctx.save;
        $!ctx.rgb(.1, .1, 1);
    }
    $chunk.print(:$!ctx, :$x, :$y);
    if $.link {
        if $.link.starts-with('#') {
            my $dest = $.link.substr(1);
            $!ctx.link: :$dest;
        }
        else {
            my $uri = $.link;
            my $width = $chunk.lines > 1 ?? $chunk.width !! $chunk.cursor.re - $!tx + $x;
            my $height = $chunk.content-height;
            my @rect = [$!tx, $!ty - $.font-size, $width, $height];
            $!ctx.link: :$uri, :@rect;
        }
        $!ctx.restore;
    }
    $!tx = $x + $chunk.cursor.re;
    $!ty = $y + $chunk.cursor.im;
    my \w = $chunk.lines > 1 ?? $chunk.width !! $chunk.cursor.re;
    my \h = $chunk.content-height;
    (w, h,'');
}
method !new-page {
    $!page-num++;
    $!surface.show_page unless $!page-num == 1;
    $!tx  = $!margin;
    $!ty  = $!margin;
}

sub dest-name(Str:D $_) {
    .trim
    .subst(/\s+/, '_', :g)
    .subst('#', '', :g);
}

method !heading(Str:D $Title, Level :$level = 2, :$underline = $level == 1) {
    my constant HeadingSizes = 20, 16, 13, 11.5, 10, 10;
    my $font-size = HeadingSizes[$level - 1];
    my Bool $bold   = $level <= 4;
    my Bool $italic = $level == 5;
    my $lines-before = $.lines-before;

    if $level == 1 {
        self!new-page;
    }
    elsif $level == 2 {
        $lines-before = 3;
    }

    self!style: :tag('H' ~ $level), :$font-size, :$bold, :$italic, :$underline, :$lines-before, {

        my Str:D $name = dest-name($Title);
        $!ctx.destination: :$name, {
            $.say($Title);
        }

        self!add-toc-entry: $Title, :dest($name), :$level;
    }
}

method !add-toc-entry(Str:D $Title, Str :$dest!, Level :$level! ) {
    my Str $name = $Title.subst(/\s+/, ' ', :g); # Tidy a little
    @!outline-stack.pop while @!outline-stack >= $level;
    my int32 $parent-id = $_ with @!outline-stack.tail;
    while @!outline-stack < $level-1 {
        # e.g. jump from =head1 to =head3
        # need to insert missing entries
        $parent-id = $!surface.add_outline: :$parent-id, :$dest;
        @!outline-stack.push: $parent-id;
    }
    my uint32 $toc-id = $!surface.add_outline: :$parent-id, :$name, :$dest;
    @!outline-stack.push: $toc-id;
}

method !code(Str $code is copy, :$inline) {
    $code .= chomp;
    my $font-size = 8;
    my $lines-before = $.lines-before;
    $lines-before = min(+$code.lines, 3)
        unless $inline;

    self!style: :mono, :indent(!$inline), :tag(CODE), :$font-size, :$lines-before, {
        while $code {
            my (\w, \h, \overflow) = @.print: $code, :!reflow;
            $code = overflow;

            unless $inline {
                # draw code-block background
                my constant pad = 5;
                my $x0 = self!indent;
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

multi method pod2pdf(Pod::FormattingCode $pod) {
    given $pod.type {
        when 'B' {
            self!style: :bold, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'C' {
            self!code: pod2text($pod), :inline;
        }
        when 'T' {
            self!style: :mono, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'K' {
            self!style: :italic, :mono, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'I' {
            self!style: :italic, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'N' {
            warn "todo Footnotes";
        }
        when 'U' {
            self!style: :underline, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'Z' {
            # invisable
        }
        when 'X' {
            warn "indexing (X) not yet handled";
            $.pod2pdf($pod.contents);
        }
        when 'L' {
            my $text = pod2text($pod.contents);
            given $pod.meta.head // $text -> $link {
                self!style: :$link, {
                    $.print: $text;
                }
            }
        }
        default {
            warn "todo: POD formatting code: $_";
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

method !indent { $!margin + 10 * $!indent; }

sub node2text($pod) {
    pod2text($pod);
}

submethod DESTROY {
    .destroy for %!fonts.values;
}
