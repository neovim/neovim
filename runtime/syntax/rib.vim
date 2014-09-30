" Vim syntax file
" Language:	Renderman Interface Bytestream
" Maintainer:	Andrew Bromage <ajb@spamcop.net>
" Last Change:	2003 May 11
"

" Remove any old syntax stuff hanging around
if version < 600
  syn clear
elseif exists("b:current_syntax")
  finish
endif

syn case match

" Comments
syn match   ribLineComment      "#.*$"
syn match   ribStructureComment "##.*$"

syn case ignore
syn match   ribCommand	       /[A-Z][a-zA-Z]*/
syn case match

syn region  ribString	       start=/"/ skip=/\\"/ end=/"/

syn match   ribStructure	"[A-Z][a-zA-Z]*Begin\>\|[A-Z][a-zA-Z]*End"
syn region  ribSectionFold	start="FrameBegin" end="FrameEnd" fold transparent keepend extend
syn region  ribSectionFold	start="WorldBegin" end="WorldEnd" fold transparent keepend extend
syn region  ribSectionFold	start="TransformBegin" end="TransformEnd" fold transparent keepend extend
syn region  ribSectionFold	start="AttributeBegin" end="AttributeEnd" fold transparent keepend extend
syn region  ribSectionFold	start="MotionBegin" end="MotionEnd" fold transparent keepend extend
syn region  ribSectionFold	start="SolidBegin" end="SolidEnd" fold transparent keepend extend
syn region  ribSectionFold	start="ObjectBegin" end="ObjectEnd" fold transparent keepend extend

syn sync    fromstart

"integer number, or floating point number without a dot and with "f".
syn case ignore
syn match	ribNumbers	  display transparent "[-]\=\<\d\|\.\d" contains=ribNumber,ribFloat
syn match	ribNumber	  display contained "[-]\=\d\+\>"
"floating point number, with dot, optional exponent
syn match	ribFloat	  display contained "[-]\=\d\+\.\d*\(e[-+]\=\d\+\)\="
"floating point number, starting with a dot, optional exponent
syn match	ribFloat	  display contained "[-]\=\.\d\+\(e[-+]\=\d\+\)\=\>"
"floating point number, without dot, with exponent
syn match	ribFloat	  display contained "[-]\=\d\+e[-+]\d\+\>"
syn case match

if version >= 508 || !exists("did_rib_syntax_inits")
  if version < 508
    let did_rib_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink ribStructure		Structure
  HiLink ribCommand		Statement

  HiLink ribStructureComment	SpecialComment
  HiLink ribLineComment		Comment

  HiLink ribString		String
  HiLink ribNumber		Number
  HiLink ribFloat		Float

  delcommand HiLink
end


let b:current_syntax = "rib"

" Options for vi: ts=8 sw=2 sts=2 nowrap noexpandtab ft=vim
