" Vim filetype plugin
" Language:		Ruby
" Maintainer:		Tim Pope <vimNOSPAM@tpope.org>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>
" Last Change:		2019 Jan 06

if (exists("b:did_ftplugin"))
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

if has("gui_running") && !has("gui_win32")
  setlocal keywordprg=ri\ -T\ -f\ bs
else
  setlocal keywordprg=ri
endif

" Matchit support
if exists("loaded_matchit") && !exists("b:match_words")
  let b:match_ignorecase = 0

  let b:match_words =
	\ '\<\%(if\|unless\|case\|while\|until\|for\|do\|class\|module\|def\|begin\)\>=\@!' .
	\ ':' .
	\ '\<\%(else\|elsif\|ensure\|when\|rescue\|break\|redo\|next\|retry\)\>' .
	\ ':' .
        \ '\%(^\|[^.\:@$]\)\@<=\<end\:\@!\>' .
	\ ',{:},\[:\],(:)'

  let b:match_skip =
	\ "synIDattr(synID(line('.'),col('.'),0),'name') =~ '" .
	\ "\\<ruby\\%(String\\|StringDelimiter\\|ASCIICode\\|Escape\\|" .
        \ "Regexp\\|RegexpDelimiter\\|" .
	\ "Interpolation\\|NoInterpolation\\|Comment\\|Documentation\\|" .
	\ "ConditionalModifier\\|RepeatModifier\\|OptionalDo\\|" .
	\ "Function\\|BlockArgument\\|KeywordAsMethod\\|ClassVariable\\|" .
	\ "InstanceVariable\\|GlobalVariable\\|Symbol\\)\\>'"
endif

setlocal formatoptions-=t formatoptions+=croql

