" Vim compiler file
" Compiler:     Spotbugs (Java static checker; needs javac compiled classes)
" Maintainer:   @konfekt and @zzzyxwvut
" Last Change:  2024 Nov 27

if exists('g:current_compiler') || bufname() !~# '\.java\=$' || wordcount().chars < 9
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Unfortunately Spotbugs does not output absolute paths, so you need to
" pass the directory of the files being checked as `-sourcepath` parameter.
" The regex, auxpath and glob try to include all dependent classes of the
" current buffer. See https://github.com/spotbugs/spotbugs/issues/856

" FIXME: When "search()" is used with the "e" flag, it makes no _further_
" progress after claiming an EOL match (i.e. "\_" or "\n", but not "$").
" XXX: Omit anonymous class declarations
let s:keywords = '\C\<\%(\.\@1<!class\|@\=interface\|enum\|record\|package\)\%(\s\|$\)'
let s:type_names = '\C\<\%(\.\@1<!class\|@\=interface\|enum\|record\)\s*\(\K\k*\)\>'
" Capture ";" for counting a class file directory (see s:package_dir_heads below)
let s:package_names = '\C\<package\s*\(\K\%(\k*\.\=\)\+;\)'
let s:package = ''

if has('syntax') && exists('g:syntax_on') && exists('b:current_syntax') &&
    \ b:current_syntax == 'java' && hlexists('javaClassDecl')

  function! s:GetDeclaredTypeNames() abort
    if bufname() =~# '\<\%(module\|package\)-info\.java\=$'
      return [expand('%:t:r')]
    endif
    defer execute('silent! normal! g``')
    call cursor(1, 1)
    let type_names = []
    let lnum = search(s:keywords, 'eW')
    while lnum > 0
      let name_attr = synIDattr(synID(lnum, (col('.') - 1), 0), 'name')
      if name_attr ==# 'javaClassDecl'
        let tokens = matchlist(getline(lnum)..getline(lnum + 1), s:type_names)
        if !empty(tokens) | call add(type_names, tokens[1]) | endif
      elseif name_attr ==# 'javaExternal'
        let tokens = matchlist(getline(lnum)..getline(lnum + 1), s:package_names)
        if !empty(tokens) | let s:package = tokens[1] | endif
      endif
      let lnum = search(s:keywords, 'eW')
    endwhile
    return type_names
  endfunction

else
  function! s:GetDeclaredTypeNames() abort
    if bufname() =~# '\<\%(module\|package\)-info\.java\=$'
      return [expand('%:t:r')]
    endif
    " Undo the unsetting of &hls, see below
    if &hls
      defer execute('set hls')
    endif
    " Possibly restore the current values for registers '"' and "y", see below
    defer call('setreg', ['"', getreg('"'), getregtype('"')])
    defer call('setreg', ['y', getreg('y'), getregtype('y')])
    defer execute('silent bwipeout')
    " Copy buffer contents for modification
    silent %y y
    new
    " Apply ":help scratch-buffer" effects and match "$" in Java (generated)
    " type names (see s:type_names)
    setlocal iskeyword+=$ buftype=nofile bufhidden=hide noswapfile nohls
    0put y
    " Discard text blocks and strings
    silent keeppatterns %s/\\\@<!"""\_.\{-}\\\@<!"""\|\\"//ge
    silent keeppatterns %s/".*"//ge
    " Discard comments
    silent keeppatterns %s/\/\/.\+$//ge
    silent keeppatterns %s/\/\*\_.\{-}\*\///ge
    call cursor(1, 1)
    let type_names = []
    let lnum = search(s:keywords, 'eW')
    while lnum > 0
      let line = getline(lnum)
      if line =~# '\<package\>'
        let tokens = matchlist(line..getline(lnum + 1), s:package_names)
        if !empty(tokens) | let s:package = tokens[1] | endif
      else
        let tokens = matchlist(line..getline(lnum + 1), s:type_names)
        if !empty(tokens) | call add(type_names, tokens[1]) | endif
      endif
      let lnum = search(s:keywords, 'eW')
    endwhile
    return type_names
  endfunction
endif

if has('win32')

  function! s:GlobClassFiles(src_type_name) abort
    return glob(a:src_type_name..'$*.class', 1, 1)
  endfunction

