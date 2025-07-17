use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 3;

mkdir "tmp";
my $save-as = "tmp/defn.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$save-as);
lives-ok {$pdf.finish}
cmp-ok $pdf.status, '==', CAIRO_STATUS_SUCCESS, 'status ok';

my $xml = q{<Document>
  <H2>
    pod2pdf() Options
  </H2>
  <P>
    <Quote>Str() :$save-as</Quote>
  </P>
  <P>
    A ﬁlename for the output PDF ﬁle.
  </P>
  <P>
    <Quote>Cairo::Surface::PDF :$surface</Quote>
  </P>
  <P>
    A surface to render to
  </P>
</Document>
};

if (try require PDF::Tags::Reader) === Nil {
    skip-rest "PDF::Tags::Reader is required to perform structural PDF testing";
    exit 0;
}

todo "Tags are not supported for Cairo version " ~ Cairo::version
    unless Pod::To::PDF.tags-support;

subtest 'document structure', {
    plan 1;

    # PDF::Class is an indirect dependency of PDF::Tags::Reader
    require PDF::Class;
    my $pdf  = PDF::Class.open: "tmp/defn.pdf";
    my $tags = PDF::Tags::Reader.read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=begin pod

=head2 pod2pdf() Options

=defn Str() :$save-as
A filename for the output PDF file.

=defn Cairo::Surface::PDF :$surface
A surface to render to

=end pod
