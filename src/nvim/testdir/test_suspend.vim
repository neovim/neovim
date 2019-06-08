" Test :suspend

source shared.vim

func Test_suspend()
  if !has('terminal') || !executable('/bin/sh')
    return
  endif

  let buf = term_start('/bin/sh')
  " Wait for shell prompt.
  call WaitForAssert({-> assert_match('[$#] $', term_getline(buf, '.'))})

  call term_sendkeys(buf, v:progpath
        \               . " --clean -X"
        \               . " -c 'set nu'"
        \               . " -c 'call setline(1, \"foo\")'"
        \               . " Xfoo\<CR>")
  " Cursor in terminal buffer should be on first line in spawned vim.
  call WaitForAssert({-> assert_equal('  1 foo', term_getline(buf, '.'))})

  for suspend_cmd in [":suspend\<CR>",
        \             ":stop\<CR>",
        \             ":suspend!\<CR>",
        \             ":stop!\<CR>",
        \             "\<C-Z>"]
    " Suspend and wait for shell prompt.
    call term_sendkeys(buf, suspend_cmd)
    call WaitForAssert({-> assert_match('[$#] $', term_getline(buf, '.'))})

    " Without 'autowrite', buffer should not be written.
    call assert_equal(0, filereadable('Xfoo'))

    call term_sendkeys(buf, "fg\<CR>")
    call WaitForAssert({-> assert_equal('  1 foo', term_getline(buf, '.'))})
  endfor

  " Test that :suspend! with 'autowrite' writes content of buffers if modified.
  call term_sendkeys(buf, ":set autowrite\<CR>")
  call assert_equal(0, filereadable('Xfoo'))
  call term_sendkeys(buf, ":suspend\<CR>")
  " Wait for shell prompt.
  call WaitForAssert({-> assert_match('[$#] $', term_getline(buf, '.'))})
  call assert_equal(['foo'], readfile('Xfoo'))
  call term_sendkeys(buf, "fg\<CR>")
  call WaitForAssert({-> assert_equal('  1 foo', term_getline(buf, '.'))})

  " Quit gracefully to dump coverage information.
  call term_sendkeys(buf, ":qall!\<CR>")
  call term_wait(buf)
  call Stop_shell_in_terminal(buf)

  exe buf . 'bwipe!'
  call delete('Xfoo')
endfunc
