" Test 'winfixbuf'

source check.vim
source shared.vim

" Find the number of open windows in the current tab
func s:get_windows_count()
  return tabpagewinnr(tabpagenr(), '$')
endfunc

" Create some unnamed buffers.
func s:make_buffers_list()
  enew
  file first
  let l:first = bufnr()

  enew
  file middle
  let l:middle = bufnr()

  enew
  file last
  let l:last = bufnr()

  set winfixbuf

  return [l:first, l:last]
endfunc

" Create some unnamed buffers and add them to an args list
func s:make_args_list()
  let [l:first, l:last] = s:make_buffers_list()

  args! first middle last

  return [l:first, l:last]
endfunc

" Create two buffers and then set the window to 'winfixbuf'
func s:make_buffer_pairs(...)
  let l:reversed = get(a:, 1, 0)

  if l:reversed == 1
    enew
    file original

    set winfixbuf

    enew!
    file other
    let l:other = bufnr()

    return l:other
  endif

  enew
  file other
  let l:other = bufnr()

  enew
  file current

  set winfixbuf

  return l:other
endfunc

" Create 3 quick buffers and set the window to 'winfixbuf'
func s:make_buffer_trio()
  edit first
  let l:first = bufnr()
  edit second
  let l:second = bufnr()

  set winfixbuf

  edit! third
  let l:third = bufnr()

  execute ":buffer! " . l:second

  return [l:first, l:second, l:third]
endfunc

" Create a location list with at least 2 entries + a 'winfixbuf' window.
func s:make_simple_location_list()
  enew
  file middle
  let l:middle = bufnr()
  call append(0, ["winfix search-term", "another line"])

  enew!
  file first
  let l:first = bufnr()
  call append(0, "first search-term")

  enew!
  file last
  let l:last = bufnr()
  call append(0, "last search-term")

  call setloclist(
  \  0,
  \  [
  \    {
  \      "filename": "first",
  \      "bufnr": l:first,
  \      "lnum": 1,
  \    },
  \    {
  \      "filename": "middle",
  \      "bufnr": l:middle,
  \      "lnum": 1,
  \    },
  \    {
  \      "filename": "middle",
  \      "bufnr": l:middle,
  \      "lnum": 2,
  \    },
  \    {
  \      "filename": "last",
  \      "bufnr": l:last,
  \      "lnum": 1,
  \    },
  \  ]
  \)

  set winfixbuf

  return [l:first, l:middle, l:last]
endfunc

" Create a quickfix with at least 2 entries that are in the current 'winfixbuf' window.
func s:make_simple_quickfix()
  enew
  file current
  let l:current = bufnr()
  call append(0, ["winfix search-term", "another line"])

  enew!
  file first
  let l:first = bufnr()
  call append(0, "first search-term")

  enew!
  file last
  let l:last = bufnr()
  call append(0, "last search-term")

  call setqflist(
  \  [
  \    {
  \      "filename": "first",
  \      "bufnr": l:first,
  \      "lnum": 1,
  \    },
  \    {
  \      "filename": "current",
  \      "bufnr": l:current,
  \      "lnum": 1,
  \    },
  \    {
  \      "filename": "current",
  \      "bufnr": l:current,
  \      "lnum": 2,
  \    },
  \    {
  \      "filename": "last",
  \      "bufnr": l:last,
  \      "lnum": 1,
  \    },
  \  ]
  \)

  set winfixbuf

  return [l:current, l:last]
endfunc

" Create a quickfix with at least 2 entries that are in the current 'winfixbuf' window.
func s:make_quickfix_windows()
  let [l:current, _] = s:make_simple_quickfix()
  execute "buffer! " . l:current

  split
  let l:first_window = win_getid()
  execute "normal \<C-w>j"
  let l:winfix_window = win_getid()

  " Open the quickfix in a separate split and go to it
  copen
  let l:quickfix_window = win_getid()

  return [l:first_window, l:winfix_window, l:quickfix_window]
endfunc

" Revert all changes that occurred in any past test
func s:reset_all_buffers()
  %bwipeout!
  set nowinfixbuf

  call setqflist([])
  call setloclist(0, [], 'f')

  delmarks A-Z0-9
endfunc

" Find and set the first quickfix entry that points to `buffer`
func s:set_quickfix_by_buffer(buffer)
  let l:index = 1  " quickfix indices start at 1
  for l:entry in getqflist()
    if l:entry["bufnr"] == a:buffer
      execute l:index . "cc"

      return
    endif

    let l:index += 1
  endfor

  echoerr 'No quickfix entry matching "' . a:buffer . '" could be found.'
endfunc

" Fail to call :Next on a 'winfixbuf' window unless :Next! is used.
func Test_Next()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_args_list()
  next!

  call assert_fails("Next", "E1513:")
  call assert_notequal(l:first, bufnr())

  Next!
  call assert_equal(l:first, bufnr())
endfunc

" Call :argdo and choose the next available 'nowinfixbuf' window.
func Test_argdo_choose_available_window()
  call s:reset_all_buffers()

  let [_, l:last] = s:make_args_list()

  " Make a split window that is 'nowinfixbuf' but make it the second-to-last
  " window so that :argdo will first try the 'winfixbuf' window, pass over it,
  " and prefer the other 'nowinfixbuf' window, instead.
  "
  " +-------------------+
  " |   'nowinfixbuf'   |
  " +-------------------+
  " |    'winfixbuf'    |  <-- Cursor is here
  " +-------------------+
  split
  let l:nowinfixbuf_window = win_getid()
  " Move to the 'winfixbuf' window now
  execute "normal \<C-w>j"
  let l:winfixbuf_window = win_getid()
  let l:expected_windows = s:get_windows_count()

  argdo echo ''
  call assert_equal(l:nowinfixbuf_window, win_getid())
  call assert_equal(l:last, bufnr())
  call assert_equal(l:expected_windows, s:get_windows_count())
endfunc

" Call :argdo and create a new split window if all available windows are 'winfixbuf'.
func Test_argdo_make_new_window()
  call s:reset_all_buffers()

  let [l:first, l:last] = s:make_args_list()
  let l:current = win_getid()
  let l:current_windows = s:get_windows_count()

  argdo echo ''
  call assert_notequal(l:current, win_getid())
  call assert_equal(l:last, bufnr())
  execute "normal \<C-w>j"
  call assert_equal(l:first, bufnr())
  call assert_equal(l:current_windows + 1, s:get_windows_count())
endfunc

" Fail :argedit but :argedit! is allowed
func Test_argedit()
  call s:reset_all_buffers()

  args! first middle last
  enew
  file first
  let l:first = bufnr()

  enew
  file middle
  let l:middle = bufnr()

  enew
  file last
  let l:last = bufnr()

  set winfixbuf

  let l:current = bufnr()
  call assert_fails("argedit first middle last", "E1513:")
  call assert_equal(l:current, bufnr())

  argedit! first middle last
  call assert_equal(l:first, bufnr())
endfunc

" Fail :arglocal but :arglocal! is allowed
func Test_arglocal()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()
  argglobal! other
  execute "buffer! " . l:current

  call assert_fails("arglocal other", "E1513:")
  call assert_equal(l:current, bufnr())

  arglocal! other
  call assert_equal(l:other, bufnr())
endfunc

" Fail :argglobal but :argglobal! is allowed
func Test_argglobal()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("argglobal other", "E1513:")
  call assert_equal(l:current, bufnr())

  argglobal! other
  call assert_equal(l:other, bufnr())
endfunc

" Fail :args but :args! is allowed
func Test_args()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_buffers_list()
  let l:current = bufnr()

  call assert_fails("args first middle last", "E1513:")
  call assert_equal(l:current, bufnr())

  args! first middle last
  call assert_equal(l:first, bufnr())
endfunc

" Fail :bNext but :bNext! is allowed
func Test_bNext()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  call assert_fails("bNext", "E1513:")
  let l:current = bufnr()

  call assert_equal(l:current, bufnr())

  bNext!
  call assert_equal(l:other, bufnr())
endfunc

" Allow :badd because it doesn't actually change the current window's buffer
func Test_badd()
  call s:reset_all_buffers()

  call s:make_buffer_pairs()
  let l:current = bufnr()

  badd other
  call assert_equal(l:current, bufnr())
endfunc

" Allow :balt because it doesn't actually change the current window's buffer
func Test_balt()
  call s:reset_all_buffers()

  call s:make_buffer_pairs()
  let l:current = bufnr()

  balt other
  call assert_equal(l:current, bufnr())
endfunc

" Fail :bfirst but :bfirst! is allowed
func Test_bfirst()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("bfirst", "E1513:")
  call assert_equal(l:current, bufnr())

  bfirst!
  call assert_equal(l:other, bufnr())
endfunc

" Fail :blast but :blast! is allowed
func Test_blast()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs(1)
  bfirst!
  let l:current = bufnr()

  call assert_fails("blast", "E1513:")
  call assert_equal(l:current, bufnr())

  blast!
  call assert_equal(l:other, bufnr())
endfunc

" Fail :bmodified but :bmodified! is allowed
func Test_bmodified()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  execute "buffer! " . l:other
  set modified
  execute "buffer! " . l:current

  call assert_fails("bmodified", "E1513:")
  call assert_equal(l:current, bufnr())

  bmodified!
  call assert_equal(l:other, bufnr())
endfunc

