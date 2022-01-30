use v6;

use Test;
use Pod::To::PDF;
use Cairo;

plan 1;

my $file = "t/code.pdf";
my Cairo::Surface $pdf = pod2pdf($=pod, :$file);
lives-ok {$pdf.finish}


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
=end pod
