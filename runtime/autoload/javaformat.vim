" Vim formatting plugin file
" Language:		Java
" Maintainer:		Aliaksei Budavei <0x000c70 AT gmail DOT com>
" Repository:		https://github.com/zzzyxwvut/java-vim.git
" Last Change:		2024 Sep 26

" Documented in ":help ft-java-plugin".
if &cp || exists("g:loaded_javaformat") || exists("g:java_ignore_javadoc") || exists("g:java_ignore_markdown")
    finish
endif

let g:loaded_javaformat = 1

"""" STRIVE TO REMAIN COMPATIBLE FOR AT LEAST VIM 7.0.

function! javaformat#RemoveCommonMarkdownWhitespace() abort
    if mode() != 'n'
	return 0
    endif

    let pattern = '\(^\s*///\)\(\s*\)\(.*\)'

    " E121 for v:numbermax before v8.2.2388.
    " E15 for expr-<< before v8.2.5003.
    let common = 0x7fffffff
    let comments = []

    for n in range(v:lnum, (v:lnum + v:count - 1))
	let parts = matchlist(getline(n), pattern)
	let whitespace = get(parts, 2, '')
	let nonwhitespace = get(parts, 3, '')

	if !empty(whitespace)
	    let common = min([common, strlen(whitespace)])
	elseif !empty(nonwhitespace) || empty(parts)
	    " No whitespace prefix or not a Markdown comment.
	    return 0
	endif

	call add(comments, [whitespace, parts[1], nonwhitespace])
    endfor

    let cursor = v:lnum

    for line in comments
	call setline(cursor, join(line[1 :], strpart(line[0], common)))
	let cursor += 1
    endfor

    return 0
endfunction

" See ":help vim9-mix".
if !has("vim9script")
    finish
endif

def! g:javaformat#RemoveCommonMarkdownWhitespace(): number
    if mode() != 'n'
	return 0
    endif

    const pattern: string = '\(^\s*///\)\(\s*\)\(.*\)'
    var common: number = v:numbermax
    var comments: list<list<string>> = []

    for n in range(v:lnum, (v:lnum + v:count - 1))
	const parts: list<string> = matchlist(getline(n), pattern)
	const whitespace: string = get(parts, 2, '')
	const nonwhitespace: string = get(parts, 3, '')

	if !empty(whitespace)
	    common = min([common, strlen(whitespace)])
	elseif !empty(nonwhitespace) || empty(parts)
	    # No whitespace prefix or not a Markdown comment.
	    return 0
	endif

	add(comments, [whitespace, parts[1], nonwhitespace])
    endfor

    var cursor: number = v:lnum

    for line in comments
	setline(cursor, join(line[1 :], strpart(line[0], common)))
	cursor += 1
    endfor

    return 0
enddef

" vim: fdm=syntax sw=4 ts=8 noet sta
