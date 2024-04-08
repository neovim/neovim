#!/usr/bin/env perl

use strict;
use warnings;
use 5.010;
use autodie;

use File::Basename;
use File::Spec::Functions;

sub read_in_file {
  my $in_file = $_[0];

  # Will contain lines before first STARTTEST
  # as Lua comments.
  my @description_lines = ();

  # Will contain alternating blocks of lines of textual input
  # (text between ENDTEST and EOF/next STARTTEST) and test commands
  # (commands between STARTTEST and ENDTEST) as Lua code.
  my @test_body_lines = ();

  # Will contain current command block, i.e. lines
  # between STARTTEST and ENDTEST.
  my @command_lines = ();

  # Will contain current input block, i.e. lines
  # between ENDTEST and STARTTEST.
  my @input_lines = ();

  open my $in_file_handle, '<', $in_file;

  use constant EMIT_DESCRIPTION => 0;
  use constant EMIT_COMMAND => 1;
  use constant EMIT_INPUT => 2;

  # Push lines from current input and
  # command blocks into @test_body_lines
  # in the correct order.
  sub end_input {
    my $input_lines = $_[0];
    my $command_lines = $_[1];
    my $test_body_lines = $_[2];

    # If there are input lines, wrap with an `insert`
    # command and add before the previous command block.
    if (@{$input_lines}) {
      my $last_input_line = pop @{$input_lines};
      unshift @{$command_lines}, '';
      unshift @{$command_lines}, $last_input_line . ']=])';
      unshift @{$command_lines}, @{$input_lines};
      unshift @{$command_lines}, "insert([=[";

      @{$input_lines} = ();
    }

    # Output remaining command lines.
    push @{$test_body_lines}, @{$command_lines};
    @{$command_lines} = ();
  }

  sub format_comment {
    # Handle empty comments.
    if (/^$/) {
      return '';
    }

    # Capitalize first character and emit as Lua comment.
    my $comment = '-- ' . ucfirst $_;

    # Add trailing dot if not already there.
    $comment .= '.' unless $comment =~ /\.$/;

    return $comment;
  }

  my %states = (
    # Add test description to @description_lines.
    EMIT_DESCRIPTION() => sub {
      if (/^STARTTEST/) {
        return EMIT_COMMAND;
      }

      # If not an empty line, emit as Lua comment.
      if (!/^$/) {
        # Remove modeline
        s/vim:.*set f\w+=vim//g;
        # Remove trailing ":"
        s/\s*:\s*$//g;
        push @description_lines, '-- ' . $_;
      }

      return EMIT_DESCRIPTION;
    },
    # Add test commands to @command_lines.
    EMIT_COMMAND() => sub {
      if (/^ENDTEST/) {
        return EMIT_INPUT;
      }

      # If line starts with ':"', emit a comment.
      if (/^:"/) {
        # Remove Vim comment prefix.
        s/^:"\s*//;

        push @command_lines, format_comment $_;

        return EMIT_COMMAND;
      }

      # Extract possible inline comment.
      if (/^[^"]*"[^"]*$/) {
        # Remove command part and prepended whitespace.
        s/^(.*?)\s*"\s*//;

        push @command_lines, format_comment $_;

        # Set implicit variable to command without comment.
        $_ = $1;
      }

      # Only continue if remaining command is not empty.
      if (!/^:?\s*$/) {
        # Replace terminal escape characters with <esc>.
        s/\e/<esc>/g;

        my $startstr = "'";
        my $endstr = "'";

        # If line contains single quotes or backslashes, use double
        # square brackets to wrap string.
        if (/'/ || /\\/) {
            # If the line contains a closing square bracket,
            # wrap it with [=[...]=].
            if (/\]/) {
              $startstr = '[=[';
              $endstr = ']=]';
            } else {
              $startstr = '[[';
              $endstr = ']]';
            }
        }

        # Emit 'feed' if not a search ('/') or ex (':') command.
        if (!/^\// && !/^:/) {
          # If command does not end with <esc>, insert trailing <cr>.
          my $command = 'feed(' . $startstr . $_;
          $command .= '<cr>' unless /<esc>$/;
          $command .= $endstr . ')';

          push @command_lines, $command;
        } else {
          # Remove prepending ':'.
          s/^://;
          push @command_lines, 'execute(' . $startstr . $_ . $endstr . ')';
        }
      }

      return EMIT_COMMAND;
    },
    # Add input to @input_lines.
    EMIT_INPUT() => sub {
      if (/^STARTTEST/) {
        end_input \@input_lines, \@command_lines, \@test_body_lines;
        return EMIT_COMMAND;
      }

      # Skip initial lines if they are empty.
      if (@input_lines or !/^$/) {
        push @input_lines, '  ' . $_;
      }
      return EMIT_INPUT;
    },
  );

  my $state = EMIT_DESCRIPTION;

  while (<$in_file_handle>) {
    # Remove trailing newline character and process line.
    chomp;
    $state = $states{$state}->($_);
  }

  # If not all lines have been processed yet,
  # do it now.
  end_input \@input_lines, \@command_lines, \@test_body_lines;

  close $in_file_handle;

  return (\@description_lines, \@test_body_lines);
}

sub read_ok_file {
  my $ok_file = $_[0];
  my @assertions = ();

  if (-f $ok_file) {
    push @assertions, '';
    push @assertions, "-- Assert buffer contents.";
    push @assertions, "expect([=[";

    open my $ok_file_handle, '<', $ok_file;

    while (<$ok_file_handle>) {
      # Remove trailing newline character and process line.
      chomp;
      push @assertions, '  ' . $_;
    }

    close $ok_file_handle;

    $assertions[-1] .= "]=])";
  }

  return \@assertions;
}

my $legacy_testfile = $ARGV[0];
my $out_dir = $ARGV[1];

if ($#ARGV != 1) {
  say "Convert a legacy Vim test to a Neovim lua spec.";
  say '';
  say "Usage: $0 legacy-testfile output-directory";
  say '';
  say "legacy-testfile:  Path to .in or .ok file.";
  say "output-directory: Directory where Lua spec will be saved to.";
  say '';
  say "Note: Only works reliably for fairly simple tests.";
  say "      Manual adjustments to generated spec files are required.";
  exit 1;
}

my @legacy_suffixes = ('.in', '.ok');
my ($base_name, $base_path, $suffix) = fileparse($legacy_testfile, @legacy_suffixes);
my $in_file = catfile($base_path, $base_name . '.in');
my $ok_file = catfile($base_path, $base_name . '.ok');

# Remove leading 'test'.
my $test_name = $base_name;
$test_name =~ s/^test_?//;

my $spec_file = do {
  if ($test_name =~ /^([0-9]+)/) {
    catfile($out_dir,  sprintf('%03d', $1) . '_spec.lua')
  } else {
    catfile($out_dir,  $test_name . '_spec.lua')
  }
};

if (! -f $in_file) {
  say "Test input file $in_file not found.";
  exit 2;
}

if (! -d $out_dir) {
  say "Output directory $out_dir does not exist.";
  exit 3;
}

if (-f $spec_file) {
  say "Output file $spec_file already exists.";
  print "Overwrite (Y/n)? ";
  my $input = <STDIN>;
  chomp($input);
  unless ($input =~ /^y|Y/) {
    say "Aborting.";
    exit 4;
  }
}

# Read .in and .ok files.
my ($description_lines, $test_body_lines) = read_in_file $in_file;
my $assertion_lines = read_ok_file $ok_file;

# Append assertions to test body.
push @{$test_body_lines}, @{$assertion_lines} if @{$assertion_lines};

# Write spec file.
open my $spec_file_handle, ">", $spec_file;

print $spec_file_handle <<"EOS";
@{[join "\n", @{$description_lines}]}

local t = require('test.functional.testutil')
local feed, insert, source = t.feed, t.insert, t.source
local clear, execute, expect = t.clear, t.execute, t.expect

describe('$test_name', function()
  before_each(clear)

  it('is working', function()
@{[join "\n", map { /^$/ ? '' : '    ' . $_ } @{$test_body_lines}]}
  end)
end)
EOS

close $spec_file_handle;

say "Written to $spec_file."
