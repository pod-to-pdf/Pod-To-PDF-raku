use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 2;

mkdir "tmp";
my $pdf-file = "tmp/code.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$pdf-file);
lives-ok {$pdf.finish}

my $xml = q{<Document>
  <P>
    asdf
  </P>
  <Code>indented</Code>
  <P>
    asdf
  </P>
  <Code>indented
multi
line</Code>
  <P>
    asdf
  </P>
  <Code>indented
multi
line
    nested
and
broken
up</Code>
  <P>
    asdf
  </P>
  <Code>Abbreviated</Code>
  <P>
    asdf
  </P>
  <Code>Paragraph
code</Code>
  <P>
    asdf
  </P>
  <Code>Delimited
code</Code>
  <P>
    asdf
  </P>
  <Code>Formatted
code</Code>
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
    my $pdf  = ::('PDF::Class').open: "tmp/code.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=begin pod
asdf

    indented

asdf

    indented
    multi
    line

asdf

    indented
    multi
    line
    
        nested
    and
    broken
    up

asdf

=code Abbreviated

asdf

=for code
Paragraph
code

asdf

=begin code
Delimited
code
=end code

asdf

=begin code :allow<B>
B<Formatted>
code
=end code

=end pod
