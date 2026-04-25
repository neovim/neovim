local t = require('test.testutil')

local dedent = t.dedent
local eq = t.eq

local parser = require('gen.luacats_parser')

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

  it('tracks class member declaration style', function()
    local classes, funs = parser.parse_str(
      dedent([[        --- @class vim.MyClass
        local MyClass = {}

        --- Dot member.
        --- @param obj vim.MyClass
        function MyClass.dot_member(obj)
        end

        --- Colon member.
        function MyClass:colon_member()
        end

        return MyClass
      ]]),
      'runtime/lua/vim/myclass.lua'
    )

    eq('vim.MyClass', classes['vim.MyClass'].name)
    eq({
      classvar = 'MyClass',
      desc = 'Dot member.',
      kind = 'field',
      name = 'dot_member',
      type = 'fun(obj: vim.MyClass)',
    }, classes['vim.MyClass'].fields[1])
    eq({
      classvar = 'MyClass',
      desc = 'Colon member.',
      kind = 'field',
      name = 'colon_member',
      type = 'fun(self: vim.MyClass)',
    }, classes['vim.MyClass'].fields[2])

    eq('.', funs[1].member_sep)
    eq('MyClass', funs[1].classvar)
    eq('MyClass', funs[1].modvar)
    eq('obj', funs[1].params[1].name)

    eq(':', funs[2].member_sep)
    eq('self', funs[2].params[1].name)
    eq('vim.MyClass', funs[2].params[1].type)
  end)

  it('keeps non-returned dot members as class fields', function()
    local classes = parser.parse_str(
      dedent([[        --- @class vim.Helper
        local Helper = {}

        --- @class vim.Module
        local M = {}

        --- Helper field.
        --- @param helper vim.Helper
        function Helper.field(helper)
        end

        return M
      ]]),
      'runtime/lua/vim/module.lua'
    )

    eq({
      classvar = 'Helper',
      desc = 'Helper field.',
      kind = 'field',
      name = 'field',
      type = 'fun(helper: vim.Helper)',
    }, classes['vim.Helper'].fields[1])
  end)
end)
