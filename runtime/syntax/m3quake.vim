" Vim syntax file
" Language:	Modula-3 Quake
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2021 April 15

if exists("b:current_syntax")
  finish
endif

" Keywords
syn keyword m3quakeKeyword else end foreach if in is local or proc readonly
syn keyword m3quakeKeyword return

" Builtin procedures {{{
" Generated from m3-sys/m3quake/src/QMachine.m3
syn keyword m3quakeProcedure arglist cp_if defined empty equal error escape
syn keyword m3quakeProcedure exec cm3_exec file format include make_dir
syn keyword m3quakeProcedure normalize path stale try_exec try_cm3_exec
syn keyword m3quakeProcedure unlink_file write datetime date datestamp
syn keyword m3quakeProcedure TRACE_INSTR eval_func hostname

syn keyword m3quakeProcedure pushd popd cd getwd

syn keyword m3quakeProcedure quake

syn keyword m3quakeProcedure q_exec q_exec_put q_exec_get

syn keyword m3quakeProcedure fs_exists fs_readable fs_writable fs_executable
syn keyword m3quakeProcedure fs_isdir fs_isfile fs_contents fs_putfile
syn keyword m3quakeProcedure fs_mkdir fs_touch fs_lsdirs fs_lsfiles fs_rmdir
syn keyword m3quakeProcedure fs_rmfile fs_rmrec fs_cp

syn keyword m3quakeProcedure pn_valid pn_decompose pn_compose pn_absolute
syn keyword m3quakeProcedure pn_prefix pn_last pn_base pn_lastbase pn_lastext
syn keyword m3quakeProcedure pn_join pn_join2 pn_replace_ext pn_parent
syn keyword m3quakeProcedure pn_current

syn keyword m3quakeProcedure len

syn keyword m3quakeProcedure split sub skipl skipr squeeze compress pos
syn keyword m3quakeProcedure tcontains bool encode decode subst_chars
syn keyword m3quakeProcedure del_chars subst subst_env add_prefix add_suffix
" }}}

" Identifiers
syn match   m3quakeEnvVariable "$\h\w\+"

" Operators
syn match m3quakeOperator "&"
syn match m3quakeOperator "\<\%(contains\|not\|and\|or\)\>"

" Strings
syn match  m3quakeEscape "\\[\\nrtbf"]" contained display
syn region m3quakeString start=+"+ end=+"+ contains=m3quakeEscape

" Comments
syn keyword m3quakeTodo	 TODO FIXME XXX contained
syn region  m3quakeComment start="%"   end="$"	 contains=m3quakeTodo,@Spell
syn region  m3quakeComment start="/\*" end="\*/" contains=m3quakeTodo,@Spell

" Default highlighting
hi def link m3quakeCommand     Statement
hi def link m3quakeComment     Comment
hi def link m3quakeEnvVariable Identifier
hi def link m3quakeEscape      Special
hi def link m3quakeKeyword     Keyword
hi def link m3quakeOperator    Operator
hi def link m3quakeProcedure   Function
hi def link m3quakeString      String
hi def link m3quakeTodo	       Todo

let b:current_syntax = "m3quake"

" vim: nowrap sw=2 sts=2 ts=8 noet fdm=marker:
