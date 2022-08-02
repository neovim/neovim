" Vim filetype plugin
" Language:	git commit file
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2022 Jan 05

" Only do this when not done yet for this buffer
if (exists("b:did_ftplugin"))
  finish
endif

let b:did_ftplugin = 1

setlocal nomodeline tabstop=8 formatoptions+=tl textwidth=72
setlocal formatoptions-=c formatoptions-=r formatoptions-=o formatoptions-=q formatoptions+=n
setlocal formatlistpat+=\\\|^\\s*[-*+]\\s\\+
setlocal include=^+++
setlocal includeexpr=substitute(v:fname,'^[bi]/','','')

let b:undo_ftplugin = 'setl modeline< tabstop< formatoptions< tw< com< cms< formatlistpat< inc< inex<'

let s:l = search('\C\m^[#;@!$%^&|:] -\{24,\} >8 -\{24,\}$', 'cnW', '', 100)
let &l:comments = ':' . (matchstr(getline(s:l ? s:l : '$'), '^[#;@!$%^&|:]\S\@!') . '#')[0]
let &l:commentstring = &l:comments[1] . ' %s'
unlet s:l

if exists("g:no_gitcommit_commands")
  finish
endif

command! -bang -bar -buffer -complete=custom,s:diffcomplete -nargs=* DiffGitCached :call s:gitdiffcached(<bang>0, <f-args>)

let b:undo_ftplugin = b:undo_ftplugin . "|delc DiffGitCached"

function! s:diffcomplete(A, L, P) abort
  let args = ""
  if a:P <= match(a:L." -- "," -- ")+3
    let args = args . "-p\n--stat\n--shortstat\n--summary\n--patch-with-stat\n--no-renames\n-B\n-M\n-C\n"
  end
  if a:A !~ '^-' && !empty(getftype('.git'))
    let args = args."\n".system("git diff --cached --name-only")
  endif
  return args
endfunction

function! s:gitdiffcached(bang, ...) abort
  let name = tempname()
  if a:0
    let extra = join(map(copy(a:000), 'shellescape(v:val)'))
  else
    let extra = "-p --stat=".&columns
  endif
  call system("git diff --cached --no-color --no-ext-diff ".extra." > ".shellescape(name))
  exe "pedit " . fnameescape(name)
  wincmd P
  command! -bang -bar -buffer -complete=custom,s:diffcomplete -nargs=* DiffGitCached :call s:gitdiffcached(<bang>0, <f-args>)
  setlocal buftype=nowrite nobuflisted noswapfile nomodifiable filetype=git
endfunction
