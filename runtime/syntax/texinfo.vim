" Vim syntax file
" Language:	Texinfo (macro package for TeX)
" Maintainer:	Sandor Kopanyi <sandor.kopanyi@mailbox.hu>
" URL:		<->
" Last Change:	2004 Jun 23
"
" the file follows the Texinfo manual structure; this file is based
" on manual for Texinfo version 4.0, 28 September 1999
" since @ can have special meanings, everything is 'match'-ed and 'region'-ed
" (including @ in 'iskeyword' option has unexpected effects)

" Remove any old syntax stuff hanging around, if needed
if version < 600
  syn clear
elseif exists("b:current_syntax")
  finish
endif

if !exists("main_syntax")
  let main_syntax = 'texinfo'
endif

"in Texinfo can be real big things, like tables; sync for that
syn sync lines=200

"some general stuff
"syn match texinfoError     "\S" contained TODO
syn match texinfoIdent	    "\k\+"		  contained "IDENTifier
syn match texinfoAssignment "\k\+\s*=\s*\k\+\s*$" contained "assigment statement ( var = val )
syn match texinfoSinglePar  "\k\+\s*$"		  contained "single parameter (used for several @-commands)
syn match texinfoIndexPar   "\k\k\s*$"		  contained "param. used for different *index commands (+ @documentlanguage command)


"marking words and phrases (chap. 9 in Texinfo manual)
"(almost) everything appears as 'contained' too; is for tables (@table)

"this chapter is at the beginning of this file to avoid overwritings

