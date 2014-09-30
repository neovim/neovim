" Vim filetype plugin file
" Language:	cobol
" Author:	Tim Pope <vimNOSPAM@tpope.info>
" Last Update:	By ZyX: use shiftwidth()

" Insert mode mappings: <C-T> <C-D> <Tab>
" Normal mode mappings: < > << >> [[ ]] [] ][
" Visual mode mappings: < >

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal commentstring=\ \ \ \ \ \ *%s
setlocal comments=:*
setlocal fo+=croqlt
setlocal expandtab
setlocal textwidth=72

" matchit support
if exists("loaded_matchit")
    let s:ordot = '\|\ze\.\%( \@=\|$\)'
    let b:match_ignorecase=1
    "let b:match_skip = 'getline(".") =~ "^.\\{6\\}[*/C]"'
    let b:match_words=
    \ '\$if\>:$else\>:\$endif\>,' .
    \ '[$-]\@<!\<if\>:\<\%(then\|else\)\>:\<end-if\>'.s:ordot.',' .
    \ '-\@<!\<perform\s\+\%(\d\+\s\+times\|until\|varying\|with\s\+test\)\>:\<end-perform\>'.s:ordot . ',' .
    \ '-\@<!\<\%(search\|evaluate\)\>:\<\%(when\)\>:\<end-\%(search\|evaluate\)\>' .s:ordot . ',' .
    \ '-\@<!\<\%(add\|compute\|divide\|multiply\|subtract\)\>\%(.*\(\%$\|\%(\n\%(\%(\s*\|.\{6\}\)[*/].*\n\)*\)\=\s*\%(not\s\+\)\=on\s\+size\s\+error\>\)\)\@=:\%(\<not\s\+\)\@<!\<\%(not\s\+\)\=on\s\+size\s\+error\>:\<end-\%(add\|compute\|divide\|multiply\|subtract\)\>' .s:ordot . ',' .
    \ '-\@<!\<\%(string\|unstring\|accept\|display\|call\)\>\%(.*\(\%$\|\%(\n\%(\%(\s*\|.\{6\}\)[*/].*\n\)*\)\=\s*\%(not\s\+\)\=on\s\+\%(overflow\|exception\)\>\)\)\@=:\%(\<not\s\+\)\@<!\<\%(not\s\+\)\=on\s\+\%(overflow\|exception\)\>:\<end-\%(string\|unstring\|accept\|display\|call\)\>' .s:ordot . ',' .
    \ '-\@<!\<\%(delete\|rewrite\|start\|write\|read\)\>\%(.*\(\%$\|\%(\n\%(\%(\s*\|.\{6\}\)[*/].*\n\)*\)\=\s*\%(invalid\s\+key\|at\s\+end\|no\s\+data\|at\s\+end-of-page\)\>\)\)\@=:\%(\<not\s\+\)\@<!\<\%(not\s\+\)\=\%(invalid\s\+key\|at\s\+end\|no\s\+data\|at\s\+end-of-page\)\>:\<end-\%(delete\|rewrite\|start\|write\|read\)\>' .s:ordot
endif

if has("gui_win32") && !exists("b:browsefilter")
  let b:browsefilter = "COBOL Source Files (*.cbl, *.cob)\t*.cbl;*.cob;*.lib\n".
		     \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setlocal com< cms< fo< et< tw<" .
            \ " | unlet! b:browsefilter b:match_words b:match_ignorecase b:match_skip"
