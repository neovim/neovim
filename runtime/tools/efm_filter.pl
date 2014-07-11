#!/usr/bin/env perl
#
# This program works as a filter that reads from stdin, copies to
# stdout *and* creates an error file that can be read by vim.
#
# This program has only been tested on SGI, Irix5.3.
#
# Written by Ives Aerts in 1996. This little program is not guaranteed
# to do (or not do) anything at all and can be freely used for
# whatever purpose you can think of.

$args = @ARGV;

unless ($args == 1) {
  die("Usage: vimccparse <output filename>\n");
}

$filename = @ARGV[0];
open (OUT, ">$filename") || die ("Can't open file: \"$filename\"");

while (<STDIN>) {
  print;
  if (   (/"(.*)", line (\d+): (e)rror\((\d+)\):/)
      || (/"(.*)", line (\d+): (w)arning\((\d+)\):/) ) {
    $file=$1;
    $line=$2;
    $errortype="\u$3";
    $errornr=$4;
    chop($errormsg=<STDIN>);
    $errormsg =~ s/^\s*//;
    $sourceline=<STDIN>;
    $column=index(<STDIN>, "^") - 1;

    print OUT "$file>$line:$column:$errortype:$errornr:$errormsg\n";
  }
}

close(OUT);
exit(0);
