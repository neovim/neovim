" Vim syntax file
" Language:	gp (version 2.15)
" Maintainer:	Karim Belabas <Karim.Belabas@math.u-bordeaux.fr>
" Last change:	2023 Aug 22
" URL:		http://pari.math.u-bordeaux.fr

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" control statements
syntax keyword gpStatement	break return next
syntax keyword gpConditional	if iferr
syntax keyword gpRepeat		until while for forcomposite fordiv
syntax keyword gpRepeat		fordivfactored foreach forell forfactored
syntax keyword gpRepeat		forpart forperm forprime forprimestep forqfvec
syntax keyword gpRepeat		forsquarefree forstep forsubgroup forsubset
syntax keyword gpRepeat		forvec
syntax keyword gpRepeat		parfor parforeach parforprime parforprimestep
syntax keyword gpRepeat		parforvec
" storage class
syntax keyword gpScope		my local global export exportall
" defaults
syntax keyword gpInterfaceKey	breakloop colors compatible
syntax keyword gpInterfaceKey	datadir debug debugfiles debugmem
syntax keyword gpInterfaceKey	echo factor_add_primes factor_proven format
syntax keyword gpInterfaceKey	graphcolormap graphcolors
syntax keyword gpInterfaceKey	help histfile histsize
syntax keyword gpInterfaceKey	lines linewrap log logfile nbthreads
syntax keyword gpInterfaceKey	new_galois_format output parisize parisizemax
syntax keyword gpInterfaceKey	path plothsizes prettyprinter primelimit prompt
syntax keyword gpInterfaceKey	prompt_cont psfile readline realbitprecision
syntax keyword gpInterfaceKey	realprecision recover secure seriesprecision
syntax keyword gpInterfaceKey	simplify sopath strictmatch TeXstyle
syntax keyword gpInterfaceKey	threadsize threadsizemax timer

syntax match gpInterface	"^\s*\\[a-z].*"
syntax keyword gpInterface	default
syntax keyword gpInput		read input

" functions
syntax match gpFunRegion "^\s*[a-zA-Z][_a-zA-Z0-9]*(.*)\s*=\s*[^ \t=]"me=e-1 contains=gpFunction,gpArgs
syntax match gpFunRegion "^\s*[a-zA-Z][_a-zA-Z0-9]*(.*)\s*=\s*$" contains=gpFunction,gpArgs
syntax match gpArgs contained "[a-zA-Z][_a-zA-Z0-9]*"
syntax match gpFunction contained "^\s*[a-zA-Z][_a-zA-Z0-9]*("me=e-1

" String and Character constants
" Highlight special (backslash'ed) characters differently
syntax match  gpSpecial contained "\\[ent\\]"
syntax region gpString  start=+"+ skip=+\\\\\|\\"+ end=+"+ contains=gpSpecial

"comments
syntax region gpComment	start="/\*"  end="\*/" contains=gpTodo
syntax match  gpComment "\\\\.*" contains=gpTodo
syntax keyword gpTodo contained	TODO
syntax sync ccomment gpComment minlines=10

"catch errors caused by wrong parenthesis
syntax region gpParen		transparent start='(' end=')' contains=ALLBUT,gpParenError,gpTodo,gpFunction,gpArgs,gpSpecial
syntax match gpParenError	")"
syntax match gpInParen contained "[{}]"

hi def link gpConditional	Conditional
hi def link gpRepeat		Repeat
hi def link gpError		Error
hi def link gpParenError	gpError
hi def link gpInParen		gpError
hi def link gpStatement		Statement
hi def link gpString		String
hi def link gpComment		Comment
hi def link gpInterface		Type
hi def link gpInput		Type
hi def link gpInterfaceKey	Statement
hi def link gpFunction		Function
hi def link gpScope		Type
" contained ones
hi def link gpSpecial		Special
hi def link gpTodo		Todo
hi def link gpArgs		Type

let b:current_syntax = "gp"
let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8