syn match texinfoSpecialChar				    "@acronym"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@acronym{" end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@b"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@b{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@cite"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@cite{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@code"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@code{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@command"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@command{" end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@dfn"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@dfn{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@email"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@email{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@emph"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@emph{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@env"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@env{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@file"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@file{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@i"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@i{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@kbd"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@kbd{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@key"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@key{"	end="}" contains=texinfoSpecialChar
syn match texinfoSpecialChar				    "@option"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@option{"	end="}" contains=texinfoSpecialChar
syn match texinfoSpecialChar				    "@r"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@r{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@samp"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@samp{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@sc"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@sc{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@strong"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@strong{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@t"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@t{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@url"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@url{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoSpecialChar				    "@var"		contained
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@var{"	end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn match texinfoAtCmd "^@kbdinputstyle" nextgroup=texinfoSinglePar skipwhite


"overview of Texinfo (chap. 1 in Texinfo manual)
syn match texinfoComment  "@c .*"
syn match texinfoComment  "@c$"
syn match texinfoComment  "@comment .*"
syn region texinfoMltlnAtCmd matchgroup=texinfoComment start="^@ignore\s*$" end="^@end ignore\s*$" contains=ALL


"beginning a Texinfo file (chap. 3 in Texinfo manual)
syn region texinfoPrmAtCmd     matchgroup=texinfoAtCmd start="@center "		 skip="\\$" end="$"		       contains=texinfoSpecialChar,texinfoBrcPrmAtCmd oneline
syn region texinfoMltlnDMAtCmd matchgroup=texinfoAtCmd start="^@detailmenu\s*$"		    end="^@end detailmenu\s*$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn region texinfoPrmAtCmd     matchgroup=texinfoAtCmd start="^@setfilename "    skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd     matchgroup=texinfoAtCmd start="^@settitle "       skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd     matchgroup=texinfoAtCmd start="^@shorttitlepage " skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd     matchgroup=texinfoAtCmd start="^@title "		 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoBrcPrmAtCmd  matchgroup=texinfoAtCmd start="@titlefont{"		    end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn region texinfoMltlnAtCmd   matchgroup=texinfoAtCmd start="^@titlepage\s*$"		    end="^@end titlepage\s*$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd,texinfoMltlnDMAtCmd,texinfoAtCmd,texinfoPrmAtCmd,texinfoMltlnAtCmd
syn region texinfoPrmAtCmd     matchgroup=texinfoAtCmd start="^@vskip "		 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn match texinfoAtCmd "^@exampleindent"     nextgroup=texinfoSinglePar skipwhite
syn match texinfoAtCmd "^@headings"	     nextgroup=texinfoSinglePar skipwhite
syn match texinfoAtCmd "^\\input"	     nextgroup=texinfoSinglePar skipwhite
syn match texinfoAtCmd "^@paragraphindent"   nextgroup=texinfoSinglePar skipwhite
syn match texinfoAtCmd "^@setchapternewpage" nextgroup=texinfoSinglePar skipwhite


"ending a Texinfo file (chap. 4 in Texinfo manual)
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="@author " skip="\\$" end="$" contains=texinfoSpecialChar oneline
"all below @bye should be comment TODO
syn match texinfoAtCmd "^@bye\s*$"
syn match texinfoAtCmd "^@contents\s*$"
syn match texinfoAtCmd "^@printindex" nextgroup=texinfoIndexPar skipwhite
syn match texinfoAtCmd "^@setcontentsaftertitlepage\s*$"
syn match texinfoAtCmd "^@setshortcontentsaftertitlepage\s*$"
syn match texinfoAtCmd "^@shortcontents\s*$"
syn match texinfoAtCmd "^@summarycontents\s*$"


"chapter structuring (chap. 5 in Texinfo manual)
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@appendix"		 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@appendixsec"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@appendixsection"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@appendixsubsec"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@appendixsubsubsec"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@centerchap"		 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@chapheading"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@chapter"		 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@heading"		 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@majorheading"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@section"		 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@subheading "	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@subsection"		 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@subsubheading"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@subsubsection"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@subtitle"		 skip="\\$" end="$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@unnumbered"		 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@unnumberedsec"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@unnumberedsubsec"	 skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@unnumberedsubsubsec" skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn match  texinfoAtCmd "^@lowersections\s*$"
syn match  texinfoAtCmd "^@raisesections\s*$"


"nodes (chap. 6 in Texinfo manual)
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@anchor{"		  end="}"
syn region texinfoPrmAtCmd    matchgroup=texinfoAtCmd start="^@top"    skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd    matchgroup=texinfoAtCmd start="^@node"   skip="\\$" end="$" contains=texinfoSpecialChar oneline


"menus (chap. 7 in Texinfo manual)
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@menu\s*$" end="^@end menu\s*$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd,texinfoMltlnDMAtCmd


"cross references (chap. 8 in Texinfo manual)
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@inforef{" end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@pxref{"   end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@ref{"     end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@uref{"    end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@xref{"    end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd


"marking words and phrases (chap. 9 in Texinfo manual)
"(almost) everything appears as 'contained' too; is for tables (@table)

"this chapter is at the beginning of this file to avoid overwritings


"quotations and examples (chap. 10 in Texinfo manual)
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@cartouche\s*$"	    end="^@end cartouche\s*$"	    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@display\s*$"	    end="^@end display\s*$"	    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@example\s*$"	    end="^@end example\s*$"	    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@flushleft\s*$"	    end="^@end flushleft\s*$"	    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@flushright\s*$"	    end="^@end flushright\s*$"	    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@format\s*$"	    end="^@end format\s*$"	    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@lisp\s*$"		    end="^@end lisp\s*$"	    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@quotation\s*$"	    end="^@end quotation\s*$"	    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@smalldisplay\s*$"     end="^@end smalldisplay\s*$"    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@smallexample\s*$"     end="^@end smallexample\s*$"    contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@smallformat\s*$"	    end="^@end smallformat\s*$"     contains=ALL
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@smalllisp\s*$"	    end="^@end smalllisp\s*$"	    contains=ALL
syn region texinfoPrmAtCmd   matchgroup=texinfoAtCmd start="^@exdent"	 skip="\\$" end="$"			    contains=texinfoSpecialChar oneline
syn match texinfoAtCmd "^@noindent\s*$"
syn match texinfoAtCmd "^@smallbook\s*$"


"lists and tables (chap. 11 in Texinfo manual)
syn match texinfoAtCmd "@asis"		   contained
syn match texinfoAtCmd "@columnfractions"  contained
syn match texinfoAtCmd "@item"		   contained
syn match texinfoAtCmd "@itemx"		   contained
syn match texinfoAtCmd "@tab"		   contained
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@enumerate"  end="^@end enumerate\s*$"  contains=ALL
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@ftable"     end="^@end ftable\s*$"     contains=ALL
syn region texinfoMltlnNAtCmd matchgroup=texinfoAtCmd start="^@itemize"    end="^@end itemize\s*$"    contains=ALL
syn region texinfoMltlnNAtCmd matchgroup=texinfoAtCmd start="^@multitable" end="^@end multitable\s*$" contains=ALL
syn region texinfoMltlnNAtCmd matchgroup=texinfoAtCmd start="^@table"      end="^@end table\s*$"      contains=ALL
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@vtable"     end="^@end vtable\s*$"     contains=ALL


"indices (chap. 12 in Texinfo manual)
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@\(c\|f\|k\|p\|t\|v\)index"   skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@..index"			 skip="\\$" end="$" contains=texinfoSpecialChar oneline
"@defcodeindex and @defindex is defined after chap. 15's @def* commands (otherwise those ones will overwrite these ones)
syn match texinfoSIPar "\k\k\s*\k\k\s*$" contained
syn match texinfoAtCmd "^@syncodeindex" nextgroup=texinfoSIPar skipwhite
syn match texinfoAtCmd "^@synindex"     nextgroup=texinfoSIPar skipwhite

"special insertions (chap. 13 in Texinfo manual)
syn match texinfoSpecialChar "@\(!\|?\|@\|\s\)"
syn match texinfoSpecialChar "@{"
syn match texinfoSpecialChar "@}"
"accents
syn match texinfoSpecialChar "@=."
syn match texinfoSpecialChar "@\('\|\"\|\^\|`\)[aeiouyAEIOUY]"
syn match texinfoSpecialChar "@\~[aeinouyAEINOUY]"
syn match texinfoSpecialChar "@dotaccent{.}"
syn match texinfoSpecialChar "@H{.}"
syn match texinfoSpecialChar "@,{[cC]}"
syn match texinfoSpecialChar "@AA{}"
syn match texinfoSpecialChar "@aa{}"
syn match texinfoSpecialChar "@L{}"
syn match texinfoSpecialChar "@l{}"
syn match texinfoSpecialChar "@O{}"
syn match texinfoSpecialChar "@o{}"
syn match texinfoSpecialChar "@ringaccent{.}"
syn match texinfoSpecialChar "@tieaccent{..}"
syn match texinfoSpecialChar "@u{.}"
syn match texinfoSpecialChar "@ubaraccent{.}"
syn match texinfoSpecialChar "@udotaccent{.}"
syn match texinfoSpecialChar "@v{.}"
"ligatures
syn match texinfoSpecialChar "@AE{}"
syn match texinfoSpecialChar "@ae{}"
syn match texinfoSpecialChar "@copyright{}"
syn match texinfoSpecialChar "@bullet" contained "for tables and lists
syn match texinfoSpecialChar "@bullet{}"
syn match texinfoSpecialChar "@dotless{i}"
syn match texinfoSpecialChar "@dotless{j}"
syn match texinfoSpecialChar "@dots{}"
syn match texinfoSpecialChar "@enddots{}"
syn match texinfoSpecialChar "@equiv" contained "for tables and lists
syn match texinfoSpecialChar "@equiv{}"
syn match texinfoSpecialChar "@error{}"
syn match texinfoSpecialChar "@exclamdown{}"
syn match texinfoSpecialChar "@expansion{}"
syn match texinfoSpecialChar "@minus" contained "for tables and lists
syn match texinfoSpecialChar "@minus{}"
syn match texinfoSpecialChar "@OE{}"
syn match texinfoSpecialChar "@oe{}"
syn match texinfoSpecialChar "@point" contained "for tables and lists
syn match texinfoSpecialChar "@point{}"
syn match texinfoSpecialChar "@pounds{}"
syn match texinfoSpecialChar "@print{}"
syn match texinfoSpecialChar "@questiondown{}"
syn match texinfoSpecialChar "@result" contained "for tables and lists
syn match texinfoSpecialChar "@result{}"
syn match texinfoSpecialChar "@ss{}"
syn match texinfoSpecialChar "@TeX{}"
"other
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@dmn{"      end="}"
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@footnote{" end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@image{"    end="}"
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@math{"     end="}"
syn match texinfoAtCmd "@footnotestyle" nextgroup=texinfoSinglePar skipwhite


"making and preventing breaks (chap. 14 in Texinfo manual)
syn match texinfoSpecialChar  "@\(\*\|-\|\.\)"
syn match texinfoAtCmd	      "^@need"	   nextgroup=texinfoSinglePar skipwhite
syn match texinfoAtCmd	      "^@page\s*$"
syn match texinfoAtCmd	      "^@sp"	   nextgroup=texinfoSinglePar skipwhite
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@group\s*$"   end="^@end group\s*$" contains=ALL
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@hyphenation{" end="}"
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@w{"	    end="}"		  contains=texinfoSpecialChar,texinfoBrcPrmAtCmd


"definition commands (chap. 15 in Texinfo manual)
syn match texinfoMltlnAtCmdFLine "^@def\k\+" contained
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@def\k\+" end="^@end def\k\+$"      contains=ALL

"next 2 commands are from chap. 12; must be defined after @def* commands above to overwrite them
syn match texinfoAtCmd "@defcodeindex" nextgroup=texinfoIndexPar skipwhite
syn match texinfoAtCmd "@defindex" nextgroup=texinfoIndexPar skipwhite


"conditionally visible text (chap. 16 in Texinfo manual)
syn match texinfoAtCmd "^@clear" nextgroup=texinfoSinglePar skipwhite
syn region texinfoMltln2AtCmd matchgroup=texinfoAtCmd start="^@html\s*$"	end="^@end html\s*$"
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@ifclear"		end="^@end ifclear\s*$"   contains=ALL
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@ifhtml"		end="^@end ifhtml\s*$"	  contains=ALL
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@ifinfo"		end="^@end ifinfo\s*$"	  contains=ALL
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@ifnothtml"	end="^@end ifnothtml\s*$" contains=ALL
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@ifnotinfo"	end="^@end ifnotinfo\s*$" contains=ALL
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@ifnottex"	end="^@end ifnottex\s*$"  contains=ALL
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@ifset"		end="^@end ifset\s*$"	  contains=ALL
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@iftex"		end="^@end iftex\s*$"	  contains=ALL
syn region texinfoPrmAtCmd    matchgroup=texinfoAtCmd start="^@set " skip="\\$" end="$" contains=texinfoSpecialChar oneline
syn region texinfoTexCmd			      start="\$\$"		end="\$\$" contained
syn region texinfoMltlnAtCmd  matchgroup=texinfoAtCmd start="^@tex"		end="^@end tex\s*$"	  contains=texinfoTexCmd
syn region texinfoBrcPrmAtCmd matchgroup=texinfoAtCmd start="@value{"		end="}" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd


"internationalization (chap. 17 in Texinfo manual)
syn match texinfoAtCmd "@documentencoding" nextgroup=texinfoSinglePar skipwhite
syn match texinfoAtCmd "@documentlanguage" nextgroup=texinfoIndexPar skipwhite


"defining new texinfo commands (chap. 18 in Texinfo manual)
syn match texinfoAtCmd	"@alias"		      nextgroup=texinfoAssignment skipwhite
syn match texinfoDIEPar "\S*\s*,\s*\S*\s*,\s*\S*\s*$" contained
syn match texinfoAtCmd	"@definfoenclose"	      nextgroup=texinfoDIEPar	  skipwhite
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@macro" end="^@end macro\s*$" contains=ALL


"formatting hardcopy (chap. 19 in Texinfo manual)
syn match texinfoAtCmd "^@afourlatex\s*$"
syn match texinfoAtCmd "^@afourpaper\s*$"
syn match texinfoAtCmd "^@afourwide\s*$"
syn match texinfoAtCmd "^@finalout\s*$"
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@pagesizes" end="$" oneline


"creating and installing Info Files (chap. 20 in Texinfo manual)
syn region texinfoPrmAtCmd   matchgroup=texinfoAtCmd start="^@dircategory"  skip="\\$" end="$" oneline
syn region texinfoMltlnAtCmd matchgroup=texinfoAtCmd start="^@direntry\s*$"	       end="^@end direntry\s*$" contains=texinfoSpecialChar
syn match  texinfoAtCmd "^@novalidate\s*$"


"include files (appendix E in Texinfo manual)
syn match texinfoAtCmd "^@include" nextgroup=texinfoSinglePar skipwhite


"page headings (appendix F in Texinfo manual)
syn match texinfoHFSpecialChar "@|"		  contained
syn match texinfoThisAtCmd     "@thischapter"	  contained
syn match texinfoThisAtCmd     "@thischaptername" contained
syn match texinfoThisAtCmd     "@thisfile"	  contained
syn match texinfoThisAtCmd     "@thispage"	  contained
syn match texinfoThisAtCmd     "@thistitle"	  contained
syn match texinfoThisAtCmd     "@today{}"	  contained
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@evenfooting"  skip="\\$" end="$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd,texinfoThisAtCmd,texinfoHFSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@evenheading"  skip="\\$" end="$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd,texinfoThisAtCmd,texinfoHFSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@everyfooting" skip="\\$" end="$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd,texinfoThisAtCmd,texinfoHFSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@everyheading" skip="\\$" end="$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd,texinfoThisAtCmd,texinfoHFSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@oddfooting"   skip="\\$" end="$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd,texinfoThisAtCmd,texinfoHFSpecialChar oneline
syn region texinfoPrmAtCmd matchgroup=texinfoAtCmd start="^@oddheading"   skip="\\$" end="$" contains=texinfoSpecialChar,texinfoBrcPrmAtCmd,texinfoThisAtCmd,texinfoHFSpecialChar oneline


"refilling paragraphs (appendix H in Texinfo manual)
syn match  texinfoAtCmd "@refill"


syn cluster texinfoAll contains=ALLBUT,texinfoThisAtCmd,texinfoHFSpecialChar
syn cluster texinfoReducedAll contains=texinfoSpecialChar,texinfoBrcPrmAtCmd
"==============================================================================
" highlighting

" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_texinfo_syn_inits")

  if version < 508
    let did_texinfo_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink texinfoSpecialChar	Special
  HiLink texinfoHFSpecialChar	Special

  HiLink texinfoError		Error
  HiLink texinfoIdent		Identifier
  HiLink texinfoAssignment	Identifier
  HiLink texinfoSinglePar	Identifier
  HiLink texinfoIndexPar	Identifier
  HiLink texinfoSIPar		Identifier
  HiLink texinfoDIEPar		Identifier
  HiLink texinfoTexCmd		PreProc


  HiLink texinfoAtCmd		Statement	"@-command
  HiLink texinfoPrmAtCmd	String		"@-command in one line with unknown nr. of parameters
						"is String because is found as a region and is 'matchgroup'-ed
						"to texinfoAtCmd
  HiLink texinfoBrcPrmAtCmd	String		"@-command with parameter(s) in braces ({})
						"is String because is found as a region and is 'matchgroup'-ed to texinfoAtCmd
  HiLink texinfoMltlnAtCmdFLine  texinfoAtCmd	"repeated embedded First lines in @-commands
  HiLink texinfoMltlnAtCmd	String		"@-command in multiple lines
						"is String because is found as a region and is 'matchgroup'-ed to texinfoAtCmd
  HiLink texinfoMltln2AtCmd	PreProc		"@-command in multiple lines (same as texinfoMltlnAtCmd, just with other colors)
  HiLink texinfoMltlnDMAtCmd	PreProc		"@-command in multiple lines (same as texinfoMltlnAtCmd, just with other colors; used for @detailmenu, which can be included in @menu)
  HiLink texinfoMltlnNAtCmd	Normal		"@-command in multiple lines (same as texinfoMltlnAtCmd, just with other colors)
  HiLink texinfoThisAtCmd	Statement	"@-command used in headers and footers (@this... series)

  HiLink texinfoComment	Comment

  delcommand HiLink
endif


let b:current_syntax = "texinfo"

if main_syntax == 'texinfo'
  unlet main_syntax
endif

" vim: ts=8
