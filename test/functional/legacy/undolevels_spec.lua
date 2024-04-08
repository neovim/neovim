local t = require('test.functional.testutil')(after_each)
local source, clear = t.source, t.clear
local eq, nvim = t.eq, t.api

describe('undolevel', function()
  setup(clear)

  it('is working', function()
    source([[
      func FillBuffer()
        for i in range(1,13)
          put=i
          " Set 'undolevels' to split undo.
          exe "setg ul=" . &g:ul
        endfor
      endfunc

      func Test_global_local_undolevels()
        new one
        set undolevels=5
        call FillBuffer()
        " will only undo the last 5 changes, end up with 13 - (5 + 1) = 7 lines
        earlier 10
        call assert_equal(5, &g:undolevels)
        call assert_equal(-123456, &l:undolevels)
        call assert_equal('7', getline('$'))

        new two
        setlocal undolevels=2
        call FillBuffer()
        " will only undo the last 2 changes, end up with 13 - (2 + 1) = 10 lines
        earlier 10
        call assert_equal(5, &g:undolevels)
        call assert_equal(2, &l:undolevels)
        call assert_equal('10', getline('$'))

        setlocal ul=10
        call assert_equal(5, &g:undolevels)
        call assert_equal(10, &l:undolevels)

        " Setting local value in "two" must not change local value in "one"
        wincmd p
        call assert_equal(5, &g:undolevels)
        call assert_equal(-123456, &l:undolevels)

        new three
        setglobal ul=50
        call assert_equal(50, &g:undolevels)
        call assert_equal(-123456, &l:undolevels)

        " Drop created windows
        set ul&
        new
        only!
      endfunc

      call Test_global_local_undolevels()
    ]])

    eq({}, nvim.nvim_get_vvar('errors'))
  end)
end)