" Fail :bnext but :bnext! is allowed
func Test_bnext()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("bnext", "E1513:")
  call assert_equal(l:current, bufnr())

  bnext!
  call assert_equal(l:other, bufnr())
endfunc

" Fail :bprevious but :bprevious! is allowed
func Test_bprevious()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("bprevious", "E1513:")
  call assert_equal(l:current, bufnr())

  bprevious!
  call assert_equal(l:other, bufnr())
endfunc

" Fail :brewind but :brewind! is allowed
func Test_brewind()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("brewind", "E1513:")
  call assert_equal(l:current, bufnr())

  brewind!
  call assert_equal(l:other, bufnr())
endfunc

" Fail :browse edit but :browse edit! is allowed
func Test_browse_edit_fail()
  " A GUI dialog may stall the test.
  CheckNotGui

  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("browse edit other", "E1513:")
  call assert_equal(l:current, bufnr())

  try
    browse edit! other
    call assert_equal(l:other, bufnr())
  catch /^Vim\%((\a\+)\)\=:E338:/
    " Ignore E338, which occurs if console Vim is built with +browse.
    " Console Vim without +browse will treat this as a regular :edit.
  endtry
endfunc

" Allow :browse w because it doesn't change the buffer in the current file
func Test_browse_edit_pass()
  " A GUI dialog may stall the test.
  CheckNotGui

  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  try
    browse write other
  catch /^Vim\%((\a\+)\)\=:E338:/
    " Ignore E338, which occurs if console Vim is built with +browse.
    " Console Vim without +browse will treat this as a regular :write.
  endtry

  call delete("other")
endfunc

" Call :bufdo and choose the next available 'nowinfixbuf' window.
func Test_bufdo_choose_available_window()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()

  " Make a split window that is 'nowinfixbuf' but make it the second-to-last
  " window so that :bufdo will first try the 'winfixbuf' window, pass over it,
  " and prefer the other 'nowinfixbuf' window, instead.
  "
  " +-------------------+
  " |   'nowinfixbuf'   |
  " +-------------------+
  " |    'winfixbuf'    |  <-- Cursor is here
  " +-------------------+
  split
  let l:nowinfixbuf_window = win_getid()
  " Move to the 'winfixbuf' window now
  execute "normal \<C-w>j"
  let l:winfixbuf_window = win_getid()

  let l:current = bufnr()
  let l:expected_windows = s:get_windows_count()

  call assert_notequal(l:current, l:other)

  bufdo echo ''
  call assert_equal(l:nowinfixbuf_window, win_getid())
  call assert_notequal(l:other, bufnr())
  call assert_equal(l:expected_windows, s:get_windows_count())
endfunc

" Call :bufdo and create a new split window if all available windows are 'winfixbuf'.
func Test_bufdo_make_new_window()
  call s:reset_all_buffers()

  let [l:first, l:last] = s:make_buffers_list()
  execute "buffer! " . l:first
  let l:current = win_getid()
  let l:current_windows = s:get_windows_count()

  bufdo echo ''
  call assert_notequal(l:current, win_getid())
  call assert_equal(l:last, bufnr())
  execute "normal \<C-w>j"
  call assert_equal(l:first, bufnr())
  call assert_equal(l:current_windows + 1, s:get_windows_count())
endfunc

" Fail :buffer but :buffer! is allowed
func Test_buffer()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("buffer " . l:other, "E1513:")
  call assert_equal(l:current, bufnr())

  execute "buffer! " . l:other
  call assert_equal(l:other, bufnr())
endfunc

" Allow :buffer on a 'winfixbuf' window if there is no change in buffer
func Test_buffer_same_buffer()
  call s:reset_all_buffers()

  call s:make_buffer_pairs()
  let l:current = bufnr()

  execute "buffer " . l:current
  call assert_equal(l:current, bufnr())

  execute "buffer! " . l:current
  call assert_equal(l:current, bufnr())
endfunc

" Allow :cNext but the 'nowinfixbuf' window is selected, instead
func Test_cNext()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()

  " The call to `:cNext` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)

  cNext
  call assert_equal(l:first_window, win_getid())
endfunc

" Allow :cNfile but the 'nowinfixbuf' window is selected, instead
func Test_cNfile()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()

  " The call to `:cNfile` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))
  cnext!

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)

  cNfile
  call assert_equal(l:first_window, win_getid())
endfunc

" Allow :caddexpr because it doesn't change the current buffer
func Test_caddexpr()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let l:file_path = tempname()
  call writefile(["Error - bad-thing-found"], l:file_path, 'D')
  execute "edit " . l:file_path
  let l:file_buffer = bufnr()
  let l:current = bufnr()

  edit first.unittest
  call append(0, ["some-search-term bad-thing-found"])

  edit! other.unittest

  set winfixbuf

  execute "buffer! " . l:file_buffer

  execute 'caddexpr expand("%") .. ":" .. line(".") .. ":" .. getline(".")'
  call assert_equal(l:current, bufnr())
endfunc

" Fail :cbuffer but :cbuffer! is allowed
func Test_cbuffer()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let l:file_path = tempname()
  call writefile(["first.unittest:1:Error - bad-thing-found"], l:file_path, 'D')
  execute "edit " . l:file_path
  let l:file_buffer = bufnr()
  let l:current = bufnr()

  edit first.unittest
  call append(0, ["some-search-term bad-thing-found"])

  edit! other.unittest

  set winfixbuf

  execute "buffer! " . l:file_buffer

  call assert_fails("cbuffer " . l:file_buffer)
  call assert_equal(l:current, bufnr())

  execute "cbuffer! " . l:file_buffer
  call assert_equal("first.unittest", expand("%:t"))
endfunc

" Allow :cc but the 'nowinfixbuf' window is selected, instead
func Test_cc()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()

  " The call to `:cnext` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)
  " Go up one line in the quickfix window to an quickfix entry that doesn't
  " point to a winfixbuf buffer
  normal k
  " Attempt to make the previous window, winfixbuf buffer, to go to the
  " non-winfixbuf quickfix entry
  .cc

  " Confirm that :.cc did not change the winfixbuf-enabled window
  call assert_equal(l:first_window, win_getid())
endfunc

" Call :cdo and choose the next available 'nowinfixbuf' window.
func Test_cdo_choose_available_window()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:current, l:last] = s:make_simple_quickfix()
  execute "buffer! " . l:current

  " Make a split window that is 'nowinfixbuf' but make it the second-to-last
  " window so that :cdo will first try the 'winfixbuf' window, pass over it,
  " and prefer the other 'nowinfixbuf' window, instead.
  "
  " +-------------------+
  " |   'nowinfixbuf'   |
  " +-------------------+
  " |    'winfixbuf'    |  <-- Cursor is here
  " +-------------------+
  split
  let l:nowinfixbuf_window = win_getid()
  " Move to the 'winfixbuf' window now
  execute "normal \<C-w>j"
  let l:winfixbuf_window = win_getid()
  let l:expected_windows = s:get_windows_count()

  cdo echo ''

  call assert_equal(l:nowinfixbuf_window, win_getid())
  call assert_equal(l:last, bufnr())
  execute "normal \<C-w>j"
  call assert_equal(l:current, bufnr())
  call assert_equal(l:expected_windows, s:get_windows_count())
endfunc

" Call :cdo and create a new split window if all available windows are 'winfixbuf'.
func Test_cdo_make_new_window()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:current_buffer, l:last] = s:make_simple_quickfix()
  execute "buffer! " . l:current_buffer

  let l:current_window = win_getid()
  let l:current_windows = s:get_windows_count()

  cdo echo ''
  call assert_notequal(l:current_window, win_getid())
  call assert_equal(l:last, bufnr())
  execute "normal \<C-w>j"
  call assert_equal(l:current_buffer, bufnr())
  call assert_equal(l:current_windows + 1, s:get_windows_count())
endfunc

" Fail :cexpr but :cexpr! is allowed
func Test_cexpr()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let l:file = tempname()
  let l:entry = '["' . l:file . ':1:bar"]'
  let l:current = bufnr()

  set winfixbuf

  call assert_fails("cexpr " . l:entry)
  call assert_equal(l:current, bufnr())

  execute "cexpr! " . l:entry
  call assert_equal(fnamemodify(l:file, ":t"), expand("%:t"))
endfunc

" Call :cfdo and choose the next available 'nowinfixbuf' window.
func Test_cfdo_choose_available_window()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:current, l:last] = s:make_simple_quickfix()
  execute "buffer! " . l:current

  " Make a split window that is 'nowinfixbuf' but make it the second-to-last
  " window so that :cfdo will first try the 'winfixbuf' window, pass over it,
  " and prefer the other 'nowinfixbuf' window, instead.
  "
  " +-------------------+
  " |   'nowinfixbuf'   |
  " +-------------------+
  " |    'winfixbuf'    |  <-- Cursor is here
  " +-------------------+
  split
  let l:nowinfixbuf_window = win_getid()
  " Move to the 'winfixbuf' window now
  execute "normal \<C-w>j"
  let l:winfixbuf_window = win_getid()
  let l:expected_windows = s:get_windows_count()

  cfdo echo ''

  call assert_equal(l:nowinfixbuf_window, win_getid())
  call assert_equal(l:last, bufnr())
  execute "normal \<C-w>j"
  call assert_equal(l:current, bufnr())
  call assert_equal(l:expected_windows, s:get_windows_count())
