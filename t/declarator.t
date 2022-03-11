use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 2;

mkdir "tmp";
my $pdf-file = "tmp/declarator.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$pdf-file);
lives-ok {$pdf.finish}

my $xml = q{<Document>
  <H2>
    Class Magician
  </H2>
  <P>
    Base class for magicians
  </P>
  <P>
    <Code>class Magician</Code>
  </P>
  <H3>
    Sub duel
  </H3>
  <P>
    Fight mechanics
  </P>
  <P>
    <Code>sub duel(
    Magician $a,
    Magician $b,
)</Code>
  </P>
  <P>
    Magicians only, no mortals.
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
    my $pdf  = ::('PDF::Class').open: "tmp/declarator.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=comment Example taken from docs.raku.org/language/pod#Declarator_blocks

#| Base class for magicians 
class Magician {
  has Int $.level;
  has Str @.spells;
}
 
#| Fight mechanics
sub duel(Magician $a, Magician $b) {
}
#= Magicians only, no mortals. 

