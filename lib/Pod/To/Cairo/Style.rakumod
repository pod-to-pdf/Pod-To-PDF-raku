#| Basic core-font styler
unit class Pod::To::Cairo::Style is rw;

use Cairo;
use FontConfig;

has Bool $.bold;
has Bool $.italic;
has Bool $.underline;
has Bool $.mono;
has UInt $.lines-before = 1;
has $.font-size is built;
has $.link;
has Cairo::Context $.ctx is required;
has FontConfig $!pattern;

submethod TWEAK(:$font-size = 10) {
    self.font-size = $font-size;
}

method font-size is rw {
    Proxy.new(
        FETCH => { $!font-size },
        STORE => -> $, Numeric() $!font-size {
            $!ctx.set_font_size($!font-size);
        }
    );
}

method leading { 1.1 }
method line-height {
    $.leading * $!font-size;
}

method pattern {

    $!pattern //= do {
        my $family = $!mono ?? 'monospace' !! 'serif';
        my %patt = :$family;
        %patt<slant> = 'italic' if $!italic;
        %patt<bold>  = 'bold' if $!bold;
        FontConfig.new: |%patt;
    }
}

