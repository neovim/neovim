local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, feed_command, expect = helpers.clear, helpers.feed_command, helpers.expect

describe('marks', function()
  before_each(function()
    clear()
  end)

  -- luacheck: ignore 621 (Indentation)
  it('restores a deleted mark after delete-undo-redo-undo', function()
    insert([[

      	textline A
      	textline B
      	textline C

      Results:]])

    feed_command([[:/^\t/+1]])
    feed([[maddu<C-R>u]])
    source([[
      let g:a = string(getpos("'a"))
      $put ='Mark after delete-undo-redo-undo: '.g:a
    ]])

    expect([=[

      	textline A
      	textline B
      	textline C

      Results:
      Mark after delete-undo-redo-undo: [0, 3, 2, 0]]=])
  end)

  it("CTRL-A and CTRL-X updates last changed mark '[, ']", function()
    insert([[
      CTRL-A CTRL-X:
      123 123 123
      123 123 123
      123 123 123]])

    source([[
      /^123/
      execute "normal! \<C-A>`[v`]rAjwvjw\<C-X>`[v`]rX"]])

    expect([=[
      CTRL-A CTRL-X:
      AAA 123 123
      123 XXXXXXX
      XXX 123 123]=])
  end)
end)
