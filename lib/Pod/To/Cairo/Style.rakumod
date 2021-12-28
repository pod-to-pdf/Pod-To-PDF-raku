#| Basic core-font styler
unit class Pod::To::Cairo::Style is rw;

use Cairo;

has Bool $.bold;
has Bool $.italic;
has Bool $.underline;
has Bool $.mono;
has Numeric $.font-size = 10;
has UInt $.lines-before = 1;
has PDF::Action $.link;

method leading { 1.1 }
method line-height {
    $.leading * $!font-size;
}

method font {
    
}
