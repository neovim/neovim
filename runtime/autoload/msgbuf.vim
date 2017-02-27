" Load a script and jump to an error source.
function! s:open_err_script(err) abort
  let fname = expand(a:err.fname)
  if !filereadable(fname)
    echoerr 'Could not read:' a:err.fname
    return
  endif

  let func_pattern = '\C^\s*fu\%[nction]!\?\s\+'
  if a:err.script_local
    let func_pattern .= '\%(<\%(sid\|SID\)>\|s:\)'
  endif
  let func_pattern .= a:err.func.'\>'

  let i = 1
  for line in readfile(fname)
    if line =~# func_pattern
      break
    endif

    let i += 1
  endfor

  let i += a:err.lnum
  let win = bufwinnr(fname)
  if win == -1
    execute 'wincmd p | split' fname
  else
    execute win 'wincmd w'
  endif

  execute 'normal! '.i.'Gzz'
endfunction


" List functions involved in an exception.
function! msgbuf#goto() abort
  let curline = getline('.')
  let nextline = getline(line('.') + 1)
  if curline =~# '<SNR>' && nextline =~? 'Line\s\+\d\+:$'
    " Looks like an error line.
    let scripts = []

    for script in split(execute('scriptnames'), "\n")
      let fname = matchstr(script, '\d\+: \zs\f\+$')
      if !empty(fname)
        call add(scripts, fname)
      endif
    endfor

    let err_funcs = []
    let selections = ['Jump to function:']
    let i = 1

    for func in split(matchstr(curline, '\S\+:$'), '\.\.')
      let index = matchstr(func, '<SNR>\zs\d\+')
      let funcname = matchstr(func, '\%(<SNR>\d\+_\)\?\zs[^\[:]\+')
      let lnum = matchstr(func, '\[\zs\d\+\ze\]$')
      let script_fname = ''
      let display_name = funcname.'()'

      if !empty(index)
        let script_fname = scripts[index - 1]
        let display_name = 's:'.display_name
      else
        let script_lines = split(execute('silent! verbose function '.funcname), "\n")
        if len(script_lines) > 1
          let script_fname = matchstr(script_lines[1], 'Last set from \zs\f\+')
        endif
      endif

      if !empty(script_fname)
        call add(selections, printf('%d. %s', i, display_name))

        if empty(lnum)
          let lnum = matchstr(nextline, '\d\+\ze:')
        endif

        call add(err_funcs, {
              \   'func': funcname,
              \   'fname': script_fname,
              \   'lnum': lnum,
              \   'script_local': func =~# '<SNR>',
              \ })
        let i += 1
      endif
    endfor

    let index = inputlist(selections)
    if index > 0
      call s:open_err_script(err_funcs[index - 1])
    endif
  else
    normal! gf
  endif
endfunction
