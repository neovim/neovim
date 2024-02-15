local helpers = require('test.functional.helpers')(after_each)
local exec_lua = helpers.exec_lua
local eq = helpers.eq

local function md_to_vimdoc(text)
  return exec_lua(
    [[
    local text_utils = require('scripts/text_utils')
    return text_utils.md_to_vimdoc(table.concat(..., '\n'), 0, 0, 70)
  ]],
    text
  )
end

local function test(act, exp)
  eq(table.concat(exp, '\n'), md_to_vimdoc(act))
end

describe('md_to_vimdoc', function()
  before_each(function()
    helpers.clear()
  end)

  it('can render para after fenced code', function()
    test({
      '- Para1',
      '  ```',
      '  code',
      '  ```',
      '  Para2',
    }, {
      '• Para1 >',
      '    code',
      '<',
      '  Para2',
      '',
    })
  end)
end)
