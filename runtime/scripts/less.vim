" Vim script to work like "less"
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2024 Feb 15
" Former Maintainer:	Bram Moolenaar <Bram@vim.org>

" Avoid loading this file twice, allow the user to define his own script.
if exists("loaded_less")
  finish
endif
let loaded_less = 1

" If not reading from stdin, skip files that can't be read.
" Exit if there is no file at all.
if argc() > 0
  let s:i = 0
  while 1
    if filereadable(argv(s:i))
      if s:i != 0
	sleep 3
      endif
      break
    endif
    if isdirectory(argv(s:i))
      echomsg "Skipping directory " . argv(s:i)
    elseif getftime(argv(s:i)) < 0
      echomsg "Skipping non-existing file " . argv(s:i)
    else
      echomsg "Skipping unreadable file " . argv(s:i)
    endif
    echo "\n"
    let s:i = s:i + 1
    if s:i == argc()
      quit
    endif
    next
  endwhile
endif

" we don't want 'compatible' here
if &cp
  set nocp
endif

" enable syntax highlighting if not done already
if !get(g:, 'syntax_on', 0)
  syntax enable
endif

set so=0
set hlsearch
set incsearch
nohlsearch
" Don't remember file names and positions
set shada=
set nows
" Inhibit screen updates while searching
let s:lz = &lz
set lz

" Allow the user to define a function, which can set options specifically for
" this script.
if exists('*LessInitFunc')
  call LessInitFunc()
endif

" Used after each command: put cursor at end and display position
if &wrap
  noremap <SID>L L0:redraw<CR>:file<CR>
  au VimEnter * normal! L0
else
  noremap <SID>L Lg0:redraw<CR>:file<CR>
  au VimEnter * normal! Lg0
endif

" When reading from stdin don't consider the file modified.
au VimEnter * set nomod

" Can't modify the text or write the file.
set nomodifiable readonly

" Give help
noremap h :call <SID>Help()<CR>
map H h
fun! s:Help()
  echo "<Space>   One page forward          b         One page backward"
  echo "d         Half a page forward       u         Half a page backward"
  echo "<Enter>   One line forward          k         One line backward"
  echo "G         End of file               g         Start of file"
  echo "N%        percentage in file"
  echo "\n"
  echo "/pattern  Search for pattern        ?pattern  Search backward for pattern"
  echo "n         next pattern match        N         Previous pattern match"
  if &foldmethod != "manual"
  echo "\n"
    echo "zR        open all folds            zm        increase fold level"
  endif
  echo "\n"
  echo ":n<Enter> Next file                 :p<Enter> Previous file"
  echo "\n"
  echo "q         Quit                      v         Edit file"
  let i = input("Hit Enter to continue")
endfun

" Scroll one page forward
noremap <script> <Space> :call <SID>NextPage()<CR><SID>L
map <C-V> <Space>
map f <Space>
map <C-F> <Space>
map <PageDown> <Space>
map <kPageDown> <Space>
map <S-Down> <Space>
" If 'foldmethod' was changed keep the "z" commands, e.g. "zR" to open all
" folds.
if &foldmethod == "manual"
  map z <Space>
endif
map <Esc><Space> <Space>
fun! s:NextPage()
  if line(".") == line("$")
    if argidx() + 1 >= argc()
      " Don't quit at the end of the last file
      return
    endif
    next
    1
  else
    exe "normal! \<C-F>"
  endif
endfun

" Re-read file and page forward "tail -f"
map F :e<CR>G<SID>L:sleep 1<CR>F

" Scroll half a page forward
noremap <script> d <C-D><SID>L
map <C-D> d

" Scroll one line forward
noremap <script> <CR> <C-E><SID>L
map <C-N> <CR>
map e <CR>
map <C-E> <CR>
map j <CR>
map <C-J> <CR>
map <Down> <CR>

" Scroll one page backward
noremap <script> b <C-B><SID>L
map <C-B> b
map <PageUp> b
map <kPageUp> b
map <S-Up> b
map w b
map <Esc>v b

" Scroll half a page backward
noremap <script> u <C-U><SID>L
noremap <script> <C-U> <C-U><SID>L

" Scroll one line backward
noremap <script> k <C-Y><SID>L
map y k
map <C-Y> k
map <C-P> k
map <C-K> k
map <Up> k

" Redraw
noremap <script> r <C-L><SID>L
noremap <script> <C-R> <C-L><SID>L
noremap <script> R <C-L><SID>L

" Start of file
noremap <script> g gg<SID>L
map < g
map <Esc>< g
map <Home> g
map <kHome> g

" End of file
noremap <script> G G<SID>L
map > G
map <Esc>> G
map <End> G
map <kEnd> G

" Go to percentage
noremap <script> % %<SID>L
map p %

" Search
noremap <script> / H$:call <SID>Forward()<CR>/
if &wrap
  noremap <script> ? H0:call <SID>Backward()<CR>?
else
  noremap <script> ? Hg0:call <SID>Backward()<CR>?
endif

