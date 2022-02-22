use Pod::To::Cairo;
unit class Pod::To::Cairo::PDF:ver<0.0.1>
    is Pod::To::Cairo;

use Cairo;
use File::Temp;

has Str $!title;
has int32 @!outline-stack;

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

submethod TWEAK(Str :$title, Str :$lang = 'en') {
    self.title = $_ with $title;
    self.surface.set_metadata(CAIRO_PDF_METADATA_CREATOR, "Raku {self.^name} v{self.^ver}");
}

method render($class: $pod, :$file = tempfile("POD6-****.pdf", :!unlink)[0], |c) {
    my Cairo::Surface::PDF $surface .= create($file, 512, 720);
    $class.new(|c, :$pod, :$surface);
    $surface.finish;
    $file;
}

our sub pod2pdf(
    $pod,
    :$class = $?CLASS,
    Str :$file = tempfile("POD6-****.pdf", :!unlink)[0],
    Cairo::Surface::PDF :$surface = Cairo::Surface::PDF.create($file, 512, 720),
    |c) is export {
    $class.new(|c, :$pod, :$surface);
    $surface;
}
