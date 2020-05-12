BEGIN   {
	# some initialization variables
	asciiart="no";
	wasset="no";
	lineset=0;
	sample="no";
	while ( getline ti <"tags.ref" > 0 ) {
		nf=split(ti,tag,"	");
		# as help.txt renders into index.html and index.txt -> vimindex.html,
		# this hack is needed to get the links right to those pages.
		if ( tag[2] == "index.txt" ) {
			tag[2] = "vimindex.txt"
		} else if ( tag[2]  == "help.txt" ) {
			tag[2] = "index.txt"
		}
		tagkey[tag[1]]="yes";tagref[tag[1]]=tag[2];
	}
	skip_word["and"]="yes";
	skip_word["backspace"]="yes";
	skip_word["beep"]="yes";
	skip_word["bugs"]="yes";
	skip_word["da"]="yes";
	skip_word["end"]="yes";
	skip_word["ftp"]="yes";
	skip_word["go"]="yes";
	skip_word["help"]="yes";
	skip_word["home"]="yes";
	skip_word["news"]="yes";
	skip_word["index"]="yes";
	skip_word["insert"]="yes";
	skip_word["into"]="yes";
	skip_word["put"]="yes";
	skip_word["reference"]="yes";
	skip_word["section"]="yes";
	skip_word["space"]="yes";
	skip_word["starting"]="yes";
	skip_word["toggle"]="yes";
	skip_word["various"]="yes";
	skip_word["version"]="yes";
	skip_word["is"]="yes";
}
#
# protect special chars
#
/[><&á]/ {gsub(/&/,"\\&amp;");gsub(/>/,"\\&gt;");gsub(/</,"\\&lt;");gsub("á","\\&aacute;");}
#
# end of sample lines by non-blank in first column
#
sample == "yes" && substr($0,1,4) == "&lt;" { sample = "no"; gsub(/^&lt;/, " "); }
sample == "yes" && substr($0,1,1) != " " && substr($0,1,1) != "	" && length($0) > 0 { sample = "no" }
#
# sample lines printed bold unless empty...
#
sample == "yes" && $0 =="" { print ""; next; }
sample == "yes" && $0 !="" { print "<B>" $0 "</B>"; next; }
#
# start of sample lines in next line
#
$0 == "&gt;" { sample = "yes"; print ""; next; }
substr($0,length($0)-4,5) == " &gt;" { sample = "yes"; gsub(/ &gt;$/, ""); }
#
# header lines printed bold, colored
#
substr($0,length($0),1) == "~" { print "<B><FONT COLOR=\"PURPLE\">" substr($0,1,length($0)-1) "</FONT></B>"; next; }
#
#ad hoc code
#
/^"\|\& / {gsub(/\|/,"\\&#124;"); }
/ = b / {gsub(/ b /," \\&#98; "); }
#
# one letter tag
#
/[ 	]\*.\*[ 	]/ {gsub(/\*/,"ZWWZ"); }
#
# isolated "*"
#
/[ 	]\*[ 	]/ {gsub(/ \* /," \\&#42; ");
		    gsub(/ \*	/," \\&#42;	");
		    gsub(/	\* /,"	\\&#42; ");
		    gsub(/	\*	/,"	\\&#42;	"); }
#
# tag start
#
/[ 	]\*[^ 	]/	{gsub(/ \*/," ZWWZ");gsub(/	\*/,"	ZWWZ");}
/^\*[^ 	]/ 	 {gsub(/^\*/,"ZWWZ");}
#
# tag end
#
/[^ 	]\*$/ 	 {gsub(/\*$/,"ZWWZ");}
/[^ \/	]\*[ 	]/  {gsub(/\*/,"ZWWZ");}
#
# isolated "|"
#
/[ 	]\|[ 	]/ {gsub(/ \| /," \\&#124; ");
		    gsub(/ \|	/," \\&#124;	");
		    gsub(/	\| /,"	\\&#124; ");
		    gsub(/	\|	/,"	\\&#124;	"); }
