" Vim syntax file
" Language:	Apache-Style configuration files (proftpd.conf/apache.conf/..)
" Maintainer:	Christian Hammers <ch@westend.com>
" URL:		none
" ChangeLog:
"	2001-05-04,ch
"		adopted Vim 6.0 syntax style
"	1999-10-28,ch
"		initial release

" The following formats are recognised:
" Apache-style .conf
"	# Comment
"	Option	value
"	Option	value1 value2
"	Option = value1 value2 #not apache but also allowed
"	<Section Name?>
"		Option	value
"		<SubSection Name?>
"		</SubSection>
"	</Section>

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn case ignore

syn match  apComment	/^\s*#.*$/
syn match  apOption	/^\s*[^ \t#<=]*/
"syn match  apLastValue	/[^ \t<=#]*$/ contains=apComment	ugly

" tags
syn region apTag	start=/</ end=/>/ contains=apTagOption,apTagError
" the following should originally be " [^<>]+" but this didn't work :(
syn match  apTagOption	contained / [-\/_\.:*a-zA-Z0-9]\+/ms=s+1
syn match  apTagError	contained /[^>]</ms=s+1

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_apachestyle_syn_inits")
  if version < 508
    let did_apachestyle_syn_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink apComment	Comment
  HiLink apOption	Keyword
  "HiLink apLastValue	Identifier		ugly?
  HiLink apTag		Special
  HiLink apTagOption	Identifier
  HiLink apTagError	Error

  delcommand HiLink
endif

let b:current_syntax = "apachestyle"
" vim: ts=8
