use Pod::To::Cairo::TextChunk;

unit class Pod::To::Cairo;

use Pod::To::Cairo::Style;
use Pod::To::Cairo::Linker;
use HarfBuzz::Font::Cairo;
use Cairo;
use FontConfig;

subset Level where 0..6;
my constant Gutter = 1;

has UInt $!indent = 0;
has $.margin = 20;
has $!gutter-lines = Gutter;
has UInt $!pad = 0;
has UInt $!page-num = 1;
has Bool $.page-numbers;
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
has %.replace;
has %.index;
has $.tag = True;
has Numeric $!code-start-y;

enum Tags ( :Artifact<Artifact>, :Caption<Caption>, :CODE<Code>, :Document<Document>, :Header<H>, :Label<Lbl>, :ListBody<LBody>, :ListItem<LI>, :Note<Note>, :Reference<Reference>, :Paragraph<P>, :Quote<Quote>, :Span<Span>, :Section<Sect>, :Table<Table>, :TableBody<TBody>, :TableHead<THead>, :TableHeader<TH>, :TableData<TD>, :TableRow<TR> );

has Cairo::Surface:D $.surface is required handles <width height>;
has $!width  = $!surface.width;
has $!height = $!surface.height;
has Cairo::Context $.ctx .= new: $!surface;
has Pod::To::Cairo::Style $.style handles<font font-size leading line-height bold italic mono underline lines-before link> .= new: :$!ctx;
has $!tx = $!margin; # text-flow x
has $!ty = $!margin + self.font-size; # text-flow y

method !tag-begin($tag) {
    if $!tag {
        $!ctx.tag_begin($tag);
        @!tags.push: $tag;
    }
}

method !tag-end {
    if $!tag {
        my Str:D $tag = @!tags.pop;
        $!ctx.tag_end($tag);
    }
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

method !preload-fonts(@fonts) {
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
}

submethod TWEAK(:$pod, :@fonts, :%metadata) {
    if $!margin < 10 && $!page-numbers {
        note "omitting page-numbers for margin < 10";
        $!page-numbers = False;
    }
    self!preload-fonts(@fonts);
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
        unless $key eq $!cur-font-patt {
            my Str:D $file = $patt.match.file;
            $!cur-font = %!fonts{$file} //= do {
                note "loading font $file" if $!verbose;
                HarfBuzz::Font::Cairo.new: :$file;
            }
            $!cur-font-patt = $key;
            my $ctx := self!ctx;
            $ctx.set_font_face: $!cur-font.cairo-font;
        }
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
    $!height - $!ty - $!margin - ($!gutter-lines+1) * $.line-height
}

method !lines-remaining {
    my $line-continuation := $!tx > self!indent;
    (self!height-remaining / $.line-height + 0.01).Int
    + $line-continuation;
}

method !text-chunk(
    Str $text,
    Numeric :$width = $!width - self!indent - $!margin,
    Numeric :$height = self!height-remaining,
    Complex :$flow = ($!tx - self!indent) + 0i;
    |c,
) {
    my $font := self!curr-font();
    Pod::To::Cairo::TextChunk.new: :$text, :$flow, :$font, :$!style :$width, :$height, |c;
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
    my constant pad = 2;
    my %link = %.link;
    if %link<uri> {
        my $width = $chunk.lines > 1 ?? $chunk.width !! $chunk.flow.re - $!tx + $x;
        my $height = $chunk.content-height;
        my @rect = [$!tx - pad, $!ty - $.font-size, $width + 2*pad, $height + pad];
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

    if $chunk.overflow {
        my $in-code-block = $!code-start-y.defined;
        self!new-page;
        $!code-start-y = $!ty if $in-code-block;
        self.print($chunk.overflow, :$nl);
    }
}

method !finish-page {
    if $!code-start-y {
        $!ty -= $.line-height - $.font-size;
        self!finish-code;
    }

    if @!footnotes {
        temp $!style .= new: :lines-before(0); # avoid current styling
        temp $!indent = 0;
        $!tx = $!margin;
        $!ty = $!height - $!margin - $!gutter-lines * $.line-height;

        self!draw-line($!margin, $!ty, $!width - $!margin, $!ty);
        temp $!gutter-lines = 0;

        self!tag: Paragraph, {
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
                    $!tx += 3;
                    self!tag: Paragraph, {
                        $.pod2pdf($footnote);
                    }
                }
            }
        }
    }
    self!number-page()
        if !$!blank-page && $!page-numbers;

}

