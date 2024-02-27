local helpers = require('test.functional.helpers')(after_each)
local exec_lua = helpers.exec_lua
local eq = helpers.eq

local function md_to_vimdoc(text, start_indent, indent, text_width)
  return exec_lua(
    [[
    local text, start_indent, indent, text_width = ...
    start_indent = start_indent or 0
    indent = indent or 0
    text_width = text_width or 70
    local text_utils = require('scripts/text_utils')
    return text_utils.md_to_vimdoc(table.concat(text, '\n'), start_indent, indent, text_width)
  ]],
    text,
    start_indent,
    indent,
    text_width
  )
end

local function test(what, act, exp, ...)
  local argc, args = select('#', ...), { ... }
  it(what, function()
    eq(table.concat(exp, '\n'), md_to_vimdoc(act, unpack(args, 1, argc)))
  end)
end

describe('md_to_vimdoc', function()
  before_each(function()
    helpers.clear()
  end)

  test('can render para after fenced code', {
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

  test('start_indent only applies to first line', {
    'para1',
    '',
    'para2',
  }, {
    'para1',
    '',
    '          para2',
    '',
  }, 0, 10, 78)
end)
