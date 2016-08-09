" Load a script and jump to an error source.
function! s:open_err_script(err) abort
  let fname = expand(a:err.fname)
  if !filereadable(fname)
    echoerr 'Could not read:' a:err.fname
    return
  endif

  let func_pattern = '\C^\s*fu\%[nction]!\?\s\+'
  if a:err.func !~# '#'
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

  execute 'split' fname
  execute 'normal! '.i.'G'
endfunction


" List functions involved in an exception.
function! msgpane#goto() abort
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

    for func in split(matchstr(curline, '<SNR>\S\+:$'), '\.\.')
      let index = matchstr(func, '<SNR>\zs\d\+')
      let funcname = matchstr(func, '\%(<SNR>\d\+_\)\?\zs[^\[:]\+')
      let lnum = matchstr(func, '\[\zs\d\+\ze\]$')
      let script_fname = ''
      let display_name = funcname.'()'

      if !empty(index)
        let script_fname = scripts[index - 1]
        let display_name = 's:'.display_name
      elseif funcname =~# '#'
        let autoload_script = '/autoload/'.join(split(funcname, '#')[:-2], '/').'\.vim$'
        for script in scripts
          if script =~# autoload_script
            let script_fname = script
            break
          endif
        endfor
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
              \ })
        let i += 1
      endif
    endfor

    let index = inputlist(selections)
    if index > 1
      call s:open_err_script(err_funcs[index - 1])
    endif
  else
    normal! gf
  endif
endfunction
