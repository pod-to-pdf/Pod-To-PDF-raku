use Pod::To::Cairo;
unit class Pod::To::PDF
    is Pod::To::Cairo;

use Cairo;
use File::Temp;

submethod TWEAK(Str :$title, Str :$lang = 'en', :$pod) {
    self.read($_) with $pod;
}

method render($class: $pod, |c) {
    my ($file-name, ) = tempfile("POD6-****.pdf", :!unlink);
    my Cairo::Surface::PDF $surface .= create($file-name, 512, 720);
    my $renderer = $class.new(|c, :$pod, :$surface);
    $surface.finish;
    $file-name;
}

our sub pod2pdf($pod, :$class = $?CLASS, |c) is export {
    my ($file-name, ) = tempfile("POD6-****.pdf", :!unlink);
    my Cairo::Surface::PDF $surface .= create($file-name, 512, 720);
    $class.new(|c, :$pod, :$surface);
    $surface;
}
