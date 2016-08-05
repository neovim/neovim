" Vim filetype plugin file
" Language:         Vim help file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2008-07-09

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl fo< tw< cole< cocu<"

setlocal formatoptions+=tcroql textwidth=78
if has("conceal")
  setlocal cole=2 cocu=nc
endif

function! s:create_toc() abort
  if !exists('b:help_toc')
    let b:help_toc = []
    let lnum = 1
    let last_line = line('$')
    let last_added = 0

    while lnum <= last_line
      let add_text = ''
      let text = getline(lnum)

      if text =~# '^=\+$'
        let text = getline(lnum + 1)
        if text =~# '\*[^*]\+\*'
          let lnum += 1
          let add_text = matchstr(text, '.\{-}\ze\s*\*')
        endif
      elseif text =~# '^[A-Z][-A-Z .][-A-Z0-9 .()]*[ \t]\+\*'
        let add_text = matchstr(text, '.\{-}\ze\s*\*')
      elseif text =~# '^\u.*\s\+\~$'
        let add_text = matchstr(text, '.\{-}\ze\s\+\~$')
      elseif lnum == 1
        let add_text = text
      endif

      if !empty(add_text) && last_added != lnum
        let last_added = lnum
        call add(b:help_toc, {'bufnr': bufnr('%'), 'lnum': lnum,
              \ 'filename': 'butt.txt',
              \ 'text': substitute(add_text, '\s\+', ' ', 'g')})
      endif
      let lnum += 1
    endwhile
  endif

  call setloclist(0, b:help_toc, ' ', 'Help TOC')
endfunction

autocmd BufWinEnter <buffer> call s:create_toc()

let &cpo = s:cpo_save
unlet s:cpo_save
