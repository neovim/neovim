" Vim filetype plugin
" Language:	git rebase --interactive
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2019 Dec 05

" Only do this when not done yet for this buffer
if (exists("b:did_ftplugin"))
  finish
endif

runtime! ftplugin/git.vim
let b:did_ftplugin = 1

setlocal comments=:# commentstring=#\ %s formatoptions-=t
setlocal nomodeline
if !exists("b:undo_ftplugin")
  let b:undo_ftplugin = ""
endif
let b:undo_ftplugin = b:undo_ftplugin."|setl com< cms< fo< ml<"

function! s:choose(word) abort
  s/^\(\w\+\>\)\=\(\s*\)\ze\x\{4,40\}\>/\=(strlen(submatch(1)) == 1 ? a:word[0] : a:word) . substitute(submatch(2),'^$',' ','')/e
endfunction

function! s:cycle(count) abort
  let words = ['pick', 'edit', 'fixup', 'squash', 'reword', 'drop']
  let index = index(map(copy(words), 'v:val[0]'), getline('.')[0])
  let index = ((index < 0 ? 0 : index) + 10000 * len(words) + a:count) % len(words)
  call s:choose(words[index])
endfunction

command! -buffer -bar -range Pick   :<line1>,<line2>call s:choose('pick')
command! -buffer -bar -range Squash :<line1>,<line2>call s:choose('squash')
command! -buffer -bar -range Edit   :<line1>,<line2>call s:choose('edit')
command! -buffer -bar -range Reword :<line1>,<line2>call s:choose('reword')
command! -buffer -bar -range Fixup  :<line1>,<line2>call s:choose('fixup')
command! -buffer -bar -range Drop   :<line1>,<line2>call s:choose('drop')
command! -buffer -count=1 -bar -bang Cycle call s:cycle(<bang>0 ? -<count> : <count>)

if exists("g:no_plugin_maps") || exists("g:no_gitrebase_maps")
  finish
endif

nnoremap <buffer> <expr> K col('.') < 7 && expand('<Lt>cword>') =~ '\X' && getline('.') =~ '^\w\+\s\+\x\+\>' ? 'wK' : 'K'
nnoremap <buffer> <silent> <C-A> :<C-U><C-R>=v:count1<CR>Cycle<CR>
nnoremap <buffer> <silent> <C-X> :<C-U><C-R>=v:count1<CR>Cycle!<CR>

let b:undo_ftplugin = b:undo_ftplugin . "|exe 'nunmap <buffer> K'|exe 'nunmap <buffer> <C-A>'|exe 'nunmap <buffer> <C-X>'"
