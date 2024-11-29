" Default pre- and post-compiler actions for SpotBugs
" Maintainers:  @konfekt and @zzzyxwvut
" Last Change:  2024 Nov 27

let s:save_cpo = &cpo
set cpo&vim

if v:version > 900

  function! spotbugs#DeleteClassFiles() abort
    if !exists('b:spotbugs_class_files')
      return
    endif

    for pathname in b:spotbugs_class_files
      let classname = pathname =~# "^'.\\+\\.class'$"
          \ ? eval(pathname)
          \ : pathname

      if classname =~# '\.class$' && filereadable(classname)
        " Since v9.0.0795.
        let octad = readblob(classname, 0, 8)

        " Test the magic number and the major version number (45 for v1.0).
        " Since v9.0.2027.
        if len(octad) == 8 && octad[0 : 3] == 0zcafe.babe &&
              \ or((octad[6] << 8), octad[7]) >= 45
          echomsg printf('Deleting %s: %d', classname, delete(classname))
        endif
      endif
    endfor

    let b:spotbugs_class_files = []
  endfunction

else

  function! s:DeleteClassFilesWithNewLineCodes(classname) abort
    " The distribution of "0a"s in class file versions 2560 and 2570:
    "
    " 0zca.fe.ba.be.00.00.0a.00    0zca.fe.ba.be.00.00.0a.0a
    " 0zca.fe.ba.be.00.0a.0a.00    0zca.fe.ba.be.00.0a.0a.0a
    " 0zca.fe.ba.be.0a.00.0a.00    0zca.fe.ba.be.0a.00.0a.0a
    " 0zca.fe.ba.be.0a.0a.0a.00    0zca.fe.ba.be.0a.0a.0a.0a
    let numbers = [0, 0, 0, 0, 0, 0, 0, 0]
    let offset = 0
    let lines = readfile(a:classname, 'b', 4)

    " Track NL byte counts to handle files of less than 8 bytes.
    let nl_cnt = len(lines)
    " Track non-NL byte counts for "0zca.fe.ba.be.0a.0a.0a.0a".
    let non_nl_cnt = 0

    for line in lines
      for idx in range(strlen(line))
        " Remap NLs to Nuls.
        let numbers[offset] = (line[idx] == "\n") ? 0 : char2nr(line[idx]) % 256
        let non_nl_cnt += 1
        let offset += 1

        if offset > 7
          break
        endif
      endfor

      let nl_cnt -= 1

      if offset > 7 || (nl_cnt < 1 && non_nl_cnt > 4)
        break
      endif

      " Reclaim NLs.
      let numbers[offset] = 10
      let offset += 1

      if offset > 7
        break
      endif
    endfor

    " Test the magic number and the major version number (45 for v1.0).
    if offset > 7 && numbers[0] == 0xca && numbers[1] == 0xfe &&
          \ numbers[2] == 0xba && numbers[3] == 0xbe &&
          \ (numbers[6] * 256 + numbers[7]) >= 45
      echomsg printf('Deleting %s: %d', a:classname, delete(a:classname))
    endif
  endfunction

  function! spotbugs#DeleteClassFiles() abort
    if !exists('b:spotbugs_class_files')
      return
    endif

    let encoding = &encoding

    try
      set encoding=latin1

      for pathname in b:spotbugs_class_files
        let classname = pathname =~# "^'.\\+\\.class'$"
            \ ? eval(pathname)
            \ : pathname

        if classname =~# '\.class$' && filereadable(classname)
          let line = get(readfile(classname, 'b', 1), 0, '')
          let length = strlen(line)

          " Test the magic number and the major version number (45 for v1.0).
          if length > 3 && line[0 : 3] == "\xca\xfe\xba\xbe"
            if length > 7 && ((line[6] == "\n" ? 0 : char2nr(line[6]) % 256) * 256 +
                    \ (line[7] == "\n" ? 0 : char2nr(line[7]) % 256)) >= 45
              echomsg printf('Deleting %s: %d', classname, delete(classname))
            else
              call s:DeleteClassFilesWithNewLineCodes(classname)
            endif
          endif
        endif
      endfor
    finally
      let &encoding = encoding
    endtry

    let b:spotbugs_class_files = []
  endfunction

