local t = require('test.functional.testutil')()
local eq = t.eq

local parser = require('scripts/luacats_parser')

--- @param name string
--- @param text string
--- @param exp table<string,string>
local function test(name, text, exp)
  exp = vim.deepcopy(exp, true)
  it(name, function()
    eq(exp, parser.parse_str(text, 'myfile.lua'))
  end)
end

describe('luacats parser', function()
  local exp = {
    myclass = {
      kind = 'class',
      module = 'myfile.lua',
      name = 'myclass',
      fields = {
        { kind = 'field', name = 'myclass', type = 'integer' },
      },
    },
  }

  test(
    'basic class',
    [[
    --- @class myclass
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.inlinedoc = true

  test(
    'class with @inlinedoc (1)',
    [[
    --- @class myclass
    --- @inlinedoc
    --- @field myclass integer
  ]],
    exp
  )

  test(
    'class with @inlinedoc (2)',
    [[
    --- @inlinedoc
    --- @class myclass
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.inlinedoc = nil
  exp.myclass.nodoc = true

  test(
    'class with @nodoc',
    [[
    --- @nodoc
    --- @class myclass
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.nodoc = nil
  exp.myclass.access = 'private'

  test(
    'class with (private)',
    [[
    --- @class (private) myclass
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.fields[1].desc = 'Field\ndocumentation'

  test(
    'class with field doc above',
    [[
    --- @class (private) myclass
    --- Field
    --- documentation
    --- @field myclass integer
  ]],
    exp
  )

  exp.myclass.fields[1].desc = 'Field documentation'
  test(
    'class with field doc inline',
    [[
    --- @class (private) myclass
    --- @field myclass integer Field documentation
  ]],
    exp
  )
end)
