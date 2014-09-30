" Vim syntax file
" Language:	Expect
" Maintainer:	Ralph Jennings <knowbudy@oro.net>
" Last Change:	2012 Jun 01
" 		(Dominique Pelle added @Spell)

" For version 5.x: Clear all syntax items
" For version 6.x: Quit when a syntax file was already loaded
if version < 600
  syntax clear
elseif exists("b:current_syntax")
  finish
endif

" Reserved Expect variable prefixes.
syn match   expectVariables "\$exp[a-zA-Z0-9_]*\|\$inter[a-zA-Z0-9_]*"
syn match   expectVariables "\$spawn[a-zA-Z0-9_]*\|\$timeout[a-zA-Z0-9_]*"

" Normal Expect variables.
syn match   expectVariables "\$env([^)]*)"
syn match   expectVariables "\$any_spawn_id\|\$argc\|\$argv\d*"
syn match   expectVariables "\$user_spawn_id\|\$spawn_id\|\$timeout"

" Expect variable arrays.
syn match   expectVariables "\$\(expect\|interact\)_out([^)]*)"			contains=expectOutVar

" User defined variables.
syn match   expectVariables "\$[a-zA-Z_][a-zA-Z0-9_]*"

" Reserved Expect command prefixes.
syn match   expectCommand    "exp_[a-zA-Z0-9_]*"

" Normal Expect commands.
syn keyword expectStatement	close debug disconnect
syn keyword expectStatement	exit exp_continue exp_internal exp_open
syn keyword expectStatement	exp_pid exp_version
syn keyword expectStatement	fork inter_return interpreter
syn keyword expectStatement	log_file log_user match_max overlay
syn keyword expectStatement	parity remove_nulls return
syn keyword expectStatement	send send_error send_log send_user
syn keyword expectStatement	sleep spawn strace stty system
syn keyword expectStatement	timestamp trace trap wait

" Tcl commands recognized and used by Expect.
syn keyword expectCommand		proc
syn keyword expectConditional	if else
syn keyword expectRepeat		while for foreach

" Expect commands with special arguments.
syn keyword expectStatement	expect expect_after expect_background			nextgroup=expectExpectOpts
syn keyword expectStatement	expect_before expect_user interact			nextgroup=expectExpectOpts

syn match   expectSpecial contained  "\\."

" Options for "expect", "expect_after", "expect_background",
" "expect_before", "expect_user", and "interact".
syn keyword expectExpectOpts	default eof full_buffer null return timeout

syn keyword expectOutVar  contained  spawn_id seconds seconds_total
syn keyword expectOutVar  contained  string start end buffer

" Numbers (Tcl style).
syn case ignore
  syn match  expectNumber	"\<\d\+\(u\=l\=\|lu\|f\)\>"
  "floating point number, with dot, optional exponent
  syn match  expectNumber	"\<\d\+\.\d*\(e[-+]\=\d\+\)\=[fl]\=\>"
  "floating point number, starting with a dot, optional exponent
  syn match  expectNumber	"\.\d\+\(e[-+]\=\d\+\)\=[fl]\=\>"
  "floating point number, without dot, with exponent
  syn match  expectNumber	"\<\d\+e[-+]\=\d\+[fl]\=\>"
  "hex number
  syn match  expectNumber	"0x[0-9a-f]\+\(u\=l\=\|lu\)\>"
  "syn match  expectIdentifier	"\<[a-z_][a-z0-9_]*\>"
syn case match

syn region  expectString	start=+"+  end=+"+  contains=@Spell,expectVariables,expectSpecial

" Are these really comments in Expect? (I never use it, so I'm just guessing).
syn keyword expectTodo		contained TODO
syn match   expectComment	"#.*$" contains=@Spell,expectTodo
syn match   expectSharpBang	"\%^#!.*"

" Define the default highlighting.
" For version 5.7 and earlier: only when not done already
" For version 5.8 and later: only when an item doesn't have highlighting yet
if version >= 508 || !exists("did_expect_syntax_inits")
  if version < 508
    let did_expect_syntax_inits = 1
    command -nargs=+ HiLink hi link <args>
  else
    command -nargs=+ HiLink hi def link <args>
  endif

  HiLink expectSharpBang	PreProc
  HiLink expectVariables	Special
  HiLink expectCommand		Function
  HiLink expectStatement	Statement
  HiLink expectConditional	Conditional
  HiLink expectRepeat		Repeat
  HiLink expectExpectOpts	Keyword
  HiLink expectOutVar		Special
  HiLink expectSpecial		Special
  HiLink expectNumber		Number

  HiLink expectString		String

  HiLink expectComment		Comment
  HiLink expectTodo		Todo
  "HiLink expectIdentifier	Identifier

  delcommand HiLink
endif

let b:current_syntax = "expect"

" vim: ts=8
