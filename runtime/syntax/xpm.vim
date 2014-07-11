" Vim syntax file
" Language:	X Pixmap
" Maintainer:	Ronald Schild <rs@scutum.de>
" Last Change:	2008 May 28
" Version:	5.4n.1

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

syn keyword xpmType		char
syn keyword xpmStorageClass	static
syn keyword xpmTodo		TODO FIXME XXX  contained
syn region  xpmComment		start="/\*"  end="\*/"  contains=xpmTodo
syn region  xpmPixelString	start=+"+  skip=+\\\\\|\\"+  end=+"+  contains=@xpmColors

if has("gui_running")

let color  = ""
let chars  = ""
let colors = 0
let cpp    = 0
let n      = 0
let i      = 1

while i <= line("$")		" scanning all lines

   let s = matchstr(getline(i), '".\{-1,}"')
   if s != ""			" does line contain a string?

      if n == 0			" first string is the Values string

	 " get the 3rd value: colors = number of colors
	 let colors = substitute(s, '"\s*\d\+\s\+\d\+\s\+\(\d\+\).*"', '\1', '')
	 " get the 4th value: cpp = number of character per pixel
	 let cpp = substitute(s, '"\s*\d\+\s\+\d\+\s\+\d\+\s\+\(\d\+\).*"', '\1', '')
	 if cpp =~ '[^0-9]'
	    break  " if cpp is not made of digits there must be something wrong
	 endif

	 " Highlight the Values string as normal string (no pixel string).
	 " Only when there is no slash, it would terminate the pattern.
	 if s !~ '/'
	    exe 'syn match xpmValues /' . s . '/'
	 endif
	 hi link xpmValues String

	 let n = 1		" n = color index

      elseif n <= colors	" string is a color specification

	 " get chars = <cpp> length string representing the pixels
	 " (first incl. the following whitespace)
	 let chars = substitute(s, '"\(.\{'.cpp.'}\s\).*"', '\1', '')

	 " now get color, first try 'c' key if any (color visual)
	 let color = substitute(s, '".*\sc\s\+\(.\{-}\)\s*\(\(g4\=\|[ms]\)\s.*\)*\s*"', '\1', '')
	 if color == s
	    " no 'c' key, try 'g' key (grayscale with more than 4 levels)
	    let color = substitute(s, '".*\sg\s\+\(.\{-}\)\s*\(\(g4\|[ms]\)\s.*\)*\s*"', '\1', '')
	    if color == s
	       " next try: 'g4' key (4-level grayscale)
	       let color = substitute(s, '".*\sg4\s\+\(.\{-}\)\s*\([ms]\s.*\)*\s*"', '\1', '')
	       if color == s
		  " finally try 'm' key (mono visual)
		  let color = substitute(s, '".*\sm\s\+\(.\{-}\)\s*\(s\s.*\)*\s*"', '\1', '')
		  if color == s
		     let color = ""
		  endif
	       endif
	    endif
	 endif

	 " Vim cannot handle RGB codes with more than 6 hex digits
	 if color =~ '#\x\{10,}$'
	    let color = substitute(color, '\(\x\x\)\x\x', '\1', 'g')
	 elseif color =~ '#\x\{7,}$'
	    let color = substitute(color, '\(\x\x\)\x', '\1', 'g')
	 " nor with 3 digits
	 elseif color =~ '#\x\{3}$'
	    let color = substitute(color, '\(\x\)\(\x\)\(\x\)', '0\10\20\3', '')
	 endif

	 " escape meta characters in patterns
	 let s = escape(s, '/\*^$.~[]')
	 let chars = escape(chars, '/\*^$.~[]')

	 " now create syntax items
	 " highlight the color string as normal string (no pixel string)
	 exe 'syn match xpmCol'.n.'Def /'.s.'/ contains=xpmCol'.n.'inDef'
	 exe 'hi link xpmCol'.n.'Def String'

	 " but highlight the first whitespace after chars in its color
	 exe 'syn match xpmCol'.n.'inDef /"'.chars.'/hs=s+'.(cpp+1).' contained'
	 exe 'hi link xpmCol'.n.'inDef xpmColor'.n

	 " remove the following whitespace from chars
	 let chars = substitute(chars, '.$', '', '')

	 " and create the syntax item contained in the pixel strings
	 exe 'syn match xpmColor'.n.' /'.chars.'/ contained'
	 exe 'syn cluster xpmColors add=xpmColor'.n

	 " if no color or color = "None" show background
	 if color == ""  ||  substitute(color, '.*', '\L&', '') == 'none'
	    exe 'hi xpmColor'.n.' guifg=bg'
	    exe 'hi xpmColor'.n.' guibg=NONE'
	 elseif color !~ "'"
	    exe 'hi xpmColor'.n." guifg='".color."'"
	    exe 'hi xpmColor'.n." guibg='".color."'"
	 endif
	 let n = n + 1
      else
	 break		" no more color string
      endif
   endif
   let i = i + 1
endwhile

unlet color chars colors cpp n i s

endif		" has("gui_running")

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_xpm_syntax_inits")
  if version < 508
    let did_xpm_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink xpmType		Type
  HiLink xpmStorageClass	StorageClass
  HiLink xpmTodo		Todo
  HiLink xpmComment		Comment
  HiLink xpmPixelString	String

  delcommand HiLink
endif

let b:current_syntax = "xpm"

" vim: ts=8:sw=3:noet:
