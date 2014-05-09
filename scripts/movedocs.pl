#!/usr/bin/perl

use strict;
use warnings;

if ($ARGV[0] eq '--help') {
  print << "EOF";
Usage:

  $0 file.h file.c

Removes documentation attached to function declarations in file.h and adds them 
to function definitions found in file.c.

  $0 file.c

Moves documentation attached to function declaration present in the same file as 
the definition.
EOF
  exit 0;
}

my $hfile = shift @ARGV;
my @cfiles = @ARGV;

my %docs = ();
my $F;

sub write_lines {
  my $file = shift;
  my @lines = @_;

  my $F;

  open $F, '>', $file;
  print $F (join "", @lines);
  close $F;
}

if (@cfiles) {
  open $F, '<', $hfile
    or die "Failed to open $hfile.";

  my @hlines = ();

  my $lastdoc = '';

  while (<$F>) {
    if (/^\/\/\/?/) {
      $lastdoc .= $_;
    } elsif (/^\S.*?(\w+)\(.*(?:,|\);?|FUNC_ATTR_\w+;?)$/) {
      die "Documentation for $1 was already defined" if (defined $docs{$1});
      if ($lastdoc ne '') {
        $docs{$1} = $lastdoc;
        $lastdoc = '';
      }
      push @hlines, $_;
    } elsif ($lastdoc ne '') {
      push @hlines, $lastdoc;
      $lastdoc = '';
      push @hlines, $_;
    } else {
      push @hlines, $_;
    }
  }

  close $F;

  my %clines_hash = ();

  for my $cfile (@cfiles) {
    open $F, '<', $cfile
      or die "Failed to open $cfile.";

    my @clines = ();

    while (<$F>) {
      if (/^\S.*?(\w+)\(.*[,)]$/ and defined $docs{$1}) {
        push @clines, $docs{$1};
        delete $docs{$1};
      } elsif (/^(?!static\s)\S.*?(\w+)\(.*[,)]$/ and not defined $docs{$1}) {
        print STDERR "Documentation not defined for $1\n";
      }
      push @clines, $_;
    }

    close $F;

    $clines_hash{$cfile} = \@clines;
  }

  while (my ($func, $value) = each %docs) {
    die "Function not found: $func\n";
  }

  write_lines($hfile, @hlines);
  while (my ($cfile, $clines) = each %clines_hash) {
    write_lines($cfile, @$clines);
  }
} else {
  open $F, '<', $hfile;

  my @lines;

  my $lastdoc = '';
  my $defstart = '';
  my $funcname;

  sub clear_lastdoc {
    if ($lastdoc ne '') {
      push @lines, $lastdoc;
      $lastdoc = '';
    }
  }

  sub record_lastdoc {
    my $funcname = shift;
    if ($lastdoc ne '') {
      $docs{$funcname} = $lastdoc;
      $lastdoc = '';
    }
  }

  sub add_doc {
    my $funcname = shift;
    if (defined $docs{$funcname}) {
      push @lines, $docs{$funcname};
      delete $docs{$funcname};
    }
  }

  sub clear_defstart {
    push @lines, $defstart;
    $defstart = '';
  }

  while (<$F>) {
    if (/\/\*/ .. /\*\// and not /\/\*.*?\*\//) {
      push @lines, $_;
    } elsif (/^\/\/\/?/) {
      $lastdoc .= $_;
    } elsif (/^\S.*?(\w+)\(.*(?:,|(\);?))$/) {
      if (not $2) {
        $defstart .= $_;
        $funcname = $1;
      } elsif ($2 eq ');') {
        record_lastdoc $1;
        push @lines, $_;
      } elsif ($2 eq ')') {
        clear_lastdoc;
        add_doc $1;
        push @lines, $_;
      }
    } elsif ($defstart ne '') {
      $defstart .= $_;
      if (/[{}]/) {
        clear_lastdoc;
        clear_defstart;
      } elsif (/\);$/) {
        record_lastdoc $funcname;
        clear_defstart;
      } elsif (/\)$/) {
        clear_lastdoc;
        add_doc $funcname;
        clear_defstart;
      }
    } else {
      clear_lastdoc;
      push @lines, $_;
    }
  }

  close $F;

  while (my ($func, $value) = each %docs) {
    die "Function not found: $func\n";
  }

  write_lines($hfile, @lines);
}
