" Vim indent file
" Language:		C-shell (tcsh)
" Maintainer:		Doug Kearns <a@b.com> where a=dougkearns, b=gmail
" Last Modified:	Sun 26 Sep 2021 12:38:38 PM EDT

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif

let b:did_indent = 1

setlocal indentexpr=TcshGetIndent()
setlocal indentkeys+=e,0=end,0=endsw indentkeys-=0{,0},0),:,0#
let b:undo_indent = "setl inde< indk<"

" Only define the function once.
if exists("*TcshGetIndent")
    finish
endif

function TcshGetIndent()
    " Find a non-blank line above the current line.
    let lnum = prevnonblank(v:lnum - 1)

    " Hit the start of the file, use zero indent.
    if lnum == 0
	return 0
    endif

    " Add indent if previous line begins with while or foreach
    " OR line ends with case <str>:, default:, else, then or \
    let ind = indent(lnum)
    let line = getline(lnum)
    if line =~ '\v^\s*%(while|foreach)>|^\s*%(case\s.*:|default:|else)\s*$|%(<then|\\)$'
	let ind = ind + shiftwidth()
    endif

    if line =~ '\v^\s*breaksw>'
	let ind = ind - shiftwidth()
    endif

    " Subtract indent if current line has on end, endif, case commands
    let line = getline(v:lnum)
    if line =~ '\v^\s*%(else|end|endif)\s*$'
	let ind = ind - shiftwidth()
    endif

    return ind
endfunction
