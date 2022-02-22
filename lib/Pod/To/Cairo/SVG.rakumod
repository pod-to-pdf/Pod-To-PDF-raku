use Pod::To::Cairo;
unit class Pod::To::Cairo::SVG
    is Pod::To::Cairo;

use Cairo;
use File::Temp;

method render($class: $pod, :$file = tempfile("POD6-****.svg", :!unlink)[0], |c) {
    my Cairo::Surface::SVG $surface .= create($file, 512, 720);
    $class.new(|c, :$pod, :$surface);
    $surface.finish;
    $file;
}

our sub pod2pdf(
    $pod,
    :$class = $?CLASS,
    Str :$file = tempfile("POD6-****.svg", :!unlink)[0],
    Cairo::Surface::PDF :$surface = Cairo::Surface::SVG.create($file, 512, 720),
    |c) is export {
    $class.new(|c, :$pod, :$surface);
    $surface;
}
