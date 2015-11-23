-- Tests for 'undolevel' setting being global-local

local helpers = require('test.functional.helpers')
local source = helpers.source
local clear, expect = helpers.clear, helpers.expect

describe('undolevel', function()
  setup(clear)

  it('is working', function()
    source([[
      set ul=5
      fu! FillBuffer()
        for i in range(1,13)
          put=i
          exe "setg ul=" . &g:ul
        endfor
      endfu
      fu! UndoLevel()
        redir @z 
          setglobal undolevels? 
          echon ' global' 
          setlocal undolevels? 
          echon ' local' 
        redir end
        $put z
      endfu

      0put ='ONE: expecting global undolevels: 5, local undolevels: -123456 (default)'
      call FillBuffer()
      setlocal undolevels<
      earlier 10
      call UndoLevel()
      set ff=unix
      %yank A
      %delete

      0put ='TWO: expecting global undolevels: 5, local undolevels: 2 (first) then 10 (afterwards)'
      setlocal ul=2
      call FillBuffer()
      earlier 10
      call UndoLevel()
      setlocal ul=10
      call UndoLevel()
      set ff=unix
      %yank A
      %delete
      setlocal undolevels<
      redir @A
        echo "global value shouldn't be changed and still be 5!" 
        echo 'ONE: expecting global undolevels: 5, local undolevels: -123456 (default)'
        setglobal undolevels? 
        echon ' global' 
        setlocal undolevels? 
        echon ' local' 
        echo "" 
      redir end

      setglobal ul=50
      1put ='global value should be changed to 50'
      2put ='THREE: expecting global undolevels: 50, local undolevels: -123456 (default)'
      call UndoLevel()
      set ff=unix
      %yank A
      %delete
      setglobal lispwords=foo,bar,baz
      setlocal lispwords-=foo 
      setlocal lispwords+=quux
      redir @A
        echo "Testing 'lispwords' local value" 
        setglobal lispwords? 
        setlocal lispwords? 
        echo &lispwords 
        echo ''
      redir end
      setlocal lispwords<
      redir @A
        echo "Testing 'lispwords' value reset" 
        setglobal lispwords? 
        setlocal lispwords? 
        echo &lispwords
      redir end

      0put a
      $d
    ]])

    -- Assert buffer contents.
    expect([[
      ONE: expecting global undolevels: 5, local undolevels: -123456 (default)
      1
      2
      3
      4
      5
      6
      7
      
      
        undolevels=5 global
        undolevels=-123456 local
      TWO: expecting global undolevels: 5, local undolevels: 2 (first) then 10 (afterwards)
      1
      2
      3
      4
      5
      6
      7
      8
      9
      10
      
      
        undolevels=5 global
        undolevels=2 local
      
        undolevels=5 global
        undolevels=10 local
      
      global value shouldn't be changed and still be 5!
      ONE: expecting global undolevels: 5, local undolevels: -123456 (default)
        undolevels=5 global
        undolevels=-123456 local
      
      global value should be changed to 50
      THREE: expecting global undolevels: 50, local undolevels: -123456 (default)
      
        undolevels=50 global
        undolevels=-123456 local
      
      Testing 'lispwords' local value
        lispwords=foo,bar,baz
        lispwords=bar,baz,quux
      bar,baz,quux
      
      Testing 'lispwords' value reset
        lispwords=foo,bar,baz
        lispwords=foo,bar,baz
      foo,bar,baz]])
  end)
end)
