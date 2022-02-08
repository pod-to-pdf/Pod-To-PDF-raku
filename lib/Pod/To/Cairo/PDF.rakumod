use Pod::To::Cairo;
unit class Pod::To::Cairo::PDF
    is Pod::To::Cairo;

use Cairo;
use File::Temp;

submethod TWEAK(Str :$title, Str :$lang = 'en', :$pod) {
    self.read($_) with $pod;
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
