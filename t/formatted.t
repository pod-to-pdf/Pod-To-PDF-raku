use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 3;

mkdir "tmp";
my $save-as = "tmp/formatted.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$save-as);
lives-ok {$pdf.finish}
cmp-ok $pdf.status, '==', CAIRO_STATUS_SUCCESS, 'status ok';

my $xml = q{<Document>
  <P>
    This text is of minor signiﬁcance.
  </P>
  <P>
    This text is of major signiﬁcance.
  </P>
  <P>
    This text is of fundamental signiﬁcance.
  </P>
  <P>
    This text is verbatim C&lt;with&gt; B&lt;disarmed&gt; Z&lt;formatting&gt;.
  </P>
  <P>
    This text is to be replaced.
  </P>
  <P>
    This text is invisible.
  </P>
  <P>
    This text contains a link to <Link href="http://www.google.com/">http://www.google.com/</Link>.
  </P>
  <P>
    This text contains a link with label to <Link href="http://www.google.com/">google</Link>.
  </P>
  <P>
    A tap on an <Code>on demand</Code> supply will initiate the production of values, and tapping the supply again may result in a
    new set of values. For example, <Code>Supply.interval</Code> produces a fresh timer with the appropriate interval each time
    it is tapped. If the tap is closed, the timer simply stops emitting values to that tap.
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
    my $pdf  = PDF::Class.open: "tmp/formatted.pdf";
    my $tags = PDF::Tags::Reader.read: :$pdf;
    is $tags[0].Str(:omit<Span>), $xml, 'PDF Structure is correct';
}

=begin pod
This text is of U<minor significance>.

This text is of I<major significance>.

This text is of B<fundamental significance>.

This text is V<verbatim C<with> B<disarmed> Z<formatting>>.

This text is R<to be replaced>.

This text is Z<blabla>invisible.

This text contains a link to L<http://www.google.com/>.

This text contains a link with label to L<google|http://www.google.com/>.

=comment a real-world sample, taken from Supply.pod6

A tap on an C<on demand> supply will initiate the production of values, and
tapping the supply again may result in a new set of values. For example,
C<Supply.interval> produces a fresh timer with the appropriate interval each
time it is tapped. If the tap is closed, the timer simply stops emitting values
to that tap.

=end pod
