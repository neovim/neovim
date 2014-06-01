#!/usr/bin/perl

use strict;
use warnings;

if ($ARGV[0] eq '--help') {
  print << "EOF";
Usage:

  $0 definitions.c
EOF
  exit;
}

my ($cfname, $sfname, $gfname, $cpp) = @ARGV;

my $F;

open $F, "<", $cfname;

my $text = join "", <$F>;

close $F;

my $s = qr/(?>\s*)/aso;
my $w = qr/(?>\w+)/aso;
my $argname = qr/$w(?:\[(?>\w+)\])?/aso;
my $type_regex = qr/(?:$w$s\**$s)+/aso;
my $arg_regex = qr/(?:$type_regex$s$argname)/aso;

while ($text =~ /
    (?<=\n)         # Definition starts at the start of line
    $type_regex     # Return type
    $s$w            # Function name
    $s\($s
    (?:
       $arg_regex(?:$s,$s$arg_regex)*+
       ($s,$s\.\.\.)?                   # varargs function
      |void
    )?
    $s\)
    (?:$s FUNC_ATTR_$w(?:\((?>[^)]*)\))?)*+ # Optional attributes
    (?=$s;)         # Ending semicolon
  /axsogp) {
  my $match = "${^MATCH}";
  my $s = "${^PREMATCH}";
  $s =~ s/[^\n]++//g;
  my $line = 1 + length $s;
  print "${cfname}:${line}: $match\n";
}
