" Vim filetype plugin
" Language:		Ruby
" Maintainer:		Tim Pope <vimNOSPAM@tpope.org>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:  Doug Kearns <dougkearns@gmail.com>
" ----------------------------------------------------------------------------

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
	\ '\<end\>' .
	\ ',{:},\[:\],(:)'

  let b:match_skip =
	\ "synIDattr(synID(line('.'),col('.'),0),'name') =~ '" .
	\ "\\<ruby\\%(String\\|StringDelimiter\\|ASCIICode\\|Escape\\|" .
	\ "Interpolation\\|NoInterpolation\\|Comment\\|Documentation\\|" .
	\ "ConditionalModifier\\|RepeatModifier\\|OptionalDo\\|" .
	\ "Function\\|BlockArgument\\|KeywordAsMethod\\|ClassVariable\\|" .
	\ "InstanceVariable\\|GlobalVariable\\|Symbol\\)\\>'"
endif

setlocal formatoptions-=t formatoptions+=croql

setlocal include=^\\s*\\<\\(load\\>\\\|require\\>\\\|autoload\\s*:\\=[\"']\\=\\h\\w*[\"']\\=,\\)
setlocal includeexpr=substitute(substitute(v:fname,'::','/','g'),'$','.rb','')
setlocal suffixesadd=.rb

if exists("&ofu") && has("ruby")
  setlocal omnifunc=rubycomplete#Complete
endif

" To activate, :set ballooneval
if has('balloon_eval') && exists('+balloonexpr')
  setlocal balloonexpr=RubyBalloonexpr()
endif


" TODO:
"setlocal define=^\\s*def

setlocal comments=:#
setlocal commentstring=#\ %s

if !exists('g:ruby_version_paths')
  let g:ruby_version_paths = {}
endif

function! s:query_path(root)
  let code = "print $:.join %q{,}"
  if &shell =~# 'sh' && $PATH !~# '\s'
    let prefix = 'env PATH='.$PATH.' '
  else
    let prefix = ''
  endif
  if &shellxquote == "'"
    let path_check = prefix.'ruby -e "' . code . '"'
  else
    let path_check = prefix."ruby -e '" . code . "'"
  endif

  let cd = haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  try
    exe cd fnameescape(a:root)
    let path = split(system(path_check),',')
    exe cd fnameescape(cwd)
    return path
  finally
    exe cd fnameescape(cwd)
  endtry
endfunction

function! s:build_path(path)
  let path = join(map(copy(a:path), 'v:val ==# "." ? "" : v:val'), ',')
  if &g:path !~# '\v^\.%(,/%(usr|emx)/include)=,,$'
    let path = substitute(&g:path,',,$',',','') . ',' . path
  endif
  return path
endfunction

if !exists('b:ruby_version') && !exists('g:ruby_path') && isdirectory(expand('%:p:h'))
  let s:version_file = findfile('.ruby-version', '.;')
  if !empty(s:version_file)
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

if has("gui_win32") && !exists("b:browsefilter")
  let b:browsefilter = "Ruby Source Files (*.rb)\t*.rb\n" .
                     \ "All Files (*.*)\t*.*\n"
endif

let b:undo_ftplugin = "setl fo< inc< inex< sua< def< com< cms< path< tags< kp<"
      \."| unlet! b:browsefilter b:match_ignorecase b:match_words b:match_skip"
      \."| if exists('&ofu') && has('ruby') | setl ofu< | endif"
      \."| if has('balloon_eval') && exists('+bexpr') | setl bexpr< | endif"

if !exists("g:no_plugin_maps") && !exists("g:no_ruby_maps")
  nnoremap <silent> <buffer> [m :<C-U>call <SID>searchsyn('\<def\>','rubyDefine','b','n')<CR>
  nnoremap <silent> <buffer> ]m :<C-U>call <SID>searchsyn('\<def\>','rubyDefine','','n')<CR>
  nnoremap <silent> <buffer> [M :<C-U>call <SID>searchsyn('\<end\>','rubyDefine','b','n')<CR>
  nnoremap <silent> <buffer> ]M :<C-U>call <SID>searchsyn('\<end\>','rubyDefine','','n')<CR>
  xnoremap <silent> <buffer> [m :<C-U>call <SID>searchsyn('\<def\>','rubyDefine','b','v')<CR>
  xnoremap <silent> <buffer> ]m :<C-U>call <SID>searchsyn('\<def\>','rubyDefine','','v')<CR>
  xnoremap <silent> <buffer> [M :<C-U>call <SID>searchsyn('\<end\>','rubyDefine','b','v')<CR>
  xnoremap <silent> <buffer> ]M :<C-U>call <SID>searchsyn('\<end\>','rubyDefine','','v')<CR>

  nnoremap <silent> <buffer> [[ :<C-U>call <SID>searchsyn('\<\%(class\<Bar>module\)\>','rubyModule\<Bar>rubyClass','b','n')<CR>
  nnoremap <silent> <buffer> ]] :<C-U>call <SID>searchsyn('\<\%(class\<Bar>module\)\>','rubyModule\<Bar>rubyClass','','n')<CR>
  nnoremap <silent> <buffer> [] :<C-U>call <SID>searchsyn('\<end\>','rubyModule\<Bar>rubyClass','b','n')<CR>
  nnoremap <silent> <buffer> ][ :<C-U>call <SID>searchsyn('\<end\>','rubyModule\<Bar>rubyClass','','n')<CR>
  xnoremap <silent> <buffer> [[ :<C-U>call <SID>searchsyn('\<\%(class\<Bar>module\)\>','rubyModule\<Bar>rubyClass','b','v')<CR>
  xnoremap <silent> <buffer> ]] :<C-U>call <SID>searchsyn('\<\%(class\<Bar>module\)\>','rubyModule\<Bar>rubyClass','','v')<CR>
  xnoremap <silent> <buffer> [] :<C-U>call <SID>searchsyn('\<end\>','rubyModule\<Bar>rubyClass','b','v')<CR>
  xnoremap <silent> <buffer> ][ :<C-U>call <SID>searchsyn('\<end\>','rubyModule\<Bar>rubyClass','','v')<CR>

  let b:undo_ftplugin = b:undo_ftplugin
        \."| sil! exe 'unmap <buffer> [[' | sil! exe 'unmap <buffer> ]]' | sil! exe 'unmap <buffer> []' | sil! exe 'unmap <buffer> ]['"
        \."| sil! exe 'unmap <buffer> [m' | sil! exe 'unmap <buffer> ]m' | sil! exe 'unmap <buffer> [M' | sil! exe 'unmap <buffer> ]M'"

  if maparg('im','n') == ''
    onoremap <silent> <buffer> im :<C-U>call <SID>wrap_i('[m',']M')<CR>
    onoremap <silent> <buffer> am :<C-U>call <SID>wrap_a('[m',']M')<CR>
    xnoremap <silent> <buffer> im :<C-U>call <SID>wrap_i('[m',']M')<CR>
    xnoremap <silent> <buffer> am :<C-U>call <SID>wrap_a('[m',']M')<CR>
    let b:undo_ftplugin = b:undo_ftplugin
          \."| sil! exe 'ounmap <buffer> im' | sil! exe 'ounmap <buffer> am'"
          \."| sil! exe 'xunmap <buffer> im' | sil! exe 'xunmap <buffer> am'"
  endif

  if maparg('iM','n') == ''
    onoremap <silent> <buffer> iM :<C-U>call <SID>wrap_i('[[','][')<CR>
    onoremap <silent> <buffer> aM :<C-U>call <SID>wrap_a('[[','][')<CR>
    xnoremap <silent> <buffer> iM :<C-U>call <SID>wrap_i('[[','][')<CR>
    xnoremap <silent> <buffer> aM :<C-U>call <SID>wrap_a('[[','][')<CR>
    let b:undo_ftplugin = b:undo_ftplugin
          \."| sil! exe 'ounmap <buffer> iM' | sil! exe 'ounmap <buffer> aM'"
          \."| sil! exe 'xunmap <buffer> iM' | sil! exe 'xunmap <buffer> aM'"
  endif

  if maparg("\<C-]>",'n') == ''
    nnoremap <silent> <buffer> <C-]>       :<C-U>exe  v:count1."tag <C-R>=RubyCursorIdentifier()<CR>"<CR>
    nnoremap <silent> <buffer> g<C-]>      :<C-U>exe         "tjump <C-R>=RubyCursorIdentifier()<CR>"<CR>
    nnoremap <silent> <buffer> g]          :<C-U>exe       "tselect <C-R>=RubyCursorIdentifier()<CR>"<CR>
    nnoremap <silent> <buffer> <C-W>]      :<C-U>exe v:count1."stag <C-R>=RubyCursorIdentifier()<CR>"<CR>
    nnoremap <silent> <buffer> <C-W><C-]>  :<C-U>exe v:count1."stag <C-R>=RubyCursorIdentifier()<CR>"<CR>
    nnoremap <silent> <buffer> <C-W>g<C-]> :<C-U>exe        "stjump <C-R>=RubyCursorIdentifier()<CR>"<CR>
    nnoremap <silent> <buffer> <C-W>g]     :<C-U>exe      "stselect <C-R>=RubyCursorIdentifier()<CR>"<CR>
    nnoremap <silent> <buffer> <C-W>}      :<C-U>exe          "ptag <C-R>=RubyCursorIdentifier()<CR>"<CR>
    nnoremap <silent> <buffer> <C-W>g}     :<C-U>exe        "ptjump <C-R>=RubyCursorIdentifier()<CR>"<CR>
    let b:undo_ftplugin = b:undo_ftplugin
          \."| sil! exe 'nunmap <buffer> <C-]>'| sil! exe 'nunmap <buffer> g<C-]>'| sil! exe 'nunmap <buffer> g]'"
          \."| sil! exe 'nunmap <buffer> <C-W>]'| sil! exe 'nunmap <buffer> <C-W><C-]>'"
          \."| sil! exe 'nunmap <buffer> <C-W>g<C-]>'| sil! exe 'nunmap <buffer> <C-W>g]'"
          \."| sil! exe 'nunmap <buffer> <C-W>}'| sil! exe 'nunmap <buffer> <C-W>g}'"
  endif

  if maparg("gf",'n') == ''
    " By using findfile() rather than gf's normal behavior, we prevent
    " erroneously editing a directory.
    nnoremap <silent> <buffer> gf         :<C-U>exe <SID>gf(v:count1,"gf",'edit')<CR>
    nnoremap <silent> <buffer> <C-W>f     :<C-U>exe <SID>gf(v:count1,"\<Lt>C-W>f",'split')<CR>
    nnoremap <silent> <buffer> <C-W><C-F> :<C-U>exe <SID>gf(v:count1,"\<Lt>C-W>\<Lt>C-F>",'split')<CR>
    nnoremap <silent> <buffer> <C-W>gf    :<C-U>exe <SID>gf(v:count1,"\<Lt>C-W>gf",'tabedit')<CR>
    let b:undo_ftplugin = b:undo_ftplugin
          \."| sil! exe 'nunmap <buffer> gf' | sil! exe 'nunmap <buffer> <C-W>f' | sil! exe 'nunmap <buffer> <C-W><C-F>' | sil! exe 'nunmap <buffer> <C-W>gf'"
  endif
