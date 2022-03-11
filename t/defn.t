use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 2;

mkdir "tmp";
my $pdf-file = "tmp/defn.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$pdf-file);
lives-ok {$pdf.finish}

my $xml = q{<Document>
  <H2>
    pod2pdf() Options
  </H2>
  Str() :$pdf-ﬁle
  <P>
    A ﬁlename for the output PDF ﬁle.
  </P>
  Cairo::Surface::PDF :$surface
  <P>
    A surface to render to
  </P>
</Document>
};

try require ::('PDF::Tags::Reader');
if ::('PDF::Tags::Reader') ~~ Failure {
    skip-rest "PDF::Tags::Reader is required to perform structural PDF testing";
    exit 0;
}

subtest 'document structure', {
    plan 1;

    # PDF::Class is an indirect dependency of PDF::Tags::Reader
    require ::('PDF::Class');
    my $pdf  = ::('PDF::Class').open: "tmp/defn.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=begin pod

=head2 pod2pdf() Options

=defn Str() :$pdf-file
A filename for the output PDF file.

=defn Cairo::Surface::PDF :$surface
A surface to render to

=end pod
