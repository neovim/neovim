"  matchit.vim: (global plugin) Extended "%" matching
"  Maintainer:  Christian Brabandt
"  Version:     1.15
"  Last Change: 2019 Jan 28
"  Repository:  https://github.com/chrisbra/matchit
"  Previous URL:http://www.vim.org/script.php?script_id=39
"  Previous Maintainer:  Benji Fisher PhD   <benji@member.AMS.org>

" Documentation:
"  The documentation is in a separate file: ../doc/matchit.txt .

" Credits:
"  Vim editor by Bram Moolenaar (Thanks, Bram!)
"  Original script and design by Raul Segura Acevedo
"  Support for comments by Douglas Potts
"  Support for back references and other improvements by Benji Fisher
"  Support for many languages by Johannes Zellner
"  Suggestions for improvement, bug reports, and support for additional
"  languages by Jordi-Albert Batalla, Neil Bird, Servatius Brandt, Mark
"  Collett, Stephen Wall, Dany St-Amant, Yuheng Xie, and Johannes Zellner.

" Debugging:
"  If you'd like to try the built-in debugging commands...
"   :MatchDebug      to activate debugging for the current buffer
"  This saves the values of several key script variables as buffer-local
"  variables.  See the MatchDebug() function, below, for details.

" TODO:  I should think about multi-line patterns for b:match_words.
"   This would require an option:  how many lines to scan (default 1).
"   This would be useful for Python, maybe also for *ML.
" TODO:  Maybe I should add a menu so that people will actually use some of
"   the features that I have implemented.
" TODO:  Eliminate the MultiMatch function.  Add yet another argument to
"   Match_wrapper() instead.
" TODO:  Allow :let b:match_words = '\(\(foo\)\(bar\)\):\3\2:end\1'
" TODO:  Make backrefs safer by using '\V' (very no-magic).
" TODO:  Add a level of indirection, so that custom % scripts can use my
"   work but extend it.

" Allow user to prevent loading and prevent duplicate loading.
if exists("g:loaded_matchit") || &cp
  finish
endif
let g:loaded_matchit = 1

let s:save_cpo = &cpo
set cpo&vim

nnoremap <silent> <Plug>(MatchitNormalForward)     :<C-U>call matchit#Match_wrapper('',1,'n')<CR>
nnoremap <silent> <Plug>(MatchitNormalBackward)    :<C-U>call matchit#Match_wrapper('',0,'n')<CR>
vnoremap <silent> <Plug>(MatchitVisualForward)     :<C-U>call matchit#Match_wrapper('',1,'v')<CR>m'gv``
vnoremap <silent> <Plug>(MatchitVisualBackward)    :<C-U>call matchit#Match_wrapper('',0,'v')<CR>m'gv``
onoremap <silent> <Plug>(MatchitOperationForward)  :<C-U>call matchit#Match_wrapper('',1,'o')<CR>
onoremap <silent> <Plug>(MatchitOperationBackward) :<C-U>call matchit#Match_wrapper('',0,'o')<CR>

nmap <silent> %  <Plug>(MatchitNormalForward)
nmap <silent> g% <Plug>(MatchitNormalBackward)
xmap <silent> %  <Plug>(MatchitVisualForward)
xmap <silent> g% <Plug>(MatchitVisualBackward)
omap <silent> %  <Plug>(MatchitOperationForward)
omap <silent> g% <Plug>(MatchitOperationBackward)

" Analogues of [{ and ]} using matching patterns:
nnoremap <silent> <Plug>(MatchitNormalMultiBackward)    :<C-U>call matchit#MultiMatch("bW", "n")<CR>
nnoremap <silent> <Plug>(MatchitNormalMultiForward)     :<C-U>call matchit#MultiMatch("W",  "n")<CR>
vnoremap <silent> <Plug>(MatchitVisualMultiBackward)    :<C-U>call matchit#MultiMatch("bW", "n")<CR>m'gv``
vnoremap <silent> <Plug>(MatchitVisualMultiForward)     :<C-U>call matchit#MultiMatch("W",  "n")<CR>m'gv``
onoremap <silent> <Plug>(MatchitOperationMultiBackward) :<C-U>call matchit#MultiMatch("bW", "o")<CR>
onoremap <silent> <Plug>(MatchitOperationMultiForward)  :<C-U>call matchit#MultiMatch("W",  "o")<CR>

nmap <silent> [% <Plug>(MatchitNormalMultiBackward)
nmap <silent> ]% <Plug>(MatchitNormalMultiForward)
xmap <silent> [% <Plug>(MatchitVisualMultiBackward)
xmap <silent> ]% <Plug>(MatchitVisualMultiForward)
omap <silent> [% <Plug>(MatchitOperationMultiBackward)
omap <silent> ]% <Plug>(MatchitOperationMultiForward)

" text object:
vmap <silent> <Plug>(MatchitVisualTextObject) <Plug>(MatchitVisualMultiBackward)o<Plug>(MatchitVisualMultiForward)
xmap a% <Plug>(MatchitVisualTextObject)

" Call this function to turn on debugging information.  Every time the main
" script is run, buffer variables will be saved.  These can be used directly
" or viewed using the menu items below.
if !exists(":MatchDebug")
  command! -nargs=0 MatchDebug call matchit#Match_debug()
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:sts=2:sw=2:et:
