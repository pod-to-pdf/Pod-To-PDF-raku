use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 5;

mkdir "tmp";
my $pdf-file = "tmp/metadata.pdf";
my $width = 200;
my $height = 250;
my Cairo::Surface::PDF $surface .= create($pdf-file, $width, $height);
my Pod::To::PDF $pod .= new(:$=pod, :$surface, :metadata{ :title<Title as option> });

is $pod.metadata('title'), 'Title as option';
is $pod.metadata('subtitle'), 'Subtitle from POD';
is $pod.metadata('version'), '1.2.3';

lives-ok {$surface.finish}

try require ::('PDF::Class');
if ::('PDF::Class') ~~ Failure {
    skip-rest "PDF::Class is required to perform Metadata verification tests";
    exit 0;
}

subtest 'Metadata verification', {
    plan 2;
    my $pdf  = ::('PDF::Class').open: "tmp/metadata.pdf";
    my $info = $pdf.Info;
    is $info.Title, 'Title as option v1.2.3', 'PDF Title (POD title + version)';
    is $info.Subject, 'Subtitle from POD', 'PDF Subject (POD subtitle)';
}

=begin pod
=SUBTITLE Subtitle from POD
=VERSION 1.2.3

a paragraph.
=end pod