fun! s:Forward()
  " Searching forward
  noremap <script> n H$nzt<SID>L
  if &wrap
    noremap <script> N H0Nzt<SID>L
  else
    noremap <script> N Hg0Nzt<SID>L
  endif
  cnoremap <silent> <script> <CR> <CR>:cunmap <lt>CR><CR>zt<SID>L
endfun

fun! s:Backward()
  " Searching backward
  if &wrap
    noremap <script> n H0nzt<SID>L
  else
    noremap <script> n Hg0nzt<SID>L
  endif
  noremap <script> N H$Nzt<SID>L
  cnoremap <silent> <script> <CR> <CR>:cunmap <lt>CR><CR>zt<SID>L
endfun

call s:Forward()
cunmap <CR>

" Quitting
noremap q :q<CR>

" Switch to editing (switch off less mode)
map v :silent call <SID>End()<CR>
fun! s:End()
  set modifiable noreadonly
  if exists('s:lz')
    let &lz = s:lz
  endif
  if !empty(maparg('h'))
    unmap h
  endif
  if !empty(maparg('H'))
    unmap H
  endif
  if !empty(maparg('<Space>'))
    unmap <Space>
  endif
  if !empty(maparg('<C-V>'))
    unmap <C-V>
  endif
  if !empty(maparg('f'))
    unmap f
  endif
  if !empty(maparg('<C-F>'))
    unmap <C-F>
  endif
  if !empty(maparg('z'))
    unmap z
  endif
  if !empty(maparg('<Esc><Space>'))
    unmap <Esc><Space>
  endif
  if !empty(maparg('F'))
    unmap F
  endif
  if !empty(maparg('d'))
    unmap d
  endif
  if !empty(maparg('<C-D>'))
    unmap <C-D>
  endif
  if !empty(maparg('<CR>'))
    unmap <CR>
  endif
  if !empty(maparg('<C-N>'))
    unmap <C-N>
  endif
  if !empty(maparg('e'))
    unmap e
  endif
  if !empty(maparg('<C-E>'))
    unmap <C-E>
  endif
  if !empty(maparg('j'))
    unmap j
  endif
  if !empty(maparg('<C-J>'))
    unmap <C-J>
  endif
  if !empty(maparg('b'))
    unmap b
  endif
  if !empty(maparg('<C-B>'))
    unmap <C-B>
  endif
  if !empty(maparg('w'))
    unmap w
  endif
  if !empty(maparg('<Esc>v'))
    unmap <Esc>v
  endif
  if !empty(maparg('u'))
    unmap u
  endif
  if !empty(maparg('<C-U>'))
    unmap <C-U>
  endif
  if !empty(maparg('k'))
    unmap k
  endif
  if !empty(maparg('y'))
    unmap y
  endif
  if !empty(maparg('<C-Y>'))
    unmap <C-Y>
  endif
  if !empty(maparg('<C-P>'))
    unmap <C-P>
  endif
  if !empty(maparg('<C-K>'))
    unmap <C-K>
  endif
  if !empty(maparg('r'))
    unmap r
  endif
  if !empty(maparg('<C-R>'))
    unmap <C-R>
  endif
  if !empty(maparg('R'))
    unmap R
  endif
  if !empty(maparg('g'))
    unmap g
  endif
  if !empty(maparg('<'))
    unmap <
  endif
  if !empty(maparg('<Esc><'))
    unmap <Esc><
  endif
  if !empty(maparg('G'))
    unmap G
  endif
  if !empty(maparg('>'))
    unmap >
  endif
  if !empty(maparg('<Esc>>'))
    unmap <Esc>>
  endif
  if !empty(maparg('%'))
    unmap %
  endif
  if !empty(maparg('p'))
    unmap p
  endif
  if !empty(maparg('n'))
    unmap n
  endif
  if !empty(maparg('N'))
    unmap N
  endif
  if !empty(maparg('q'))
    unmap q
  endif
  if !empty(maparg('v'))
    unmap v
  endif
  if !empty(maparg('/'))
    unmap /
  endif
  if !empty(maparg('?'))
    unmap ?
  endif
  if !empty(maparg('<Up>'))
    unmap <Up>
  endif
  if !empty(maparg('<Down>'))
    unmap <Down>
  endif
  if !empty(maparg('<PageDown>'))
    unmap <PageDown>
  endif
  if !empty(maparg('<kPageDown>'))
    unmap <kPageDown>
  endif
  if !empty(maparg('<PageUp>'))
    unmap <PageUp>
  endif
  if !empty(maparg('<kPageUp>'))
    unmap <kPageUp>
  endif
  if !empty(maparg('<S-Down>'))
    unmap <S-Down>
  endif
  if !empty(maparg('<S-Up>'))
    unmap <S-Up>
  endif
  if !empty(maparg('<Home>'))
    unmap <Home>
  endif
  if !empty(maparg('<kHome>'))
    unmap <kHome>
  endif
  if !empty(maparg('<End>'))
    unmap <End>
  endif
  if !empty(maparg('<kEnd>'))
    unmap <kEnd>
  endif
endfun

" vim: sw=2