/'\|'/ { gsub(/'\|'/,"'\\&#124;'"); }
/\^V\|/ {gsub(/\^V\|/,"^V\\&#124;");}
/ \\\|	/ {gsub(/\|/,"\\&#124;");}
#
# one letter pipes and "||" false pipe (digraphs)
#
/[ 	]\|.\|[ 	]/ && asciiart == "no" {gsub(/\|/,"YXXY"); }
/^\|.\|[ 	]/ {gsub(/\|/,"YXXY"); }
/\|\|/ {gsub(/\|\|/,"\\&#124;\\&#124;"); }
/^shellpipe/ {gsub(/\|/,"\\&#124;"); }
#
# pipe start
#
/[ 	]\|[^ 	]/ && asciiart == "no"	{gsub(/ \|/," YXXY");
			gsub(/	\|/,"	YXXY");}
/^\|[^ 	]/ 	 {gsub(/^\|/,"YXXY");}
#
# pipe end
#
/[^ 	]\|$/ && asciiart == "no" {gsub(/\|$/,"YXXY");}
/[^ 	]\|[s ,.);	]/ && asciiart == "no" {gsub(/\|/,"YXXY");}
/[^ 	]\|]/ && asciiart == "no" {gsub(/\|/,"YXXY");}
#
# various
#
/'"/ 	{gsub(/'"/,"\\&#39;\\&#34;'");}
/"/	{gsub(/"/,"\\&quot;");}
/%/	{gsub(/%/,"\\&#37;");}

NR == 1 { nf=split(FILENAME,f,".")
	print "<HTML>";

	print "<HEAD>"
	if ( FILENAME == "mbyte.txt" ) {
	    # needs utf-8 as uses many languages
	    print "<META HTTP-EQUIV=\"Content-type\" content=\"text/html; charset=UTF-8\">";
	} else {
	    # common case - Latin1
	    print "<META HTTP-EQUIV=\"Content-type\" content=\"text/html; charset=ISO-8859-1\">";
	}
	print "<TITLE>Nvim documentation: " f[1] "</TITLE>";
	print "</HEAD>";

	print "<BODY BGCOLOR=\"#ffffff\">";
	print "<H1>Nvim documentation: " f[1] "</H1>";
	print "<A NAME=\"top\"></A>";
	if ( FILENAME != "help.txt" ) {
	  print "<A HREF=\"index.html\">main help file</A>\n";
	}
	print "<HR>";
	print "<PRE>";
	filename=f[1]".html";
}

# set to a low value to test for few lines of text
# NR == 99999 { exit; }

# ignore underlines and tags
substr($0,1,5) == " vim:" { next; }
substr($0,1,4) == "vim:" { next; }
# keep just whole lines of "-", "="
substr($0,1,3) == "===" && substr($0,75,1) != "=" { next; }
substr($0,1,3) == "---" && substr($0,75,1) != "-" { next; }

{
	nstar = split($0,s,"ZWWZ");
	for ( i=2 ; i <= nstar ; i=i+2 ) {
		nbla=split(s[i],blata,"[ 	]");
		if ( nbla > 1 ) {
			gsub("ZWWZ","*");
			nstar = split($0,s,"ZWWZ");
		}
	}
	npipe = split($0,p,"YXXY");
	for ( i=2 ; i <= npipe ; i=i+2 ) {
		nbla=split(p[i],blata,"[ 	]");
		if ( nbla > 1 ) {
			gsub("YXXY","|");
			ntabs = split($0,p,"YXXY");
		}
	}
}


FILENAME == "gui.txt" && asciiart == "no"  \
	  && $0 ~ /\+----/ && $0 ~ /----\+/ {
	asciiart= "yes";
	asciicnt=0;
	}

FILENAME == "usr_20.txt" && asciiart == "no" \
	  && $0 ~ /an empty line at the end:/ {
	asciiart= "yes";
	asciicnt=0;
	}

asciiart == "yes" && $0=="" { asciicnt++; }

asciiart == "yes" && asciicnt == 2 { asciiart = "no"; }

asciiart == "yes" { npipe = 1; }
#	{ print NR " <=> " asciiart; }

#
# line contains  "*"
#
nstar > 2 && npipe < 3 {
	printf("\n");
	for ( i=1; i <= nstar ; i=i+2 ) {
		this=s[i];
		put_this();
		ii=i+1;
		nbla = split(s[ii],blata," ");
		if ( ii <= nstar ) {
			if ( nbla == 1 && substr(s[ii],length(s[ii]),1) != " " ) {
			printf("*<A NAME=\"%s\"></A>",s[ii]);
				printf("<B>%s</B>*",s[ii]);
			} else {
			printf("*%s*",s[ii]);
			}
		}
	}
	printf("\n");
	next;
	}
