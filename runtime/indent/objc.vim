"   Vim indent file
"   Language:	    Objective-C
"   Maintainer:	    Kazunobu Kuriyama <kazunobu.kuriyama@nifty.com>
"   Last Change:    2004 May 16
"


" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif
let b:did_indent = 1
setlocal cindent

" Set the function to do the work.
setlocal indentexpr=GetObjCIndent()

" To make a colon (:) suggest an indentation other than a goto/switch label,
setlocal indentkeys-=:
setlocal indentkeys+=<:>

" Only define the function once.
if exists("*GetObjCIndent")
    finish
endif

function s:GetWidth(line, regexp)
    let end = matchend(a:line, a:regexp)
    let width = 0
    let i = 0
    while i < end
	if a:line[i] != "\t"
	    let width = width + 1
	else
	    let width = width + &ts - (width % &ts)
	endif
	let i = i + 1
    endwhile
    return width
endfunction

function s:LeadingWhiteSpace(line)
    let end = strlen(a:line)
    let width = 0
    let i = 0
    while i < end
	let char = a:line[i]
	if char != " " && char != "\t"
	    break
	endif
	if char != "\t"
	    let width = width + 1
	else
	    let width = width + &ts - (width % &ts)
	endif
	let i = i + 1
    endwhile
    return width
endfunction


function GetObjCIndent()
    let theIndent = cindent(v:lnum)

    let prev_line = getline(v:lnum - 1)
    let cur_line = getline(v:lnum)

    if prev_line !~# ":" || cur_line !~# ":"
	return theIndent
    endif

    if prev_line !~# ";"
	let prev_colon_pos = s:GetWidth(prev_line, ":")
	let delta = s:GetWidth(cur_line, ":") - s:LeadingWhiteSpace(cur_line)
	let theIndent = prev_colon_pos - delta
    endif

    return theIndent
endfunction
