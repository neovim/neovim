" Vim ftplugin file
" Language:     Erlang
" Author:       Oscar Hellström <oscar@oscarh.net>
" Contributors: Ricardo Catalinas Jiménez <jimenezrick@gmail.com>
"               Eduardo Lopez (http://github.com/tapichu)
" License:      Vim license
" Version:      2012/01/25

if exists('b:did_ftplugin')
	finish
else
	let b:did_ftplugin = 1
endif

if exists('s:did_function_definitions')
	call s:SetErlangOptions()
	finish
else
	let s:did_function_definitions = 1
endif

let s:cpo_save = &cpo
set cpo&vim

if !exists('g:erlang_keywordprg')
	let g:erlang_keywordprg = 'erl -man'
endif

if !exists('g:erlang_folding')
	let g:erlang_folding = 0
endif

let s:erlang_fun_begin = '^\a\w*(.*$'
let s:erlang_fun_end   = '^[^%]*\.\s*\(%.*\)\?$'

function s:SetErlangOptions()
	if g:erlang_folding
		setlocal foldmethod=expr
		setlocal foldexpr=GetErlangFold(v:lnum)
		setlocal foldtext=ErlangFoldText()
	endif

	setlocal comments=:%%%,:%%,:%
	setlocal commentstring=%%s

	setlocal formatoptions+=ro
	let &l:keywordprg = g:erlang_keywordprg
endfunction

function GetErlangFold(lnum)
	let lnum = a:lnum
	let line = getline(lnum)

	if line =~ s:erlang_fun_end
		return '<1'
	endif

	if line =~ s:erlang_fun_begin && foldlevel(lnum - 1) == 1
		return '1'
	endif

	if line =~ s:erlang_fun_begin
		return '>1'
	endif

	return '='
endfunction

function ErlangFoldText()
	let line    = getline(v:foldstart)
	let foldlen = v:foldend - v:foldstart + 1
	let lines   = ' ' . foldlen . ' lines: ' . substitute(line, "[\ \t]*", '', '')
	if foldlen < 10
		let lines = ' ' . lines
	endif
	let retval = '+' . v:folddashes . lines

	return retval
endfunction

call s:SetErlangOptions()

let b:undo_ftplugin = "setlocal foldmethod< foldexpr< foldtext<"
	\ . " comments< commentstring< formatoptions<"

let &cpo = s:cpo_save
unlet s:cpo_save