endif

let &cpo = s:cpo_save
unlet s:cpo_save

if exists("g:did_ruby_ftplugin_functions")
  finish
endif
let g:did_ruby_ftplugin_functions = 1

function! RubyBalloonexpr()
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

function! s:searchsyn(pattern,syn,flags,mode)
  norm! m'
  if a:mode ==# 'v'
    norm! gv
  endif
  let i = 0
  let cnt = v:count ? v:count : 1
  while i < cnt
    let i = i + 1
    let line = line('.')
    let col  = col('.')
    let pos = search(a:pattern,'W'.a:flags)
    while pos != 0 && s:synname() !~# a:syn
      let pos = search(a:pattern,'W'.a:flags)
    endwhile
    if pos == 0
      call cursor(line,col)
      return
    endif
  endwhile
endfunction

function! s:synname()
  return synIDattr(synID(line('.'),col('.'),0),'name')
endfunction

function! s:wrap_i(back,forward)
  execute 'norm k'.a:forward
  let line = line('.')
  execute 'norm '.a:back
  if line('.') == line - 1
    return s:wrap_a(a:back,a:forward)
  endif
  execute 'norm jV'.a:forward.'k'
endfunction

function! s:wrap_a(back,forward)
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

function! RubyCursorIdentifier()
  let asciicode    = '\%(\w\|[]})\"'."'".']\)\@<!\%(?\%(\\M-\\C-\|\\C-\\M-\|\\M-\\c\|\\c\\M-\|\\c\|\\C-\|\\M-\)\=\%(\\\o\{1,3}\|\\x\x\{1,2}\|\\\=\S\)\)'
  let number       = '\%(\%(\w\|[]})\"'."'".']\s*\)\@<!-\)\=\%(\<[[:digit:]_]\+\%(\.[[:digit:]_]\+\)\=\%([Ee][[:digit:]_]\+\)\=\>\|\<0[xXbBoOdD][[:xdigit:]_]\+\>\)\|'.asciicode
  let operator     = '\%(\[\]\|<<\|<=>\|[!<>]=\=\|===\=\|[!=]\~\|>>\|\*\*\|\.\.\.\=\|=>\|[~^&|*/%+-]\)'
  let method       = '\%(\<[_a-zA-Z]\w*\>\%([?!]\|\s*=>\@!\)\=\)'
  let global       = '$\%([!$&"'."'".'*+,./:;<=>?@\`~]\|-\=\w\+\>\)'
  let symbolizable = '\%(\%(@@\=\)\w\+\>\|'.global.'\|'.method.'\|'.operator.'\)'
  let pattern      = '\C\s*\%('.number.'\|\%(:\@<!:\)\='.symbolizable.'\)'
  let [lnum, col]  = searchpos(pattern,'bcn',line('.'))
  let raw          = matchstr(getline('.')[col-1 : ],pattern)
  let stripped     = substitute(substitute(raw,'\s\+=$','=',''),'^\s*:\=','','')
  return stripped == '' ? expand("<cword>") : stripped
endfunction

function! s:gf(count,map,edit) abort
  if getline('.') =~# '^\s*require_relative\s*\(["'']\).*\1\s*$'
    let target = matchstr(getline('.'),'\(["'']\)\zs.\{-\}\ze\1')
    return a:edit.' %:h/'.target.'.rb'
  elseif getline('.') =~# '^\s*\%(require[( ]\|load[( ]\|autoload[( ]:\w\+,\)\s*\s*\%(::\)\=File\.expand_path(\(["'']\)\.\./.*\1,\s*__FILE__)\s*$'
    let target = matchstr(getline('.'),'\(["'']\)\.\./\zs.\{-\}\ze\1')
    return a:edit.' %:h/'.target.'.rb'
  elseif getline('.') =~# '^\s*\%(require \|load \|autoload :\w\+,\)\s*\(["'']\).*\1\s*$'
    let target = matchstr(getline('.'),'\(["'']\)\zs.\{-\}\ze\1')
  else
    let target = expand('<cfile>')
  endif
  let found = findfile(target, &path, a:count)
  if found ==# ''
    return 'norm! '.a:count.a:map
  else
    return a:edit.' '.fnameescape(found)
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
