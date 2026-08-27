" Vim filetype plugin file
" Language:     Luau
" Maintainer:   Lopy (@lopi-py)
" Last Change:  2026 Jun 16

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:---,:--
setlocal commentstring=--\ %s
setlocal formatoptions-=t formatoptions+=croql

let &l:define = '\<\%(function\|local\%(\s\+function\)\=\|const\%(\s\+function\)\=\|type\%(\s\+function\)\=\|export\s\+type\%(\s\+function\)\=\|class\|declare\s\+\%(function\|class\|extern\s\+type\)\)\>'
let &l:include = '\<require\s*('
setlocal includeexpr=s:LuauInclude(v:fname)
setlocal suffixesadd=.luau,.lua

let b:undo_ftplugin = "setl cms< com< def< fo< inc< inex< sua<"

let s:attr = '@\%(\h\w*\|\[[^]]*\]\)\s*'
let s:line_end = '\s*\%(--.*\)\=$'
let s:end_pat = '^\s*end\>' .. s:line_end
let s:end_block = '^\s*\%(' .. s:attr .. '\)*if\>.\{-}\<then\>' ..
      \ '\|^\s*\%(' .. s:attr .. '\)*class\>\s\+\h' ..
      \ '\|^\s*\%(' .. s:attr .. '\)*declare\s\+class\>\s\+\h' ..
      \ '\|^\s*\%(' .. s:attr .. '\)*declare\s\+extern\s\+type\>.\{-}\<with\>' .. s:line_end

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  let s:match_tail = ':\<return\>\|^\s*\%(else\|elseif\)\>:' .. s:end_pat ..
        \ ',^\s*repeat\>:\<until\>,' ..
        \ '\%(--\)\=\[\(=*\)\[:\]\1\]'
  let s:match_words = '\<\%(do\|function\)\>\|' .. s:end_block .. s:match_tail
  let s:match_words_no_function = '\<do\>\|' .. s:end_block .. s:match_tail
  let b:match_words = "LuauMatchWords()"
  let b:match_skip = 'LuauMatchSkip()'
  let b:undo_ftplugin ..= " | unlet! b:match_words b:match_ignorecase b:match_skip"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Luau Source Files (*.luau)\t*.luau\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

if has("folding") && get(g:, "luau_folding", 0)
  setlocal foldmethod=expr
  setlocal foldexpr=s:LuauFold()
  let b:luau_lasttick = -1
  let b:undo_ftplugin ..= " | setl foldexpr< foldmethod< | unlet! b:luau_lasttick b:luau_foldlists"
endif

" the rest of the file needs to be sourced only once per Vim session
if exists("s:loaded_luau") || &cp
  let &cpo = s:cpo_save
  unlet s:cpo_save
  finish
endif
let s:loaded_luau = 1

function s:LuauInclude(fname) abort
  let fname = a:fname
  if fname =~# '^@'
    return fname
  endif
  for path in [fname, fname .. ".luau", fname .. ".lua", fname .. "/init.luau", fname .. "/init.lua"]
    if filereadable(path)
      return path
    endif
  endfor
  return fname
endfunction

function s:IsStringOrComment(lnum, col) abort
  let name = synIDattr(synID(a:lnum, a:col, 1), "name")
  return name =~# '^luau\%(Comment\|.*String\)'
endfunction

function s:LineCommentStart(lnum) abort
  let line = getline(a:lnum)
  let midx = stridx(line, '--')
  while midx != -1
    if !s:IsStringOrComment(a:lnum, midx + 1)
      return midx
    endif
    let midx = stridx(line, '--', midx + 2)
  endwhile
  return -1
endfunction

function s:InDeclareClass(lnum) abort
  let save_cursor = getcurpos()
  call cursor(a:lnum - 1, 1)
  let lnum = search('^\s*\%(end\>\|declare\s\+class\>\)', 'bcnW')
  call setpos('.', save_cursor)
  return lnum > 0 && getline(lnum) =~# '^\s*declare\s\+class\>'
endfunction

function LuauMatchSkip() abort
  let lnum = line(".")
  let col = col(".")
  let comment = s:LineCommentStart(lnum)
  return s:IsStringOrComment(lnum, col)
        \ || (comment != -1 && col > comment)
        \ || (expand("<cword>") ==# "function" && s:InDeclareClass(lnum))
endfunction

function LuauMatchWords() abort
  if exists("s:match_words_no_function")
        \ && expand("<cword>") ==# "function" && s:InDeclareClass(line("."))
    return s:match_words_no_function
  endif
  return get(s:, "match_words", "")
endfunction

let s:fold_guard = '^\s*\%(@\|\%(do\|if\|repeat\|for\|while\|public' ..
      \ '\|function\|return\|local\|const\|type\|export\|class' ..
      \ '\|declare\|end\|until\)\>\)'

let s:patterns = [
      \ ['^\s*do\>' .. s:line_end, s:end_pat, 'block'],
      \ ['^\s*if\>.\{-}\<then\>' .. s:line_end, s:end_pat, 'block'],
      \ ['^\s*repeat\>' .. s:line_end, '^\s*until\>.*', 'block'],
      \ ['^\s*for\>.\{-}\<do\>' .. s:line_end, s:end_pat, 'block'],
      \ ['^\s*while\>.\{-}\<do\>' .. s:line_end, s:end_pat, 'block'],
      \ ['^\s*\%(' .. s:attr .. '\)*\%(public\s\+\)\=function\>.*', s:end_pat, 'function'],
      \ ['^\s*return\s\+function\>.*', s:end_pat, 'function'],
      \ ['^\s*\%(' .. s:attr .. '\)*local\s\+function\>.*', s:end_pat, 'function'],
      \ ['^\s*\%(' .. s:attr .. '\)*const\s\+function\>.*', s:end_pat, 'function'],
      \ ['^\s*\%(' .. s:attr .. '\)*\%(export\s\+\)\=type\s\+function\>.*', s:end_pat, 'function'],
      \ ['^\s*class\>\s\+\h.*', s:end_pat, 'class'],
      \ ['^\s*declare\s\+class\>\s\+\h.*', s:end_pat, 'declare_class'],
      \ ['^\s*declare\s\+extern\s\+type\>.\{-}\<with\>' .. s:line_end, s:end_pat, 'block'],
      \ ]

function s:LuauFold() abort
  if b:luau_lasttick == b:changedtick
    return b:luau_foldlists[v:lnum - 1]
  endif
  let b:luau_lasttick = b:changedtick

  let b:luau_foldlists = []
  let foldlist = []
  let buf = getline(1, "$")
  for line in buf
    let open = 0
    let end = 0
    if line !~# s:fold_guard
      call add(b:luau_foldlists, "" .. len(foldlist))
      continue
    endif
    for t in s:patterns
      let tagopen = t[0]
      let tagend = t[1]
      if line =~# tagopen
        if t[2] ==# 'function' && len(foldlist) > 0 && foldlist[-1][2] ==# 'declare_class'
          continue
        endif
        call add(foldlist, t)
        let open = 1
        break
      elseif line =~# tagend
        if len(foldlist) > 0 && line =~# foldlist[-1][1]
          call remove(foldlist, -1)
          let end = 1
        else
          let foldlist = []
        endif
        break
      endif
    endfor
    let prefix = ""
    if open == 1 | let prefix = ">" | endif
    if end == 1 | let prefix = "<" | endif
    call add(b:luau_foldlists, prefix .. (len(foldlist) + end))
  endfor

  return b:luau_foldlists[v:lnum - 1]
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