endfunc

" Call :cfdo and create a new split window if all available windows are 'winfixbuf'.
func Test_cfdo_make_new_window()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:current_buffer, l:last] = s:make_simple_quickfix()
  execute "buffer! " . l:current_buffer

  let l:current_window = win_getid()
  let l:current_windows = s:get_windows_count()

  cfdo echo ''
  call assert_notequal(l:current_window, win_getid())
  call assert_equal(l:last, bufnr())
  execute "normal \<C-w>j"
  call assert_equal(l:current_buffer, bufnr())
  call assert_equal(l:current_windows + 1, s:get_windows_count())
endfunc

" Fail :cfile but :cfile! is allowed
func Test_cfile()
  CheckFeature quickfix
  call s:reset_all_buffers()

  edit first.unittest
  call append(0, ["some-search-term bad-thing-found"])
  write
  let l:first = bufnr()

  edit! second.unittest
  call append(0, ["some-search-term"])
  write

  let l:file = tempname()
  call writefile(["first.unittest:1:Error - bad-thing-found was detected"], l:file)

  let l:current = bufnr()

  set winfixbuf

  call assert_fails(":cfile " . l:file)
  call assert_equal(l:current, bufnr())

  execute ":cfile! " . l:file
  call assert_equal(l:first, bufnr())

  call delete(l:file)
  call delete("first.unittest")
  call delete("second.unittest")
endfunc

" Allow :cfirst but the 'nowinfixbuf' window is selected, instead
func Test_cfirst()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()

  " The call to `:cfirst` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)

  cfirst
  call assert_equal(l:first_window, win_getid())
endfunc

" Allow :clast but the 'nowinfixbuf' window is selected, instead
func Test_clast()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()

  " The call to `:clast` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)

  clast
  call assert_equal(l:first_window, win_getid())
endfunc

" Allow :cnext but the 'nowinfixbuf' window is selected, instead
" Make sure no new windows are created and previous windows are reused
func Test_cnext()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()
  let l:expected = s:get_windows_count()

  " The call to `:cnext` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))

  cnext!
  call assert_equal(l:expected, s:get_windows_count())

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)

  cnext
  call assert_equal(l:first_window, win_getid())
  call assert_equal(l:expected, s:get_windows_count())
endfunc

" Make sure :cnext creates a split window if no previous window exists
func Test_cnext_no_previous_window()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:current, _] = s:make_simple_quickfix()
  execute "buffer! " . l:current

  let l:expected = s:get_windows_count()

  " Open the quickfix in a separate split and go to it
  copen

  call assert_equal(l:expected + 1, s:get_windows_count())
endfunc

" Allow :cnext and create a 'nowinfixbuf' window if none exists
func Test_cnext_make_new_window()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:current, _] = s:make_simple_quickfix()
  let l:current = win_getid()

  cfirst!

  let l:windows = s:get_windows_count()
  let l:expected = l:windows + 1  " We're about to create a new split window

  cnext
  call assert_equal(l:expected, s:get_windows_count())

  cnext!
  call assert_equal(l:expected, s:get_windows_count())
endfunc

" Allow :cprevious but the 'nowinfixbuf' window is selected, instead
func Test_cprevious()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()

  " The call to `:cprevious` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)

  cprevious
  call assert_equal(l:first_window, win_getid())
endfunc

" Allow :cnfile but the 'nowinfixbuf' window is selected, instead
func Test_cnfile()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()

  " The call to `:cnfile` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))
  cnext!

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)

  cnfile
  call assert_equal(l:first_window, win_getid())
endfunc

" Allow :cpfile but the 'nowinfixbuf' window is selected, instead
func Test_cpfile()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()

  " The call to `:cpfile` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))
  cnext!

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)

  cpfile
  call assert_equal(l:first_window, win_getid())
endfunc

" Allow :crewind but the 'nowinfixbuf' window is selected, instead
func Test_crewind()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first_window, l:winfix_window, l:quickfix_window] = s:make_quickfix_windows()

  " The call to `:crewind` succeeds but it selects the window with 'nowinfixbuf' instead
  call s:set_quickfix_by_buffer(winbufnr(l:winfix_window))
  cnext!

  " Make sure the previous window has 'winfixbuf' so we can test that our
  " "skip 'winfixbuf' window" logic works.
  call win_gotoid(l:winfix_window)
  call win_gotoid(l:quickfix_window)

  crewind
  call assert_equal(l:first_window, win_getid())
endfunc

" Allow <C-w>f because it opens in a new split
func Test_ctrl_w_f()
  call s:reset_all_buffers()

  enew
  let l:file_name = tempname()
  call writefile([], l:file_name)
  let l:file_buffer = bufnr()

  enew
  file other
  let l:other_buffer = bufnr()

  set winfixbuf

  call setline(1, l:file_name)
  let l:current_windows = s:get_windows_count()
  execute "normal \<C-w>f"

  call assert_equal(l:current_windows + 1, s:get_windows_count())

  call delete(l:file_name)
endfunc

" Fail :djump but :djump! is allowed
func Test_djump()
  call s:reset_all_buffers()

  let l:include_file = tempname() . ".h"
  call writefile(["min(1, 12);",
        \ '#include "' . l:include_file . '"'
        \ ],
        \ "main.c")
  call writefile(["#define min(X, Y)  ((X) < (Y) ? (X) : (Y))"], l:include_file)
  edit main.c

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("djump 1 /min/", "E1513:")
  call assert_equal(l:current, bufnr())

  djump! 1 /min/
  call assert_notequal(l:current, bufnr())

  call delete("main.c")
  call delete(l:include_file)
endfunc

" Fail :drop but :drop! is allowed
func Test_drop()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("drop other", "E1513:")
  call assert_equal(l:current, bufnr())

  drop! other
  call assert_equal(l:other, bufnr())
endfunc

" Fail :edit but :edit! is allowed
func Test_edit()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("edit other", "E1513:")
  call assert_equal(l:current, bufnr())

  edit! other
  call assert_equal(l:other, bufnr())
endfunc

" Fail :e when selecting a buffer from a relative path if in a different folder
"
" In this tests there's 2 buffers
"
" foo - lives on disk, in some folder. e.g. /tmp/foo
" foo - an in-memory buffer that has not been saved to disk. If saved, it
"       would live in a different folder, /other/foo.
"
" The 'winfixbuf' is looking at the in-memory buffer and trying to switch to
" the buffer on-disk (and fails, because it's a different buffer)
func Test_edit_different_buffer_on_disk_and_relative_path_to_disk()
  call s:reset_all_buffers()

  let l:file_on_disk = tempname()
  let l:directory_on_disk1 = fnamemodify(l:file_on_disk, ":p:h")
  let l:name = fnamemodify(l:file_on_disk, ":t")
  execute "edit " . l:file_on_disk
  write!

  let l:directory_on_disk2 = l:directory_on_disk1 . "_something_else"

  if !isdirectory(l:directory_on_disk2)
    call mkdir(l:directory_on_disk2)
  endif

  execute "cd " . l:directory_on_disk2
  execute "edit " l:name

  let l:current = bufnr()

  call assert_equal(l:current, bufnr())
  set winfixbuf
  call assert_fails("edit " . l:file_on_disk, "E1513:")
  call assert_equal(l:current, bufnr())

  call delete(l:directory_on_disk1)
  call delete(l:directory_on_disk2)
endfunc

" Fail :e when selecting a buffer from a relative path if in a different folder
"
" In this tests there's 2 buffers
"
" foo - lives on disk, in some folder. e.g. /tmp/foo
" foo - an in-memory buffer that has not been saved to disk. If saved, it
"       would live in a different folder, /other/foo.
"
" The 'winfixbuf' is looking at the on-disk buffer and trying to switch to
" the in-memory buffer (and fails, because it's a different buffer)
func Test_edit_different_buffer_on_disk_and_relative_path_to_memory()
  call s:reset_all_buffers()

  let l:file_on_disk = tempname()
  let l:directory_on_disk1 = fnamemodify(l:file_on_disk, ":p:h")
  let l:name = fnamemodify(l:file_on_disk, ":t")
  execute "edit " . l:file_on_disk
  write!

  let l:directory_on_disk2 = l:directory_on_disk1 . "_something_else"

  if !isdirectory(l:directory_on_disk2)
    call mkdir(l:directory_on_disk2)
  endif

  execute "cd " . l:directory_on_disk2
  execute "edit " l:name
  execute "cd " . l:directory_on_disk1
  execute "edit " l:file_on_disk
  execute "cd " . l:directory_on_disk2

  let l:current = bufnr()

  call assert_equal(l:current, bufnr())
  set winfixbuf
  call assert_fails("edit " . l:name, "E1513:")
  call assert_equal(l:current, bufnr())

  call delete(l:directory_on_disk1)
  call delete(l:directory_on_disk2)
endfunc

" Fail to call `:e first` if called from a starting, in-memory buffer
func Test_edit_first_buffer()
  call s:reset_all_buffers()

  set winfixbuf
  let l:current = bufnr()

  call assert_fails("edit first", "E1513:")
  call assert_equal(l:current, bufnr())

  edit! first
  call assert_equal(l:current, bufnr())
  edit! somewhere_else
  call assert_notequal(l:current, bufnr())
endfunc