#
# line contains "|"
#
npipe > 2 && nstar < 3 {
	if  ( npipe%2 == 0 ) {
		for ( i=1; i < npipe ; i++ ) {
			gsub("ZWWZ","*",p[i]);
			printf("%s|",p[i]);
		}
		printf("%s\n",p[npipe]);
		next;
		}
	for ( i=1; i <= npipe ; i++ )
		{
		if ( i % 2 == 1 ) {
			gsub("ZWWZ","*",p[i]);
			this=p[i];
			put_this();
			}
			else {
			nfn=split(p[i],f,".");
			if ( nfn == 1 || f[2] == "" || f[1] == "" || length(f[2]) < 3 ) {
				find_tag1();
				}
				else {
					if ( f[1] == "index" ) {
		printf "|<A HREF=\"vimindex.html\">" p[i] "</A>|";
					} else {
						if ( f[1] == "help" ) {
		printf "|<A HREF=\"index.html\">" p[i] "</A>|";
						} else {
		printf "|<A HREF=\"" f[1] ".html\">" p[i] "</A>|";
						}
					}
				}
			}
		}
		printf("\n");
		next;
	}
#
# line contains both "|" and "*"
#
npipe > 2 && nstar > 2 {
	printf("\n");
	for ( j=1; j <= nstar ; j=j+2 ) {
		npipe = split(s[j],p,"YXXY");
		if ( npipe > 1 ) {
			for ( np=1; np<=npipe; np=np+2 ) {
				this=p[np];
				put_this();
				i=np+1;find_tag1();
			}
		} else {
			this=s[j];
			put_this();
		}
		jj=j+1;
		nbla = split(s[jj],blata," ");
		if ( jj <= nstar && nbla == 1 && s[jj] != "" ) {
		printf("*<A NAME=\"%s\"></A>",s[jj]);
			printf("<B>%s</B>*",s[jj]);
		} else {
			if ( s[jj] != "" ) {
			printf("*%s*",s[jj]);
			}
		}
	}
	printf("\n");
	next;
	}
#
# line contains e-mail address john.doe@some.place.edu
#
$0 ~ /@/ && $0 ~ /[a-zA-Z0-9]@[a-z]/ \
	{
	nemail=split($0,em," ");
	if ( substr($0,1,1) == "	" ) { printf("	"); }
	for ( i=1; i <= nemail; i++ ) {
		if ( em[i] ~ /@/ ) {
			if ( substr(em[i],2,3) == "lt;" && substr(em[i],length(em[i])-2,3) == "gt;" ) {
				mailaddr=substr(em[i],5,length(em[i])-8);
				printf("<A HREF=\"mailto:%s\">&lt;%s&gt;</A> ",mailaddr,mailaddr);
			} else {
				if ( substr(em[i],2,3) == "lt;" && substr(em[i],length(em[i])-3,3) == "gt;" ) {
					mailaddr=substr(em[i],5,length(em[i])-9);
					printf("<A HREF=\"mailto:%s\">&lt;%s&gt;</A>%s ",mailaddr,mailaddr,substr(em[i],length(em[i]),1));
				} else {
					printf("<A HREF=\"mailto:%s\">%s</A> ",em[i],em[i]);
				}
			}
		} else {
				printf("%s ",em[i]);
		}
	}
	#print "*** " NR " " FILENAME " - possible mail ref";
	printf("\n");
	next;
	}
#
# line contains http / ftp reference
#
$0 ~ /http:\/\// || $0 ~ /ftp:\/\// {
	gsub("URL:","");
	gsub("&lt;","");
	gsub("&gt;","");
	gsub("\\(","");
	gsub("\\)","");
	nemail=split($0,em," ");
	for ( i=1; i <= nemail; i++ ) {
		if ( substr(em[i],1,5) == "http:" ||
	     	substr(em[i],1,4) == "ftp:" ) {
			if ( substr(em[i],length(em[i]),1) != "." ) {
				printf("	<A HREF=\"%s\">%s</A>",em[i],em[i]);
			} else {
				em[i]=substr(em[i],1,length(em[i])-1);
				printf("	<A HREF=\"%s\">%s</A>.",em[i],em[i]);
			}
		} else {
		printf(" %s",em[i]);
		}
	}
	#print "*** " NR " " FILENAME " - possible http ref";
	printf("\n");
	next;
	}
