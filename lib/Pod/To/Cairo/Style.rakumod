#| Basic core-font styler
unit class Pod::To::Cairo::Style is rw;

use Cairo;

has Bool $.bold;
has Bool $.italic;
has Bool $.underline;
has Bool $.mono;
has UInt $.lines-before = 1;
has $.font-size is built;
has $.link;
has Cairo::Context $.ctx is required;

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

method font {
    my $family = $!mono ?? 'monospace' !! 'serif';
    my $slant  = $!italic ?? Cairo::FONT_SLANT_ITALIC !! Cairo::FONT_SLANT_NORMAL;
    my $weight = $!bold   ?? Cairo::FONT_WEIGHT_BOLD  !! Cairo::FONT_WEIGHT_NORMAL;
    $!ctx.select_font_face($family, $slant, $weight);
}