" Allow reloading a buffer using :e
func Test_edit_no_arguments()
  call s:reset_all_buffers()

  let l:current = bufnr()
  file some_buffer

  call assert_equal(l:current, bufnr())
  set winfixbuf
  edit
  call assert_equal(l:current, bufnr())
endfunc

" Allow :e selecting the current buffer
func Test_edit_same_buffer_in_memory()
  call s:reset_all_buffers()

  let current = bufnr()
  file same_buffer

  call assert_equal(current, bufnr())
  set winfixbuf
  edit same_buffer
  call assert_equal(current, bufnr())
  set nowinfixbuf
endfunc

" Allow :e selecting the current buffer as a full path
func Test_edit_same_buffer_on_disk_absolute_path()
  call s:reset_all_buffers()

  let file = tempname()
  " file must exist for expansion of 8.3 paths to succeed
  call writefile([], file, 'D')
  let file = fnamemodify(file, ':p')
  let current = bufnr()
  execute "edit " . file
  write!

  call assert_equal(current, bufnr())
  set winfixbuf
  execute "edit " file
  call assert_equal(current, bufnr())

  set nowinfixbuf
endfunc

" Fail :enew but :enew! is allowed
func Test_enew()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("enew", "E1513:")
  call assert_equal(l:current, bufnr())

  enew!
  call assert_notequal(l:other, bufnr())
  call assert_notequal(3, bufnr())
endfunc

" Fail :ex but :ex! is allowed
func Test_ex()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("ex other", "E1513:")
  call assert_equal(l:current, bufnr())

  ex! other
  call assert_equal(l:other, bufnr())
endfunc

" Fail :find but :find! is allowed
func Test_find()
  call s:reset_all_buffers()

  let l:current = bufnr()
  let l:file = tempname()
  call writefile([], l:file, 'D')
  let l:file = fnamemodify(l:file, ':p')  " In case it's Windows 8.3-style.
  let l:directory = fnamemodify(l:file, ":p:h")
  let l:name = fnamemodify(l:file, ":p:t")

  let l:original_path = &path
  execute "set path=" . l:directory

  set winfixbuf

  call assert_fails("execute 'find " . l:name . "'", "E1513:")
  call assert_equal(l:current, bufnr())

  execute "find! " . l:name
  call assert_equal(l:file, expand("%:p"))

  execute "set path=" . l:original_path
endfunc

" Fail :first but :first! is allowed
func Test_first()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_args_list()
  next!

  call assert_fails("first", "E1513:")
  call assert_notequal(l:first, bufnr())

  first!
  call assert_equal(l:first, bufnr())
endfunc

" Fail :grep but :grep! is allowed
func Test_grep()
  CheckFeature quickfix
  call s:reset_all_buffers()

  edit first.unittest
  call append(0, ["some-search-term"])
  write
  let l:first = bufnr()

  edit current.unittest
  call append(0, ["some-search-term"])
  write
  let l:current = bufnr()

  edit! last.unittest
  call append(0, ["some-search-term"])
  write
  let l:last = bufnr()

  set winfixbuf

  buffer! current.unittest

  call assert_fails("silent! grep some-search-term *.unittest", "E1513:")
  call assert_equal(l:current, bufnr())
  execute "edit! " . l:first

  silent! grep! some-search-term *.unittest
  call assert_notequal(l:first, bufnr())

  call delete("first.unittest")
  call delete("current.unittest")
  call delete("last.unittest")
endfunc

" Fail :ijump but :ijump! is allowed
func Test_ijump()
  call s:reset_all_buffers()

  let l:include_file = tempname() . ".h"
  call writefile([
        \ '#include "' . l:include_file . '"'
        \ ],
        \ "main.c", 'D')
  call writefile(["#define min(X, Y)  ((X) < (Y) ? (X) : (Y))"], l:include_file, 'D')
  edit main.c

  set winfixbuf

  let l:current = bufnr()

  set define=^\\s*#\\s*define
  set include=^\\s*#\\s*include
  set path=.,/usr/include,,

  call assert_fails("ijump /min/", "E1513:")
  call assert_equal(l:current, bufnr())

  set nowinfixbuf

  ijump! /min/
  call assert_notequal(l:current, bufnr())

  set define&
  set include&
  set path&
endfunc

" Fail :lNext but :lNext! is allowed
func Test_lNext()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, l:middle, _] = s:make_simple_location_list()
  call assert_equal(1, getloclist(0, #{idx: 0}).idx)

  lnext!
  call assert_equal(2, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:middle, bufnr())

  call assert_fails("lNext", "E1513:")
  " Ensure the entry didn't change.
  call assert_equal(2, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:middle, bufnr())

  lnext!
  call assert_equal(3, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:middle, bufnr())

  lNext!
  call assert_equal(2, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:middle, bufnr())

  lNext!
  call assert_equal(1, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:first, bufnr())
endfunc

" Fail :lNfile but :lNfile! is allowed
func Test_lNfile()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, l:current, _] = s:make_simple_location_list()
  call assert_equal(1, getloclist(0, #{idx: 0}).idx)

  lnext!
  call assert_equal(2, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:current, bufnr())

  call assert_fails("lNfile", "E1513:")
  " Ensure the entry didn't change.
  call assert_equal(2, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:current, bufnr())

  lnext!
  call assert_equal(3, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:current, bufnr())

  lNfile!
  call assert_equal(1, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:first, bufnr())
endfunc

" Allow :laddexpr because it doesn't change the current buffer
func Test_laddexpr()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let l:file_path = tempname()
  call writefile(["Error - bad-thing-found"], l:file_path, 'D')
  execute "edit " . l:file_path
  let l:file_buffer = bufnr()
  let l:current = bufnr()

  edit first.unittest
  call append(0, ["some-search-term bad-thing-found"])

  edit! other.unittest

  set winfixbuf

  execute "buffer! " . l:file_buffer

  execute 'laddexpr expand("%") .. ":" .. line(".") .. ":" .. getline(".")'
  call assert_equal(l:current, bufnr())
endfunc

" Fail :last but :last! is allowed
func Test_last()
  call s:reset_all_buffers()

  let [_, l:last] = s:make_args_list()
  next!

  call assert_fails("last", "E1513:")
  call assert_notequal(l:last, bufnr())

  last!
  call assert_equal(l:last, bufnr())
endfunc

" Fail :lbuffer but :lbuffer! is allowed
func Test_lbuffer()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let l:file_path = tempname()
  call writefile(["first.unittest:1:Error - bad-thing-found"], l:file_path, 'D')
  execute "edit " . l:file_path
  let l:file_buffer = bufnr()
  let l:current = bufnr()

  edit first.unittest
  call append(0, ["some-search-term bad-thing-found"])

  edit! other.unittest

  set winfixbuf

  execute "buffer! " . l:file_buffer

  call assert_fails("lbuffer " . l:file_buffer)
  call assert_equal(l:current, bufnr())

  execute "lbuffer! " . l:file_buffer
  call assert_equal("first.unittest", expand("%:t"))
endfunc

" Fail :ldo but :ldo! is allowed
func Test_ldo()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, l:middle, l:last] = s:make_simple_location_list()
  lnext!

  call assert_fails('execute "ldo buffer ' . l:first . '"', "E1513:")
  call assert_equal(l:middle, bufnr())
  execute "ldo! buffer " . l:first
  call assert_notequal(l:last, bufnr())
endfunc

" Fail :lfdo but :lfdo! is allowed
func Test_lexpr()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let l:file = tempname()
  let l:entry = '["' . l:file . ':1:bar"]'
  let l:current = bufnr()

  set winfixbuf

  call assert_fails("lexpr " . l:entry)
  call assert_equal(l:current, bufnr())

  execute "lexpr! " . l:entry
  call assert_equal(fnamemodify(l:file, ":t"), expand("%:t"))
endfunc

" Fail :lfdo but :lfdo! is allowed
func Test_lfdo()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, l:middle, l:last] = s:make_simple_location_list()
  lnext!

  call assert_fails('execute "lfdo buffer ' . l:first . '"', "E1513:")
  call assert_equal(l:middle, bufnr())
  execute "lfdo! buffer " . l:first
  call assert_notequal(l:last, bufnr())
endfunc

" Fail :lfile but :lfile! is allowed
func Test_lfile()
  CheckFeature quickfix
  call s:reset_all_buffers()

  edit first.unittest
  call append(0, ["some-search-term bad-thing-found"])
  write
  let l:first = bufnr()

  edit! second.unittest
  call append(0, ["some-search-term"])
  write

  let l:file = tempname()
  call writefile(["first.unittest:1:Error - bad-thing-found was detected"], l:file, 'D')

  let l:current = bufnr()

  set winfixbuf

  call assert_fails(":lfile " . l:file)
  call assert_equal(l:current, bufnr())

  execute ":lfile! " . l:file
  call assert_equal(l:first, bufnr())

  call delete("first.unittest")
  call delete("second.unittest")
endfunc

" Fail :ll but :ll! is allowed
func Test_ll()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, l:middle, l:last] = s:make_simple_location_list()
  lopen
  lfirst!
  execute "normal \<C-w>j"
  normal j

  call assert_fails(".ll", "E1513:")
  execute "normal \<C-w>k"
  call assert_equal(l:first, bufnr())
  execute "normal \<C-w>j"
  .ll!
  execute "normal \<C-w>k"
  call assert_equal(l:middle, bufnr())
endfunc