#
# some lines contains just one "almost regular" "*"...
#
nstar == 2  {
	this=s[1];
	put_this();
	printf("*");
	this=s[2];
	put_this();
	printf("\n");
	next;
	}
#
# regular line
#
	{ ntabs = split($0,tb,"	");
	for ( i=1; i < ntabs ; i++) {
		this=tb[i];
		put_this();
		printf("	");
		}
	this=tb[ntabs];
	put_this();
	printf("\n");
	}


asciiart == "yes"  && $0 ~ /\+-\+--/  \
	&& $0 ~ "scrollbar" { asciiart = "no"; }

END {
	topback();
	print "</PRE>\n</BODY>\n\n\n</HTML>"; }

#
# as main we keep index.txt (by default)
#
function topback () {
	if ( FILENAME != "tags" ) {
	if ( FILENAME != "help.txt" ) {
	printf("<A HREF=\"#top\">top</A> - ");
	printf("<A HREF=\"index.html\">main help file</A>\n");
	} else {
	printf("<A HREF=\"#top\">top</A>\n");
	}
	}
}

function find_tag1() {
	if ( p[i] == "" ) { return; }
	if ( tagkey[p[i]] == "yes" ) {
		which=tagref[p[i]];
		put_href();
		return;
	}
	# if not found, then we have a problem
	print "============================================"  >>"errors.log";
	print FILENAME ", line " NR ", pointer: >>" p[i] "<<" >>"errors.log";
	print $0 >>"errors.log";
	which="intro.html";
	put_href();
}

function see_tag() {
# ad-hoc code:
if ( atag == "\"--" || atag == "--\"" ) { return; }
if_already();
if ( already == "yes" ) {
	printf("%s",aword);
	return;
	}
allow_one_char="no";
find_tag2();
if ( done == "yes" ) { return; }
rightchar=substr(atag,length(atag),1);
if (    rightchar == "." \
     || rightchar == "," \
     || rightchar == ":" \
     || rightchar == ";" \
     || rightchar == "!" \
     || rightchar == "?" \
     || rightchar == ")" ) {
	atag=substr(atag,1,length(atag)-1);
	if_already();
	if ( already == "yes" ) {
		printf("%s",aword);
		return;
	}
	find_tag2();
	if ( done == "yes" ) { printf("%s",rightchar);return; }
	leftchar=substr(atag,1,1);
	lastbut1=substr(atag,length(atag),1);
	if (    leftchar == "'" && lastbut1 == "'"  ) {
		allow_one_char="yes";
		atag=substr(atag,2,length(atag)-2);
		if_already();
		if ( already == "yes" ) {
			printf("%s",aword);
			return;
		}
		printf("%s",leftchar);
		aword=substr(atag,1,length(atag))""lastbut1""rightchar;
		find_tag2();
		if ( done == "yes" ) { printf("%s%s",lastbut1,rightchar);return; }
		}
	}
atag=aword;
leftchar=substr(atag,1,1);
if (    leftchar == "'" && rightchar == "'"  ) {
	allow_one_char="yes";
	atag=substr(atag,2,length(atag)-2);
	if  ( atag == "<" ) { printf(" |%s|%s| ",atag,p[2]); }
	if_already();
	if ( already == "yes" ) {
		printf("%s",aword);
		return;
		}
	printf("%s",leftchar);
	find_tag2();
	if ( done == "yes" ) { printf("%s",rightchar);return; }
	printf("%s%s",atag,rightchar);
	return;
	}
last2=substr(atag,length(atag)-1,2);
first2=substr(atag,1,2);
if (    first2 == "('" && last2 == "')"  ) {
	allow_one_char="yes";
	atag=substr(atag,3,length(atag)-4);
	if_already();
	if ( already == "yes" ) {
		printf("%s",aword);
		return;
		}
	printf("%s",first2);
	find_tag2();
	if ( done == "yes" ) { printf("%s",last2);return; }
	printf("%s%s",atag,last2);
	return;
	}
if ( last2 == ".)" ) {
	atag=substr(atag,1,length(atag)-2);
	if_already();
	if ( already == "yes" ) {
		printf("%s",aword);
		return;
		}
	find_tag2();
	if ( done == "yes" ) { printf("%s",last2);return; }
	printf("%s%s",atag,last2);
	return;
	}
if ( last2 == ")." ) {
	atag=substr(atag,1,length(atag)-2);
	find_tag2();
	if_already();
	if ( already == "yes" ) {
		printf("%s",aword);
		return;
		}
	if ( done == "yes" ) { printf("%s",last2);return; }
	printf("%s%s",atag,last2);
	return;
	}
first6=substr(atag,1,6);
last6=substr(atag,length(atag)-5,6);
if ( last6 == atag ) {
	printf("%s",aword);
	return;
	}
last6of7=substr(atag,length(atag)-6,6);
if ( first6 == "&quot;" && last6of7 == "&quot;" && length(atag) > 12 ) {
	allow_one_char="yes";
	atag=substr(atag,7,length(atag)-13);
	if_already();
	if ( already == "yes" ) {
		printf("%s",aword);
		return;
		}
	printf("%s",first6);
	find_tag2();
	if ( done == "yes" ) { printf("&quot;%s",rightchar); return; }
	printf("%s&quot;%s",atag,rightchar);
	return;
	}
if ( first6 == "&quot;" && last6 != "&quot;" ) {
	allow_one_char="yes";
	atag=substr(atag,7,length(atag)-6);
	if ( atag == "[" ) { printf("&quot;%s",atag); return; }
	if ( atag == "." ) { printf("&quot;%s",atag); return; }
	if ( atag == ":" ) { printf("&quot;%s",atag); return; }
	if ( atag == "a" ) { printf("&quot;%s",atag); return; }
	if ( atag == "A" ) { printf("&quot;%s",atag); return; }
	if ( atag == "g" ) { printf("&quot;%s",atag); return; }
	if_already();
	if ( already == "yes" ) {
		printf("&quot;%s",atag);
		return;
		}
	printf("%s",first6);
	find_tag2();
	if ( done == "yes" ) { return; }
	printf("%s",atag);
	return;
	}
if ( last6 == "&quot;" && first6 == "&quot;" ) {
	allow_one_char="yes";
	atag=substr(atag,7,length(atag)-12);
	if_already();
	if ( already == "yes" ) {
		printf("%s",aword);
		return;
		}
	printf("%s",first6);
	find_tag2();
	if ( done == "yes" ) { printf("%s",last6);return; }
	printf("%s%s",atag,last6);
	return;
	}
last6of7=substr(atag,length(atag)-6,6);
if ( last6of7 == "&quot;" && first6 == "&quot;" ) {
	allow_one_char="yes";
	atag=substr(atag,7,length(atag)-13);
	#printf("\natag=%s,aword=%s\n",atag,aword);
	if_already();
	if ( already == "yes" ) {
		printf("%s",aword);
		return;
		}
	printf("%s",first6);
	find_tag2();
	if ( done == "yes" ) { printf("%s%s",last6of7,rightchar);return; }
	printf("%s%s%s",atag,last6of7,rightchar);
	return;
	}
printf("%s",aword);
}

