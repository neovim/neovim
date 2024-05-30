-- Inserts 10000 lines with text to fill the swap file with two levels of
-- pointer blocks.  Then recovers from the swap file and checks all text is
-- restored. We need about 10000 lines of 100 characters to get two levels of
-- pointer blocks.

local n = require('test.functional.testnvim')()

local clear, expect, source = n.clear, n.expect, n.source

describe('78', function()
  setup(clear)
  teardown(function()
    os.remove('.Xtest.swp')
    os.remove('.Xtest.swo')
  end)

  it('is working', function()
    source([=[
      set directory=. swapfile fileformat=unix undolevels=-1
      e! Xtest
      let text = "\tabcdefghijklmnoparstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnoparstuvwxyz0123456789"
      let i = 1
      let linecount = 10000
      while i <= linecount | call append(i - 1, i . text) | let i += 1 | endwhile
      preserve

      " Get the name of the swap file, and clean up the :redir capture.
      redir => g:swapname | swapname | redir END
      let g:swapname = substitute(g:swapname, '[[:blank:][:cntrl:]]*\(.\{-}\)[[:blank:][:cntrl:]]*$', '\1', 'g')
      let g:swapname = fnameescape(g:swapname)

      " Make a copy of the swap file in Xswap
      set bin
      exe 'sp ' . g:swapname
      w! Xswap

      set nobin
      new
      only!
      bwipe! Xtest
      call rename('Xswap', g:swapname)

      "TODO(jkeyes): without 'silent', this hangs the test " at message:
      "    'Recovery completed. You should check if everything is OK.'
      silent recover Xtest

      call delete(g:swapname)
      new
      call append(0, 'recovery start')
      wincmd w

      let g:linedollar = line('$')
      if g:linedollar < linecount
        wincmd w
        call append(line('$'), "expected " . linecount
          \ . " lines but found only " . g:linedollar)
        wincmd w
        let linecount = g:linedollar
      endif

      let i = 1
      while i <= linecount
        if getline(i) != i . text
          exe 'wincmd w'
          call append(line('$'), i . ' differs')
          exe 'wincmd w'
        endif
        let i += 1
      endwhile
      q!
      call append(line('$'), 'recovery end')
    ]=])

    expect([[
      recovery start

      recovery end]])
  end)
end)
