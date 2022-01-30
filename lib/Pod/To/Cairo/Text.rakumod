unit class Pod::To::Cairo::Text;

use Text::FriBidi::Defs :FriBidiPar;
use Text::FriBidi::Line;
use Pod::To::Cairo::Style;
use HarfBuzz::Shaper::Cairo;

has Numeric $.width;
has Numeric $.height;
has Numeric $.indent = 0;
subset TextDirection of Str where 'ltr'|'rtl';
has TextDirection $.direction = 'ltr';

has Str $.text is required;
has @.overflow is rw is built;
has  Pod::To::Cairo::Style $.style is rw handles <font font-size leading space-width shape>;
has Bool $.verbatim;

method !shaper(Str:D :$text!) {
    my UInt $direction = $!direction eq 'rtl'
        ?? FRIBIDI_PAR_RTL
        !! FRIBIDI_PAR_LTR;
    my Text::FriBidi::Line $line .= new: :$text, :$direction;
    my HarfBuzz::Buffer() $buf = %( :text($line.Str), :direction(HB_DIRECTION_LTR));
    given $.font.shaping-font(:$!cache) {
        .size = $.font-size;
        HarfBuzz::Shaper::Cairo.new: :$buf, :font($_);
    }
}

method print(Bool :$nl) {
    ...
}