endif

function! spotbugs#DefaultPostCompilerAction() abort
  " Since v7.4.191.
  make %:S
endfunction

" Look for "spotbugs#compiler" in "ftplugin/java.vim".
let s:compiler = exists('spotbugs#compiler') ? spotbugs#compiler : ''
let s:readable = filereadable($VIMRUNTIME . '/compiler/' . s:compiler . '.vim')

if s:readable && s:compiler ==# 'maven' && executable('mvn')

  function! spotbugs#DefaultPreCompilerAction() abort
    call spotbugs#DeleteClassFiles()
    compiler maven
    make compile
  endfunction

  function! spotbugs#DefaultPreCompilerTestAction() abort
    call spotbugs#DeleteClassFiles()
    compiler maven
    make test-compile
  endfunction

  function! spotbugs#DefaultProperties() abort
    return {
        \ 'PreCompilerAction':
            \ function('spotbugs#DefaultPreCompilerAction'),
        \ 'PreCompilerTestAction':
            \ function('spotbugs#DefaultPreCompilerTestAction'),
        \ 'PostCompilerAction':
            \ function('spotbugs#DefaultPostCompilerAction'),
        \ 'sourceDirPath':      'src/main/java',
        \ 'classDirPath':       'target/classes',
        \ 'testSourceDirPath':  'src/test/java',
        \ 'testClassDirPath':   'target/test-classes',
        \ }
  endfunction

  unlet s:readable s:compiler
elseif s:readable && s:compiler ==# 'ant' && executable('ant')

  function! spotbugs#DefaultPreCompilerAction() abort
    call spotbugs#DeleteClassFiles()
    compiler ant
    make compile
  endfunction

  function! spotbugs#DefaultPreCompilerTestAction() abort
    call spotbugs#DeleteClassFiles()
    compiler ant
    make compile-test
  endfunction

  function! spotbugs#DefaultProperties() abort
    return {
        \ 'PreCompilerAction':
            \ function('spotbugs#DefaultPreCompilerAction'),
        \ 'PreCompilerTestAction':
            \ function('spotbugs#DefaultPreCompilerTestAction'),
        \ 'PostCompilerAction':
            \ function('spotbugs#DefaultPostCompilerAction'),
        \ 'sourceDirPath':      'src',
        \ 'classDirPath':       'build/classes',
        \ 'testSourceDirPath':  'test',
        \ 'testClassDirPath':   'build/test/classes',
        \ }
  endfunction

  unlet s:readable s:compiler
elseif s:readable && s:compiler ==# 'javac' && executable('javac')

  function! spotbugs#DefaultPreCompilerAction() abort
    call spotbugs#DeleteClassFiles()
    compiler javac

    if get(b:, 'javac_makeprg_params', get(g:, 'javac_makeprg_params', '')) =~ '\s@\S'
      " Read options and filenames from @options [@sources ...].
      make
    else
      " Let Javac figure out what files to compile.
      execute 'make ' . join(map(filter(copy(v:argv),
          \ "v:val =~# '\\.java\\=$'"),
          \ 'shellescape(v:val)'), ' ')
    endif
  endfunction

  function! spotbugs#DefaultPreCompilerTestAction() abort
    call spotbugs#DefaultPreCompilerAction()
  endfunction

  function! spotbugs#DefaultProperties() abort
    return {
        \ 'PreCompilerAction':
            \ function('spotbugs#DefaultPreCompilerAction'),
        \ 'PreCompilerTestAction':
            \ function('spotbugs#DefaultPreCompilerTestAction'),
        \ 'PostCompilerAction':
            \ function('spotbugs#DefaultPostCompilerAction'),
        \ }
  endfunction

  unlet s:readable s:compiler
else

  function! spotbugs#DefaultPreCompilerAction() abort
    echomsg printf('Not supported: "%s"', s:compiler)
  endfunction

  function! spotbugs#DefaultPreCompilerTestAction() abort
    call spotbugs#DefaultPreCompilerAction()
  endfunction

  function! spotbugs#DefaultProperties() abort
    return {}
  endfunction

  unlet s:readable
endif

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set foldmethod=syntax shiftwidth=2 expandtab:
