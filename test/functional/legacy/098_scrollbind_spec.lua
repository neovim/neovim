-- Test for 'scrollbind' causing an unexpected scroll of one of the windows.

local helpers = require('test.functional.helpers')(after_each)
local source = helpers.source
local clear, expect = helpers.clear, helpers.expect

describe('scrollbind', function()
  setup(clear)

  it('is working', function()
    source([[
      set laststatus=0
      let g:totalLines = &lines * 20
      let middle = g:totalLines / 2
      wincmd n
      wincmd o
      for i in range(1, g:totalLines)
          call setline(i, 'LINE ' . i)
      endfor
      exe string(middle)
      normal zt
      normal M
      aboveleft vert new
      for i in range(1, g:totalLines)
          call setline(i, 'line ' . i)
      endfor
      exe string(middle)
      normal zt
      normal M
      setl scb | wincmd p
      setl scb
      wincmd w
      let topLineLeft = line('w0')
      wincmd p
      let topLineRight = line('w0')
      setl noscrollbind
      wincmd p
      setl noscrollbind
      q!
      %del _
      call setline(1, 'Difference between the top lines (left - right): ' . string(topLineLeft - topLineRight))
      brewind
    ]])

    -- Assert buffer contents.
    expect("Difference between the top lines (left - right): 0")
  end)
end)
