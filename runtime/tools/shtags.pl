#!/usr/bin/env perl
#
# shtags: create a tags file for perl scripts
#
# Author:	Stephen Riehm
# Last Changed:	96/11/27 19:46:06
#
# "@(#) shtags 1.1 by S. Riehm"
#

# obvious... :-)
sub usage
    {
    print <<_EOUSAGE_ ;
USAGE: $program [-kvwVx] [-t <file>] <files>
    -t <file>	Name of tags file to create. (default is 'tags')
    -s <shell>	Name of the shell language in the script
    -v		Include variable definitions.
		(variables mentioned at the start of a line)
    -V		Print version information.
    -w		Suppress "duplicate tag" warnings.
    -x		Explicitly create a new tags file. Normally tags are merged.
    <files>	List of files to scan for tags.
_EOUSAGE_
    exit 0
    }

sub version
{
    #
    # Version information
    #
    @id = split( ', ', 'scripts/bin/shtags, /usr/local/, LOCAL_SCRIPTS, 1.1, 96/11/27, 19:46:06' );
    $id[0] =~ s,.*/,,;
    print <<_EOVERS;
$id[0]:		$id[3]
Last Modified:	@id[4,5]
Component:	$id[1]
Release:	$id[2]
_EOVERS
    exit( 1 );
}

#
# initialisations
#
($program = $0) =~ s,.*/,,;
require 'getopts.pl';

#
# parse command line
#
&Getopts( "t:s:vVwx" ) || &usage();
$tags_file = $opt_t || 'tags';
$explicit = $opt_x;
$variable_tags = $opt_v;
$allow_warnings = ! $opt_w;
&version	  if $opt_V;
&usage()	unless @ARGV != 0;

# slurp up the existing tags. Some will be replaced, the ones that aren't
# will be re-written exactly as they were read
if( ! $explicit && open( TAGS, "< $tags_file" ) )
    {
    while( <TAGS> )
	{
	/^\S+/;
	$tags{$&} = $_;
	}
    close( TAGS );
    }

#
# for each line of every file listed on the command line, look for a
# 'sub' definition, or, if variables are wanted aswell, look for a
# variable definition at the start of a line
#
while( <> )
    {
    &check_shell($_), ( $old_file = $ARGV ) if $ARGV ne $old_file;
    next unless $shell;
    if( $shell eq "sh" )
	{
	next	unless /^\s*(((\w+)))\s*\(\s*\)/
		    || ( $variable_tags && /^(((\w+)=))/ );
	$match = $3;
	}
    if( $shell eq "ksh" )
	{
	# ksh
	next	unless /^\s*function\s+(((\w+)))/
		    || ( $variable_tags && /^(((\w+)=))/ );
	$match = $3;
	}
    if( $shell eq "perl" )
	{
	# perl
	next	unless /^\s*sub\s+(\w+('|::))?(\w+)/
		    || /^\s*(((\w+))):/
		    || ( $variable_tags && /^(([(\s]*[\$\@\%]{1}(\w+).*=))/ );
	$match = $3;
	}
    if( $shell eq "tcl" )
	{
	next	unless /^\s*proc\s+(((\S+)))/
		    || ( $variable_tags && /^\s*set\s+(((\w+)\s))/ );
	$match = $3;
	}
    chop;
    warn "$match - duplicate ignored\n"
	if ( $new{$match}++
	    || !( $tags{$match} = sprintf( "%s\t%s\t?^%s\$?\n", $match, $ARGV, $_ ) ) )
	    && $allow_warnings;
    }

# write the new tags to the tags file - note that the whole file is rewritten
open( TAGS, "> $tags_file" );
foreach( sort( keys %tags ) )
    {
    print TAGS "$tags{$_}";
    }
close( TAGS );

sub check_shell
    {
    local( $_ ) = @_;
    # read the first line of a script, and work out which shell it is,
    # unless a shell was specified on the command line
    #
    # This routine can't handle clever scripts which start sh and then
    # use sh to start the shell they really wanted.
    if( $opt_s )
	{
	$shell = $opt_s;
	}
    else
	{
	$shell = "sh"	if /^:$/ || /^#!.*\/bin\/sh/;
	$shell = "ksh"	if /^#!.*\/ksh/;
	$shell = "perl"	if /^#!.*\/perl/;
	$shell = "tcl"  if /^#!.*\/wish/;
	printf "Using $shell for $ARGV\n";
	}
    }
