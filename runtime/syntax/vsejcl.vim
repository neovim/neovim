" Vim syntax file
" Language:    JCL job control language - DOS/VSE
" Maintainer:  Davyd Ondrejko <david.ondrejko@safelite.com>
" URL:
" Last change: 2001 May 10

" quit when a syntax file was already loaded
if exists("b:current_syntax")
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
" Only when an item doesn't have highlighting yet
command -nargs=+ HiLink hi def link <args>

HiLink vsejclComment		Comment
HiLink vsejclField		Type
HiLink vsejclKeyword		Statement
HiLink vsejclObject		Constant
HiLink vsejclString		Constant
HiLink vsejclMisc			Special
HiLink vsejclParms		Constant

delcommand HiLink

let b:current_syntax = "vsejcl"

" vim: ts=4
