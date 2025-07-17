use v6;

use Test;
use Pod::To::PDF;
use Cairo;
plan 3;

mkdir "tmp";
my $save-as = "tmp/table.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$save-as);
lives-ok {$pdf.finish}
cmp-ok $pdf.status, '==', CAIRO_STATUS_SUCCESS, 'status ok';

my $xml = q{<Document>
  <P>
    asdf
  </P>
  <Table>
    <Caption>
      Table 1
    </Caption>
    <TBody>
      <TR>
        <TD>
          A A
        </TD>
        <TD>
          B B
        </TD>
        <TD>
          C C
        </TD>
      </TR>
      <TR>
        <TD>
          1 1
        </TD>
        <TD>
          2 2
        </TD>
        <TD>
          3 3
        </TD>
      </TR>
    </TBody>
  </Table>
  <P>
    asdf
  </P>
  <Table>
    <Caption>
      Table 2
    </Caption>
    <THead>
      <TR>
        <TH>
          H 1
        </TH>
        <TH>
          H 2
        </TH>
        <TH>
          H 3
        </TH>
      </TR>
    </THead>
    <TBody>
      <TR>
        <TD>
          A A
        </TD>
        <TD>
          B B
        </TD>
        <TD>
          C C
        </TD>
      </TR>
      <TR>
        <TD>
          1 1
        </TD>
        <TD>
          2 2
        </TD>
        <TD>
          3 3
        </TD>
      </TR>
    </TBody>
  </Table>
  <P>
    asdf
  </P>
  <Table>
    <Caption>
      Table 3
    </Caption>
    <THead>
      <TR>
        <TH>
          H11
        </TH>
        <TH>
          HHH 222
        </TH>
        <TH>
          H 3
        </TH>
      </TR>
    </THead>
    <TBody>
      <TR>
        <TD>
          AAA
        </TD>
        <TD>
          BB
        </TD>
        <TD>
          C C C C
        </TD>
      </TR>
      <TR>
        <TD>
          1 1
        </TD>
        <TD>
          2 2 2 2
        </TD>
        <TD>
          3 3
        </TD>
      </TR>
    </TBody>
  </Table>
  <P>
    asdf
  </P>
  <Table>
    <Caption>
      Table 4
    </Caption>
    <THead>
      <TR>
        <TH>
          H 1
        </TH>
        <TH>
          H 2
        </TH>
        <TH>
          H 3
        </TH>
        <TH>
          H 4
        </TH>
      </TR>
    </THead>
    <TBody>
      <TR>
        <TD>
          Hello, I'm kinda long, I think
        </TD>
        <TD>
          B B
        </TD>
        <TD>
          C C
        </TD>
        <TD>
          X
        </TD>
      </TR>
      <TR>
        <TD>
          1 1
        </TD>
        <TD>
          Me also, methinks
        </TD>
        <TD>
          3 3
        </TD>
        <TD>
          This should deﬁnitely wrap. Lorem ipsum dolor sit
          amet, consectetur adipiscing elit, sed do eiusmod
          tempor incididunt
        </TD>
      </TR>
      <TR>
        <TD>
          ww
        </TD>
        <TD>
          xx
        </TD>
        <TD>
          yy
        </TD>
        <TD>
          zz
        </TD>
      </TR>
    </TBody>
  </Table>
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
    my $pdf  = PDF::Class.open: "tmp/table.pdf";
    my $tags = PDF::Tags::Reader.read: :$pdf;
    is $tags[0].Str, $xml, 'PDF Structure is correct';
}

=begin pod
asdf
=begin table :caption('Table 1')
A A    B B       C C
1 1    2 2       3 3
=end table
asdf
=begin table :caption('Table 2')
H 1 | H 2 | H 3
====|=====|====
A A | B B | C C
1 1 | 2 2 | 3 3
=end table
asdf

=begin table :caption('Table 3')
       HHH
  H11  222  H 3
  ===  ===  ===
  AAA  BB   C C
            C C

  1 1  2 2  3 3
       2 2
=end table
asdf

=begin table :caption('Table 4')
H 1 | H 2 | H 3 | H 4
====|=====|=====|====
Hello, I'm kinda long, I think | B B | C C | X
1 1 | Me also, methinks | 3 3 | This should definitely wrap. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt
ww | xx | yy | zz
=end table
asdf

=end pod
