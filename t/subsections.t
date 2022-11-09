use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 2;

mkdir "tmp";
my $save-as = "tmp/subsections.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$save-as);
lives-ok {$pdf.finish}

my $xml = q{<Document>
  <H2>
    Outer
  </H2>
  <P>
    This is an outer paragraph
  </P>
  <H3>
    Inner1
  </H3>
  <P>
    This is the ﬁrst inner paragraph
  </P>
  <H3>
    Inner2
  </H3>
  <P>
    This is the second inner paragraph
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
    my $pdf  = ::('PDF::Class').open: "tmp/subsections.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=begin pod
=begin Outer

This is an outer paragraph

=begin Inner1

This is the first inner paragraph

=end Inner1

    =begin Inner2

    This is the second inner paragraph

    =end Inner2
=end Outer
=end pod