else
  function! s:GlobClassFiles(src_type_name) abort
    return glob(a:src_type_name..'\$*.class', 1, 1)
  endfunction
endif

if exists('g:spotbugs_properties') &&
    \ (has_key(g:spotbugs_properties, 'sourceDirPath') &&
    \ has_key(g:spotbugs_properties, 'classDirPath')) ||
    \ (has_key(g:spotbugs_properties, 'testSourceDirPath') &&
    \ has_key(g:spotbugs_properties, 'testClassDirPath'))

function! s:FindClassFiles(src_type_name) abort
  let class_files = []
  " Match pairwise the components of source and class pathnames
  for [src_dir, bin_dir] in filter([
            \ [get(g:spotbugs_properties, 'sourceDirPath', ''),
                \ get(g:spotbugs_properties, 'classDirPath', '')],
            \ [get(g:spotbugs_properties, 'testSourceDirPath', ''),
                \ get(g:spotbugs_properties, 'testClassDirPath', '')]],
        \ '!(empty(v:val[0]) || empty(v:val[1]))')
    " Since only the rightmost "src" is sought, while there can be any number of
    " such filenames, no "fnamemodify(a:src_type_name, ':p:s?src?bin?')" is used
    let tail_idx = strridx(a:src_type_name, src_dir)
    " No such directory or no such inner type (i.e. without "$")
    if tail_idx < 0 | continue | endif
    " Substitute "bin_dir" for the rightmost "src_dir"
    let candidate_type_name = strpart(a:src_type_name, 0, tail_idx)..
        \ bin_dir..
        \ strpart(a:src_type_name, (tail_idx + strlen(src_dir)))
    for candidate in insert(s:GlobClassFiles(candidate_type_name),
            \ candidate_type_name..'.class')
      if filereadable(candidate) | call add(class_files, shellescape(candidate)) | endif
    endfor
    if !empty(class_files) | break | endif
  endfor
  return class_files
endfunction

else
function! s:FindClassFiles(src_type_name) abort
  let class_files = []
  for candidate in insert(s:GlobClassFiles(a:src_type_name),
          \ a:src_type_name..'.class')
    if filereadable(candidate) | call add(class_files, shellescape(candidate)) | endif
  endfor
  return class_files
endfunction
endif

function! s:CollectClassFiles() abort
  " Get a platform-independent pathname prefix, cf. "expand('%:p:h')..'/'"
  let pathname = expand('%:p')
  let tail_idx = strridx(pathname, expand('%:t'))
  let src_pathname = strpart(pathname, 0, tail_idx)
  let all_class_files = []
  " Get all type names in the current buffer and let the filename globbing
  " discover inner type names from arbitrary type names
  for type_name in s:GetDeclaredTypeNames()
    call extend(all_class_files, s:FindClassFiles(src_pathname..type_name))
  endfor
  return all_class_files
endfunction

" Expose class files for removal etc.
let b:spotbugs_class_files = s:CollectClassFiles()
let s:package_dir_heads = repeat(':h', (1 + strlen(substitute(s:package, '[^.;]', '', 'g'))))
let g:current_compiler = 'spotbugs'
" CompilerSet makeprg=spotbugs
let &l:makeprg = 'spotbugs'..(has('win32') ? '.bat' : '')..' '..
    \ get(b:, 'spotbugs_makeprg_params', get(g:, 'spotbugs_makeprg_params', '-workHard -experimental'))..
    \ ' -textui -emacs -auxclasspath %:p'..s:package_dir_heads..':S -sourcepath %:p'..s:package_dir_heads..':S '..
    \ join(b:spotbugs_class_files, ' ')
" Emacs expects doubled line numbers
setlocal errorformat=%f:%l:%*[0-9]\ %m,%f:-%*[0-9]:-%*[0-9]\ %m

" " This compiler is meant to be used for a single buffer only
" exe 'CompilerSet makeprg='..escape(&l:makeprg, ' \|"')
" exe 'CompilerSet errorformat='..escape(&l:errorformat, ' \|"')

delfunction s:CollectClassFiles
delfunction s:FindClassFiles
delfunction s:GlobClassFiles
delfunction s:GetDeclaredTypeNames
let &cpo = s:cpo_save
unlet s:package_dir_heads s:package s:package_names s:type_names s:keywords s:cpo_save

" vim: set foldmethod=syntax shiftwidth=2 expandtab:
