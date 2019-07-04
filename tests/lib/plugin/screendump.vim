" Functions shared by tests making screen dumps.

" Only load this script once.
if exists('*CanRunVimInTerminal')
  finish
endif

" For most tests we need to be able to run terminal Vim with 256 colors.  On
" MS-Windows the console only has 16 colors and the GUI can't run in a
" terminal.
func CanRunVimInTerminal()
  return has('terminal') && !has('win32')
endfunc

" Skip the rest if there is no terminal feature at all.
if !has('terminal')
  finish
endif

" Run Vim with "arguments" in a new terminal window.
" By default uses a size of 20 lines and 75 columns.
" Returns the buffer number of the terminal.
"
" Options is a dictionary, these items are recognized:
" "rows" - height of the terminal window (max. 20)
" "cols" - width of the terminal window (max. 78)
" "statusoff" - number of lines the status is offset from default
func RunVimInTerminal(arguments, options)
  " If Vim doesn't exit a swap file remains, causing other tests to fail.
  " Remove it here.
  call delete(".swp")

  if exists('$COLORFGBG')
    " Clear $COLORFGBG to avoid 'background' being set to "dark", which will
    " only be corrected if the response to t_RB is received, which may be too
    " late.
    let $COLORFGBG = ''
  endif

  " Make a horizontal and vertical split, so that we can get exactly the right
  " size terminal window.  Works only when the current window is full width.
  call assert_equal(&columns, winwidth(0))
  split
  vsplit

  " Always do this with 256 colors and a light background.
  set t_Co=256 background=light
  hi Normal ctermfg=NONE ctermbg=NONE

  " Make the window 20 lines high and 75 columns, unless told otherwise.
  let rows = get(a:options, 'rows', 20)
  let cols = get(a:options, 'cols', 75)
  let statusoff = get(a:options, 'statusoff', 1)

  let cmd = GetVimCommandClean()

  " Add -v to have gvim run in the terminal (if possible)
  let cmd .= ' -v ' . a:arguments
  let buf = term_start(cmd, {
	\ 'curwin': 1,
	\ 'term_rows': rows,
	\ 'term_cols': cols,
	\ })
  if &termwinsize == ''
    " in the GUI we may end up with a different size, try to set it.
    if term_getsize(buf) != [rows, cols]
      call term_setsize(buf, rows, cols)
    endif
    call assert_equal([rows, cols], term_getsize(buf))
  else
    let rows = term_getsize(buf)[0]
    let cols = term_getsize(buf)[1]
  endif

  " Wait for "All" or "Top" of the ruler to be shown in the last line or in
  " the status line of the last window. This can be quite slow (e.g. when
  " using valgrind).
  " If it fails then show the terminal contents for debugging.
  try
    call WaitFor({-> len(term_getline(buf, rows)) >= cols - 1 || len(term_getline(buf, rows - statusoff)) >= cols - 1})
  catch /timed out after/
    let lines = map(range(1, rows), {key, val -> term_getline(buf, val)})
    call assert_report('RunVimInTerminal() failed, screen contents: ' . join(lines, "<NL>"))
  endtry

  return buf
endfunc

" Stop a Vim running in terminal buffer "buf".
func StopVimInTerminal(buf)
  call assert_equal("running", term_getstatus(a:buf))

  " CTRL-O : works both in Normal mode and Insert mode to start a command line.
  " In Command-line it's inserted, the CTRL-U removes it again.
  call term_sendkeys(a:buf, "\<C-O>:\<C-U>qa!\<cr>")

  call WaitForAssert({-> assert_equal("finished", term_getstatus(a:buf))})
  only!
endfunc

" Verify that Vim running in terminal buffer "buf" matches the screen dump.
" "options" is passed to term_dumpwrite().
" The file name used is "dumps/{filename}.dump".
" Optionally an extra argument can be passed which is prepended to the error
" message.  Use this when using the same dump file with different options.
" Will wait for up to a second for the screen dump to match.
" Returns non-zero when verification fails.
func VerifyScreenDump(buf, filename, options, ...)
  let reference = 'dumps/' . a:filename . '.dump'
  let testfile = 'failed/' . a:filename . '.dump'

  " Redraw to execute the code that updates the screen.  Otherwise we get the
  " text and attributes only from the internal buffer.
  redraw

  let did_mkdir = 0
  if !isdirectory('failed')
    let did_mkdir = 1
    call mkdir('failed')
  endif

  let i = 0
  while 1
    " leave some time for updating the original window
    sleep 10m
    call delete(testfile)
    call term_dumpwrite(a:buf, testfile, a:options)
    let testdump = readfile(testfile)
    if filereadable(reference)
      let refdump = readfile(reference)
    else
      " Must be a new screendump, always fail
      let refdump = []
    endif
    if refdump == testdump
      call delete(testfile)
      if did_mkdir
	call delete('failed', 'd')
      endif
      break
    endif
    if i == 100
      " Leave the failed dump around for inspection.
      if filereadable(reference)
	let msg = 'See dump file difference: call term_dumpdiff("' . testfile . '", "' . reference . '")'
	if a:0 == 1
	  let msg = a:1 . ': ' . msg
	endif
	if len(testdump) != len(refdump)
	  let msg = msg . '; line count is ' . len(testdump) . ' instead of ' . len(refdump)
	endif
      else
	let msg = 'See new dump file: call term_dumpload("' . testfile . '")'
      endif
      for i in range(len(refdump))
	if i >= len(testdump)
	  break
	endif
	if testdump[i] != refdump[i]
	  let msg = msg . '; difference in line ' . (i + 1) . ': "' . testdump[i] . '"'
	endif
      endfor
      call assert_report(msg)
      return 1
    endif
    let i += 1
  endwhile
  return 0
endfunc
