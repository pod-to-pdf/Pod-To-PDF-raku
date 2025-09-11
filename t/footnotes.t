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
    </Reference><Note>if you click, here, you should got back to the paragraph</Note> footnotes. <Reference>
      <Lbl>
        <Link>[2]</Link>
      </Lbl>
    </Reference>
  </P>
  <Lbl>
    <Link>[1]</Link>
  </Lbl>
  <Lbl>
    <Link>[2]</Link>
  </Lbl>
  <Note>a footnote with a <Link href="link">link</Link></Note>
</Document>
};

if (try require PDF::Tags::Reader) === Nil {
    skip-rest "PDF::Tags::Reader is required to perform structural PDF testing";
    exit 0;
}

todo "Tags are not supported for Cairo version " ~ Cairo::version
    unless Pod::To::PDF.tags-support;

subtest 'footnote structure', {
    plan 1;
    # PDF::Class is an indirect dependency of PDF::Tags::Reader
    require PDF::Class;
    my $pdf  = PDF::Class.open: "tmp/footnotes.pdf";
    my $tags = PDF::Tags::Reader.read: :$pdf;
    is $tags[0].Str, $xml, 'footnote structure as expected';
}

=begin pod

=para sanity test of N<if you click, here, you should got back to the paragraph> footnotes. N<a footnote with a L<link>>

=end pod
