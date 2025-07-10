use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 8;

mkdir "tmp";
my $save-as = "tmp/metadata.pdf";
my $width = 250;
my $height = 350;
my %replace = :author('David Warring'), :where<POD>;
my Cairo::Surface::PDF $surface .= create($save-as, $width, $height);
my Pod::To::PDF $pod .= new(:$=pod, :$surface, :%replace);

my $xml = q{<Document>
  <H1>
    Title from POD
  </H1>
  <H2>
    Subtitle from POD
  </H2>
  <H2>
    Author
  </H2>
  <P>
    David Warring
  </P>
  <H2>
    Version
  </H2>
  <P>
    1.2.3
  </P>
  <H2>
    header2
  </H2>
  <P>
    a paragraph.
  </P>
</Document>
};

is $pod.metadata('title'), 'Title from POD';
is $pod.metadata('subtitle'), 'Subtitle from POD';
is $pod.metadata('version'), '1.2.3';
is $pod.metadata('author'), 'David Warring';

lives-ok {$surface.finish}
cmp-ok $surface.status, '==', CAIRO_STATUS_SUCCESS, 'status ok';

if (try require PDF::Tags::Reader) === Nil {
    skip-rest "PDF::Tags::Reader is required to perform structural PDF testing";
    exit 0;
}

subtest 'Metadata verification', {
    plan 2;
    require PDF::Class;
    my $pdf  = PDF::Class.open: "tmp/metadata.pdf";
    my $info = $pdf.Info;
    is $info.Title, 'Title from POD v1.2.3', 'PDF Title (POD title + version)';
    is $info.Subject, 'Subtitle from POD', 'PDF Subject (POD subtitle)';
}

subtest 'document structure', {
    plan 1;
    # PDF::Class is an indirect dependency of PDF::Tags::Reader
    require PDF::Class;
    my $pdf  = PDF::Class.open: "tmp/metadata.pdf";
    my $tags = PDF::Tags::Reader.read: :$pdf;
    my $actual-xml = $tags[0].Str(:omit<Span>);
    is $actual-xml, $xml, 'PDF Structure is correct';
}

=begin pod

=TITLE Title from R<where>

=SUBTITLE Subtitle from R<where>

=AUTHOR R<author>

=VERSION 1.2.3

=head2 header2

a paragraph.
=end pod

