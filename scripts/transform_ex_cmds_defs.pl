#!/usr/bin/perl

use strict;
use warnings;
no utf8;

my $srcfname = shift @ARGV;
my $tgtfname = shift @ARGV;

if ($srcfname eq "--help") {
  print << "EOF";
$0 path/to/ex_cmds_defs.h path/to/ex_cmds.lua

  Translate Ex commands defines from old format to new one.
EOF
}

my $flag_const = qr((?:[A-Z]+[A-Z1-9]));

my $F;
open $F, "<", "$srcfname"
  or die "Failed to open $srcfname";

my $T;
open $T, ">", "$tgtfname"
  or die "Failed to open $tgtfname";

my ($enum_name, $cmd_name, $cmd_func);
my ($flags);
my $did_header = 0;
while (<$F>) {
  if (/^#define\s+($flag_const)\s+(.*)/) {
    my $const_name = $1;
    my $const_value = $2;
    $const_value =~ s@/\*.*|//.*@@g;
    $const_value =~ s/\s+//g;
    $const_value =~ s/\|/+/g;
    $const_value =~ s/(?<=\d)L//g;
    print $T "local $const_name = $const_value\n";
  } elsif (/^\{/../^\}/) {
    if (/^\s*EX\(\s*CMD_(\w+)\s*,\s*"((?:\\.|[^"\\])+)"\s*,\s*(\w+)\s*,\s*$/) {
      $enum_name = $1;
      $cmd_name = $2;
      $cmd_func = $3;
    } elsif (defined $enum_name and /^\s*($flag_const(?:\|$flag_const)*|0)/) {
      if (not $did_header) {
        print $T "return {\n";
        $did_header = 1;
      }
      $flags = $1;
      $flags =~ s/\|/+/g;
      local $\ = "\n";
      print $T "  {";
      print $T "    command='$cmd_name',";
      print $T "    enum='CMD_$enum_name',"
        if ($cmd_name ne $enum_name);
      print $T "    flags=$flags,";
      print $T "    func='$cmd_func',";
      print $T "  },";
      undef $enum_name;
      undef $cmd_name;
      undef $cmd_func;
      undef $flags;
    } else {
      next;
    }
  }
}

print $T "}\n";
