-- Tests for marks.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('marks', function()
  setup(clear)

  it('is working', function()
    insert([=[
      	textline A
      	textline B
      	textline C
      ]=])

    execute('so small.vim')
    -- Test that a deleted mark is restored after delete-undo-redo-undo.
    execute([[/^\t/+1]])
    execute('set nocp viminfo+=nviminfo')
    feed('madduu<cr>')
    execute([[let a = string(getpos("'a"))]])
    execute([[$put ='Mark after delete-undo-redo-undo: '.a]])
    execute([['']])
    insert([=[
      CTRL-A CTRL-X:
      123 123 123
      123 123 123
      123 123 123
      ]=])

    -- Test that CTRL-A and CTRL-X updates last changed mark '[, '].
    execute('/^123/')
    execute([=[execute "normal! \<C-A>`[v`]rAjwvjw\<C-X>`[v`]rX"]=])
    insert([=[
      Results:]=])

    execute('g/^STARTTEST/.,/^ENDTEST/d')
    execute('wq! test.out')

    -- Assert buffer contents.
    expect([=[
      Tests for marks.
      
      
      	textline A
      	textline B
      	textline C
      
      
      CTRL-A CTRL-X:
      AAA 123 123
      123 XXXXXXX
      XXX 123 123
      
      
      Results:
      Mark after delete-undo-redo-undo: [0, 15, 2, 0]]=])
  end)
end)