has $!last-page-num = 0;
method !number-page {
    my $font-size := 8;
    my Pod::To::Cairo::Style $style .= new: :$font-size;
    my HarfBuzz::Font::Cairo $font = self!curr-font;
    unless $!page-num == $!last-page-num {
        my $text = $!page-num.Str;
        my Pod::To::Cairo::TextChunk $chunk .= new: :$text, :$font, :$style;
        my $x = $.width - $!margin - $chunk.content-width;
        my $y = $.height - $!margin + $font-size;
        self!artifact: {
            $chunk.print: :$x, :$y, :$!ctx;
        }
        $!last-page-num = $!page-num;
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
    if self!lines-remaining < $.lines-before {
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
                        @overflow[$_] = $tb.clone: :$text, :$width, :overflow(Str);
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
    my $text = $.pod2text-inline($pod);
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
            my @headers = @table.shift.List;
            if @headers {
                self!tag: TableHead, {
                    self!table-row: @headers, @widths, :header;
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

method !heading($pod is copy, Level:D :$level = $!level, :$underline = $level <= 1, Bool :$toc = True, :$!pad = 2) {
    my constant HeadingSizes = 24, 20, 16, 13, 11.5, 10, 10;
    my $font-size = HeadingSizes[$level];
    my Bool $bold   = $level <= 4;
    my Bool $italic;
    my $lines-before = $.lines-before;

    given $level {
        when 0|1 { self!new-page; }
        when 2   { $lines-before = 3; }
        when 3   { $lines-before = 2; }
        when 5   { $italic = True; }
    }

    $pod .= &strip-para;

    my $tag = 'H' ~ ($level||1);
    self!style: :$tag, :$font-size, :$bold, :$italic, :$underline, :$lines-before, {

        my Str $Title = $.pod2text-inline($pod);
        my Str:D $name = self!gen-dest-name($Title);
        self!pad-here; # ensure destination is correctly positioned
        self!ctx.destination: :$name, {
            $.pod2pdf($pod);
        }

        self.add-toc-entry: $Title, :dest($name), :$level
            if $toc && $!contents;
    }
}

method !artifact(&code) {
    ## $!ctx.tag_begin(Artifact); # can't do content-level tags
    &code();
    ## $!ctx.tag_end(Artifact);
}

method !finish-code {
    my constant pad = 5;
    with $!code-start-y -> $y0 {
        my $x0 = self!indent;
        my $width = $!surface.width - $!margin - $x0 - 2*pad;
        self!artifact: {
            given $!ctx {
                .save;
                .rgba(0, 0, 0, 0.1);
                .line_width = 1.0;
                .rectangle($x0 - pad, $y0 - 2*pad, $width + 2*pad, $!ty - $y0 + 3*pad);
                .fill: :preserve;
                .rgba(0, 0, 0, 0.25);
                .stroke;
                .restore;
            }
        }
        $!code-start-y = Nil;
    }
}

method !code(@contents is copy) {
    @contents.pop if @contents.tail ~~ "\n";
    my $font-size = $.font-size * .85;

    self!ctx;

    self!style: :mono, :indent, :tag(CODE), :lines-before(0), :pad, {
        self!pad-here;
        my @plain-text;

        for 0 ..^ @contents -> $i {
            $!code-start-y //= $!ty;
            given @contents[$i] {
                when Str {
                    @plain-text.push: $_;
                }
                default  {
                    # presumably formatted
                    if @plain-text {
                        $.print: @plain-text.join;
                        @plain-text = ();
                    }
                    temp $!tag = False;
                    $.pod2pdf($_);
                }
            }
        }
        if @plain-text {
            $.print: @plain-text.join;
        }
        self!finish-code;
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
                my $toc = $_ eq 'TITLE';
                $!level = $toc ?? 0 !! 2;
                self.metadata(.lc) ||= $.pod2text-inline($pod.contents);
                self!heading($pod.contents, :$toc, :pad(1));
            }
            default {
                my $name = $_;
                temp $!level += 1;
               if $name eq $name.uc {
                    if $name ~~ 'VERSION'|'NAME'|'AUTHOR' {
                        self.metadata(.lc) ||= $.pod2text-inline($pod.contents);
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
    self!style: :pad, :tag(Paragraph), :lines-before(3), {
        self!code: $pod.contents;
    }
}

# to reduce the common case <Hn><P>Xxxx<P></Hn> -> <Hn>Xxxx</Hn>
multi sub strip-para(List $_ where +$_ == 1) {
    .map(&strip-para).List;
}
multi sub strip-para(Pod::Block::Para $_) {
    .contents;
}
multi sub strip-para($_) { $_ }

multi method pod2pdf(Pod::Heading $pod) {
    $.pad: {
        $!level = min($pod.level, 6);
        self!heading: $pod.contents;
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

method !resolve-link(Str $url) {
    my %style;
    with $url {
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
    %style;
}

has %!replacing;
method !replace(Pod::FormattingCode $pod where .type eq 'R', &continue) {
    my $place-holder = $.pod2text($pod.contents);

    die "unable to recursively replace R\<$place-holder\>"
         if %!replacing{$place-holder}++;

    my $new-pod = %!replace{$place-holder};
    without $new-pod {
        note "replacement not specified for R\<$place-holder\>"
           if $!verbose;
        $_ = $pod.contents;
    }

    my $rv := &continue($new-pod);

    %!replacing{$place-holder}:delete;;
    $rv;
}

multi method pod2pdf(Pod::FormattingCode $pod) {
    given $pod.type {
        when 'B' {
            self!style: :bold, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'C' {
            self!style: :mono, :tag(CODE), {
                $.print: $.pod2text($pod);
            }
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
                my $draft-footnote = $ind ~ $.pod2text-inline($pod.contents);
                $!gutter-lines += self!text-chunk($draft-footnote).lines;
            }
        }
        when 'U' {
            self!style: :underline, {
                $.pod2pdf($pod.contents);
            }
        }
        when 'E' {
            $.pod2pdf($pod.contents);
        }
        when 'Z' {
            # invisable
        }
        when 'X' {
            my %link;
            my $term = $.pod2text-inline($pod.contents).trim;
            if $term {
                my Str:D $name = self!gen-dest-name('index-' ~ $term);
                %link = :dest($name);
                self!ctx.destination: :$name, {
                    $.pod2pdf($pod.contents);
                }
            }
            else {
                # unamed term. link to the position on the page
                $.pod2pdf($pod.contents);

                my @pos = $!tx.round, ($!ty - $.line-height).round;
                %link = :page($!page-num), :@pos;
            }

            if $pod.meta -> $meta {
                for $meta.List {
                    my $idx = %!index{.head.trim} //= %();
                    $idx = $idx{.trim} //= %() for .skip;
                    $idx<#refs>.push: %link;
                }
            }
            elsif $term {
                %!index{$term}<#refs>.push: %link;
            }
            # otherwise X<|> ?
        }
        when 'L' {
            my $text = $.pod2text-inline($pod.contents);
            my %style = self!resolve-link: $pod.meta.head // $text;
            self!style: |%style, {
                $.print: $text;
            }
        }
        when 'P' {
            # todo insertion of placed text
            if $.pod2text-inline($pod.contents) -> $url {
                my %style = self!resolve-link: $url;
                $.pod2pdf('(see: ');
                self!style: |%style, {
                    $.print: $url;
                }
                $.pod2pdf(')');
            }
        }
        when 'R' {
            self!replace: $pod, {$.pod2pdf($_)};
        }
        default {
            warn "unhandled: POD formatting code: $_\<\>";
            $.pod2pdf: $pod.contents;
        }
    }
}

multi method pod2pdf(Pod::Defn $pod) {
    self!tag: Paragraph, {
        self!style: :bold, :tag(Quote), {
            $.pod2pdf($pod.term);
        }
    }
    $.pod2pdf: $pod.contents;
}

multi method pod2pdf(Pod::Block::Declarator $pod) {
    my $w := $pod.WHEREFORE;

    my %spec := do given $w {
        when Method {
            my @params = .signature.params.skip(1);
            @params.pop if @params.tail.name eq '%_';
            %(
                :type((.multi ?? 'multi ' !! '') ~ 'method'),
                :code(.name ~ signature2text(@params, .returns)),
            )
        }
        when Sub {
            %(
                :type((.multi ?? 'multi ' !! '') ~ 'sub'),
                :code(.name ~ signature2text(.signature.params, .returns))
            )
        }
        when Attribute {
            my $code = .gist;
            $code .= subst('!', '.')
                if .has_accessor;
            my $name = .name.subst('$!', '');

            %(:type<attribute>, :$code, :$name, :decl<has>);
        }
        when .HOW ~~ Metamodel::EnumHOW {
            %(:type<enum>, :code(.raku() ~ signature2text($_.enums.pairs)));
        }
        when .HOW ~~ Metamodel::ClassHOW {
            %(:type<class>, :name(.^name), :level(2));
        }
        when .HOW ~~ Metamodel::ModuleHOW {
            %(:type<module>, :name(.^name), :level(2));
        }
        when .HOW ~~ Metamodel::SubsetHOW {
            %(:type<subset>, :code(.raku ~ ' of ' ~ .^refinee().raku));
        }
        when .HOW ~~ Metamodel::PackageHOW {
            %(:type<package>)
        }
        default {
            %()
        }
    }

    my Str $type = %spec<type> // '';
    my Level $level = %spec<level> // 3;
    my $name = %spec<name>  // $w.?name // '';
    my $decl = %spec<decl>  // $type;
    my $code = %spec<code>  // $w.raku;

    self!style: :lines-before(3), :pad, {
        self!heading($type.tclc ~ ' ' ~ $name, :$level);

        if $pod.leading -> $leading {
            self!style: :pad, :tag(Paragraph), {
                $.pod2pdf($leading);
            }
        }

        self!style: :pad, :tag(Paragraph), {
            self!code: [$decl ~ ' ' ~ $code];
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
    $.say: $.pod2text($pod);
}

method !underline-position {
    (self!curr-font.ft-face.underline-position // -100) * $.font-size / 1250;
}

method !underline-thickness {
    (self!curr-font.ft-face.underline-thickness // 50) * $.font-size / 1250;
}

method !underline($tc, :$tab = self!indent, ) {
    my \dy = self!underline-position;
    my $linewidth = self!underline-thickness;
    self!artifact: {
        for $tc.lines {
            self!draw-line(.x, .y - dy, .x1, :$linewidth);
        }
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

method pod2text-inline($pod) {
    $.pod2text($pod).subst(/\s+/, ' ', :g);
}

multi method pod2text(Pod::FormattingCode $pod) {
    given $pod.type {
        when 'N'|'Z' { '' }
        when 'R' { self!replace: $pod, { $.pod2text($_) } }
        default  { $.pod2text: $pod.contents }
    }
}

multi method pod2text(Pod::Block $pod) {
    $pod.contents.map({$.pod2text($_)}).join;
}
multi method pod2text(List $pod) { $pod.map({$.pod2text($_)}).join }
multi method pod2text(Str $pod) { $pod }

submethod DESTROY {
    .destroy for %!fonts.values;
}
