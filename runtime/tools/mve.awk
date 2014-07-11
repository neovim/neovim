#!/usr/bin/nawk -f
#
# Change "nawk" to "awk" or "gawk" if you get errors.
#
# Make Vim Errors
# Processes errors from cc for use by Vim's quick fix tools
# specifically it translates the ---------^ notation to a
# column number
#
BEGIN { FS="[:,]" }

/^cfe/ { file=$3
	 msg=$5
	 split($4,s," ")
	 line=s[2]
}

# You may have to substitute a tab character for the \t here:
/^[\t-]*\^/ {
	p=match($0, ".*\\^" )
	col=RLENGTH-2
	printf("%s, line %d, col %d : %s\n", file,line,col,msg)
}
