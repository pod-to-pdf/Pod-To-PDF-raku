unit class Pod::To::Cairo;

use Pod::To::Cairo::Style;
use Pod::To::Cairo::TextChunk;
use Pod::To::Cairo::Linker;
use HarfBuzz::Font::Cairo;
use Cairo;
use FontConfig;
use Pod::To::Text;

subset Level where 0..6;
my constant Gutter = 1;

has UInt $!indent = 0;
has $.margin = 20;
has $!gutter-lines = Gutter;
has UInt $!pad = 0;
has UInt $!page-num = 1;
has HarfBuzz::Font::Cairo %!fonts;
has HarfBuzz::Font::Cairo $!cur-font;
has Str $!cur-font-patt = '';
has @!footnotes;
has Bool $.contents = True;
has Bool $.verbose;
has Bool $!blank-page = True;
has UInt:D $!level = 1;
has Str @!tags;
has $.linker = Pod::To::Cairo::Linker;

enum Tags ( :Caption<Caption>, :CODE<Code>, :Document<Document>, :Header<H>, :Label<Lbl>, :ListBody<LBody>, :ListItem<LI>, :Note<Note>, :Reference<Reference>, :Paragraph<P>, :Span<Span>, :Section<Sect>, :Table<Table>, :TableBody<TBody>, :TableHead<THead>, :TableHeader<TH>, :TableData<TD>, :TableRow<TR> );

has Cairo::Surface:D $.surface is required handles <width height>;
has $!width  = $!surface.width;
has $!height = $!surface.height;
has Cairo::Context $.ctx .= new: $!surface;
has Pod::To::Cairo::Style $.style handles<font font-size leading line-height bold italic mono underline lines-before link> .= new: :$!ctx;
has $!tx = $!margin; # text-flow x
has $!ty = $!margin + self.font-size; # text-flow y

method !tag-begin($tag) {
    $!ctx.tag_begin($tag);
    @!tags.push: $tag;
}

method !tag-end {
    my Str:D $tag = @!tags.pop;
    $!ctx.tag_end($tag);
}

method !tag($tag, &codez) {
    self!tag-begin($tag);
    &codez();
    self!tag-end;
}

method read($pod) {
    self!tag: Document, {
        self.pod2pdf($pod);
        self!finish-page;
    }
}

submethod TWEAK(:$pod, :@fonts, :%metadata) {
    for @fonts -> % ( Str :$file!, Bool :$bold, Bool :$italic, Bool :$mono ) {
        # font preload
        my Pod::To::Cairo::Style $style .= new: :$bold, :$italic, :$mono;
        my Str() $key = $style.pattern;
        if $file.IO.e {
            %!fonts{$key} = HarfBuzz::Font::Cairo.new: :$file;
        }
        else {
            warn "no such font file: $file";
        }
    }
    self.metadata(.key.lc) = .value for %metadata.pairs;
    self.read($_) with $pod;
}

# Backend specific methods
method render(|) {...}
method metadata($?) is rw { $ }
method add-toc-entry(Str:D $Title, Str :$dest!, Level :$level! ) { }

multi method pad(&codez) { $.pad; &codez(); $.pad}
multi method pad($!pad = 2) {}

method !pad-here {
    $.say for ^$!pad;
    $!pad = 0;
    self!ctx;
}

method !curr-font {
    given $!style.pattern -> FontConfig $patt {
        my $key := $patt.Str;
        my $ctx := self!ctx;
        unless $key eq $!cur-font-patt {
            $!cur-font = %!fonts{$key} //= do {
                my Str:D $file = $patt.match.file;
                note "loading $file" if $!verbose;
                HarfBuzz::Font::Cairo.new: :$file;
            }
            $!cur-font-patt = $key;
            $ctx.set_font_face: $!cur-font.cairo-font;
        }
        $ctx.set_font_size($!style.font-size);
        $!cur-font;
    }
}

method !style(&codez, Int :$indent, Str :tag($name), Bool :$pad, |c) {
    temp $!style .= clone: |c;
    temp $!indent;
    $!indent += $indent if $indent;
    $.pad if $pad;
    my $rv := $name ?? self!tag($name, &codez) !! &codez();
    $.pad if $pad;
    $rv;
}