setlocal include=^\\s*\\<\\(load\\>\\\|require\\>\\\|autoload\\s*:\\=[\"']\\=\\h\\w*[\"']\\=,\\)
setlocal suffixesadd=.rb

if exists("&ofu") && has("ruby")
  setlocal omnifunc=rubycomplete#Complete
endif

" TODO:
"setlocal define=^\\s*def

setlocal comments=:#
setlocal commentstring=#\ %s

if !exists('g:ruby_version_paths')
  let g:ruby_version_paths = {}
endif

function! s:query_path(root) abort
  let code = "print $:.join %q{,}"
  if &shell =~# 'sh' && empty(&shellxquote)
    let prefix = 'env PATH='.shellescape($PATH).' '
  else
    let prefix = ''
  endif
  if &shellxquote == "'"
    let path_check = prefix.'ruby --disable-gems -e "' . code . '"'
  else
    let path_check = prefix."ruby --disable-gems -e '" . code . "'"
  endif

  let cd = haslocaldir() ? 'lcd' : 'cd'
  let cwd = fnameescape(getcwd())
  try
    exe cd fnameescape(a:root)
    let path = split(system(path_check),',')
    exe cd cwd
    return path
  finally
    exe cd cwd
  endtry
endfunction

function! s:build_path(path) abort
  let path = join(map(copy(a:path), 'v:val ==# "." ? "" : v:val'), ',')
  if &g:path !~# '\v^\.%(,/%(usr|emx)/include)=,,$'
    let path = substitute(&g:path,',,$',',','') . ',' . path
  endif
  return path
endfunction

if !exists('b:ruby_version') && !exists('g:ruby_path') && isdirectory(expand('%:p:h'))
  let s:version_file = findfile('.ruby-version', '.;')
  if !empty(s:version_file) && filereadable(s:version_file)
    let b:ruby_version = get(readfile(s:version_file, '', 1), '')
    if !has_key(g:ruby_version_paths, b:ruby_version)
      let g:ruby_version_paths[b:ruby_version] = s:query_path(fnamemodify(s:version_file, ':p:h'))
    endif
  endif
endif

if exists("g:ruby_path")
  let s:ruby_path = type(g:ruby_path) == type([]) ? join(g:ruby_path, ',') : g:ruby_path
elseif has_key(g:ruby_version_paths, get(b:, 'ruby_version', ''))
  let s:ruby_paths = g:ruby_version_paths[b:ruby_version]
  let s:ruby_path = s:build_path(s:ruby_paths)
else
  if !exists('g:ruby_default_path')
    if has("ruby") && has("win32")
      ruby ::VIM::command( 'let g:ruby_default_path = split("%s",",")' % $:.join(%q{,}) )
    elseif executable('ruby')
      let g:ruby_default_path = s:query_path($HOME)
    else
      let g:ruby_default_path = map(split($RUBYLIB,':'), 'v:val ==# "." ? "" : v:val')
    endif
  endif
  let s:ruby_paths = g:ruby_default_path
  let s:ruby_path = s:build_path(s:ruby_paths)
endif

if stridx(&l:path, s:ruby_path) == -1
  let &l:path = s:ruby_path
endif
if exists('s:ruby_paths') && stridx(&l:tags, join(map(copy(s:ruby_paths),'v:val."/tags"'),',')) == -1
  let &l:tags = &tags . ',' . join(map(copy(s:ruby_paths),'v:val."/tags"'),',')
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let b:browsefilter = "Ruby Source Files (*.rb)\t*.rb\n" .
                     \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setl inc= sua= path= tags= fo< com< cms< kp="
      \."| unlet! b:browsefilter b:match_ignorecase b:match_words b:match_skip"
      \."| if exists('&ofu') && has('ruby') | setl ofu< | endif"

if get(g:, 'ruby_recommended_style', 1)
  setlocal shiftwidth=2 softtabstop=2 expandtab
  let b:undo_ftplugin .= ' | setl sw< sts< et<'
endif

" To activate, :set ballooneval
if exists('+balloonexpr') && get(g:, 'ruby_balloonexpr')
  setlocal balloonexpr=RubyBalloonexpr()
  let b:undo_ftplugin .= "| setl bexpr="
endif

function! s:map(mode, flags, map) abort
  let from = matchstr(a:map, '\S\+')
  if empty(mapcheck(from, a:mode))
    exe a:mode.'map' '<buffer>' a:map
    let b:undo_ftplugin .= '|sil! '.a:mode.'unmap <buffer> '.from
  endif
endfunction

cmap <buffer><script><expr> <Plug><ctag> substitute(RubyCursorTag(),'^$',"\022\027",'')
cmap <buffer><script><expr> <Plug><cfile> substitute(RubyCursorFile(),'^$',"\022\006",'')
let b:undo_ftplugin .= "| sil! cunmap <buffer> <Plug><ctag>| sil! cunmap <buffer> <Plug><cfile>"

if !exists("g:no_plugin_maps") && !exists("g:no_ruby_maps")
  nmap <buffer><script> <SID>:  :<C-U>
  nmap <buffer><script> <SID>c: :<C-U><C-R>=v:count ? v:count : ''<CR>

  nnoremap <silent> <buffer> [m :<C-U>call <SID>searchsyn('\<def\>',['rubyDefine'],'b','n')<CR>
  nnoremap <silent> <buffer> ]m :<C-U>call <SID>searchsyn('\<def\>',['rubyDefine'],'','n')<CR>
  nnoremap <silent> <buffer> [M :<C-U>call <SID>searchsyn('\<end\>',['rubyDefine'],'b','n')<CR>
  nnoremap <silent> <buffer> ]M :<C-U>call <SID>searchsyn('\<end\>',['rubyDefine'],'','n')<CR>
  xnoremap <silent> <buffer> [m :<C-U>call <SID>searchsyn('\<def\>',['rubyDefine'],'b','v')<CR>
  xnoremap <silent> <buffer> ]m :<C-U>call <SID>searchsyn('\<def\>',['rubyDefine'],'','v')<CR>
  xnoremap <silent> <buffer> [M :<C-U>call <SID>searchsyn('\<end\>',['rubyDefine'],'b','v')<CR>
  xnoremap <silent> <buffer> ]M :<C-U>call <SID>searchsyn('\<end\>',['rubyDefine'],'','v')<CR>

  nnoremap <silent> <buffer> [[ :<C-U>call <SID>searchsyn('\<\%(class\<Bar>module\)\>',['rubyModule','rubyClass'],'b','n')<CR>
  nnoremap <silent> <buffer> ]] :<C-U>call <SID>searchsyn('\<\%(class\<Bar>module\)\>',['rubyModule','rubyClass'],'','n')<CR>
  nnoremap <silent> <buffer> [] :<C-U>call <SID>searchsyn('\<end\>',['rubyModule','rubyClass'],'b','n')<CR>
  nnoremap <silent> <buffer> ][ :<C-U>call <SID>searchsyn('\<end\>',['rubyModule','rubyClass'],'','n')<CR>
  xnoremap <silent> <buffer> [[ :<C-U>call <SID>searchsyn('\<\%(class\<Bar>module\)\>',['rubyModule','rubyClass'],'b','v')<CR>
  xnoremap <silent> <buffer> ]] :<C-U>call <SID>searchsyn('\<\%(class\<Bar>module\)\>',['rubyModule','rubyClass'],'','v')<CR>
  xnoremap <silent> <buffer> [] :<C-U>call <SID>searchsyn('\<end\>',['rubyModule','rubyClass'],'b','v')<CR>
  xnoremap <silent> <buffer> ][ :<C-U>call <SID>searchsyn('\<end\>',['rubyModule','rubyClass'],'','v')<CR>

  let b:undo_ftplugin = b:undo_ftplugin
        \."| sil! exe 'unmap <buffer> [[' | sil! exe 'unmap <buffer> ]]' | sil! exe 'unmap <buffer> []' | sil! exe 'unmap <buffer> ]['"
        \."| sil! exe 'unmap <buffer> [m' | sil! exe 'unmap <buffer> ]m' | sil! exe 'unmap <buffer> [M' | sil! exe 'unmap <buffer> ]M'"

  if maparg('im','x') == '' && maparg('im','o') == '' && maparg('am','x') == '' && maparg('am','o') == ''
    onoremap <silent> <buffer> im :<C-U>call <SID>wrap_i('[m',']M')<CR>
    onoremap <silent> <buffer> am :<C-U>call <SID>wrap_a('[m',']M')<CR>
    xnoremap <silent> <buffer> im :<C-U>call <SID>wrap_i('[m',']M')<CR>
    xnoremap <silent> <buffer> am :<C-U>call <SID>wrap_a('[m',']M')<CR>
    let b:undo_ftplugin = b:undo_ftplugin
          \."| sil! exe 'ounmap <buffer> im' | sil! exe 'ounmap <buffer> am'"
          \."| sil! exe 'xunmap <buffer> im' | sil! exe 'xunmap <buffer> am'"
  endif

  if maparg('iM','x') == '' && maparg('iM','o') == '' && maparg('aM','x') == '' && maparg('aM','o') == ''
    onoremap <silent> <buffer> iM :<C-U>call <SID>wrap_i('[[','][')<CR>
    onoremap <silent> <buffer> aM :<C-U>call <SID>wrap_a('[[','][')<CR>
    xnoremap <silent> <buffer> iM :<C-U>call <SID>wrap_i('[[','][')<CR>
    xnoremap <silent> <buffer> aM :<C-U>call <SID>wrap_a('[[','][')<CR>
    let b:undo_ftplugin = b:undo_ftplugin
          \."| sil! exe 'ounmap <buffer> iM' | sil! exe 'ounmap <buffer> aM'"
          \."| sil! exe 'xunmap <buffer> iM' | sil! exe 'xunmap <buffer> aM'"
  endif

  call s:map('c', '', '<C-R><C-F> <Plug><cfile>')

  cmap <buffer><script><expr> <SID>tagzv &foldopen =~# 'tag' ? '<Bar>norm! zv' : ''
  call s:map('n', '<silent>', '<C-]>       <SID>:exe  v:count1."tag <Plug><ctag>"<SID>tagzv<CR>')
  call s:map('n', '<silent>', 'g<C-]>      <SID>:exe         "tjump <Plug><ctag>"<SID>tagzv<CR>')
  call s:map('n', '<silent>', 'g]          <SID>:exe       "tselect <Plug><ctag>"<SID>tagzv<CR>')
  call s:map('n', '<silent>', '<C-W>]      <SID>:exe v:count1."stag <Plug><ctag>"<SID>tagzv<CR>')
  call s:map('n', '<silent>', '<C-W><C-]>  <SID>:exe v:count1."stag <Plug><ctag>"<SID>tagzv<CR>')
  call s:map('n', '<silent>', '<C-W>g<C-]> <SID>:exe        "stjump <Plug><ctag>"<SID>tagzv<CR>')
  call s:map('n', '<silent>', '<C-W>g]     <SID>:exe      "stselect <Plug><ctag>"<SID>tagzv<CR>')
  call s:map('n', '<silent>', '<C-W>}      <SID>:exe v:count1."ptag <Plug><ctag>"<CR>')
  call s:map('n', '<silent>', '<C-W>g}     <SID>:exe        "ptjump <Plug><ctag>"<CR>')

  call s:map('n', '<silent>', 'gf           <SID>c:find <Plug><cfile><CR>')
  call s:map('n', '<silent>', '<C-W>f      <SID>c:sfind <Plug><cfile><CR>')
  call s:map('n', '<silent>', '<C-W><C-F>  <SID>c:sfind <Plug><cfile><CR>')
  call s:map('n', '<silent>', '<C-W>gf   <SID>c:tabfind <Plug><cfile><CR>')
endif

let &cpo = s:cpo_save
unlet s:cpo_save

if exists("g:did_ruby_ftplugin_functions")
  finish
endif
let g:did_ruby_ftplugin_functions = 1

function! RubyBalloonexpr() abort
  if !exists('s:ri_found')
    let s:ri_found = executable('ri')
  endif
  if s:ri_found
    let line = getline(v:beval_lnum)
    let b = matchstr(strpart(line,0,v:beval_col),'\%(\w\|[:.]\)*$')
    let a = substitute(matchstr(strpart(line,v:beval_col),'^\w*\%([?!]\|\s*=\)\?'),'\s\+','','g')
    let str = b.a
    let before = strpart(line,0,v:beval_col-strlen(b))
    let after  = strpart(line,v:beval_col+strlen(a))
    if str =~ '^\.'
      let str = substitute(str,'^\.','#','g')
      if before =~ '\]\s*$'
        let str = 'Array'.str
      elseif before =~ '}\s*$'
        " False positives from blocks here
        let str = 'Hash'.str
      elseif before =~ "[\"'`]\\s*$" || before =~ '\$\d\+\s*$'
        let str = 'String'.str
      elseif before =~ '\$\d\+\.\d\+\s*$'
        let str = 'Float'.str
      elseif before =~ '\$\d\+\s*$'
        let str = 'Integer'.str
      elseif before =~ '/\s*$'
        let str = 'Regexp'.str
      else
        let str = substitute(str,'^#','.','')
      endif
    endif
    let str = substitute(str,'.*\.\s*to_f\s*\.\s*','Float#','')
    let str = substitute(str,'.*\.\s*to_i\%(nt\)\=\s*\.\s*','Integer#','')
    let str = substitute(str,'.*\.\s*to_s\%(tr\)\=\s*\.\s*','String#','')
    let str = substitute(str,'.*\.\s*to_sym\s*\.\s*','Symbol#','')
    let str = substitute(str,'.*\.\s*to_a\%(ry\)\=\s*\.\s*','Array#','')
    let str = substitute(str,'.*\.\s*to_proc\s*\.\s*','Proc#','')
    if str !~ '^\w'
      return ''
    endif
    silent! let res = substitute(system("ri -f rdoc -T \"".str.'"'),'\n$','','')
    if res =~ '^Nothing known about' || res =~ '^Bad argument:' || res =~ '^More than one method'
      return ''
    endif
    return res
  else
    return ""
  endif
endfunction

function! s:searchsyn(pattern, syn, flags, mode) abort
  let cnt = v:count1
  norm! m'
  if a:mode ==# 'v'
    norm! gv
  endif
  let i = 0
  call map(a:syn, 'hlID(v:val)')
  while i < cnt
    let i = i + 1
    let line = line('.')
    let col  = col('.')
    let pos = search(a:pattern,'W'.a:flags)
    while pos != 0 && index(a:syn, s:synid()) < 0
      let pos = search(a:pattern,'W'.a:flags)
    endwhile
    if pos == 0
      call cursor(line,col)
      return
    endif
  endwhile
endfunction

function! s:synid() abort
  return synID(line('.'),col('.'),0)
endfunction

function! s:wrap_i(back,forward) abort
  execute 'norm k'.a:forward
  let line = line('.')
  execute 'norm '.a:back
  if line('.') == line - 1
    return s:wrap_a(a:back,a:forward)
  endif
  execute 'norm jV'.a:forward.'k'
endfunction

function! s:wrap_a(back,forward) abort
  execute 'norm '.a:forward
  if line('.') < line('$') && getline(line('.')+1) ==# ''
    let after = 1
  endif
  execute 'norm '.a:back
  while getline(line('.')-1) =~# '^\s*#' && line('.')
    -
  endwhile
  if exists('after')
    execute 'norm V'.a:forward.'j'
  elseif line('.') > 1 && getline(line('.')-1) =~# '^\s*$'
    execute 'norm kV'.a:forward
  else
    execute 'norm V'.a:forward
  endif
endfunction

function! RubyCursorIdentifier() abort
  let asciicode    = '\%(\w\|[]})\"'."'".']\)\@<!\%(?\%(\\M-\\C-\|\\C-\\M-\|\\M-\\c\|\\c\\M-\|\\c\|\\C-\|\\M-\)\=\%(\\\o\{1,3}\|\\x\x\{1,2}\|\\\=\S\)\)'
  let number       = '\%(\%(\w\|[]})\"'."'".']\s*\)\@<!-\)\=\%(\<[[:digit:]_]\+\%(\.[[:digit:]_]\+\)\=\%([Ee][[:digit:]_]\+\)\=\>\|\<0[xXbBoOdD][[:xdigit:]_]\+\>\)\|'.asciicode
  let operator     = '\%(\[\]\|<<\|<=>\|[!<>]=\=\|===\=\|[!=]\~\|>>\|\*\*\|\.\.\.\=\|=>\|[~^&|*/%+-]\)'
  let method       = '\%(\.[_a-zA-Z]\w*\s*=>\@!\|\<[_a-zA-Z]\w*\>[?!]\=\)'
  let global       = '$\%([!$&"'."'".'*+,./:;<=>?@\`~]\|-\=\w\+\>\)'
  let symbolizable = '\%(\%(@@\=\)\w\+\>\|'.global.'\|'.method.'\|'.operator.'\)'
  let pattern      = '\C\s*\%('.number.'\|\%(:\@<!:\)\='.symbolizable.'\)'
  let [lnum, col]  = searchpos(pattern,'bcn',line('.'))
  let raw          = matchstr(getline('.')[col-1 : ],pattern)
  let stripped     = substitute(substitute(raw,'\s\+=$','=',''),'^\s*[:.]\=','','')
  return stripped == '' ? expand("<cword>") : stripped
endfunction

function! RubyCursorTag() abort
  return substitute(RubyCursorIdentifier(), '^[$@]*', '', '')
endfunction

function! RubyCursorFile() abort
  let isfname = &isfname
  try
    set isfname+=:
    let cfile = expand('<cfile>')
  finally
    let isfname = &isfname
  endtry
  let pre = matchstr(strpart(getline('.'), 0, col('.')-1), '.*\f\@<!')
  let post = matchstr(strpart(getline('.'), col('.')), '\f\@!.*')
  let ext = getline('.') =~# '^\s*\%(require\%(_relative\)\=\|autoload\)\>' && cfile !~# '\.rb$' ? '.rb' : ''
  if s:synid() ==# hlID('rubyConstant')
    let cfile = substitute(cfile,'\.\w\+[?!=]\=$','','')
    let cfile = substitute(cfile,'^::','','')
    let cfile = substitute(cfile,'::','/','g')
    let cfile = substitute(cfile,'\(\u\+\)\(\u\l\)','\1_\2', 'g')
    let cfile = substitute(cfile,'\(\l\|\d\)\(\u\)','\1_\2', 'g')
    return tolower(cfile) . '.rb'
  elseif getline('.') =~# '^\s*require_relative\s*\(["'']\).*\1\s*$'
    let cfile = expand('%:p:h') . '/' . matchstr(getline('.'),'\(["'']\)\zs.\{-\}\ze\1') . ext
  elseif getline('.') =~# '^\s*\%(require[( ]\|load[( ]\|autoload[( ]:\w\+,\)\s*\%(::\)\=File\.expand_path(\(["'']\)\.\./.*\1,\s*__FILE__)\s*$'
    let target = matchstr(getline('.'),'\(["'']\)\.\.\zs/.\{-\}\ze\1')
    let cfile = expand('%:p:h') . target . ext
  elseif getline('.') =~# '^\s*\%(require \|load \|autoload :\w\+,\)\s*\(["'']\).*\1\s*$'
    let cfile = matchstr(getline('.'),'\(["'']\)\zs.\{-\}\ze\1') . ext
  elseif pre.post =~# '\<File.expand_path[( ].*[''"]\{2\}, *__FILE__\>' && cfile =~# '^\.\.'
    let cfile = expand('%:p:h') . strpart(cfile, 2)
  else
    return substitute(cfile, '\C\v^(.*):(\d+)%(:in)=$', '+\2 \1', '')
  endif
  let cwdpat = '^\M' . substitute(getcwd(), '[\/]', '\\[\\/]', 'g').'\ze\[\/]'
  let cfile = substitute(cfile, cwdpat, '.', '')
  if fnameescape(cfile) !=# cfile
    return '+ '.fnameescape(cfile)
  else
    return cfile
  endif
endfunction

"
" Instructions for enabling "matchit" support:
"
" 1. Look for the latest "matchit" plugin at
"
"         http://www.vim.org/scripts/script.php?script_id=39
"
"    It is also packaged with Vim, in the $VIMRUNTIME/macros directory.
"
" 2. Copy "matchit.txt" into a "doc" directory (e.g. $HOME/.vim/doc).
"
" 3. Copy "matchit.vim" into a "plugin" directory (e.g. $HOME/.vim/plugin).
"
" 4. Ensure this file (ftplugin/ruby.vim) is installed.
"
" 5. Ensure you have this line in your $HOME/.vimrc:
"         filetype plugin on
"
" 6. Restart Vim and create the matchit documentation:
"
"         :helptags ~/.vim/doc
"
"    Now you can do ":help matchit", and you should be able to use "%" on Ruby
"    keywords.  Try ":echo b:match_words" to be sure.
"
" Thanks to Mark J. Reed for the instructions.  See ":help vimrc" for the
" locations of plugin directories, etc., as there are several options, and it
" differs on Windows.  Email gsinclair@soyabean.com.au if you need help.
"

" vim: nowrap sw=2 sts=2 ts=8:
