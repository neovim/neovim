local t = require('test.testutil')

local describe, it = t.describe, t.it
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

  for _, access in ipairs({ 'internal', 'internal, exact' }) do
    it('tracks internal visibility with (' .. access .. ')', function()
      local classes, funs = parser.parse_str(
        dedent([[
          --- @class (%s) vim.MyClass
          --- @field internal value string
          local MyClass = {}

          --- @internal
          function MyClass.get() end

          return MyClass
        ]]):format(access),
        'runtime/lua/vim/myclass.lua'
      )

      eq(access, classes['vim.MyClass'].access)
      eq('internal', classes['vim.MyClass'].fields[1].access)
      eq('internal', funs[1].access)
    end)
  end

  it('keeps annotation text in field descriptions', function()
    local classes = parser.parse_str(
      dedent([[
        --- @class Options
        --- @field text string Use @field name type to document a field.
        --- @field internal boolean
      ]]),
      'options.lua'
    )
    eq({
      {
        kind = 'field',
        name = 'text',
        type = 'string',
        desc = 'Use @field name type to document a field.',
      },
      { kind = 'field', name = 'internal', type = 'boolean' },
    }, classes.Options.fields)
  end)

  it('preserves source section order and handle methods', function()
    local classes, funs, _, _, _, sections = parser.parse_str(
      dedent([[
        --- # Base handle
        --- Handle functions apply to all handles.

        --- @class Handle
        local handle = {}

        --- ## Closing a handle
        --- Close the handle.
        function handle:close() end

        --- # Timer handle
        --- Timers inherit handle operations.
        --- @class Timer: Handle
        local timer = {}

        --- Start the timer.
        --- @param timeout integer
        function timer:start(timeout) end

        --- # Additional handle operations
        --- Timers also support closing.
      ]]),
      'handles.lua',
      { sections = true }
    )

    eq(
      { 'Base handle', 'Timer handle', 'Additional handle operations' },
      { sections[1].name, sections[2].name, sections[3].name }
    )
    eq({ 'Handle functions apply to all handles.' }, sections[1].briefs)
    eq('Timers inherit handle operations.', sections[2].classes.Timer.desc)
    eq({ 'Timers also support closing.' }, sections[3].briefs)
    eq('Handle', classes.Timer.parent)
    eq({ 'close', 'start' }, { funs[1].name, funs[2].name })
    eq('## Closing a handle\nClose the handle.', funs[1].desc)
    eq('Handle', sections[1].funs[1].params[1].type)
    eq('Timer', sections[2].funs[1].params[1].type)
    eq('timeout', sections[2].funs[1].params[2].name)
    eq(true, sections[2].classes.Timer == classes.Timer)
    eq(true, sections[2].funs[1] == funs[2])
  end)

  it('keeps constants and described error names in their source sections', function()
    local _, _, _, _, _, sections = parser.parse_str(
      dedent([[
        --- # Signals
        --- @type integer
        uv.constants.SIGTERM = nil

        --- # Errors
        --- @alias uv.error_name
        --- | 'ENOENT' # no such file or directory.
        --- | 'EACCES' # permission denied.
      ]]),
      'constants.lua',
      { sections = true }
    )

    local signal = sections[1].funs[1]
    eq('uv.constants.SIGTERM', signal.name)
    eq({ { type = 'integer' } }, signal.type)
    eq(true, signal.table)
    eq(
      { '- `ENOENT`: no such file or directory.\n- `EACCES`: permission denied.' },
      sections[2].briefs
    )
  end)

  it('supports @return_cast annotations', function()
    local _, funs = parser.parse_str(
      dedent([[
        --- @param value any
        --- @return boolean # Whether the value is nil.
        --- @return_cast value nil|vim.NIL else -nil
        function is_nil(value) end
      ]]),
      'myfile.lua'
    )

    eq({ { type = 'boolean', desc = 'Whether the value is nil.' } }, funs[1].returns)
  end)

  it('links require bindings without renaming declarations', function()
    local _, _, _, _, consumer = parser.parse_str(
      dedent([[
        local M = {}
        --- A binding with its own documentation.
        M.create = require('vim.factory')
        M.missing = require('vim.missing')
        return M
      ]]),
      'runtime/lua/vim/_consumer.lua'
    )
    local _, funs, _, _, implementation = parser.parse_str(
      dedent([[
        --- Create a value.
        --- @param value string
        --- @return string
        local function new_value(value) end
        return new_value
      ]]),
      'runtime/lua/vim/factory.lua'
    )
    parser.resolve_modules({ ['vim._consumer'] = consumer, ['vim.factory'] = implementation })

    -- Check table identity: the import must reference the original parsed module.
    eq(true, implementation == consumer.imports.create)
    eq('vim.missing', consumer.requires.missing)
    eq(nil, consumer.imports.missing)
    eq({}, funs)
    eq('new_value', implementation.callable.name)
    eq('vim.factory', implementation.callable.module)
    eq('Create a value.', implementation.callable.desc)
    eq({ { name = 'value', type = 'string' } }, implementation.callable.params)
    eq({ { type = 'string' } }, implementation.callable.returns)
  end)

  it('keeps a callable module declaration separate from its members', function()
    local _, funs, _, _, module = parser.parse_str(
      dedent([[
        local M = {}
        setmetatable(M, {
          --- Format a value.
          --- @param value any
          --- @return string
          __call = function(_, value) end,
        })
        return M
      ]]),
      'runtime/lua/vim/example.lua'
    )
    eq({}, funs)
    eq('__call', module.callable.name)
    eq('vim.example', module.callable.module)
    eq('Format a value.', module.callable.desc)
    eq({ { name = 'value', type = 'any' } }, module.callable.params)
    eq({ { type = 'string' } }, module.callable.returns)
  end)

  it('links table imports and parent modules without copying or hiding members', function()
    local _, core_funs, _, _, core = parser.parse_str(
      dedent([[
        --- @class vim._core
        local Core = {}

        --- Shared function.
        --- @return string
        function Core.create() end
        return Core
      ]]),
      'runtime/lua/vim/_core.lua'
    )
    local _, funs, _, _, public = parser.parse_str(
      dedent([[
        --- @class vim.public: vim._core
        local M = {}
        M._core = require('vim._core')
        M.create = false
        return M
      ]]),
      'runtime/lua/vim/public.lua'
    )
    parser.resolve_modules({ ['vim._core'] = core, ['vim.public'] = public })

    -- Check table identity: both links must reference the original parsed module.
    eq(true, core == public.imports._core)
    eq(true, core == public.parent)
    eq(true, public.assignments.create)
    eq({}, funs)
    eq('create', core_funs[1].name)
    eq('vim._core', core_funs[1].module)
    eq('Shared function.', core_funs[1].desc)
    eq({ { type = 'string' } }, core_funs[1].returns)
    eq(nil, core_funs[1].nodoc)
  end)

  it('parses multiline return annotations', function()
    local _, funs = parser.parse_str(
      dedent([[
        --- Inspect the registry.
        --- @return table<string, {
        ---   name: string
        --- }> # Registry contents.
        --- @return integer count # Number of entries.
        function inspect() end
      ]]),
      'myfile.lua'
    )

    eq('Inspect the registry.', funs[1].desc)
    eq({
      {
        type = 'table<string, { name: string }>',
        desc = 'Registry contents.',
      },
      { type = 'integer', name = 'count', desc = 'Number of entries.' },
    }, funs[1].returns)
  end)

  it('tracks class member declaration style', function()
    local classes, funs = parser.parse_str(
      dedent([[
        --- @class vim.MyClass
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
      member_sep = '.',
      desc = 'Dot member.',
      kind = 'field',
      name = 'dot_member',
      type = 'fun(obj: vim.MyClass)',
    }, classes['vim.MyClass'].fields[1])
    eq({
      classvar = 'MyClass',
      member_sep = ':',
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
      member_sep = '.',
      desc = 'Helper field.',
      kind = 'field',
      name = 'field',
      type = 'fun(helper: vim.Helper)',
    }, classes['vim.Helper'].fields[1])
  end)
end)
