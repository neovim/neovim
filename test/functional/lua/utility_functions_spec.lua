-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local funcs = helpers.funcs
local clear = helpers.clear
local eq = helpers.eq

before_each(clear)

describe('vim.stricmp', function()
  -- İ: `tolower("İ")` is `i` which has length 1 while `İ` itself has
  --    length 2 (in bytes).
  -- Ⱥ: `tolower("Ⱥ")` is `ⱥ` which has length 2 while `Ⱥ` itself has
  --    length 3 (in bytes).
  --
  -- Note: 'i' !=? 'İ' and 'ⱥ' !=? 'Ⱥ' on some systems.
  -- Note: Built-in Nvim comparison (on systems lacking `strcasecmp`) works
  --       only on ASCII characters.
  it('works', function()
    eq(0, funcs.luaeval('vim.stricmp("a", "A")'))
    eq(0, funcs.luaeval('vim.stricmp("A", "a")'))
    eq(0, funcs.luaeval('vim.stricmp("a", "a")'))
    eq(0, funcs.luaeval('vim.stricmp("A", "A")'))

    eq(0, funcs.luaeval('vim.stricmp("", "")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0", "\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0", "\\0\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0\\0", "\\0\\0\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0\\0A", "\\0\\0\\0a")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0A")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0a")'))

    eq(0, funcs.luaeval('vim.stricmp("a\\0", "A\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("A\\0", "a\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("a\\0", "a\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("A\\0", "A\\0")'))

    eq(0, funcs.luaeval('vim.stricmp("\\0a", "\\0A")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0A", "\\0a")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0a", "\\0a")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0A", "\\0A")'))

    eq(0, funcs.luaeval('vim.stricmp("\\0a\\0", "\\0A\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0A\\0", "\\0a\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0a\\0", "\\0a\\0")'))
    eq(0, funcs.luaeval('vim.stricmp("\\0A\\0", "\\0A\\0")'))

    eq(-1, funcs.luaeval('vim.stricmp("a", "B")'))
    eq(-1, funcs.luaeval('vim.stricmp("A", "b")'))
    eq(-1, funcs.luaeval('vim.stricmp("a", "b")'))
    eq(-1, funcs.luaeval('vim.stricmp("A", "B")'))

    eq(-1, funcs.luaeval('vim.stricmp("", "\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0", "\\0\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0\\0", "\\0\\0\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0\\0\\0A", "\\0\\0\\0b")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0B")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0\\0\\0a", "\\0\\0\\0b")'))

    eq(-1, funcs.luaeval('vim.stricmp("a\\0", "B\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("A\\0", "b\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("a\\0", "b\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("A\\0", "B\\0")'))

    eq(-1, funcs.luaeval('vim.stricmp("\\0a", "\\0B")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0A", "\\0b")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0a", "\\0b")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0A", "\\0B")'))

    eq(-1, funcs.luaeval('vim.stricmp("\\0a\\0", "\\0B\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0A\\0", "\\0b\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0a\\0", "\\0b\\0")'))
    eq(-1, funcs.luaeval('vim.stricmp("\\0A\\0", "\\0B\\0")'))

    eq(1, funcs.luaeval('vim.stricmp("c", "B")'))
    eq(1, funcs.luaeval('vim.stricmp("C", "b")'))
    eq(1, funcs.luaeval('vim.stricmp("c", "b")'))
    eq(1, funcs.luaeval('vim.stricmp("C", "B")'))

    eq(1, funcs.luaeval('vim.stricmp("\\0", "")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0", "\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0", "\\0\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0\\0", "\\0\\0\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0C", "\\0\\0\\0b")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0c", "\\0\\0\\0B")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0\\0\\0c", "\\0\\0\\0b")'))

    eq(1, funcs.luaeval('vim.stricmp("c\\0", "B\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("C\\0", "b\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("c\\0", "b\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("C\\0", "B\\0")'))

    eq(1, funcs.luaeval('vim.stricmp("c\\0", "B")'))
    eq(1, funcs.luaeval('vim.stricmp("C\\0", "b")'))
    eq(1, funcs.luaeval('vim.stricmp("c\\0", "b")'))
    eq(1, funcs.luaeval('vim.stricmp("C\\0", "B")'))

    eq(1, funcs.luaeval('vim.stricmp("\\0c", "\\0B")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0C", "\\0b")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0c", "\\0b")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0C", "\\0B")'))

    eq(1, funcs.luaeval('vim.stricmp("\\0c\\0", "\\0B\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0C\\0", "\\0b\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0c\\0", "\\0b\\0")'))
    eq(1, funcs.luaeval('vim.stricmp("\\0C\\0", "\\0B\\0")'))
  end)
end)
