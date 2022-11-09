use Test;
plan 3;
use Pod::To::PDF;

mkdir "tmp";
my $save-as = "tmp/replace.pdf";

my $title = 'Sample Title';
my $date = '2022-03-17';
my $author = 'David Warring';
my $description = "sample Pod with replaced content";
my %replace = :$date, :$title, :$author, :$description;
lives-ok {
    .finish()
        given pod2pdf($=pod, :%replace, :$save-as);
}

%replace<description> = $=pod;
dies-ok {
    pod2pdf($=pod, :%replace, :save-as<tmp/replace-bad.pdf>);
}, 'recursive replacement detected';

my $xml = q{<Document>
  <H1>
    Sample Title
  </H1>
  <H2>
    Replacement Test
  </H2>
  <H2>
    Author
  </H2>
  <P>
    David Warring
  </P>
  <H2>
    Date
  </H2>
  <P>
    2022-03-17
  </P>
  <H2>
    Description
  </H2>
  <P>
    sample Pod with replaced content;
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
    my $pdf  = ::('PDF::Class').open: "tmp/replace.pdf";
    my $tags = ::('PDF::Tags::Reader').read: :$pdf;
    my $actual-xml = $tags[0].Str(:omit<Span>);
    todo 'losing intra-formatting space'
        if $actual-xml ~~ s/withformatting/with formatting/;
    is $actual-xml, $xml, 'PDF Structure is correct';
}

=begin pod
=comment sample Pod with replaced content
=TITLE R<title>
=SUBTITLE Replacement Test
=AUTHOR R<author>
=DATE R<date>
=head2 Description
=para R<description>;
=end pod