" Fail :llast but :llast! is allowed
func Test_llast()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, _, l:last] = s:make_simple_location_list()
  lfirst!

  call assert_fails("llast", "E1513:")
  call assert_equal(l:first, bufnr())

  llast!
  call assert_equal(l:last, bufnr())
endfunc

" Fail :lnext but :lnext! is allowed
func Test_lnext()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, l:middle, l:last] = s:make_simple_location_list()
  ll!

  call assert_fails("lnext", "E1513:")
  call assert_equal(l:first, bufnr())

  lnext!
  call assert_equal(l:middle, bufnr())
endfunc

" Fail :lnfile but :lnfile! is allowed
func Test_lnfile()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [_, l:current, l:last] = s:make_simple_location_list()
  call assert_equal(1, getloclist(0, #{idx: 0}).idx)

  lnext!
  call assert_equal(2, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:current, bufnr())

  call assert_fails("lnfile", "E1513:")
  " Ensure the entry didn't change.
  call assert_equal(2, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:current, bufnr())

  lnfile!
  call assert_equal(4, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:last, bufnr())
endfunc

" Fail :lpfile but :lpfile! is allowed
func Test_lpfile()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, l:current, _] = s:make_simple_location_list()
  lnext!

  call assert_fails("lpfile", "E1513:")
  call assert_equal(l:current, bufnr())

  lnext!  " Reset for the next test call

  lpfile!
  call assert_equal(l:first, bufnr())
endfunc

" Fail :lprevious but :lprevious! is allowed
func Test_lprevious()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, l:middle, _] = s:make_simple_location_list()
  call assert_equal(1, getloclist(0, #{idx: 0}).idx)

  lnext!
  call assert_equal(2, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:middle, bufnr())

  call assert_fails("lprevious", "E1513:")
  " Ensure the entry didn't change.
  call assert_equal(2, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:middle, bufnr())

  lprevious!
  call assert_equal(1, getloclist(0, #{idx: 0}).idx)
  call assert_equal(l:first, bufnr())
endfunc

" Fail :lrewind but :lrewind! is allowed
func Test_lrewind()
  CheckFeature quickfix
  call s:reset_all_buffers()

  let [l:first, l:middle, _] = s:make_simple_location_list()
  lnext!

  call assert_fails("lrewind", "E1513:")
  call assert_equal(l:middle, bufnr())

  lrewind!
  call assert_equal(l:first, bufnr())
endfunc

" Fail :ltag but :ltag! is allowed
func Test_ltag()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother
  execute "normal \<C-]>"

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("ltag one", "E1513:")

  ltag! one

  set tags&
endfunc

" Fail vim.cmd if we try to change buffers while 'winfixbuf' is set
func Test_lua_command()
  " CheckFeature lua
  call s:reset_all_buffers()

  enew
  file first
  let l:previous = bufnr()

  enew
  file second
  let l:current = bufnr()

  set winfixbuf

  call assert_fails('lua vim.cmd("buffer " .. ' . l:previous . ')')
  call assert_equal(l:current, bufnr())

  execute 'lua vim.cmd("buffer! " .. ' . l:previous . ')'
  call assert_equal(l:previous, bufnr())
endfunc

" Fail :lvimgrep but :lvimgrep! is allowed
func Test_lvimgrep()
  CheckFeature quickfix
  call s:reset_all_buffers()

  edit first.unittest
  call append(0, ["some-search-term"])
  write

  edit winfix.unittest
  call append(0, ["some-search-term"])
  write
  let l:current = bufnr()

  set winfixbuf

  edit! last.unittest
  call append(0, ["some-search-term"])
  write
  let l:last = bufnr()

  buffer! winfix.unittest

  call assert_fails("lvimgrep /some-search-term/ *.unittest", "E1513:")
  call assert_equal(l:current, bufnr())

  lvimgrep! /some-search-term/ *.unittest
  call assert_notequal(l:current, bufnr())

  call delete("first.unittest")
  call delete("winfix.unittest")
  call delete("last.unittest")
endfunc

" Fail :lvimgrepadd but :lvimgrepadd! is allowed
func Test_lvimgrepadd()
  CheckFeature quickfix
  call s:reset_all_buffers()

  edit first.unittest
  call append(0, ["some-search-term"])
  write

  edit winfix.unittest
  call append(0, ["some-search-term"])
  write
  let l:current = bufnr()

  set winfixbuf

  edit! last.unittest
  call append(0, ["some-search-term"])
  write
  let l:last = bufnr()

  buffer! winfix.unittest

  call assert_fails("lvimgrepadd /some-search-term/ *.unittest")
  call assert_equal(l:current, bufnr())

  lvimgrepadd! /some-search-term/ *.unittest
  call assert_notequal(l:current, bufnr())

  call delete("first.unittest")
  call delete("winfix.unittest")
  call delete("last.unittest")
endfunc

" Don't allow global marks to change the current 'winfixbuf' window
func Test_marks_mappings_fail()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()
  execute "buffer! " . l:other
  normal mA
  execute "buffer! " . l:current
  normal mB

  call assert_fails("normal `A", "E1513:")
  call assert_equal(l:current, bufnr())

  call assert_fails("normal 'A", "E1513:")
  call assert_equal(l:current, bufnr())

  set nowinfixbuf

  normal `A
  call assert_equal(l:other, bufnr())
endfunc

" Allow global marks in a 'winfixbuf' window if the jump is the same buffer
func Test_marks_mappings_pass_intra_move()
  call s:reset_all_buffers()

  let l:current = bufnr()
  call append(0, ["some line", "another line"])
  normal mA
  normal j
  normal mB

  set winfixbuf

  normal `A
  call assert_equal(l:current, bufnr())
endfunc

" Fail :next but :next! is allowed
func Test_next()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_args_list()
  first!

  call assert_fails("next", "E1513:")
  call assert_equal(l:first, bufnr())

  next!
  call assert_notequal(l:first, bufnr())
endfunc

" Ensure :mksession saves 'winfixbuf' details
func Test_mksession()
  CheckFeature mksession
  call s:reset_all_buffers()

  set sessionoptions+=options
  set winfixbuf

  mksession test_winfixbuf_Test_mksession.vim

  call s:reset_all_buffers()
  let l:winfixbuf = &winfixbuf
  call assert_equal(0, l:winfixbuf)

  source test_winfixbuf_Test_mksession.vim

  let l:winfixbuf = &winfixbuf
  call assert_equal(1, l:winfixbuf)

  set sessionoptions&
  call delete("test_winfixbuf_Test_mksession.vim")
endfunc

" Allow :next if the next index is the same as the current buffer
func Test_next_same_buffer()
  call s:reset_all_buffers()

  enew
  file foo
  enew
  file bar
  enew
  file fizz
  enew
  file buzz
  args foo foo bar fizz buzz

  edit foo
  set winfixbuf
  let l:current = bufnr()

  " Allow :next because the args list is `[foo] foo bar fizz buzz
  next
  call assert_equal(l:current, bufnr())

  " Fail :next because the args list is `foo [foo] bar fizz buzz
  " and the next buffer would be bar, which is a different buffer
  call assert_fails("next", "E1513:")
  call assert_equal(l:current, bufnr())
endfunc

" Fail to jump to a tag with g<C-]> if 'winfixbuf' is enabled
func Test_normal_g_ctrl_square_bracket_right()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal g\<C-]>", "E1513:")
  call assert_equal(l:current, bufnr())

  set tags&
endfunc

" Fail to jump to a tag with g<RightMouse> if 'winfixbuf' is enabled
func Test_normal_g_rightmouse()
  call s:reset_all_buffers()
  set mouse=n

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother
  execute "normal \<C-]>"

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal g\<RightMouse>", "E1513:")
  call assert_equal(l:current, bufnr())

  set tags&
  set mouse&
endfunc

" Fail to jump to a tag with g] if 'winfixbuf' is enabled
func Test_normal_g_square_bracket_right()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal g]", "E1513:")
  call assert_equal(l:current, bufnr())

  set tags&
endfunc

" Fail to jump to a tag with <C-RightMouse> if 'winfixbuf' is enabled
func Test_normal_ctrl_rightmouse()
  call s:reset_all_buffers()
  set mouse=n

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother
  execute "normal \<C-]>"

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal \<C-RightMouse>", "E1513:")
  call assert_equal(l:current, bufnr())

  set tags&
  set mouse&
endfunc

" Fail to jump to a tag with <C-t> if 'winfixbuf' is enabled
func Test_normal_ctrl_t()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother
  execute "normal \<C-]>"

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal \<C-t>", "E1513:")
  call assert_equal(l:current, bufnr())

  set tags&
endfunc

" Disallow <C-^> in 'winfixbuf' windows
func Test_normal_ctrl_hat()
  call s:reset_all_buffers()
  clearjumps

  enew
  file first
  let l:first = bufnr()

  enew
  file current
  let l:current = bufnr()

  set winfixbuf

  call assert_fails("normal \<C-^>", "E1513:")
  call assert_equal(l:current, bufnr())
endfunc

" Allow <C-i> in 'winfixbuf' windows if the movement stays within the buffer
func Test_normal_ctrl_i_pass()
  call s:reset_all_buffers()
  clearjumps

  enew
  file first
  let l:first = bufnr()

  enew!
  file current
  let l:current = bufnr()
  " Add some lines so we can populate a jumplist"
  call append(0, ["some line", "another line"])
  " Add an entry to the jump list
  " Go up another line
  normal m`
  normal k
  execute "normal \<C-o>"

  set winfixbuf

  let l:line = getcurpos()[1]
  execute "normal 1\<C-i>"
  call assert_notequal(l:line, getcurpos()[1])
endfunc

" Disallow <C-o> in 'winfixbuf' windows if it would cause the buffer to switch
func Test_normal_ctrl_o_fail()
  call s:reset_all_buffers()
  clearjumps

  enew
  file first
  let l:first = bufnr()

  enew
  file current
  let l:current = bufnr()

  set winfixbuf

  call assert_fails("normal \<C-o>", "E1513:")
  call assert_equal(l:current, bufnr())
endfunc

" Allow <C-o> in 'winfixbuf' windows if the movement stays within the buffer
func Test_normal_ctrl_o_pass()
  call s:reset_all_buffers()
  clearjumps

  enew
  file first
  let l:first = bufnr()

  enew!
  file current
  let l:current = bufnr()
  " Add some lines so we can populate a jumplist
  call append(0, ["some line", "another line"])
  " Add an entry to the jump list
  " Go up another line
  normal m`
  normal k

  set winfixbuf

  execute "normal \<C-o>"
  call assert_equal(l:current, bufnr())
endfunc

" Fail to jump to a tag with <C-]> if 'winfixbuf' is enabled
func Test_normal_ctrl_square_bracket_right()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal \<C-]>", "E1513:")
  call assert_equal(l:current, bufnr())

  set tags&
endfunc

" Allow <C-w><C-]> with 'winfixbuf' enabled because it runs in a new, split window
func Test_normal_ctrl_w_ctrl_square_bracket_right()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current_windows = s:get_windows_count()
  execute "normal \<C-w>\<C-]>"
  call assert_equal(l:current_windows + 1, s:get_windows_count())

  set tags&
endfunc

" Allow <C-w>g<C-]> with 'winfixbuf' enabled because it runs in a new, split window
func Test_normal_ctrl_w_g_ctrl_square_bracket_right()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current_windows = s:get_windows_count()
  execute "normal \<C-w>g\<C-]>"
  call assert_equal(l:current_windows + 1, s:get_windows_count())

  set tags&
endfunc

" Fail to jump to a tag with <C-]> if 'winfixbuf' is enabled
func Test_normal_gt()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one", "two", "three"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal \<C-]>", "E1513:")
  call assert_equal(l:current, bufnr())

  set tags&
