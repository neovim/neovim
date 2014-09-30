BEGIN   { FS="	"; }

NR == 1 { nf=split(FILENAME,f,".")
	print "<HTML>";
	print "<HEAD><TITLE>" f[1] "</TITLE></HEAD>";
	print "<BODY BGCOLOR=\"#ffffff\">";
	print "<H1>Vim Documentation: " f[1] "</H1>";
	print "<A NAME=\"top\"></A>";
	print "<HR>";
	print "<PRE>";
}

{
	#
	# protect special chars
	#
	gsub(/&/,"\\&amp;");
	gsub(/>/,"\\&gt;");
	gsub(/</,"\\&lt;");
	gsub(/"/,"\\&quot;");
	gsub(/%/,"\\&#37;");

	nf=split($0,tag,"	");
	tagkey[t]=tag[1];tagref[t]=tag[2];tagnum[t]=NR;
	print $1 "	" $2 "	line " NR >"tags.ref"
	n=split($2,w,".");
	printf ("|<A HREF=\"%s.html#%s\">%s</A>|	%s\n",w[1],$1,$1,$2);
}

END     {
	topback();
	print "</PRE>\n</BODY>\n\n\n</HTML>";
	}

#
# as main we keep index.txt (by default)
# other candidate, help.txt
#
function topback () {
	printf("<A HREF=\"#top\">top</A> - ");
	printf("<A HREF=\"help.html\">back to help</A>\n");
}