method !height-remaining {
    $!height - $!ty - $!margin - $!gutter-lines * $.line-height
}

method !text-chunk(
    Str $text,
    Numeric :$width = $!width - self!indent - $!margin,
    Numeric :$height = self!height-remaining,
    Complex :$flow = ($!tx - self!indent) + 0i;
    |c,
) {
    my $font := self!curr-font();
    ::('Pod::To::Cairo::TextChunk').new: :$text, :$flow, :$font, :$!style :$width, :$height, |c;
}

multi method say {
    $!tx = self!indent;
    $!ty += $.line-height
        unless $!blank-page;
}

multi method say($text) {
    self.print($text, :nl);
}

method !link_begin($chunk, :$x!, :$y!) {
    my %link = %.link;
    if %link<uri> {
        my $width = $chunk.lines > 1 ?? $chunk.width !! $chunk.flow.re - $!tx + $x;
        my $height = $chunk.content-height;
        my @rect = [$!tx, $!ty - $.font-size, $width, $height];
        %link ,= :@rect;
    }
    self!ctx.link_begin: |%link;
}

method print($text is copy, Bool :$nl) {
    self!pad-here;
    $!blank-page = False;
    $text ~= "\n" if $nl && !$text.ends-with: "\n";
    my $x = self!indent;
    my $y = $!ty;
    my $chunk = self!text-chunk($text, :$x, :$y);

    if %.link {
        self!link_begin: $chunk, :$x, :$y;
        $!ctx.save;
        $!ctx.rgb(.1, .1, 1);
    }

    $chunk.print(:$!ctx);
    self!underline($chunk) if $.underline;

    if %.link {
        $!ctx.restore;
        $!ctx.link_end;
    }

    $!ty += $chunk.lines * $.line-height;
    if $nl {
        $!tx = $!margin;
    }
    else {
        $!tx = $x + $chunk.flow.re;
        $!ty -= $.line-height;
    }
    my \w = $chunk.lines > 1 ?? $chunk.width !! $chunk.flow.re;
    my \h = $chunk.content-height;
    (w, h, $chunk.overflow);
}


method !finish-page {
    if @!footnotes {
        temp $!style .= new: :lines-before(0); # avoid current styling
        $!tx = $!margin;
        $!ty = $!height - $!margin - $!gutter-lines * $.line-height;

        self!draw-line($!margin, $!ty, $!width - $!margin, $!ty);
        temp $!gutter-lines = 0;

        while @!footnotes {
            $.pad(1);
            my $footnote = @!footnotes.shift;
            self!style: :tag(Note), {
                my $y = $footnote.shift;
                my $ind = $footnote.shift;
                my %link = :page($!page-num), :pos[$!margin, $y];
                self!style: :tag(Label), :%link, {
                    $.print($ind); #[n]
                }
                $!tx += 5;
                self!tag: Paragraph, {
                    $.pod2pdf($footnote);
                }
            }
        }
    }
}

method !new-page {
    self!finish-page();
    $!gutter-lines = Gutter;
     unless $!blank-page {
         $!surface.show_page;
         $!tx  = self!indent;
         $!ty  = $!margin + $.font-size;
         $!page-num++;
         $!blank-page = True;
     }
}

method !ctx {
    if self!height-remaining < $.lines-before * $.line-height {
        self!new-page;
    }
    elsif $!tx > $!margin && $!tx > $!width - self!indent {
        self.say;
    }
    $!ctx;
}

# a simple algorithm for sizing table column widths
sub fit-widths($width is copy, @widths) {
    my $cell-width = $width / +@widths;
    my @idx;

    for @widths.pairs {
        if .value <= $cell-width {
            $width -= .value;
        }
        else {
            @idx.push: .key;
        }
    }

    if @idx {
        if @idx < @widths {
            my @over;
            my $i = 0;
            @over[$_] := @widths[ @idx[$_] ]
                for  ^+@idx;
            fit-widths($width, @over);
        }
        else {
            $_ = $cell-width
                  for @widths;
        }
    }
}

sub dest-name(Str:D $_) {
    # restrict to a smaller character set
    .trim
    .subst(/[\s|<-[0..9A..Za..z\-.~_]>]+/, '_', :g);
}

