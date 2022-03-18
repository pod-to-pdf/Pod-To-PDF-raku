use Test;
use Pod::To::Cairo::Style;
plan 3;

my Pod::To::Cairo::Style $style .= new: :italic;

subtest 'new', {
    is $style.family, 'serif';
    ok $style.italic;
    nok $style.bold;
    is $style.pattern.Str, 'serif:slant=100';
    is $style.leading, 1.15;
    is $style.font-size, 10;
    is $style.line-height, 11.5;
}

$style .= clone: :bold, :font-size(12);

subtest 'clone', {
    is $style.family, 'serif';
    ok $style.italic;
    ok $style.bold;
    is $style.pattern.Str, 'serif:slant=100:weight=200';
    is $style.leading, 1.15;
    is $style.font-size, 12;
    is $style.line-height, 13.8;
}

$style .= new :mono;
is $style.family, 'monospace';
