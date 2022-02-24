use Pod::To::Cairo;
unit class Pod::To::PDF:ver<0.0.1>
    is Pod::To::Cairo;

use Cairo;
use File::Temp;

has Str $!title;
has int32 @!outline-stack;

submethod TWEAK(Str :$title, Str :$lang = 'en') {
    self.title = $_ with $title;
    self.surface.set_metadata(CAIRO_PDF_METADATA_CREATOR, "Raku {self.^name} v{self.^ver}");
}

method render(
    $class: $pod,
    :$file = tempfile("POD6-****.pdf", :!unlink)[0],
    UInt:D :$width  = 512,
    UInt:D :$height = 720,
    |c,
) {
    state %cache{Any};
    %cache{$pod}{$width~'x'~$height} //= do {
        my Cairo::Surface::PDF $surface .= create($file, $width, $height);
        $class.new(:$pod, :$surface, :$width, :$height, |c);
        $surface.finish;
        $file;
    }
}

our sub pod2pdf(
    $pod,
    :$class = $?CLASS,
    Str :$file = tempfile("POD6-****.pdf", :!unlink)[0],
    UInt:D :$width  = 512,
    UInt:D :$height = 720,
    Cairo::Surface::PDF :$surface = Cairo::Surface::PDF.create($file, $width, $height);
    |c,
) is export {
    $class.new(|c, :$pod, :$surface);
    $surface;
}

method add-toc-entry(Str:D $Title, Str :$dest!, UInt:D :$level! ) {
    my Str $name = $Title.subst(/\s+/, ' ', :g); # Tidy a little
    @!outline-stack.pop while @!outline-stack >= $level;
    my int32 $parent-id = $_ with @!outline-stack.tail;
    while @!outline-stack < $level-1 {
        # e.g. jump from =head1 to =head3
        # need to insert missing entries
        $parent-id = $.surface.add_outline: :$parent-id, :$dest;
        @!outline-stack.push: $parent-id;
    }
    my uint32 $toc-id = $.surface.add_outline: :$parent-id, :$name, :$dest;
    @!outline-stack.push: $toc-id;
}

method title is rw {
    Proxy.new(
        FETCH => { $!title },
        STORE => -> $, $!title {
            self.surface.set_metadata(CAIRO_PDF_METADATA_TITLE, $!title);
        }
    )
}

