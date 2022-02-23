use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 2;

my $file = "t/declarator.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$file);
lives-ok {$pdf.finish}

my $xml = q{<Document>
  <H2>
    Class Magician
  </H2>
  <P>
    Base class for magicians
  </P>
  <Code>class Magician</Code>
  <H3>
    Sub duel
  </H3>
  <P>
    Fight mechanics
  </P>
  <Code>sub duel(
    Magician $a,
    Magician $b,
)</Code>
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
    my $pdf  = ::('PDF::Class').open: "t/declarator.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

## Example taken from docs.raku.org/language/pod#Declarator_blocks

#| Base class for magicians 
class Magician {
  has Int $.level;
  has Str @.spells;
}
 
#| Fight mechanics 
sub duel(Magician $a, Magician $b) {
}
#= Magicians only, no mortals. 

