-- Tests for marks.

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('marks', function()
  setup(clear)

  it('is working', function()
    insert([[
      Tests for marks.
      
      
      	textline A
      	textline B
      	textline C
      
      
      CTRL-A CTRL-X:
      123 123 123
      123 123 123
      123 123 123
      
      
      Results:]])

    -- Test that a deleted mark is restored after delete-undo-redo-undo.
    execute([[/^\t/+1]])
    execute('set nocp viminfo+=nviminfo')
    feed('maddu<C-R>u<cr>')
    execute([[let a = string(getpos("'a"))]])
    execute([[$put ='Mark after delete-undo-redo-undo: '.a]])
    execute([['']])

    -- Test that CTRL-A and CTRL-X updates last changed mark '[, '].
    execute('/^123/')
    execute([[execute "normal! \<C-A>`[v`]rAjwvjw\<C-X>`[v`]rX"]])

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
      Mark after delete-undo-redo-undo: [0, 5, 1, 0]]=])
  end)
end)
