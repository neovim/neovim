" Vim filetype plugin file
" Language:             Zsh shell script
" Maintainer:           Christian Brabandt <cb@256bit.org>
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se>
" Latest Revision:      2020-01-10
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

if executable('zsh')
 if !has('gui_running') && executable('less')
   command! -buffer -nargs=1 RunHelp silent exe '!zsh -ic "autoload -Uz run-help; run-help <args> 2>/dev/null | LESS= less"' | redraw!
 elseif has('terminal')
   command! -buffer -nargs=1 RunHelp silent exe ':term zsh -ic "autoload -Uz run-help; run-help <args>"'
 else
   command! -buffer -nargs=1 RunHelp echo system('zsh -ic "autoload -Uz run-help; run-help <args> 2>/dev/null"')
 endif
  setlocal keywordprg=:RunHelp
  setlocal makeprg=zsh\ -n\ --\ %:S
  setlocal errorformat=%f:\ line\ %l:\ %m
  let b:undo_ftplugin .= 'keywordprg< errorformat< makeprg<'
endif

let b:match_words = ',\<if\>:\<elif\>:\<else\>:\<fi\>'
      \ . ',\<case\>:^\s*([^)]*):\<esac\>'
      \ . ',\<\%(select\|while\|until\|repeat\|for\%(each\)\=\)\>:\<done\>'
let b:match_skip = 's:comment\|string\|heredoc\|subst'

let &cpo = s:cpo_save
unlet s:cpo_save
