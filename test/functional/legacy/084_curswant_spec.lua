-- Tests for curswant not changing when setting an option.

local helpers = require('test.functional.helpers')(after_each)
local insert, source = helpers.insert, helpers.source
local clear, expect = helpers.clear, helpers.expect

describe('curswant', function()
  setup(clear)

  -- luacheck: ignore 621 (Indentation)
  it('is working', function()
    insert([[
      start target options
      	tabstop
      	timeoutlen
      	ttimeoutlen
      end target options]])

    source([[
      /^start target options$/+1,/^end target options$/-1 yank
      let target_option_names = split(@0)
      function TestCurswant(option_name)
        normal! ggf8j
        let curswant_before = winsaveview().curswant
        execute 'let' '&'.a:option_name '=' '&'.a:option_name
        let curswant_after = winsaveview().curswant
        return [a:option_name, curswant_before, curswant_after]
      endfunction

      new
      put =['1234567890', '12345']
      1 delete _
      let result = []
      for option_name in target_option_names
        call add(result, TestCurswant(option_name))
      endfor

      new
      put =map(copy(result), 'join(v:val, '' '')')
      1 delete _
    ]])

    -- Assert buffer contents.
    expect([[
      tabstop 7 4
      timeoutlen 7 7
      ttimeoutlen 7 7]])
  end)
end)
