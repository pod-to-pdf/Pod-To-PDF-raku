use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 2;

mkdir "tmp";
my $save-as = "tmp/paragraph.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$save-as);
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
    Paragraph with formatting, <Code>code</Code> and <Reference><Link href="#blah">links</Link></Reference>.
  </P>
  <P>
    Paragraph with (see: <Link href="file:included.pod">ﬁle:included.pod</Link>) placement
  </P>
  <P>
    aaaaabbbbbcccccdddddeeeeeﬀﬀfggggghhhhhiiiiijjjjjkkkkklllllmmmmmnnnnnooooopppppqqqqqrrrrrssssstttttuuuuuvvvvvwwwwwxxxxxy
  </P>
</Document>
};

if (try require PDF::Tags::Reader) === Nil {
    skip-rest "PDF::Tags::Reader is required to perform structural PDF testing";
    exit 0;
}

subtest 'document structure', {
    plan 1;
    # PDF::Class is an indirect dependency of PDF::Tags::Reader
    require PDF::Class;
    my $pdf  = PDF::Class.open: "tmp/paragraph.pdf";
    my $tags = PDF::Tags::Reader.read: :$pdf;
    my $actual-xml = $tags[0].Str(:omit<Span>);
    todo 'losing intra-formatting space'
        if $actual-xml ~~ s/withformatting/with formatting/;
    is $actual-xml, $xml, 'PDF Structure is correct';
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

=para Paragraph U<with> B<formatting>, C<code> and L<links|#blah>.

=para Paragraph with P<file:included.pod> placement

=comment a single word that exceeds the line width

=para aaaaabbbbbcccccdddddeeeeefffffggggghhhhhiiiiijjjjjkkkkklllllmmmmmnnnnnooooopppppqqqqqrrrrrssssstttttuuuuuvvvvvwwwwwxxxxxyyyyyzzzzz
