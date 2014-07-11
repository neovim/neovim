" Vim filetype plugin
" Language:	git commit file
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2013 May 30

" Only do this when not done yet for this buffer
if (exists("b:did_ftplugin"))
  finish
endif

runtime! ftplugin/git.vim
let b:did_ftplugin = 1

setlocal nomodeline tabstop=8 formatoptions-=croq formatoptions+=tl

let b:undo_ftplugin = 'setl modeline< tabstop< formatoptions<'

if &textwidth == 0
  " make sure that log messages play nice with git-log on standard terminals
  setlocal textwidth=72
  let b:undo_ftplugin .= "|setl tw<"
endif

if exists("g:no_gitcommit_commands") || v:version < 700
  finish
endif

if !exists("b:git_dir")
  let b:git_dir = expand("%:p:h")
endif

command! -bang -bar -buffer -complete=custom,s:diffcomplete -nargs=* DiffGitCached :call s:gitdiffcached(<bang>0,b:git_dir,<f-args>)

function! s:diffcomplete(A,L,P)
  let args = ""
  if a:P <= match(a:L." -- "," -- ")+3
    let args = args . "-p\n--stat\n--shortstat\n--summary\n--patch-with-stat\n--no-renames\n-B\n-M\n-C\n"
  end
  if exists("b:git_dir") && a:A !~ '^-'
    let tree = fnamemodify(b:git_dir,':h')
    if strpart(getcwd(),0,strlen(tree)) == tree
      let args = args."\n".system("git diff --cached --name-only")
    endif
  endif
  return args
endfunction

function! s:gitdiffcached(bang,gitdir,...)
  let tree = fnamemodify(a:gitdir,':h')
  let name = tempname()
  let git = "git"
  if strpart(getcwd(),0,strlen(tree)) != tree
    let git .= " --git-dir=".(exists("*shellescape") ? shellescape(a:gitdir) : '"'.a:gitdir.'"')
  endif
  if a:0
    let extra = join(map(copy(a:000),exists("*shellescape") ? 'shellescape(v:val)' : "'\"'.v:val.'\"'"))
  else
    let extra = "-p --stat=".&columns
  endif
  call system(git." diff --cached --no-color --no-ext-diff ".extra." > ".(exists("*shellescape") ? shellescape(name) : name))
  exe "pedit ".(exists("*fnameescape") ? fnameescape(name) : name)
  wincmd P
  let b:git_dir = a:gitdir
  command! -bang -bar -buffer -complete=custom,s:diffcomplete -nargs=* DiffGitCached :call s:gitdiffcached(<bang>0,b:git_dir,<f-args>)
  nnoremap <buffer> <silent> q :q<CR>
  setlocal buftype=nowrite nobuflisted noswapfile nomodifiable filetype=git
endfunction
