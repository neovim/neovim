" Runs all the indent tests for which there is no .out file.
"
" Current directory must be runtime/indent.

" Only do this with the +eval feature
if 1

set nocp
filetype indent on
syn on
set nowrapscan
set report=9999
set modeline

au! SwapExists * call HandleSwapExists()
func HandleSwapExists()
  " Ignore finding a swap file for the test input and output, the user might be
  " editing them and that's OK.
  if expand('<afile>') =~ '.*\.\(in\|out\|fail\|ok\)'
    let v:swapchoice = 'e'
  endif
endfunc

let failed_count = 0
for fname in glob('testdir/*.in', 1, 1)
  let root = substitute(fname, '\.in', '', '')

  " Execute the test if the .out file does not exist of when the .in file is
  " newer.
  let in_time = getftime(fname)
  let out_time = getftime(root . '.out')
  if out_time < 0 || in_time > out_time
    call delete(root . '.fail')
    call delete(root . '.out')

    set sw& ts& filetype=
    exe 'split ' . fname

    let did_some = 0
    let failed = 0
    let end = 1
    while 1
      " Indent all the lines between "START_INDENT" and "END_INDENT"
      exe end
      let start = search('\<START_INDENT\>')
      let end = search('\<END_INDENT\>')
      if start <= 0 || end <= 0 || end <= start
	if did_some == 0
	  call append(0, 'ERROR: START_INDENT and/or END_INDENT not found')
	  let failed = 1
	endif
	break
      else
	let did_some = 1

	" Execute all commands marked with INDENT_EXE and find any pattern.
	let lnum = start
	let pattern = ''
	let at = ''
	while 1
	  exe lnum + 1
	  let lnum_exe = search('\<INDENT_EXE\>')
	  exe lnum + 1
	  let indent_at = search('\<INDENT_\(AT\|NEXT\|PREV\)\>')
	  if lnum_exe > 0 && lnum_exe < end && (indent_at <= 0 || lnum_exe < indent_at)
	    exe substitute(getline(lnum_exe), '.*INDENT_EXE', '', '')
	    let lnum = lnum_exe
	    let start = lnum
	  elseif indent_at > 0 && indent_at < end
	    if pattern != ''
	      call append(indent_at, 'ERROR: duplicate pattern')
	      let failed = 1
	      break
	    endif
	    let text = getline(indent_at)
	    let pattern = substitute(text, '.*INDENT_\S*\s*', '', '')
	    let at = substitute(text, '.*INDENT_\(\S*\).*', '\1', '')
	    let lnum = indent_at
	    let start = lnum
	  else
	    break
	  endif
	endwhile

	exe start + 1
	if pattern == ''
	  exe 'normal =' . (end - 1) . 'G'
	else
	  let lnum = search(pattern)
	  if lnum <= 0
	    call append(indent_at, 'ERROR: pattern not found: ' . pattern)
	    let failed = 1
	    break
	  endif
	  if at == 'AT'
	    exe lnum
	  elseif at == 'NEXT'
	    exe lnum + 1
	  else
	    exe lnum - 1
	  endif
	  normal ==
	endif
      endif
    endwhile

    if !failed
      " Check the resulting text equals the .ok file.
      if getline(1, '$') != readfile(root . '.ok')
	let failed = 1
      endif
    endif

    if failed
      let failed_count += 1
      exe 'write ' . root . '.fail'
      echoerr 'Test ' . fname . ' FAILED!'
    else
      exe 'write ' . root . '.out'
      echo "Test " . fname . " OK\n"
    endif

    quit!  " close the indented file
  endif
endfor

" Matching "if 1" at the start.
endif

if failed_count > 0
  " have make report an error
  cquit
endif
qall!
