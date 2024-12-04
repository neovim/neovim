" Vim filetype plugin file.
" Language:		Lua
" Maintainer:		Doug Kearns <dougkearns@gmail.com>
" Previous Maintainer:	Max Ischenko <mfi@ukr.net>
" Contributor:		Dorai Sitaram <ds26@gte.com>
"			C.D. MacEachern <craig.daniel.maceachern@gmail.com>
"			Tyler Miller <tmillr@proton.me>
" Last Change:		2024 Dec 03

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:---,:--
setlocal commentstring=--\ %s
setlocal formatoptions-=t formatoptions+=croql

let &l:define = '\<function\|\<local\%(\s\+function\)\='

" TODO: handle init.lua
setlocal includeexpr=tr(v:fname,'.','/')
setlocal suffixesadd=.lua

let b:undo_ftplugin = "setlocal cms< com< def< fo< inex< sua<"

if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0
  let b:match_words =
	\ '\<\%(do\|function\|if\)\>:' ..
	\ '\<\%(return\|else\|elseif\)\>:' ..
	\ '\<end\>,' ..
	\ '\<repeat\>:\<until\>,' ..
	\ '\%(--\)\=\[\(=*\)\[:]\1]'
  let b:undo_ftplugin ..= " | unlet! b:match_words b:match_ignorecase"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Lua Source Files (*.lua)\t*.lua\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif

if has("folding") && get(g:, "lua_folding", 0)
  setlocal foldmethod=expr
  setlocal foldexpr=LuaFold(v:lnum)
  let b:lua_lasttick = -1
  let b:undo_ftplugin ..= "|setl foldexpr< foldmethod< | unlet! b:lua_lasttick b:lua_foldlists"
endif


" The rest of the file needs to be :sourced only once per Vim session
if exists('s:loaded_lua') || &cp
  let &cpo = s:cpo_save
  unlet s:cpo_save
  finish
endif
let s:loaded_lua = 1

let s:patterns = [
      \ ['do', 'end'],
      \ ['if\s+.+\s+then', 'end'],
      \ ['repeat', 'until\s+.+'],
      \ ['for\s+.+\s+do', 'end'],
      \ ['while\s+.+\s+do', 'end'],
      \ ['function.+', 'end'],
      \ ['return\s+function.+', 'end'],
      \ ['local\s+function\s+.+', 'end'],
      \ ]

function! LuaFold(lnum) abort
  if b:lua_lasttick == b:changedtick
    return b:lua_foldlists[a:lnum-1]
  endif
  let b:lua_lasttick = b:changedtick

  let b:lua_foldlists = []
  let foldlist = []
  let buf = getline(1, '$')
  for line in buf
    for t in s:patterns
      let tagopen = '\v^\s*'..t[0]..'\s*$'
      let tagclose = '\v^\s*'..t[1]..'\s*$'
      if line =~# tagopen
        call add(foldlist, t)
        break
      elseif line =~# tagclose
        if len(foldlist) > 0 && line =~# foldlist[-1][1]
          call remove(foldlist, -1)
        else
          let foldlist = []
        endif
        break
      endif
    endfor
    call add(b:lua_foldlists, len(foldlist))
  endfor

  return lua_foldlists[a:lnum-1]
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: nowrap sw=2 sts=2 ts=8 noet:
