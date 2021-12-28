unit class Pod::To::Cairo;

use Cairo;

has $.width = 512;
has $.height = 720;
has Cairo::Surface:D $.surface is required;
has Cairo::Context $.ctx .= new: $!surface;

method read($pod) {
    self.pod2pdf($pod);
}

method pod2pdf($_) {
    given $!ctx {
        .move_to(10, 10);
        .select_font_face("courier", Cairo::FONT_SLANT_ITALIC, Cairo::FONT_WEIGHT_BOLD);
        .show_text("***Pod::To::Cairo stub***");
    }
}