function find_tag2() {
	done="no";
	# no blanks present in a tag...
	ntags=split(atag,blata,"[ 	]");
	if ( ntags > 1 ) { return; }
	if 	( ( allow_one_char == "no" ) && \
		  ( index("!#$%&'()+,-./0:;=?@ACINX\\[\\]^_`at\\{\\}~",atag) !=0 ) ) {
		return;
	}
	if ( skip_word[atag] == "yes" ) { return; }
	if ( wasset == "yes" && lineset == NR ) {
	wasset="no";
	see_opt();
	if ( done_opt == "yes" ) {return;}
	}
	if ( wasset == "yes" && lineset != NR ) {
	wasset="no";
	}
	if ( atag == ":set" ) {
	wasset="yes";
	lineset=NR;
	}
	if ( tagkey[atag] == "yes" ) {
		which=tagref[atag];
		put_href2();
		done="yes";
	}
}

function find_tag3() {
	done="no";
	# no blanks present in a tag...
	ntags=split(btag,blata,"[ 	]");
	if ( ntags > 1 ) { return; }
	if 	( ( allow_one_char == "no" ) && \
		  ( index("!#$%&'()+,-./0:;=?@ACINX\\[\\]^_`at\\{\\}~",btag) !=0 ) ) {
	  	return;
	}
	if ( skip_word[btag] == "yes" ) { return; }
	if ( tagkey[btag] == "yes" ) {
		which=tagref[btag];
		put_href3();
		done="yes";
	}
}

