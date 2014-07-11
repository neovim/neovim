#!/usr/bin/perl -w

# vimparse.pl - Reformats the error messages of the Perl interpreter for use
# with the quickfix mode of Vim
#
# Copyright (c) 2001 by Joerg Ziefle <joerg.ziefle@gmx.de>
# You may use and distribute this software under the same terms as Perl itself.
#
# Usage: put one of the two configurations below in your ~/.vimrc (without the
# description and '# ') and enjoy (be sure to adjust the paths to vimparse.pl
# before):
#
# Program is run interactively with 'perl -w':
#
# set makeprg=$HOME/bin/vimparse.pl\ %\ $*
# set errorformat=%f:%l:%m
#
# Program is only compiled with 'perl -wc':
#
# set makeprg=$HOME/bin/vimparse.pl\ -c\ %\ $*
# set errorformat=%f:%l:%m
#
# Usage:
#	vimparse.pl [-c] [-f <errorfile>] <programfile> [programargs]
#
#		-c	compile only, don't run (perl -wc)
#		-f	write errors to <errorfile>
#
# Example usages:
#	* From the command line:
#		vimparse.pl program.pl
#
#		vimparse.pl -c -f errorfile program.pl
#		Then run vim -q errorfile to edit the errors with Vim.
#
#	* From Vim:
#		Edit in Vim (and save, if you don't have autowrite on), then
#		type ':mak' or ':mak args' (args being the program arguments)
#		to error check.
#
# Version history:
#	0.2 (04/12/2001):
#		* First public version (sent to Bram)
#		* -c command line option for compiling only
#		* grammatical fix: 'There was 1 error.'
#		* bug fix for multiple arguments
#		* more error checks
#		* documentation (top of file, &usage)
#		* minor code clean ups
#	0.1 (02/02/2001):
#		* Initial version
#		* Basic functionality
#
# Todo:
#	* test on more systems
#	* use portable way to determine the location of perl ('use Config')
#	* include option that shows perldiag messages for each error
#	* allow to pass in program by STDIN
#	* more intuitive behaviour if no error is found (show message)
#
# Tested under SunOS 5.7 with Perl 5.6.0.  Let me know if it's not working for
# you.

use strict;
use Getopt::Std;

use vars qw/$opt_c $opt_f $opt_h/; # needed for Getopt in combination with use strict 'vars'

use constant VERSION => 0.2;

getopts('cf:h');

&usage if $opt_h; # not necessarily needed, but good for further extension

if (defined $opt_f) {

    open FILE, "> $opt_f" or do {
	warn "Couldn't open $opt_f: $!.  Using STDOUT instead.\n";
	undef $opt_f;
    };

};

my $handle = (defined $opt_f ? \*FILE : \*STDOUT);

(my $file = shift) or &usage; # display usage if no filename is supplied
my $args = (@ARGV ? ' ' . join ' ', @ARGV : '');

my @lines = `perl @{[defined $opt_c ? '-c ' : '' ]} -w "$file$args" 2>&1`;

my $errors = 0;
foreach my $line (@lines) {

    chomp($line);
    my ($file, $lineno, $message, $rest);

    if ($line =~ /^(.*)\sat\s(.*)\sline\s(\d+)(\.|,\snear\s\".*\")$/) {

	($message, $file, $lineno, $rest) = ($1, $2, $3, $4);
	$errors++;
	$message .= $rest if ($rest =~ s/^,//);
	print $handle "$file:$lineno:$message\n";

    } else { next };

}

if (defined $opt_f) {

    my $msg;
    if ($errors == 1) {

	$msg = "There was 1 error.\n";

    } else {

	$msg = "There were $errors errors.\n";

    };

    print STDOUT $msg;
    close FILE;
    unlink $opt_f unless $errors;

};

sub usage {

    (local $0 = $0) =~ s/^.*\/([^\/]+)$/$1/; # remove path from name of program
    print<<EOT;
Usage:
	$0 [-c] [-f <errorfile>] <programfile> [programargs]

		-c	compile only, don't run (executes 'perl -wc')
		-f	write errors to <errorfile>

Examples:
	* At the command line:
		$0 program.pl
		Displays output on STDOUT.

		$0 -c -f errorfile program.pl
		Then run 'vim -q errorfile' to edit the errors with Vim.

	* In Vim:
		Edit in Vim (and save, if you don't have autowrite on), then
		type ':mak' or ':mak args' (args being the program arguments)
		to error check.
EOT

    exit 0;

};
