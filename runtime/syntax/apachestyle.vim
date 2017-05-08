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

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet

hi def link apComment	Comment
hi def link apOption	Keyword
"hi def link apLastValue	Identifier		ugly?
hi def link apTag		Special
hi def link apTagOption	Identifier
hi def link apTagError	Error


let b:current_syntax = "apachestyle"
" vim: ts=8
