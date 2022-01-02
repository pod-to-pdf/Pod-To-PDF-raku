unit class Pod::To::Cairo;

use Pod::To::Cairo::Style;
use Cairo;
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

method !style(&codez, Bool :$indent, Bool :$pad, |c) {
    temp $!style .= clone: |c;
    temp $!indent;
    $!indent += 1 if $indent;
    $pad ?? $.pad(&codez) !! &codez();
}

multi method say {
    $!tx = 0;
    $!ty -= $.line-height;
}
multi method say($wot) {
    warn "STUB!";
    for $wot.lines {
        $!ctx.move_to($!tx, $!ty);
        $!ctx.show_text($_);
        $!ty += $.line-height;
    }
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

multi method pod2pdf($pod) {
    warn "fallback render of {$pod.WHAT.raku}";
    $.say: pod2text($pod);
}

sub node2text($pod) {
    warn "stub";
    pod2text($pod);
}
