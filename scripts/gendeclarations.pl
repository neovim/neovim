#!/usr/bin/perl

use strict;
use warnings;

if ($ARGV[0] eq '--help') {
  print << "EOF";
Usage:

  $0 definitions.c static.h non-static.h "cc -E …"
EOF
  exit;
}

my ($cfname, $sfname, $gfname, $cpp) = @ARGV;

my $pipe;

open $pipe, '-|', "$cpp $cfname";

my $text = join "", <$pipe>;

close $pipe;

my $s = qr/(?>\s*)/aso;
my $w = qr/(?>\w+)/aso;
my $type_regex = qr/(?:$w$s\**$s)+/aso;
my $arg_regex = qr/(?:$type_regex$s$w)/aso;

while ($text =~ /
    \n              # Definition starts at the start of line
    $type_regex     # Return type
    $s$w            # Function name
    $s\($s
    (?:
       $arg_regex(?:$s,$s$arg_regex)*+
      |void
    )?
    $s\)
    (?:$s FUNC_ATTR_$w(?:\((?>[^)]*)\))?)*+ # Optional attributes
    (?=$s\{)        # Start of function body (excluded from match)
  /axsog) {
  print "Match: $&\n";
}