endfunc

" Prevent gF from switching a 'winfixbuf' window's buffer
func Test_normal_gF()
  call s:reset_all_buffers()

  let l:file = tempname()
  call append(0, [l:file])
  call writefile([], l:file, 'D')
  " Place the cursor onto the line that has `l:file`
  normal gg
  " Prevent Vim from erroring with "No write since last change @ command
  " line" when we try to call gF, later.
  set hidden

  set winfixbuf

  let l:buffer = bufnr()

  call assert_fails("normal gF", "E1513:")
  call assert_equal(l:buffer, bufnr())

  set nowinfixbuf

  normal gF
  call assert_notequal(l:buffer, bufnr())

  set nohidden
endfunc

" Prevent gf from switching a 'winfixbuf' window's buffer
func Test_normal_gf()
  call s:reset_all_buffers()

  let l:file = tempname()
  call append(0, [l:file])
  call writefile([], l:file, 'D')
  " Place the cursor onto the line that has `l:file`
  normal gg
  " Prevent Vim from erroring with "No write since last change @ command
  " line" when we try to call gf, later.
  set hidden

  set winfixbuf

  let l:buffer = bufnr()

  call assert_fails("normal gf", "E1513:")
  call assert_equal(l:buffer, bufnr())

  set nowinfixbuf

  normal gf
  call assert_notequal(l:buffer, bufnr())

  set nohidden
endfunc

" Fail "goto file under the cursor" (using [f, which is the same as `:normal gf`)
func Test_normal_square_bracket_left_f()
  call s:reset_all_buffers()

  let l:file = tempname()
  call append(0, [l:file])
  call writefile([], l:file, 'D')
  " Place the cursor onto the line that has `l:file`
  normal gg
  " Prevent Vim from erroring with "No write since last change @ command
  " line" when we try to call gf, later.
  set hidden

  set winfixbuf

  let l:buffer = bufnr()

  call assert_fails("normal [f", "E1513:")
  call assert_equal(l:buffer, bufnr())

  set nowinfixbuf

  normal [f
  call assert_notequal(l:buffer, bufnr())

  set nohidden
endfunc

" Fail to go to a C macro with [<C-d> if 'winfixbuf' is enabled
func Test_normal_square_bracket_left_ctrl_d()
  call s:reset_all_buffers()

  let l:include_file = tempname() . ".h"
  call writefile(["min(1, 12);",
        \ '#include "' . l:include_file . '"'
        \ ],
        \ "main.c", 'D')
  call writefile(["#define min(X, Y)  ((X) < (Y) ? (X) : (Y))"], l:include_file, 'D')
  edit main.c
  normal ]\<C-d>

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal [\<C-d>", "E1513:")
  call assert_equal(l:current, bufnr())

  set nowinfixbuf

  execute "normal [\<C-d>"
  call assert_notequal(l:current, bufnr())
endfunc

" Fail to go to a C macro with ]<C-d> if 'winfixbuf' is enabled
func Test_normal_square_bracket_right_ctrl_d()
  call s:reset_all_buffers()

  let l:include_file = tempname() . ".h"
  call writefile(["min(1, 12);",
        \ '#include "' . l:include_file . '"'
        \ ],
        \ "main.c", 'D')
  call writefile(["#define min(X, Y)  ((X) < (Y) ? (X) : (Y))"], l:include_file, 'D')
  edit main.c

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal ]\<C-d>", "E1513:")
  call assert_equal(l:current, bufnr())

  set nowinfixbuf

  execute "normal ]\<C-d>"
  call assert_notequal(l:current, bufnr())
endfunc

" Fail to go to a C macro with [<C-i> if 'winfixbuf' is enabled
func Test_normal_square_bracket_left_ctrl_i()
  call s:reset_all_buffers()

  let l:include_file = tempname() . ".h"
  call writefile(['#include "' . l:include_file . '"',
        \ "min(1, 12);",
        \ ],
        \ "main.c", 'D')
  call writefile(["#define min(X, Y)  ((X) < (Y) ? (X) : (Y))"], l:include_file, 'D')
  edit main.c
  " Move to the line with `min(1, 12);` on it"
  normal j

  set define=^\\s*#\\s*define
  set include=^\\s*#\\s*include
  set path=.,/usr/include,,

  let l:current = bufnr()

  set winfixbuf

  call assert_fails("normal [\<C-i>", "E1513:")

  set nowinfixbuf

  execute "normal [\<C-i>"
  call assert_notequal(l:current, bufnr())

  set define&
  set include&
  set path&
endfunc

" Fail to go to a C macro with ]<C-i> if 'winfixbuf' is enabled
func Test_normal_square_bracket_right_ctrl_i()
  call s:reset_all_buffers()

  let l:include_file = tempname() . ".h"
  call writefile(["min(1, 12);",
        \ '#include "' . l:include_file . '"'
        \ ],
        \ "main.c", 'D')
  call writefile(["#define min(X, Y)  ((X) < (Y) ? (X) : (Y))"], l:include_file, 'D')
  edit main.c

  set winfixbuf

  set define=^\\s*#\\s*define
  set include=^\\s*#\\s*include
  set path=.,/usr/include,,

  let l:current = bufnr()

  call assert_fails("normal ]\<C-i>", "E1513:")
  call assert_equal(l:current, bufnr())

  set nowinfixbuf

  execute "normal ]\<C-i>"
  call assert_notequal(l:current, bufnr())

  set define&
  set include&
  set path&
endfunc

" Fail "goto file under the cursor" (using ]f, which is the same as `:normal gf`)
func Test_normal_square_bracket_right_f()
  call s:reset_all_buffers()

  let l:file = tempname()
  call append(0, [l:file])
  call writefile([], l:file, 'D')
  " Place the cursor onto the line that has `l:file`
  normal gg
  " Prevent Vim from erroring with "No write since last change @ command
  " line" when we try to call gf, later.
  set hidden

  set winfixbuf

  let l:buffer = bufnr()

  call assert_fails("normal ]f", "E1513:")
  call assert_equal(l:buffer, bufnr())

  set nowinfixbuf

  normal ]f
  call assert_notequal(l:buffer, bufnr())

  set nohidden
endfunc

" Fail to jump to a tag with v<C-]> if 'winfixbuf' is enabled
func Test_normal_v_ctrl_square_bracket_right()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal v\<C-]>", "E1513:")
  call assert_equal(l:current, bufnr())

  set tags&
endfunc

" Fail to jump to a tag with vg<C-]> if 'winfixbuf' is enabled
func Test_normal_v_g_ctrl_square_bracket_right()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("normal vg\<C-]>", "E1513:")
  call assert_equal(l:current, bufnr())

  set tags&
endfunc

" Allow :pedit because, unlike :edit, it uses a separate window
func Test_pedit()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()

  pedit other

  execute "normal \<C-w>w"
  call assert_equal(l:other, bufnr())
endfunc

