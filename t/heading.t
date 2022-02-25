use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 2;

mkdir "tmp";
my $pdf-file = "tmp/heading.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$pdf-file);
lives-ok {$pdf.finish}

my $xml = q{<Document>
  <H1>
    Abbreviated heading1
  </H1>
  <P>
    asdf
  </P>
  <H1>
    Paragraph heading1
  </H1>
  <P>
    asdf
  </P>
  <H2>
    Subheading2
  </H2>
  <H1>
    Delimited
    heading1
  </H1>
  <H3>
    Heading3
  </H3>
  <P>
    asdf
  </P>
  <H2>
    Head2
  </H2>
  <P>
    asdf
  </P>
  <H3>
    Head3
  </H3>
  <P>
    asdf
  </P>
  <H4>
    Head4
  </H4>
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
    my $pdf  = ::('PDF::Class').open: "tmp/heading.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=begin pod
=head1 Abbreviated heading1

asdf

=for head1
Paragraph heading1

asdf

=head2 Subheading2

=begin head1
Delimited

heading1
=end head1

=head3 	Heading3

asdf

=head2 Head2

asdf

=head3 Head3

asdf

=head4 Head4

asdf

=end pod
