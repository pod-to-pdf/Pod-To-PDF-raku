#| Basic core-font styler
unit class Pod::To::Cairo::Style;

use FontConfig;

has Bool $.bold;
has Bool $.italic;
has Bool $.underline;
has Bool $.mono;
has UInt $.lines-before = 1;
has $.font-size = 10;
has %.link;
has FontConfig $.pattern is built;

method clone { nextwith :pattern(FontConfig), |%_; }
method leading { 1.15 }
method line-height { $.leading * $!font-size; }

method family { $!mono ?? 'monospace' !! 'serif'; }

method pattern {
    $!pattern //= do {
        my %patt = :$.family;
        %patt<slant> = 'italic' if $!italic;
        %patt<weight>  = 'bold' if $!bold;
        FontConfig.new: |%patt;
    }
}

