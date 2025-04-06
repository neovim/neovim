" Vim indent file
" Language:		C-shell (tcsh)
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Gautam Iyer <gi1242+vim@NoSpam.com> where NoSpam=gmail (Original Author)
" Last Change:		2021 Oct 15

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
    finish
endif

let b:did_indent = 1

setlocal indentexpr=TcshGetIndent()
setlocal indentkeys+=e,0=end
setlocal indentkeys-=0{,0},0),:,0#

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

    " Subtract indent if current line has on end, endif, endsw, case commands
    let line = getline(v:lnum)
    if line =~ '\v^\s*%(else|end|endif|endsw)\s*$'
	let ind = ind - shiftwidth()
    endif

    return ind
endfunction