" Fail :pop but :pop! is allowed
func Test_pop()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "thesame\tXfile\t1;\"\td\tfile:",
        \ "thesame\tXfile\t2;\"\td\tfile:",
        \ "thesame\tXfile\t3;\"\td\tfile:",
        \ ],
        \ "Xtags", 'D')
  call writefile(["thesame one", "thesame two", "thesame three"], "Xfile", 'D')
  call writefile(["thesame one"], "Xother", 'D')
  edit Xother

  tag thesame

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("pop", "E1513:")
  call assert_equal(l:current, bufnr())

  pop!
  call assert_notequal(l:current, bufnr())

  set tags&
endfunc

" Fail :previous but :previous! is allowed
func Test_previous()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_args_list()
  next!

  call assert_fails("previous", "E1513:")
  call assert_notequal(l:first, bufnr())

  previous!
  call assert_equal(l:first, bufnr())
endfunc

" Fail pyxdo if it changes a window with 'winfixbuf' is set
func Test_pythonx_pyxdo()
  CheckFeature pythonx
  call s:reset_all_buffers()

  enew
  file first
  let g:_previous_buffer = bufnr()

  enew
  file second

  set winfixbuf

  pythonx << EOF
import vim

def test_winfixbuf_Test_pythonx_pyxdo_set_buffer():
    buffer = vim.vars['_previous_buffer']
    vim.current.buffer = vim.buffers[buffer]
EOF

  try
    pyxdo test_winfixbuf_Test_pythonx_pyxdo_set_buffer()
  catch /pynvim\.api\.common\.NvimError: E1513:/
    let l:caught = 1
  endtry

  call assert_equal(1, l:caught)

  unlet g:_previous_buffer
endfunc

" Fail pyxfile if it changes a window with 'winfixbuf' is set
func Test_pythonx_pyxfile()
  CheckFeature pythonx
  call s:reset_all_buffers()

  enew
  file first
  let g:_previous_buffer = bufnr()

  enew
  file second

  set winfixbuf

  call writefile(["import vim",
        \ "buffer = vim.vars['_previous_buffer']",
        \ "vim.current.buffer = vim.buffers[buffer]",
        \ ],
        \ "file.py", 'D')

  try
    pyxfile file.py
  catch /pynvim\.api\.common\.NvimError: E1513:/
    let l:caught = 1
  endtry

  call assert_equal(1, l:caught)

  unlet g:_previous_buffer
endfunc

" Fail vim.current.buffer if 'winfixbuf' is set
func Test_pythonx_vim_current_buffer()
  CheckFeature pythonx
  call s:reset_all_buffers()

  enew
  file first
  let g:_previous_buffer = bufnr()

  enew
  file second

  let l:caught = 0

  set winfixbuf

  try
    pythonx << EOF
import vim

buffer = vim.vars["_previous_buffer"]
vim.current.buffer = vim.buffers[buffer]
EOF
  catch /pynvim\.api\.common\.NvimError: E1513:/
    let l:caught = 1
  endtry

  call assert_equal(1, l:caught)
  unlet g:_previous_buffer
endfunc

" Ensure remapping to a disabled action still triggers failures
func Test_remap_key_fail()
  call s:reset_all_buffers()

  enew
  file first
  let l:first = bufnr()

  enew
  file current
  let l:current = bufnr()

  set winfixbuf

  nnoremap g <C-^>

  call assert_fails("normal g", "E1513:")
  call assert_equal(l:current, bufnr())

  nunmap g
endfunc

" Ensure remapping a disabled key to something valid does trigger any failures
func Test_remap_key_pass()
  call s:reset_all_buffers()

  enew
  file first
  let l:first = bufnr()

  enew
  file current
  let l:current = bufnr()

  set winfixbuf

  call assert_fails("normal \<C-^>", "E1513:")
  call assert_equal(l:current, bufnr())

  " Disallow <C-^> by default but allow it if the command does something else
  nnoremap <C-^> :echo "hello!"

  execute "normal \<C-^>"
  call assert_equal(l:current, bufnr())

  nunmap <C-^>
endfunc

" Fail :rewind but :rewind! is allowed
func Test_rewind()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_args_list()
  next!

  call assert_fails("rewind", "E1513:")
  call assert_notequal(l:first, bufnr())

  rewind!
  call assert_equal(l:first, bufnr())
endfunc

" Allow :sblast because it opens the buffer in a new, split window
func Test_sblast()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs(1)
  bfirst!
  let l:current = bufnr()

  sblast
  call assert_equal(l:other, bufnr())
endfunc

" Fail :sbprevious but :sbprevious! is allowed
func Test_sbprevious()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  sbprevious
  call assert_equal(l:other, bufnr())
endfunc

" Make sure 'winfixbuf' can be set using 'winfixbuf' or 'wfb'
func Test_short_option()
  call s:reset_all_buffers()

  call s:make_buffer_pairs()

  set winfixbuf
  call assert_fails("edit something_else", "E1513:")

  set nowinfixbuf
  set wfb
  call assert_fails("edit another_place", "E1513:")

  set nowfb
  edit last_place
endfunc

" Allow :snext because it makes a new window
func Test_snext()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_args_list()
  first!

  let l:current_window = win_getid()

  snext
  call assert_notequal(l:current_window, win_getid())
  call assert_notequal(l:first, bufnr())
endfunc

" Ensure the first has 'winfixbuf' and a new split window is 'nowinfixbuf'
func Test_split_window()
  call s:reset_all_buffers()

  split
  execute "normal \<C-w>j"

  set winfixbuf

  let l:winfix_window_1 = win_getid()
  vsplit
  let l:winfix_window_2 = win_getid()

  call assert_equal(1, getwinvar(l:winfix_window_1, "&winfixbuf"))
  call assert_equal(0, getwinvar(l:winfix_window_2, "&winfixbuf"))
endfunc

" Fail :tNext but :tNext! is allowed
func Test_tNext()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "thesame\tXfile\t1;\"\td\tfile:",
        \ "thesame\tXfile\t2;\"\td\tfile:",
        \ "thesame\tXfile\t3;\"\td\tfile:",
        \ ],
        \ "Xtags", 'D')
  call writefile(["thesame one", "thesame two", "thesame three"], "Xfile", 'D')
  call writefile(["thesame one"], "Xother", 'D')
  edit Xother

  tag thesame
  execute "normal \<C-^>"
  tnext!

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("tNext", "E1513:")
  call assert_equal(l:current, bufnr())

  tNext!

  set tags&
endfunc

" Call :tabdo and choose the next available 'nowinfixbuf' window.
func Test_tabdo_choose_available_window()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_args_list()

  " Make a split window that is 'nowinfixbuf' but make it the second-to-last
  " window so that :tabdo will first try the 'winfixbuf' window, pass over it,
  " and prefer the other 'nowinfixbuf' window, instead.
  "
  " +-------------------+
  " |   'nowinfixbuf'   |
  " +-------------------+
  " |    'winfixbuf'    |  <-- Cursor is here
  " +-------------------+
  split
  let l:nowinfixbuf_window = win_getid()
  " Move to the 'winfixbuf' window now
  execute "normal \<C-w>j"
  let l:winfixbuf_window = win_getid()

  let l:expected_windows = s:get_windows_count()
  tabdo echo ''
  call assert_equal(l:nowinfixbuf_window, win_getid())
  call assert_equal(l:first, bufnr())
  call assert_equal(l:expected_windows, s:get_windows_count())
endfunc

" Call :tabdo and create a new split window if all available windows are 'winfixbuf'.
func Test_tabdo_make_new_window()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_buffers_list()
  execute "buffer! " . l:first

  let l:current = win_getid()
  let l:current_windows = s:get_windows_count()

  tabdo echo ''
  call assert_notequal(l:current, win_getid())
  call assert_equal(l:first, bufnr())
  execute "normal \<C-w>j"
  call assert_equal(l:first, bufnr())
  call assert_equal(l:current_windows + 1, s:get_windows_count())
endfunc

" Fail :tag but :tag! is allowed
func Test_tag()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("tag one", "E1513:")
  call assert_equal(l:current, bufnr())

  tag! one
  call assert_notequal(l:current, bufnr())

  set tags&
endfunc


" Fail :tfirst but :tfirst! is allowed
func Test_tfirst()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  tag one
  edit Xother

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("tfirst", "E1513:")
  call assert_equal(l:current, bufnr())

  tfirst!
  call assert_notequal(l:current, bufnr())

  set tags&
endfunc

" Fail :tjump but :tjump! is allowed
func Test_tjump()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  call writefile(["one"], "Xother", 'D')
  edit Xother

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("tjump one", "E1513:")
  call assert_equal(l:current, bufnr())

  tjump! one
  call assert_notequal(l:current, bufnr())

  set tags&
endfunc

" Fail :tlast but :tlast! is allowed
func Test_tlast()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "one\tXfile\t1",
        \ "three\tXfile\t3",
        \ "two\tXfile\t2"],
        \ "Xtags", 'D')
  call writefile(["one", "two", "three"], "Xfile", 'D')
  edit Xfile
  tjump one
  edit Xfile

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("tlast", "E1513:")
  call assert_equal(l:current, bufnr())

  tlast!
  call assert_equal(l:current, bufnr())

  set tags&
endfunc

