" Vim syntax file
" Language:	C macro for C preprocessor
" Maintainer:	Wu, Zhenyu <wuzhenyu@ustc.edu>
" Last Change:	2024 Dec 31
" modified from syntax/c.vim

" C compiler has a preprocessor: `cpp -P test.txt`
" test.txt doesn't need to be a C file
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Accept %: for # (C99)
syn region	cmacroPreCondit	start="^\s*\zs\%(%:\|#\)\s*\%(if\|ifdef\|ifndef\|elif\)\>" skip="\\$" end="$" keepend contains=cmacroCppParen,cmacroNumbers
syn match	cmacroPreConditMatch	display "^\s*\zs\%(%:\|#\)\s*\%(else\|endif\)\>"
if !exists("c_no_if0")
  syn cluster	cmacroCppOutInGroup	contains=cmacroCppInIf,cmacroCppInElse,cmacroCppInElse2,cmacroCppOutIf,cmacroCppOutIf2,cmacroCppOutElse,cmacroCppInSkip,cmacroCppOutSkip
  syn region	cmacroCppOutWrapper	start="^\s*\zs\%(%:\|#\)\s*if\s\+0\+\s*\%($\|//\|/\*\|&\)" end=".\@=\|$" contains=cmacroCppOutIf,cmacroCppOutElse,@NoSpell fold
  syn region	cmacroCppOutIf	contained start="0\+" matchgroup=cmacroCppOutWrapper end="^\s*\%(%:\|#\)\s*endif\>" contains=cmacroCppOutIf2,cmacroCppOutElse
  if !exists("c_no_if0_fold")
    syn region	cmacroCppOutIf2	contained matchgroup=cmacroCppOutWrapper start="0\+" end="^\s*\%(%:\|#\)\s*\%(else\>\|elif\s\+\%(0\+\s*\%($\|//\|/\*\|&\)\)\@!\|endif\>\)"me=s-1 contains=cmacroCppOutSkip,@Spell fold
  else
    syn region	cmacroCppOutIf2	contained matchgroup=cmacroCppOutWrapper start="0\+" end="^\s*\%(%:\|#\)\s*\%(else\>\|elif\s\+\%(0\+\s*\%($\|//\|/\*\|&\)\)\@!\|endif\>\)"me=s-1 contains=cmacroCppOutSkip,@Spell
  endif
  syn region	cmacroCppOutElse	contained matchgroup=cmacroCppOutWrapper start="^\s*\%(%:\|#\)\s*\%(else\|elif\)" end="^\s*\%(%:\|#\)\s*endif\>"me=s-1 contains=TOP,cmacroPreCondit
  syn region	cmacroCppInWrapper	start="^\s*\zs\%(%:\|#\)\s*if\s\+0*[1-9]\d*\s*\%($\|//\|/\*\||\)" end=".\@=\|$" contains=cmacroCppInIf,cmacroCppInElse fold
  syn region	cmacroCppInIf	contained matchgroup=cmacroCppInWrapper start="\d\+" end="^\s*\%(%:\|#\)\s*endif\>" contains=TOP,cmacroPreCondit
  if !exists("c_no_if0_fold")
    syn region	cmacroCppInElse	contained start="^\s*\%(%:\|#\)\s*\%(else\>\|elif\s\+\%(0*[1-9]\d*\s*\%($\|//\|/\*\||\)\)\@!\)" end=".\@=\|$" containedin=cmacroCppInIf contains=cmacroCppInElse2 fold
  else
    syn region	cmacroCppInElse	contained start="^\s*\%(%:\|#\)\s*\%(else\>\|elif\s\+\%(0*[1-9]\d*\s*\%($\|//\|/\*\||\)\)\@!\)" end=".\@=\|$" containedin=cmacroCppInIf contains=cmacroCppInElse2
  endif
  syn region	cmacroCppInElse2	contained matchgroup=cmacroCppInWrapper start="^\s*\%(%:\|#\)\s*\%(else\|elif\)\%([^/]\|/[^/*]\)*" end="^\s*\%(%:\|#\)\s*endif\>"me=s-1 contains=cmacroCppOutSkip,@Spell
  syn region	cmacroCppOutSkip	contained start="^\s*\%(%:\|#\)\s*\%(if\>\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*\%(%:\|#\)\s*endif\>" contains=cmacroCppOutSkip
  syn region	cmacroCppInSkip	contained matchgroup=cmacroCppInWrapper start="^\s*\%(%:\|#\)\s*\%(if\s\+\%(\d\+\s*\%($\|//\|/\*\||\|&\)\)\@!\|ifdef\>\|ifndef\>\)" skip="\\$" end="^\s*\%(%:\|#\)\s*endif\>" containedin=cmacroCppOutElse,cmacroCppInIf,cmacroCppInSkip contains=TOP,cmacroPreProc
endif
syn region	cmacroIncluded	display contained start=+"+ skip=+\\\\\|\\"+ end=+"+
syn match	cmacroIncluded	display contained "<[^>]*>"
syn match	cmacroInclude	display "^\s*\zs\%(%:\|#\)\s*include\>\s*["<]" contains=cmacroIncluded
"syn match cmacroLineSkip	"\\$"
syn cluster	cmacroPreProcmacroGroup	contains=cmacroPreCondit,cmacroIncluded,cmacroInclude,cmacroDefine,cmacroCppOutWrapper,cmacroCppInWrapper,@cmacroCppOutInGroup,cmacroNumbersCom,@cmacroCommentGroup,cmacroParen,cmacroBracket,cmacroMulti,cmacroBadBlock
syn region	cmacroDefine		start="^\s*\zs\%(%:\|#\)\s*\%(define\|undef\)\>" skip="\\$" end="$" keepend contains=ALLBUT,@cmacroPreProcmacroGroup,@Spell
syn region	cmacroPreProc	start="^\s*\zs\%(%:\|#\)\s*\%(pragma\>\|line\>\|warning\>\|warn\>\|error\>\)" skip="\\$" end="$" keepend contains=ALLBUT,@cmacroPreProcmacroGroup,@Spell

" be able to fold #pragma regions
syn region	cmacroPragma		start="^\s*#pragma\s\+region\>" end="^\s*#pragma\s\+endregion\>" transparent keepend extend fold

syn keyword cmacroTodo			contained TODO FIXME XXX NOTE
syn region  cmacroComment		start='/\*' end='\*/' contains=cmacroTodo,@Spell
syn match   cmacroCommentError "\*/"
syn region  cmacroComment		start='//' end='$' contains=cmacroTodo,@Spell

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link cmacroInclude		Include
hi def link cmacroPreProc		PreProc
hi def link cmacroDefine		Macro
hi def link cmacroIncluded		cmacroString
hi def link cmacroCppInWrapper	cmacroCppOutWrapper
hi def link cmacroCppOutWrapper	cmacroPreCondit
hi def link cmacroPreConditMatch	cmacroPreCondit
hi def link cmacroPreCondit		PreCondit
hi def link cmacroCppOutSkip		cmacroCppOutIf2
hi def link cmacroCppInElse2		cmacroCppOutIf2
hi def link cmacroCppOutIf2		cmacroCppOut
hi def link cmacroCppOut		Comment
hi def link cmacroTodo			Todo
hi def link cmacroComment		Comment
hi def link cmacroCommentError		Error

let b:current_syntax = "cmacro"

let &cpo = s:cpo_save
unlet s:cpo_save
