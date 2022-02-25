use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 2;

mkdir "tmp";
my $pdf-file = "tmp/paragraph.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$pdf-file);
lives-ok {$pdf.finish}

my $xml = q{<Document>
  <P>
    This is all a paragraph.
  </P>
  <P>
    This is the next paragraph.
  </P>
  <P>
    This is the third paragraph.
  </P>
  <P>
    Abbreviated paragraph
  </P>
  <P>
    Paragraph paragraph
  </P>
  <P>
    Block
  </P>
  <P>
    paragraph
  </P>
  <P>
    spaces and tabs are ignored
  </P>
  <P>
    sanity test of 
    <Lbl>
      <Link>[1]</Link>
    </Lbl>
     footnotes.
  </P>
  <P>
    Paragraph with formatting, <Code>code</Code> and <Link href="#blah">links</Link>.
  </P>
  <P>
    aaaaabbbbbcccccdddddeeeeeﬀﬀfggggghhhhhiiiiijjjjjkkkkklllllmmmmmnnnnnooooopppppqqqqqrrrrrssssstttttuuuuuv
  </P>
  <Note>
    <Lbl>
      <Link>[1]</Link>
    </Lbl>
    if you click, here, you should got back to the paragraph</Note>
</Document>
};

try require ::('PDF::Tags::Reader');
if ::('PDF::Tags::Reader') ~~ Failure {
    skip-rest "PDF::Tags::Reader is required to perform structural PDF testing";
    exit 0;
}

todo "Cairo losing spaces";
subtest 'document structure', {
    plan 1;
    # PDF::Class is an indirect dependency of PDF::Tags::Reader
    require ::('PDF::Class');
    my $pdf  = ::('PDF::Class').open: "tmp/paragraph.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=begin pod
This is all
a paragraph.

This is the
next paragraph.

This is the
third paragraph.
=end pod

=para Abbreviated paragraph

=for para
Paragraph
paragraph

=begin para
Block

paragraph
=end para

=para spaces  and	tabs are ignored

=para sanity test of N<if you click, here, you should got back to the paragraph> footnotes.

=para Paragraph U<with> B<formatting>, C<code> and L<links|#blah>.

=para aaaaabbbbbcccccdddddeeeeefffffggggghhhhhiiiiijjjjjkkkkklllllmmmmmnnnnnooooopppppqqqqqrrrrrssssstttttuuuuuvvvvvwwwwwxxxxxyyyyyzzzzz
