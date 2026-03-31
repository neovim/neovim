" Vim filetype plugin
" Language:	Eiffel
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2024 Jan 14

if (exists("b:did_ftplugin"))
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:--
setlocal commentstring=--\ %s

setlocal formatoptions-=t formatoptions+=croql

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Eiffel Source Files (*.e)\t*.e\n" .
		     \ "Eiffel Control Files (*.ecf, *.ace, *.xace)\t*.ecf;*.ace;*.xace\n"
  if has("win32")
    let b:browsefilter .= "All Files (*.*)\t*\n"
  else
    let b:browsefilter .= "All Files (*)\t*\n"
  endif
endif

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  " Silly \%^ trick to match note at head of pair and in middle prevents
  " 'g%' wrapping from 'note' to 'end'
  let b:match_words = '\%^:' .
		  \	'\<\%(^note\|indexing\|class\|^obsolete\|inherit\|insert\|^create\|convert\|feature\|^invariant\)\>:' .
		  \   '^end\>,' .
		  \   '\<\%(do\|deferred\|external\|once\%(\s\+"\)\@!\|check\|debug\|if\|inspect\|from\|across\)\>:' .
		  \	'\%(\%(^\s\+\)\@<=\%(then\|until\|loop\)\|\%(then\|until\|loop\)\s\+[^ -]\|' .
		  \	'\<\%(ensure\%(\s\+then\)\=\|rescue\|_then\|elseif\|else\|when\|\s\@<=invariant\|_until\|_loop\|variant\|_as\|alias\)\>\):' .
		  \   '\s\@<=end\>'
  let b:match_skip = 's:\<eiffel\%(Comment\|String\|Operator\)\>'
  noremap  [% <Nop>
  noremap  ]% <Nop>
  vnoremap a% <Nop>
endif

let b:undo_ftplugin = "setl fo< com< cms<" .
  \ "| unlet! b:browsefilter b:match_ignorecase b:match_words b:match_skip"

if !exists("g:no_plugin_maps") && !exists("g:no_eiffel_maps")
  function! s:DoMotion(pattern, count, flags) abort
    normal! m'
    for i in range(a:count)
      call search(a:pattern, a:flags)
    endfor
  endfunction

  let sections = '^\%(note\|indexing\|' .
	     \	 '\%(\%(deferred\|expanded\|external\|frozen\)\s\+\)*class\|' .
	     \	 'obsolete\|inherit\|insert\|create\|convert\|feature\|' .
	     \	 'invariant\|end\)\>'

  nnoremap <silent> <buffer> ]] :<C-U>call <SID>DoMotion(sections, v:count1, 'W')<CR>
  xnoremap <silent> <buffer> ]] :<C-U>exe "normal! gv"<Bar>call <SID>DoMotion(sections, v:count1, 'W')<CR>
  nnoremap <silent> <buffer> [[ :<C-U>call <SID>DoMotion(sections, v:count1, 'Wb')<CR>
  xnoremap <silent> <buffer> [[ :<C-U>exe "normal! gv"<Bar>call <SID>DoMotion(sections, v:count1, 'Wb')<CR>

  function! s:DoFeatureMotion(count, flags)
    let view = winsaveview()
    call cursor(1, 1)
    let [features_start, _] = searchpos('^feature\>')
    call search('^\s\+\a') " find the first feature
    let spaces = indent(line('.'))
    let [features_end, _] = searchpos('^\%(invariant\|note\|end\)\>')
    call winrestview(view)
    call s:DoMotion('\%>' . features_start . 'l\%<' . features_end . 'l^\s*\%' . (spaces + 1) . 'v\zs\a', a:count, a:flags)
  endfunction

  nnoremap <silent> <buffer> ]m :<C-U>call <SID>DoFeatureMotion(v:count1, 'W')<CR>
  xnoremap <silent> <buffer> ]m :<C-U>exe "normal! gv"<Bar>call <SID>DoFeatureMotion(v:count1, 'W')<CR>
  nnoremap <silent> <buffer> [m :<C-U>call <SID>DoFeatureMotion(v:count1, 'Wb')<CR>
  xnoremap <silent> <buffer> [m :<C-U>exe "normal! gv"<Bar>call <SID>DoFeatureMotion(v:count1, 'Wb')<CR>

  let comment_block_start = '^\%(\s\+--.*\n\)\@<!\s\+--'
  let comment_block_end = '^\s\+--.*\n\%(\s\+--\)\@!'

  nnoremap <silent> <buffer> ]- :<C-U>call <SID>DoMotion(comment_block_start, 1, 'W')<CR>
  xnoremap <silent> <buffer> ]- :<C-U>exe "normal! gv"<Bar>call <SID>DoMotion(comment_block_start, 1, 'W')<CR>
  nnoremap <silent> <buffer> [- :<C-U>call <SID>DoMotion(comment_block_end, 1, 'Wb')<CR>
  xnoremap <silent> <buffer> [- :<C-U>exe "normal! gv"<Bar>call <SID>DoMotion(comment_block_end, 1, 'Wb')<CR>

  let b:undo_ftplugin = b:undo_ftplugin .
    \ "| silent! execute 'unmap <buffer> [[' | silent! execute 'unmap <buffer> ]]'" .
    \ "| silent! execute 'unmap <buffer> [m' | silent! execute 'unmap <buffer> ]m'" .
    \ "| silent! execute 'unmap <buffer> [-' | silent! execute 'unmap <buffer> ]-'"
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8
