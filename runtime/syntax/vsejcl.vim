" Vim syntax file
" Language:    JCL job control language - DOS/VSE
" Maintainer:  Davyd Ondrejko <david.ondrejko@safelite.com>
" URL:
" Last change: 2001 May 10

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" tags
syn keyword vsejclKeyword DLBL EXEC JOB ASSGN EOJ
syn keyword vsejclField JNM CLASS DISP USER SYSID JSEP SIZE
syn keyword vsejclField VSAM
syn region vsejclComment start="^/\*" end="$"
syn region vsejclComment start="^[\* ]\{}$" end="$"
syn region vsejclMisc start="^  " end="$" contains=Jparms
syn match vsejclString /'.\{-}'/
syn match vsejclParms /(.\{-})/ contained

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_vsejcl_syntax")
  if version < 508
    let did_vsejcl_syntax = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink vsejclComment		Comment
  HiLink vsejclField		Type
  HiLink vsejclKeyword		Statement
  HiLink vsejclObject		Constant
  HiLink vsejclString		Constant
  HiLink vsejclMisc			Special
  HiLink vsejclParms		Constant

  delcommand HiLink
endif

let b:current_syntax = "vsejcl"

" vim: ts=4
