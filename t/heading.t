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
  <H>
    Abbreviated heading1
  </H>
  <P>
    asdf
  </P>
  <H>
    Paragraph heading1
  </H>
  <P>
    asdf
  </P>
  <Sect>
    <H>
      Subheading2
    </H>
  </Sect>
  <H>
    Delimited heading1
  </H>
  <Sect>
    <Sect>
      <H>
        Heading3
      </H>
      <P>
        asdf
      </P>
    </Sect>
    <H>
      Head2
    </H>
    <P>
      asdf
    </P>
    <Sect>
      <H>
        Head3
      </H>
      <P>
        asdf
      </P>
      <Sect>
        <H>
          Head4
        </H>
        <P>
          asdf
        </P>
      </Sect>
    </Sect>
  </Sect>
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
