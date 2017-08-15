-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local funcs = helpers.funcs
local clear = helpers.clear
local eq = helpers.eq

before_each(clear)

describe('stricmp', function()
  -- İ: `tolower("İ")` is `i` which has length 1 while `İ` itself has
  --    length 2 (in bytes).
  -- Ⱥ: `tolower("Ⱥ")` is `ⱥ` which has length 2 while `Ⱥ` itself has
  --    length 3 (in bytes).
  -- For some reason 'i' !=? 'İ' and 'ⱥ' !=? 'Ⱥ' on some systems. Also built-in
  -- Neovim comparison (i.e. when there is no strcasecmp) works only on ASCII
  -- characters.
  it('works', function()
    eq(0, funcs.luaeval('stricmp("a", "A")'))
    eq(0, funcs.luaeval('stricmp("A", "a")'))
    eq(0, funcs.luaeval('stricmp("a", "a")'))
    eq(0, funcs.luaeval('stricmp("A", "A")'))

    eq(0, funcs.luaeval('stricmp("", "")'))
    eq(0, funcs.luaeval('stricmp("\\0", "\\0")'))
    eq(0, funcs.luaeval('stricmp("\\0\\0", "\\0\\0")'))
    eq(0, funcs.luaeval('stricmp("\\0\\0\\0", "\\0\\0\\0")'))
    eq(0, funcs.luaeval('stricmp("\\0\\0\\0A", "\\0\\0\\0a")'))
    eq(0, funcs.luaeval('stricmp("\\0\\0\\0a", "\\0\\0\\0A")'))
    eq(0, funcs.luaeval('stricmp("\\0\\0\\0a", "\\0\\0\\0a")'))

    eq(0, funcs.luaeval('stricmp("a\\0", "A\\0")'))
    eq(0, funcs.luaeval('stricmp("A\\0", "a\\0")'))
    eq(0, funcs.luaeval('stricmp("a\\0", "a\\0")'))
    eq(0, funcs.luaeval('stricmp("A\\0", "A\\0")'))

    eq(0, funcs.luaeval('stricmp("\\0a", "\\0A")'))
    eq(0, funcs.luaeval('stricmp("\\0A", "\\0a")'))
    eq(0, funcs.luaeval('stricmp("\\0a", "\\0a")'))
    eq(0, funcs.luaeval('stricmp("\\0A", "\\0A")'))

    eq(0, funcs.luaeval('stricmp("\\0a\\0", "\\0A\\0")'))
    eq(0, funcs.luaeval('stricmp("\\0A\\0", "\\0a\\0")'))
    eq(0, funcs.luaeval('stricmp("\\0a\\0", "\\0a\\0")'))
    eq(0, funcs.luaeval('stricmp("\\0A\\0", "\\0A\\0")'))

    eq(-1, funcs.luaeval('stricmp("a", "B")'))
    eq(-1, funcs.luaeval('stricmp("A", "b")'))
    eq(-1, funcs.luaeval('stricmp("a", "b")'))
    eq(-1, funcs.luaeval('stricmp("A", "B")'))

    eq(-1, funcs.luaeval('stricmp("", "\\0")'))
    eq(-1, funcs.luaeval('stricmp("\\0", "\\0\\0")'))
    eq(-1, funcs.luaeval('stricmp("\\0\\0", "\\0\\0\\0")'))
    eq(-1, funcs.luaeval('stricmp("\\0\\0\\0A", "\\0\\0\\0b")'))
    eq(-1, funcs.luaeval('stricmp("\\0\\0\\0a", "\\0\\0\\0B")'))
    eq(-1, funcs.luaeval('stricmp("\\0\\0\\0a", "\\0\\0\\0b")'))

    eq(-1, funcs.luaeval('stricmp("a\\0", "B\\0")'))
    eq(-1, funcs.luaeval('stricmp("A\\0", "b\\0")'))
    eq(-1, funcs.luaeval('stricmp("a\\0", "b\\0")'))
    eq(-1, funcs.luaeval('stricmp("A\\0", "B\\0")'))

    eq(-1, funcs.luaeval('stricmp("\\0a", "\\0B")'))
    eq(-1, funcs.luaeval('stricmp("\\0A", "\\0b")'))
    eq(-1, funcs.luaeval('stricmp("\\0a", "\\0b")'))
    eq(-1, funcs.luaeval('stricmp("\\0A", "\\0B")'))

    eq(-1, funcs.luaeval('stricmp("\\0a\\0", "\\0B\\0")'))
    eq(-1, funcs.luaeval('stricmp("\\0A\\0", "\\0b\\0")'))
    eq(-1, funcs.luaeval('stricmp("\\0a\\0", "\\0b\\0")'))
    eq(-1, funcs.luaeval('stricmp("\\0A\\0", "\\0B\\0")'))

    eq(1, funcs.luaeval('stricmp("c", "B")'))
    eq(1, funcs.luaeval('stricmp("C", "b")'))
    eq(1, funcs.luaeval('stricmp("c", "b")'))
    eq(1, funcs.luaeval('stricmp("C", "B")'))

    eq(1, funcs.luaeval('stricmp("\\0", "")'))
    eq(1, funcs.luaeval('stricmp("\\0\\0", "\\0")'))
    eq(1, funcs.luaeval('stricmp("\\0\\0\\0", "\\0\\0")'))
    eq(1, funcs.luaeval('stricmp("\\0\\0\\0\\0", "\\0\\0\\0")'))
    eq(1, funcs.luaeval('stricmp("\\0\\0\\0C", "\\0\\0\\0b")'))
    eq(1, funcs.luaeval('stricmp("\\0\\0\\0c", "\\0\\0\\0B")'))
    eq(1, funcs.luaeval('stricmp("\\0\\0\\0c", "\\0\\0\\0b")'))

    eq(1, funcs.luaeval('stricmp("c\\0", "B\\0")'))
    eq(1, funcs.luaeval('stricmp("C\\0", "b\\0")'))
    eq(1, funcs.luaeval('stricmp("c\\0", "b\\0")'))
    eq(1, funcs.luaeval('stricmp("C\\0", "B\\0")'))

    eq(1, funcs.luaeval('stricmp("\\0c", "\\0B")'))
    eq(1, funcs.luaeval('stricmp("\\0C", "\\0b")'))
    eq(1, funcs.luaeval('stricmp("\\0c", "\\0b")'))
    eq(1, funcs.luaeval('stricmp("\\0C", "\\0B")'))

    eq(1, funcs.luaeval('stricmp("\\0c\\0", "\\0B\\0")'))
    eq(1, funcs.luaeval('stricmp("\\0C\\0", "\\0b\\0")'))
    eq(1, funcs.luaeval('stricmp("\\0c\\0", "\\0b\\0")'))
    eq(1, funcs.luaeval('stricmp("\\0C\\0", "\\0B\\0")'))
  end)
end)