my constant vpad = 2;
my constant hpad = 10;

method !table-row(@row, @widths, Bool :$header) {
    if +@row -> \cols {
        self!tag: TableRow, {
            my @overflow;
            # simple fixed column widths, for now
            self!ctx;
            my $tab = self!indent;
            my $row-height = 0;
            my $height = $!surface.height - $!ty - $!margin;
            my $cell-tag = $header ?? TableHeader !! TableData;
            my $head-space = $.line-height - $.font-size;

            for ^cols {
                my $width = @widths[$_];
                if @row[$_] -> $tb is rw {
                    if $tb.content-width > $width || $tb.content-height > $height {
                        $tb .= clone: :$width, :$height;
                    }
                    self!tag: $cell-tag, {
                        $tb.print: :$!ctx, :x($tab), :y($!ty);
                        if $header {
                            # draw underline
                            my $y = $!ty - self!underline-position + $head-space;
                            self!draw-line: $tab, $y, $tab + $width;
                        }
                    }
                    given $tb.content-height {
                        $row-height = $_ if $_ > $row-height;
                    }
                    if $tb.overflow -> $text {
                        @overflow[$_] = $tb.clone: :$text, :$width, :height(Inf);
                    }
                }
                $tab += $width + hpad;
            }
            if @overflow {
                # continue table
                self!style: :lines-before(3), {
                    self!table-row(@overflow, @widths, :$header);
                }
            }
            else {
                $!ty += $row-height + vpad;
                $!ty += $head-space if $header;
            }
        }
    }
}

method !table-cell($pod) {
    my $text = pod2text-inline($pod);
    self!text-chunk: $text, :width(Inf), :height(Inf), :flow(0 + 0i);
}

