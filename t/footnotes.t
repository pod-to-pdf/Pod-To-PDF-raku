use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 3;

mkdir "tmp";
my $save-as = "tmp/footnotes.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$save-as);
lives-ok { $pdf.finish; }
cmp-ok $pdf.status, '==', CAIRO_STATUS_SUCCESS, 'status ok';

my $xml = q{<Document>
  <P>
    sanity test of <Reference>
      <Lbl>
        <Link>[1]</Link>
      </Lbl>
    </Reference> footnotes.
  </P>
  <!-- this is how Pod::To::PDF::API6 structures footnotes
    -- see also PDF Association - Tagged PDF Best Practice Guide: Syntax
    -- Difficult to do via current tag support in Cairo's API.
    -->
  <P>
    Paragraph with formatting, <Code>code</Code> and <Reference><Link href="#blah">links</Link></Reference><Note>
      <Lbl>
        <Link>[1]</Link>
      </Lbl>
      if you click, here, you should got back to the paragraph</Note>.
  </P>
</Document>
};

if (try require PDF::Tags::Reader) === Nil {
    skip-rest "PDF::Tags::Reader is required to perform structural PDF testing";
    exit 0;
}

todo "best practice footnotes";
subtest 'footnote structure', {
    plan 1;
    # PDF::Class is an indirect dependency of PDF::Tags::Reader
    require PDF::Class;
    my $pdf  = PDF::Class.open: "tmp/footnotes.pdf";
    my $tags = PDF::Tags::Reader.read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'footnote structure as expected';
}

=begin pod

=para sanity test of N<if you click, here, you should got back to the paragraph> footnotes.

=end pod
