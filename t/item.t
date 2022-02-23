use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 2;

my $file = "t/item.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$file);
lives-ok {$pdf.finish}

my $xml = q{<Document>
  <P>
    asdf
  </P>
  <LI>
    <Lbl>
      •
    </Lbl>
    <LBody>
      <P>
        Abbreviated 1
      </P>
    </LBody>
  </LI>
  <LI>
    <Lbl>
      •
    </Lbl>
    <LBody>
      <P>
        Abbreviated 2
      </P>
    </LBody>
  </LI>
  <P>
    asdf
  </P>
  <LI>
    <Lbl>
      •
    </Lbl>
    <LBody>
      <P>
        Paragraph item
      </P>
    </LBody>
  </LI>
  <P>
    asdf
  </P>
  <LI>
    <Lbl>
      •
    </Lbl>
    <LBody>
      <P>
        Block item
      </P>
    </LBody>
  </LI>
  <P>
    asdf
  </P>
  <LI>
    <Lbl>
      •
    </Lbl>
    <LBody>
      <P>
        Abbreviated
      </P>
    </LBody>
  </LI>
  <LI>
    <Lbl>
      •
    </Lbl>
    <LBody>
      <P>
        Paragraph item
      </P>
    </LBody>
  </LI>
  <LI>
    <Lbl>
      •
    </Lbl>
    <LBody>
      <P>
        Block item
      </P>
      <P>
        with multiple
      </P>
      <P>
        paragraphs
      </P>
    </LBody>
  </LI>
  <P>
    asdf
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
    my $pdf  = ::('PDF::Class').open: "t/item.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=begin pod
asdf

=item Abbreviated 1
=item Abbreviated 2

asdf

=for item
Paragraph
item

asdf

=begin item
Block
item
=end item

asdf

=item Abbreviated

=for item
Paragraph
item

=begin item
Block
item

with
multiple

paragraphs
=end item

asdf
=end pod
