-- Tests for completefunc/omnifunc.

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, expect, execute = helpers.clear, helpers.expect, helpers.execute

describe('completefunc', function()
  setup(clear)

  it('is working', function()
    insert([=[
      +++
      one
      two
      three]=])

    -- Test that nothing happens if the 'completefunc' opens
    -- a new window (no completion, no crash).
    source([=[
      function! DummyCompleteOne(findstart, base)
        if a:findstart
          return 0
        else
          wincmd n
          return ['onedef', 'oneDEF']
        endif
      endfunction
      setlocal completefunc=DummyCompleteOne
      /^one
    ]=])
    feed('A<C-X><C-U><C-N><esc>')
    execute('q!')
    source([=[
      function! DummyCompleteTwo(findstart, base)
        if a:findstart
          wincmd n
          return 0
        else
          return ['twodef', 'twoDEF']
        endif
      endfunction
      setlocal completefunc=DummyCompleteTwo
      /^two
    ]=])
    feed('A<C-X><C-U><C-N><esc>')
    execute('q!')
    -- Test that 'completefunc' works when it's OK.
    source([=[
      function! DummyCompleteThree(findstart, base)
        if a:findstart
          return 0
        else
          return ['threedef', 'threeDEF']
        endif
      endfunction
      setlocal completefunc=DummyCompleteThree
      /^three
    ]=])
    feed('A<C-X><C-U><C-N><esc>')

    -- Assert buffer contents.
    expect([=[
      +++
      
      two
      threeDEF]=])
  end)
end)
