" Vim filetype plugin file
" Language:	PDF
" Maintainer:	Tim Pope <vimNOSPAM@tpope.info>
" Last Change:	2007 Dec 16
" 		2024 May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

setlocal commentstring=%\ %s
setlocal comments=:%
let b:undo_ftplugin = "setlocal cms< com< | unlet! b:match_words"

if exists("g:loaded_matchit")
    let b:match_words = '\<\%(\d\+\s\+\d\+\s\+\)obj\>:\<endobj\>,\<stream$:\<endstream\>,\<xref\>:\<trailer\>,<<:>>'
endif

if exists("g:no_plugin_maps") || exists("g:no_pdf_maps") || v:version < 700
    finish
endif

if !exists("b:pdf_tagstack")
    let b:pdf_tagstack = []
endif

let b:undo_ftplugin .= " | silent! nunmap <buffer> <C-]> | silent! nunmap <buffer> <C-T>"
nnoremap <silent><buffer> <C-]> :call <SID>Tag()<CR>
" Inline, so the error from an empty tag stack will be simple.
nnoremap <silent><buffer> <C-T> :if len(b:pdf_tagstack) > 0 <Bar> call setpos('.',remove(b:pdf_tagstack, -1)) <Bar> else <Bar> exe "norm! \<Lt>C-T>" <Bar> endif<CR>

function! s:Tag()
    call add(b:pdf_tagstack,getpos('.'))
    if getline('.') =~ '^\d\+$' && getline(line('.')-1) == 'startxref'
	return s:dodigits(getline('.'))
    elseif getline('.') =~ '/Prev\s\+\d\+\>\%(\s\+\d\)\@!' && expand("<cword>") =~ '^\d\+$'
	return s:dodigits(expand("<cword>"))
    elseif getline('.') =~ '^\d\{10\} \d\{5\} '
	return s:dodigits(matchstr(getline('.'),'^\d\+'))
    else
	let line = getline(".")
	let lastend = 0
	let pat = '\<\d\+\s\+\d\+\s\+R\>'
	while lastend >= 0
	    let beg = match(line,'\C'.pat,lastend)
	    let end = matchend(line,'\C'.pat,lastend)
	    if beg < col(".") && end >= col(".")
		return s:doobject(matchstr(line,'\C'.pat,lastend))
	    endif
	    let lastend = end
	endwhile
	return s:notag()
    endif
endfunction

function! s:doobject(string)
    let first = matchstr(a:string,'^\s*\zs\d\+')
    let second = matchstr(a:string,'^\s*\d\+\s\+\zs\d\+')
    norm! m'
    if first != '' && second != ''
	let oldline = line('.')
	let oldcol = col('.')
	1
	if !search('^\s*'.first.'\s\+'.second.'\s\+obj\>')
	    exe oldline
	    exe 'norm! '.oldcol.'|'
	    return s:notag()
	endif
    endif
endfunction

function! s:dodigits(digits)
    let digits = 0 + substitute(a:digits,'^0*','','')
    norm! m'
    if digits <= 0
	norm! 1go
    else
	" Go one character before the destination and advance.  This method
	" lands us after a newline rather than before, if that is our target.
	exe "goto ".(digits)."|norm! 1 "
    endif
endfunction

function! s:notag()
    silent! call remove(b:pdf_tagstack,-1)
    echohl ErrorMsg
    echo "E426: tag not found"
    echohl NONE
endfunction
