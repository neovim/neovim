" Vim filetype plugin file
" Language:             Zsh shell script
" Maintainer:           Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2023-10-07
" License:              Vim (see :h license)
" Repository:           https://github.com/chrisbra/vim-zsh

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:# commentstring=#\ %s formatoptions-=t formatoptions+=croql

let b:undo_ftplugin = "setl com< cms< fo< "

if executable('zsh') && &shell !~# '/\%(nologin\|false\)$'
  if !has('gui_running') && executable('less')
    command! -buffer -nargs=1 ZshKeywordPrg silent exe '!MANPAGER= zsh -c "autoload -Uz run-help; run-help <args> 2>/dev/null | LESS= less"' | redraw!
  elseif has('terminal')
    command! -buffer -nargs=1 ZshKeywordPrg silent exe ':term zsh -c "autoload -Uz run-help; run-help <args>"'
  else
    command! -buffer -nargs=1 ZshKeywordPrg echo system('zsh -c "autoload -Uz run-help; run-help <args> 2>/dev/null"')
  endif
  if !exists('current_compiler')
    compiler zsh
  endif
  setlocal keywordprg=:ZshKeywordPrg
  let b:undo_ftplugin .= 'keywordprg< | sil! delc -buffer ZshKeywordPrg'
endif

let b:match_words = '\<if\>:\<elif\>:\<else\>:\<fi\>'
      \ . ',\<case\>:^\s*([^)]*):\<esac\>'
      \ . ',\<\%(select\|while\|until\|repeat\|for\%(each\)\=\)\>:\<done\>'
let b:match_skip = 's:comment\|string\|heredoc\|subst'

let &cpo = s:cpo_save
unlet s:cpo_save