method !build-table($pod, @table) {
    my $x0 = self!indent;
    my \total-width = $!width - $x0 - $!margin;
    @table = ();

    self!style: :bold, :lines-before(3), {
        my @row = $pod.headers.map: { self!table-cell($_) }
        @table.push: @row;
    }

    $pod.contents.map: {
        my @row = .map: { self!table-cell($_) }
        @table.push: @row;
    }

    my $cols = @table.max: *.Int;
    my @widths = (^$cols).map: -> $col { @table.map({.[$col].?content-width // 0}).max };
   fit-widths(total-width - hpad * (@widths-1), @widths);
   @widths;
}

multi method pod2pdf(Pod::Block::Table $pod) {
    my @widths = self!build-table: $pod, my @table;

    self!style: :lines-before(3), :pad, {
        self!tag: Table, {
            if $pod.caption -> $caption {
                self!style: :tag(Caption), :italic, {
                    $.say: $caption;
                }
            }
            self!pad-here;
            my @header = @table.shift.List;
            if @header {
                self!tag: TableHead, {
                    self!table-row: @header, @widths, :header;
                }
            }

            if @table {
                 self!tag: TableBody, {
                     for @table {
                         my @row = .List;
                         if @row {
                             self!table-row: @row, @widths;
                         }
                     }
                }
            }
        }
    }
}

has UInt %!dest-used;
method !gen-dest-name($title, $seq = '') {
    my $name = dest-name($title ~ $seq);
    if %!dest-used{$name}++ {
        self!gen-dest-name($title, ($seq||0) + 1);
    }
    else {
        $name;
    }
}

method !heading(Str:D $Title, Level:D :$level = $!level, :$underline = $level <= 1, Bool :$toc = True) {
    my constant HeadingSizes = 24, 20, 16, 13, 11.5, 10, 10;
    my $font-size = HeadingSizes[$level];
    my Bool $bold   = $level <= 4;
    my Bool $italic;
    my $lines-before = $.lines-before;

    given $level {
        when 1   { self!new-page; }
        when 2   { $lines-before = 3; }
        when 3   { $lines-before = 2; }
        when 5   { $italic = True; }
    }

    my $tag = 'H' ~ ($level||1);
    self!style: :$tag, :$font-size, :$bold, :$italic, :$underline, :$lines-before, {

        my Str:D $name = self!gen-dest-name($Title);
        self!pad-here;
        self!ctx.destination: :$name, {
            $.say($Title);
        }

        self.add-toc-entry: $Title, :dest($name), :$level
            if $toc;
    }
}

method !code(Str $code is copy, :$inline) {
    my $font-size = 8;
    my $lines-before = $.lines-before;
    $lines-before = min(+$code.lines, 3)
        unless $inline;

    self!style: :mono, :indent(!$inline), :tag(CODE), :$font-size, :$lines-before, {
        $code .= chomp;

        while $code {
            my (\w, \h, \overflow) = @.print: $code;
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
            self!new-page if overflow;
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
            when 'TITLE'|'SUBTITLE' {
                $.pad(0);
                my $toc = $_ eq 'TITLE';
                $!level = $toc ?? 0 !! 2;
                my $title = pod2text-inline($pod.contents);
                self.metadata(.lc) ||= $title;
                self!heading($title, :$toc);
            }
            default {
                my $name = $_;
                temp $!level += 1;
               if $name eq $name.uc {
                    if $name ~~ 'VERSION'|'NAME'|'AUTHOR' {
                        self.metadata(.lc) ||= pod2text-inline($pod.contents);
                    }
                    $!level = 2;
                    $name = .tclc;
                }

                self!heading($name);
                $.pod2pdf($pod.contents);
            }
        }
    }
}

multi method pod2pdf(Pod::Item $pod) {
    $.pad: {
        my Level $list-level = min($pod.level // 1, 3);
        self!style: :tag(ListItem), :pad, :indent($list-level), {
            {
                my constant BulletPoints = ("\c[BULLET]",
                                            "\c[WHITE BULLET]",
                                            '-');
                my Str $bp = BulletPoints[$list-level - 1];
                self!style: :tag(Label), {
                    $.print: $bp;
                }
            }

            # slightly iffy $!ty fixup
            $!ty -= 2 * $.line-height;

            self!style: :tag(ListBody), :indent, {
                $.pod2pdf($pod.contents);
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Code $pod) {
    self!style: :pad, :tag(Paragraph), {
        self!code: pod2text-code($pod);
    }
}

multi method pod2pdf(Pod::Heading $pod) {
    $.pad: {
        $!level = min($pod.level, 6);
        self!heading( pod2text-inline($pod.contents));
    }
}

multi method pod2pdf(Pod::Block::Para $pod) {
    $.pad: {
        self!style: :tag(Paragraph), {
            $.pod2pdf($pod.contents);
        }
    }
}

sub uri-to-ascii($s) {
    $s.subst: rx/<- [\x0 .. \x7f]>/, { .Str.encode.list.fmt('%%%X', "") }, :g
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
            # rough positioning to footnote area
            my @pos = $!margin, $!height - $!margin - (Gutter+2) * $.line-height;
            my %link = :page($!page-num), :@pos;
            my $ind = '[' ~ @!footnotes+1 ~ ']';
            self!tag: Reference, {
                self!style: :tag(Label), :%link, {  $.pod2pdf($ind); }
            }
            my @contents = $!ty - $.line-height, $ind, $pod.contents.Slip;
            @!footnotes.push: @contents;
            do {
                # pre-compute footnote size 
                temp $!style .= new;
                temp $!tx = $!margin;
                temp $!ty = $!margin;
                my $draft-footnote = $ind ~ pod2text-inline($pod.contents);
                $!gutter-lines += self!text-chunk($draft-footnote).lines;
            }
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
            my $text = pod2text-inline($pod.contents);
            my %style;
            given $pod.meta.head // $text {
                if .starts-with('#') {
                    %style<link><dest> = dest-name .substr(1);
                    %style<tag> = Reference;
                }
                else {
                    with $!linker.resolve-link($_) -> $uri {
                        %style<link><uri> = uri-to-ascii $uri;
                    }
                }
            }
            self!style: |%style, {
                $.print: $text;
            }
        }
        default {
            warn "todo: POD formatting code: $_";
            $.pod2pdf($pod.contents);
        }
    }
}

multi method pod2pdf(Pod::Defn $pod) {
    $.pad;
    self!style: :bold, :tag(Label), {
        $.pod2pdf($pod.term);
    }
    $.pod2pdf($pod.contents);
}

multi method pod2pdf(Pod::Block::Declarator $pod) {
    my $w := $pod.WHEREFORE;
    my Level $level = 3;
    my ($type, $code, $name, $decl) = do given $w {
        when Method {
            my @params = .signature.params.skip(1);
            @params.pop if @params.tail.name eq '%_';
            (
                (.multi ?? 'multi ' !! '') ~ 'method',
                .name ~ signature2text(@params, .returns),
            )
        }
        when Sub {
            (
                (.multi ?? 'multi ' !! '') ~ 'sub',
                .name ~ signature2text(.signature.params, .returns)
            )
        }
        when Attribute {
            my $gist = .gist;
            my $name = .name.subst('$!', '');
            $gist .= subst('!', '.')
                if .has_accessor;

            ('attribute', $gist, $name, 'has');
        }
        when .HOW ~~ Metamodel::EnumHOW {
            ('enum', .raku() ~ signature2text($_.enums.pairs));
        }
        when .HOW ~~ Metamodel::ClassHOW {
            $level = 2;
            ('class', .raku, .^name);
        }
        when .HOW ~~ Metamodel::ModuleHOW {
            $level = 2;
            ('module', .raku, .^name);
        }
        when .HOW ~~ Metamodel::SubsetHOW {
            ('subset', .raku ~ ' of ' ~ .^refinee().raku);
        }
        when .HOW ~~ Metamodel::PackageHOW {
            ('package', .raku)
        }
        default {
            '', ''
        }
    }

    $name //= $w.?name // '';
    $decl //= $type;

    self!style: :lines-before(3), :pad, {
        self!heading($type.tclc ~ ' ' ~ $name, :$level);

        if $pod.leading -> $leading {
            self!style: :pad, :tag(Paragraph), {
                $.pod2pdf($leading);
            }
        }

        if $code {
            self!style: :pad, :tag(Paragraph), {
                self!code($decl ~ ' ' ~ $code);
            };
        }

        if $pod.trailing -> $trailing {
            $.pad;
            self!style: :pad, :tag(Paragraph), {
                $.pod2pdf($trailing);
            }
        }
    }
}

multi method pod2pdf(Pod::Block::Comment) {
    # ignore comments
}

sub signature2text($params, Mu $returns?) {
    my constant NL = "\n    ";
    my $result = '(';

    if $params.elems {
        $result ~= NL ~ $params.map(&param2text).join(NL) ~ "\n";
    }
    $result ~= ')';
    unless $returns<> =:= Mu {
        $result ~= " returns " ~ $returns.raku
    }
    $result;
}
sub param2text($p) {
    $p.raku ~ ',' ~ ( $p.WHY ?? ' # ' ~ $p.WHY !! '')
}

multi method pod2pdf(Str $pod) {
    self!style: :tag(Span), {
        $.print($pod);
    }
}

multi method pod2pdf(List:D $pod) {
    $.pod2pdf($_) for $pod.List;
}

multi method pod2pdf($pod) {
    warn "fallback render of {$pod.WHAT.raku}";
    $.say: pod2text($pod);
}

method !underline-position {
    (self!curr-font.ft-face.underline-position // -100) * $.font-size / 1000;
}

method !underline-thickness {
    (self!curr-font.ft-face.underline-thickness // 50) * $.font-size / 1000;
}

method !underline($tc, :$tab = self!indent, ) {
    my \dy = self!underline-position;
    my $linewidth = self!underline-thickness;
    for $tc.lines {
        self!draw-line(.x, .y - dy, .x1, :$linewidth);
    }
}

method !draw-line($x0, $y0, $x1, $y1 = $y0, :$linewidth = 1) {
    given $!ctx {
        .save;
        .line_width = $linewidth;
        .move_to: $x0, $y0;
        .line_to: $x1, $y1;
        .stroke;
        .restore;
    }
}

method !indent { $!margin + 10 * $!indent; }

# we're currently throwing code formatting away
multi sub pod2text-code(Pod::Block $pod) {
    $pod.contents.map(&pod2text-code).join;
}
multi sub pod2text-code(Str $pod) { $pod }

sub pod2text-inline($pod) {
    pod2text($pod).subst(/\s+/, ' ', :g);
}

submethod DESTROY {
    .destroy for %!fonts.values;
}
