use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 3;

mkdir "tmp";
my $save-as = "tmp/item.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$save-as);
lives-ok {$pdf.finish}
cmp-ok $pdf.status, '==', CAIRO_STATUS_SUCCESS, 'status ok';

my $xml = q{<Document>
  <P>
    asdf
  </P>
  <L>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        Abbreviated 1
      </LBody>
    </LI>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        Abbreviated 2
      </LBody>
    </LI>
  </L>
  <P>
    asdf
  </P>
  <L>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        <P>
          Top Item
        </P>
        <L>
          <LI>
            <Lbl>
              ◦
            </Lbl>
            <LBody>
              First sub-item
            </LBody>
          </LI>
          <LI>
            <Lbl>
              ◦
            </Lbl>
            <LBody>
              Second sub-item
            </LBody>
          </LI>
        </L>
      </LBody>
    </LI>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        Paragraph item
      </LBody>
    </LI>
  </L>
  <P>
    asdf
  </P>
  <L>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        Block item
      </LBody>
    </LI>
  </L>
  <P>
    asdf
  </P>
  <L>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        Abbreviated
      </LBody>
    </LI>
    <LI>
      <Lbl>
        •
      </Lbl>
      <LBody>
        Paragraph item
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
  </L>
  <P>
    asdf
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
    my $pdf  = PDF::Class.open: "tmp/item.pdf";
    my $tags = PDF::Tags::Reader.read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=begin pod
asdf

=item Abbreviated 1
=item Abbreviated 2

asdf

=begin item1
Top Item
=item2     First sub-item
=item2     Second sub-item
=end item1

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