function put_href() {
	if ( p[i] == "" ) { return; }
	if ( which == FILENAME ) {
		printf("|<A HREF=\"#%s\">%s</A>|",p[i],p[i]);
		}
		else {
		nz=split(which,zz,".");
		if ( zz[2] == "txt" || zz[1] == "tags" ) {
		printf("|<A HREF=\"%s.html#%s\">%s</A>|",zz[1],p[i],p[i]);
		}
		else {
		printf("|<A HREF=\"intro.html#%s\">%s</A>|",p[i],p[i]);
		}
	}
}

function put_href2() {
	if ( atag == "" ) { return; }
	if ( which == FILENAME ) {
		printf("<A HREF=\"#%s\">%s</A>",atag,atag);
		}
		else {
		nz=split(which,zz,".");
		if ( zz[2] == "txt" || zz[1] == "tags" ) {
		printf("<A HREF=\"%s.html#%s\">%s</A>",zz[1],atag,atag);
		}
		else {
		printf("<A HREF=\"intro.html#%s\">%s</A>",atag,atag);
		}
	}
}

function put_href3() {
	if ( btag == "" ) { return; }
	if ( which == FILENAME ) {
		printf("<A HREF=\"#%s\">%s</A>",btag,btag2);
		}
		else {
		nz=split(which,zz,".");
		if ( zz[2] == "txt" || zz[1] == "tags" ) {
		printf("<A HREF=\"%s.html#%s\">%s</A>",zz[1],btag,btag2);
		}
		else {
		printf("<A HREF=\"intro.html#%s\">%s</A>",btag,btag2);
		}
	}
}

function put_this() {
	ntab=split(this,ta,"	");
	for ( nta=1 ; nta <= ntab ; nta++ ) {
		ata=ta[nta];
		lata=length(ata);
		aword="";
		for ( iata=1 ; iata <=lata ; iata++ ) {
			achar=substr(ata,iata,1);
			if ( achar != " " ) { aword=aword""achar; }
			else {
				if ( aword != "" ) { atag=aword;
					see_tag();
					aword="";
					printf(" "); }
				else	{
					printf(" ");
					}
			}
		}
		if ( aword != "" ) { atag=aword;
					see_tag();
					}
		if ( nta != ntab ) { printf("	"); }
	}
}

function if_already() {
	already="no";
	if  ( npipe < 2 ) { return; }
	if  ( atag == ":au" && p[2] == ":autocmd" ) { already="yes";return; }
	for ( npp=2 ; npp <= npipe ; npp=npp+2 ) {
		if 	(  (  (index(p[npp],atag)) != 0 \
			      && length(p[npp]) > length(atag) \
			      && length(atag) >= 1  \
			    ) \
			    || (p[npp] == atag) \
			) {
		# printf("p=|%s|,tag=|%s| ",p[npp],atag);
		already="yes"; return; }
	}
}

function see_opt() {
	done_opt="no";
	stag=atag;
	nfields = split(atag,tae,"=");
	if ( nfields > 1 )  {
		btag="'"tae[1]"'";
		btag2=tae[1];
	    find_tag3();
		if (done == "yes") {
			for ( ntae=2 ; ntae <= nfields ; ntae++ ) {
				printf("=%s",tae[ntae]);
			}
			atag=stag;
			done_opt="yes";
			return;
		}
		btag=tae[1];
		btag2=tae[1];
	    find_tag3();
		if ( done=="yes" ) {
			for ( ntae=2 ; ntae <= nfields ; ntae++ ) {
				printf("=%s",tae[ntae]);
			}
			atag=stag;
			done_opt="yes";
			return;
		}
	}
	nfields = split(atag,tae,"&quot;");
	if ( nfields > 1 )  {
		btag="'"tae[1]"'";
		btag2=tae[1];
	   	find_tag3();
		if (done == "yes") {
			printf("&quot;");
			atag=stag;
			done_opt="yes";
			return;
		}
		btag=tae[1];
		btag2=tae[1];
	    find_tag3();
		if (done == "yes") {
			printf("&quot;");
			atag=stag;
			done_opt="yes";
			return;
		}
	}
	btag="'"tae[1]"'";
	btag2=tae[1];
	find_tag3();
	if (done == "yes") {
		atag=stag;
		done_opt="yes";
		return;
	}
	btag=tae[1];
	btag2=tae[1];
	find_tag3();
	if (done == "yes") {
		atag=stag;
		done_opt="yes";
		return;
	}
	atag=stag;
}
