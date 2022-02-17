#| Basic core-font styler
unit class Pod::To::Cairo::Style;

use Cairo;
use FontConfig;

has Bool $.bold;
has Bool $.italic;
has Bool $.underline;
has Bool $.mono;
has UInt $.lines-before = 1;
has $.font-size = 10;
has $.link;
has Cairo::Context $.ctx is required;
has FontConfig $!pattern;

submethod TWEAK {
    $!ctx.set_font_size($!font-size);
}

method leading { 1.1 }
method line-height { $.leading * $!font-size; }

method pattern {
    $!pattern //= do {
        my $family = $!mono ?? 'monospace' !! 'serif';
        my %patt = :$family;
        %patt<slant> = 'italic' if $!italic;
        %patt<weight>  = 'bold' if $!bold;
        FontConfig.new: |%patt;
    }
}