" Fail :tnext but :tnext! is allowed
func Test_tnext()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "thesame\tXfile\t1;\"\td\tfile:",
        \ "thesame\tXfile\t2;\"\td\tfile:",
        \ "thesame\tXfile\t3;\"\td\tfile:",
        \ ],
        \ "Xtags", 'D')
  call writefile(["thesame one", "thesame two", "thesame three"], "Xfile", 'D')
  call writefile(["thesame one"], "Xother", 'D')
  edit Xother

  tag thesame
  execute "normal \<C-^>"

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("tnext", "E1513:")
  call assert_equal(l:current, bufnr())

  tnext!
  call assert_notequal(l:current, bufnr())

  set tags&
endfunc

" Fail :tprevious but :tprevious! is allowed
func Test_tprevious()
  call s:reset_all_buffers()

  set tags=Xtags
  call writefile(["!_TAG_FILE_ENCODING\tutf-8\t//",
        \ "thesame\tXfile\t1;\"\td\tfile:",
        \ "thesame\tXfile\t2;\"\td\tfile:",
        \ "thesame\tXfile\t3;\"\td\tfile:",
        \ ],
        \ "Xtags", 'D')
  call writefile(["thesame one", "thesame two", "thesame three"], "Xfile", 'D')
  call writefile(["thesame one"], "Xother", 'D')
  edit Xother

  tag thesame
  execute "normal \<C-^>"
  tnext!

  set winfixbuf

  let l:current = bufnr()

  call assert_fails("tprevious", "E1513:")
  call assert_equal(l:current, bufnr())

  tprevious!

  set tags&
endfunc

" Fail :view but :view! is allowed
func Test_view()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("view other", "E1513:")
  call assert_equal(l:current, bufnr())

  view! other
  call assert_equal(l:other, bufnr())
endfunc

" Fail :visual but :visual! is allowed
func Test_visual()
  call s:reset_all_buffers()

  let l:other = s:make_buffer_pairs()
  let l:current = bufnr()

  call assert_fails("visual other", "E1513:")
  call assert_equal(l:current, bufnr())

  visual! other
  call assert_equal(l:other, bufnr())
endfunc

" Fail :vimgrep but :vimgrep! is allowed
func Test_vimgrep()
  CheckFeature quickfix
  call s:reset_all_buffers()

  edit first.unittest
  call append(0, ["some-search-term"])
  write

  edit winfix.unittest
  call append(0, ["some-search-term"])
  write
  let l:current = bufnr()

  set winfixbuf

  edit! last.unittest
  call append(0, ["some-search-term"])
  write
  let l:last = bufnr()

  buffer! winfix.unittest

  call assert_fails("vimgrep /some-search-term/ *.unittest")
  call assert_equal(l:current, bufnr())

  " Don't error and also do swap to the first match because ! was included
  vimgrep! /some-search-term/ *.unittest
  call assert_notequal(l:current, bufnr())

  call delete("first.unittest")
  call delete("winfix.unittest")
  call delete("last.unittest")
endfunc

" Fail :vimgrepadd but ::vimgrepadd! is allowed
func Test_vimgrepadd()
  CheckFeature quickfix
  call s:reset_all_buffers()

  edit first.unittest
  call append(0, ["some-search-term"])
  write

  edit winfix.unittest
  call append(0, ["some-search-term"])
  write
  let l:current = bufnr()

  set winfixbuf

  edit! last.unittest
  call append(0, ["some-search-term"])
  write
  let l:last = bufnr()

  buffer! winfix.unittest

  call assert_fails("vimgrepadd /some-search-term/ *.unittest")
  call assert_equal(l:current, bufnr())

  vimgrepadd! /some-search-term/ *.unittest
  call assert_notequal(l:current, bufnr())
  call delete("first.unittest")
  call delete("winfix.unittest")
  call delete("last.unittest")
endfunc

" Fail :wNext but :wNext! is allowed
func Test_wNext()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_args_list()
  next!

  call assert_fails("wNext", "E1513:")
  call assert_notequal(l:first, bufnr())

  wNext!
  call assert_equal(l:first, bufnr())

  call delete("first")
  call delete("middle")
  call delete("last")
endfunc

" Allow :windo unless `:windo foo` would change a 'winfixbuf' window's buffer
func Test_windo()
  call s:reset_all_buffers()

  let l:current_window = win_getid()
  let l:current_buffer = bufnr()
  split
  enew
  file some_other_buffer

  set winfixbuf

  let l:current = win_getid()

  windo echo ''
  call assert_equal(l:current_window, win_getid())

  call assert_fails('execute "windo buffer ' . l:current_buffer . '"', "E1513:")
  call assert_equal(l:current_window, win_getid())

  execute "windo buffer! " . l:current_buffer
  call assert_equal(l:current_window, win_getid())
endfunc

" Fail :wnext but :wnext! is allowed
func Test_wnext()
  call s:reset_all_buffers()

  let [_, l:last] = s:make_args_list()
  next!

  call assert_fails("wnext", "E1513:")
  call assert_notequal(l:last, bufnr())

  wnext!
  call assert_equal(l:last, bufnr())

  call delete("first")
  call delete("middle")
  call delete("last")
endfunc

" Fail :wprevious but :wprevious! is allowed
func Test_wprevious()
  call s:reset_all_buffers()

  let [l:first, _] = s:make_args_list()
  next!

  call assert_fails("wprevious", "E1513:")
  call assert_notequal(l:first, bufnr())

  wprevious!
  call assert_equal(l:first, bufnr())

  call delete("first")
  call delete("middle")
  call delete("last")
endfunc

func Test_quickfix_switchbuf_invalid_prevwin()
  call s:reset_all_buffers()

  call s:make_simple_quickfix()
  call assert_equal(1, getqflist(#{idx: 0}).idx)

  set switchbuf=uselast
  split
  copen
  execute winnr('#') 'quit'
  call assert_equal(2, winnr('$'))

  cnext  " Would've triggered a null pointer member access
  call assert_equal(2, getqflist(#{idx: 0}).idx)

  set switchbuf&
endfunc

func Test_listdo_goto_prevwin()
  call s:reset_all_buffers()
  call s:make_buffers_list()

  new
  call assert_equal(0, &winfixbuf)
  wincmd p
  call assert_equal(1, &winfixbuf)
  call assert_notequal(bufnr(), bufnr('#'))

  augroup ListDoGotoPrevwin
    au!
    au BufLeave * let s:triggered = 1
          \| call assert_equal(bufnr(), winbufnr(winnr()))
  augroup END
  " Should correctly switch to the window without 'winfixbuf', and curbuf should
  " be consistent with curwin->w_buffer for autocommands.
  bufdo "
  call assert_equal(0, &winfixbuf)
  call assert_equal(1, s:triggered)
  unlet! s:triggered
  au! ListDoGotoPrevwin

  set winfixbuf
  wincmd p
  call assert_equal(2, winnr('$'))
  " Both curwin and prevwin have 'winfixbuf' set, so should split a new window
  " without it set.
  bufdo "
  call assert_equal(0, &winfixbuf)
  call assert_equal(3, winnr('$'))

  quit
  call assert_equal(2, winnr('$'))
  call assert_equal(1, &winfixbuf)
  augroup ListDoGotoPrevwin
    au!
    au WinEnter * ++once set winfixbuf
  augroup END
  " Same as before, but naughty autocommands set 'winfixbuf' for the new window.
  " :bufdo should give up in this case.
  call assert_fails('bufdo "', 'E1513:')

  au! ListDoGotoPrevwin
  augroup! ListDoGotoPrevwin
endfunc

func Test_quickfix_changed_split_failed()
  call s:reset_all_buffers()

  call s:make_simple_quickfix()
  call assert_equal(1, winnr('$'))

  " Quickfix code will open a split in an attempt to get a 'nowinfixbuf' window
  " to switch buffers in.  Interfere with things by setting 'winfixbuf' in it.
  augroup QfChanged
    au!
    au WinEnter * ++once call assert_equal(2, winnr('$'))
          \| set winfixbuf | call setqflist([], 'f')
  augroup END
  call assert_fails('cnext', ['E1513:', 'E925:'])
  " Check that the split was automatically closed.
  call assert_equal(1, winnr('$'))

  au! QfChanged
  augroup! QfChanged
endfunc

func Test_bufdo_cnext_splitwin_fails()
  call s:reset_all_buffers()
  call s:make_simple_quickfix()
  call assert_equal(1, getqflist(#{idx: 0}).idx)
  " Make sure there is not enough room to
  " split the winfixedbuf window
  let &winheight=&lines
  let &winminheight=&lines-2
  " Still want E1513, or it may not be clear why a split was attempted and why
  " it failing caused the commands to abort.
  call assert_fails(':bufdo echo 1', ['E36:', 'E1513:'])
  call assert_fails(':cnext', ['E36:', 'E1513:'])
  " Ensure the entry didn't change.
  call assert_equal(1, getqflist(#{idx: 0}).idx)
  set winminheight&vim winheight&vim
endfunc

" Test that exiting with 'winfixbuf' and EXITFREE doesn't cause an error.
func Test_exitfree_no_error()
  let lines =<< trim END
    set winfixbuf
    qall!
  END
  call writefile(lines, 'Xwfb_exitfree', 'D')
  call assert_notmatch('E1513:',
        "\ system(GetVimCommandClean() .. ' --not-a-term -X -S Xwfb_exitfree'))
        \ system(GetVimCommandClean() .. ' -X -S Xwfb_exitfree'))
endfunc

" vim: shiftwidth=2 sts=2 expandtab