if !exists("g:no_plugin_maps") && !exists("g:no_cobol_maps")
    let b:undo_ftplugin = b:undo_ftplugin .
            \ " | sil! exe 'nunmap <buffer> <'" .
            \ " | sil! exe 'nunmap <buffer> >'" .
            \ " | sil! exe 'nunmap <buffer> <<'" .
            \ " | sil! exe 'nunmap <buffer> >>'" .
            \ " | sil! exe 'vunmap <buffer> <'" .
            \ " | sil! exe 'vunmap <buffer> >'" .
            \ " | sil! exe 'iunmap <buffer> <C-D>'" .
            \ " | sil! exe 'iunmap <buffer> <C-T>'" .
            \ " | sil! exe 'iunmap <buffer> <Tab>'" .
            \ " | sil! exe 'nunmap <buffer> <Plug>Traditional'" .
            \ " | sil! exe 'nunmap <buffer> <Plug>Comment'" .
            \ " | sil! exe 'nunmap <buffer> <Plug>DeComment'" .
            \ " | sil! exe 'vunmap <buffer> <Plug>VisualTraditional'" .
            \ " | sil! exe 'vunmap <buffer> <Plug>VisualComment'" .
            \ " | sil! exe 'iunmap <buffer> <Plug>VisualDeComment'" .
            \ " | sil! exe 'unmap  <buffer> [['" .
            \ " | sil! exe 'unmap  <buffer> ]]'" .
            \ " | sil! exe 'unmap  <buffer> []'" .
            \ " | sil! exe 'unmap  <buffer> ]['"
endif

if !exists("g:no_plugin_maps") && !exists("g:no_cobol_maps")
    if version >= 700
        nnoremap <silent> <buffer> > :set opfunc=<SID>IncreaseFunc<CR>g@
        nnoremap <silent> <buffer> < :set opfunc=<SID>DecreaseFunc<CR>g@
    endif
    nnoremap <silent> <buffer> >> :call CobolIndentBlock(1)<CR>
    nnoremap <silent> <buffer> << :call CobolIndentBlock(-1)<CR>
    vnoremap <silent> <buffer> > :call CobolIndentBlock(v:count1)<CR>
    vnoremap <silent> <buffer> < :call CobolIndentBlock(-v:count1)<CR>
    inoremap <silent> <buffer> <C-T> <C-R>=<SID>IncreaseIndent()<CR><C-R>=<SID>RestoreShiftwidth()<CR>
    inoremap <silent> <buffer> <C-D> <C-R>=<SID>DecreaseIndent()<CR><C-R>=<SID>RestoreShiftwidth()<CR>
    if !maparg("<Tab>","i")
        inoremap <silent> <buffer> <Tab> <C-R>=<SID>Tab()<CR><C-R>=<SID>RestoreShiftwidth()<CR>
    endif
    noremap <silent> <buffer> [[ m':call search('\c^\%(\s*\<Bar>.\{6\}\s\+\)\zs[A-Za-z0-9-]\+\s\+\%(division\<Bar>section\)\s*\.','bW')<CR>
    noremap <silent> <buffer> ]] m':call search('\c^\%(\s*\<Bar>.\{6\}\s\+\)\zs[A-Za-z0-9-]\+\s\+\%(division\<Bar>section\)\.','W')<CR>
    noremap <silent> <buffer> [] m':call <SID>toend('b')<CR>
    noremap <silent> <buffer> ][ m':call <SID>toend('')<CR>
    " For EnhancedCommentify
    noremap <silent> <buffer> <Plug>Traditional      :call <SID>Comment('t')<CR>
    noremap <silent> <buffer> <Plug>Comment          :call <SID>Comment('c')<CR>
    noremap <silent> <buffer> <Plug>DeComment        :call <SID>Comment('u')<CR>
    noremap <silent> <buffer> <Plug>VisualTraditional :'<,'>call <SID>Comment('t')<CR>
    noremap <silent> <buffer> <Plug>VisualComment     :'<,'>call <SID>Comment('c')<CR>
    noremap <silent> <buffer> <Plug>VisualDeComment   :'<,'>call <SID>Comment('u')<CR>
endif

let &cpo = s:cpo_save
unlet s:cpo_save

if exists("g:did_cobol_ftplugin_functions")
    finish
endif
let g:did_cobol_ftplugin_functions = 1

function! s:repeat(str,count)
    let i = 0
    let ret = ""
    while i < a:count
        let ret = ret . a:str
        let i = i + 1
    endwhile
    return ret
endfunction

function! s:increase(...)
    let lnum = '.'
    let sw = shiftwidth()
    let i = a:0 ? a:1 : indent(lnum)
    if i >= 11
        return sw - (i - 11) % sw
    elseif i >= 7
        return 11-i
    elseif i == 6
        return 1
    else
        return 6-i
    endif
endfunction

function! s:decrease(...)
    let lnum = '.'
    let sw = shiftwidth()
    let i = indent(a:0 ? a:1 : lnum)
    if i >= 11 + sw
        return 1 + (i + 12) % sw
    elseif i > 11
        return i-11
    elseif i > 7
        return i-7
    elseif i == 7
        return 1
    else
        return i
    endif
endfunction

function! CobolIndentBlock(shift)
    let head = strpart(getline('.'),0,7)
    let tail = strpart(getline('.'),7)
    let indent = match(tail,'[^ ]')
    let sw = shiftwidth()
    let shift = a:shift
    if shift > 0
        if indent < 4
            let tail = s:repeat(" ",4-indent).tail
            let shift = shift - 1
        endif
        let tail = s:repeat(" ",shift*sw).tail
        let shift = 0
    elseif shift < 0
        if (indent-4) > -shift * sw
            let tail = strpart(tail,-shift * sw)
        elseif (indent-4) > (-shift-1) * sw
            let tail = strpart(tail,indent - 4)
        else
            let tail = strpart(tail,indent)
        endif
    endif
    call setline('.',head.tail)
endfunction

function! s:IncreaseFunc(type)
    '[,']call CobolIndentBlock(1)
