" Vim syntax file
" Language:			ESTEREL
" Maintainer:		Maurizio Tranchero <maurizio.tranchero@polito.it> - <maurizio.tranchero@gmail.com>
" Credits:			Luca Necchi	<luca.necchi@polito.it>, Nikos Andrikos <nick.andrik@gmail.com>
" First Release:	Tue May 17 23:49:39 CEST 2005
" Last Change:		Tue May  6 13:29:56 CEST 2008
" Version:			0.8

" quit when a syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

" case is significant
syn case ignore
" Esterel Regions
syn region esterelModule					start=/module/		end=/end module/	contains=ALLBUT,esterelModule
syn region esterelLoop						start=/loop/		end=/end loop/		contains=ALLBUT,esterelModule
syn region esterelAbort						start=/abort/		end=/when/			contains=ALLBUT,esterelModule
syn region esterelAbort						start=/weak abort/	end=/when/			contains=ALLBUT,esterelModule
syn region esterelEvery						start=/every/		end=/end every/		contains=ALLBUT,esterelModule
syn region esterelIf						start=/if/			end=/end if/		contains=ALLBUT,esterelModule
syn region esterelConcurrent	transparent start=/\[/			end=/\]/			contains=ALLBUT,esterelModule
syn region esterelIfThen					start=/if/			end=/then/			oneline
" Esterel Keywords
syn keyword esterelIO			input output inputoutput constant
syn keyword esterelBoolean		and or not xor xnor nor nand
syn keyword esterelExpressions	mod pre
syn keyword esterelStatement	nothing halt
syn keyword esterelStatement	module signal sensor end
syn keyword esterelStatement	every do loop abort weak
syn keyword esterelStatement	emit present await
syn keyword esterelStatement	pause when immediate
syn keyword esterelStatement	if then else case
syn keyword esterelStatement	var in  run  suspend
syn keyword esterelStatement	repeat times combine with
syn keyword esterelStatement	assert sustain
" check what it is the following
syn keyword esterelStatement	relation						
syn keyword esterelFunctions	function procedure task
syn keyword esterelSysCall		call trap exit exec
" Esterel Types
syn keyword esterelType 		integer float bolean
" Esterel Comment
syn match esterelComment		"%.*$"
" Operators and special characters
syn match esterelSpecial		":"
syn match esterelSpecial		"<="
syn match esterelSpecial		">="
syn match esterelSpecial		"+"
syn match esterelSpecial		"-"
syn match esterelSpecial		"="
syn match esterelSpecial		";"
syn match esterelSpecial		"/"
syn match esterelSpecial		"?"
syn match esterelOperator		"\["
syn match esterelOperator		"\]"
syn match esterelOperator		":="
syn match esterelOperator		"||"
syn match esterelStatement		"\<\(if\|else\)\>"
syn match esterelNone			"\<else\s\+if\>$"
syn match esterelNone			"\<else\s\+if\>\s"

" Class Linking

hi def link esterelStatement		Statement
hi def link esterelType			Type
hi def link esterelComment		Comment
hi def link esterelBoolean		Number
hi def link esterelExpressions	Number
hi def link esterelIO			String
hi def link esterelOperator		Type
hi def link esterelSysCall		Type
hi def link esterelFunctions		Type
hi def link esterelSpecial		Special


let b:current_syntax = "esterel"