endfunction

function! s:DecreaseFunc(type)
    '[,']call CobolIndentBlock(-1)
endfunction

function! s:IncreaseIndent()
    let c = "\<C-T>"
    if exists("*InsertCtrlTWrapper")
        let key = InsertCtrlTWrapper()
        if key != c
            return key
        endif
    endif
    let interval = s:increase()
    let b:cobol_shiftwidth = &shiftwidth
    let &shiftwidth = 1
    let lastchar = strpart(getline('.'),col('.')-2,1)
    if lastchar == '0' || lastchar == '^'
        return "\<BS>".lastchar.c
    else
        return s:repeat(c,interval)
    endif
endfunction

function! s:DecreaseIndent()
    let c = "\<C-D>"
    if exists("*InsertCtrlDWrapper")
        " I hack Ctrl-D to delete when not at the end of the line.
        let key = InsertCtrlDWrapper()
        if key != c
            return key
        endif
    endif
    let interval = s:decrease()
    let b:cobol_shiftwidth = &shiftwidth
    let &shiftwidth = 1
    return s:repeat(c,interval)
endfunction

function! s:RestoreShiftwidth()
    if exists("b:cobol_shiftwidth")
        let &shiftwidth=b:cobol_shiftwidth
        unlet b:cobol_shiftwidth
    endif
    return ""
endfunction

function! s:Tab()
    if (strpart(getline('.'),0,col('.')-1) =~ '^\s*$' && &sta)
        return s:IncreaseIndent()
    " &softtabstop < 0: &softtabstop follows &shiftwidth
    elseif (&sts < 0 || &sts == shiftwidth()) && &sts != 8 && &et
        return s:repeat(" ",s:increase(col('.')-1))
    else
        return "\<Tab>"
    endif
endfunction

function! s:Comment(arg)
    " For EnhancedCommentify
    let line = getline('.')
    if (line =~ '^.\{6\}[*/C]' || a:arg == 'c') && a:arg != 'u'
        let line = substitute(line,'^.\{6\}\zs.',' ','')
    else
        let line = substitute(line,'^.\{6\}\zs.','*','')
    endif
    call setline('.',line)
endfunction

function! s:toend(direction)
    let ignore = '^\(\s*\|.\{6\}\)\%([*/]\|\s*$\)'
    let keep = line('.')
    keepjumps +
    while line('.') < line('$') && getline('.') =~ ignore
        keepjumps +
    endwhile
    let res = search('\c^\%(\s*\|.\{6\}\s\+\)\zs[A-Za-z0-9-]\+\s\+\%(division\|section\)\s*\.',a:direction.'W')
    if a:direction != 'b' && !res
        let res = line('$')
        keepjumps $
    elseif res
        keepjumps -
    endif
    if res
        while line('.') > 1 && getline('.') =~ ignore
            keepjumps -
        endwhile
        if line('.') == 1 && getline('.') =~ ignore
            exe "keepjumps ".keep
        endif
    else
        exe "keepjumps ".keep
    endif
endfunction
