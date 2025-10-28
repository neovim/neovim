-- Test suite for testing interactions with API bindings
local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local exc_exec = n.exc_exec
local remove_trace = t.remove_trace
local fn = n.fn
local clear = n.clear
local eval = n.eval
local NIL = vim.NIL
local eq = t.eq
local exec_lua = n.exec_lua
local pcall_err = t.pcall_err

before_each(clear)

describe('luaeval(vim.api.…)', function()
  describe('with channel_id and buffer handle', function()
    describe('nvim_buf_get_lines', function()
      it('works', function()
        fn.setline(1, { 'abc', 'def', 'a\nb', 'ttt' })
        eq({ 'a\000b' }, fn.luaeval('vim.api.nvim_buf_get_lines(1, 2, 3, false)'))
      end)
    end)
    describe('nvim_buf_set_lines', function()
      it('works', function()
        fn.setline(1, { 'abc', 'def', 'a\nb', 'ttt' })
        eq(NIL, fn.luaeval('vim.api.nvim_buf_set_lines(1, 1, 2, false, {"b\\0a"})'))
        eq(
          { 'abc', 'b\000a', 'a\000b', 'ttt' },
          fn.luaeval('vim.api.nvim_buf_get_lines(1, 0, 4, false)')
        )
      end)
    end)
  end)
  describe('with errors', function()
    it('transforms API error from nvim_buf_set_lines into lua error', function()
      fn.setline(1, { 'abc', 'def', 'a\nb', 'ttt' })
      eq(
        { false, "'replacement string' item contains newlines" },
        fn.luaeval('{pcall(vim.api.nvim_buf_set_lines, 1, 1, 2, false, {"b\\na"})}')
      )
    end)

    it('transforms API error from nvim_win_set_cursor into lua error', function()
      eq(
        { false, 'Argument "pos" must be a [row, col] array' },
        fn.luaeval('{pcall(vim.api.nvim_win_set_cursor, 0, {1, 2, 3})}')
      )
      -- Used to produce a memory leak due to a bug in nvim_win_set_cursor
      eq(
        { false, 'Invalid window id: -1' },
        fn.luaeval('{pcall(vim.api.nvim_win_set_cursor, -1, {1, 2, 3})}')
      )
    end)

    it(
      'transforms API error from nvim_win_set_cursor + same array as in first test into lua error',
      function()
        eq(
          { false, 'Argument "pos" must be a [row, col] array' },
          fn.luaeval('{pcall(vim.api.nvim_win_set_cursor, 0, {"b\\na"})}')
        )
      end
    )
  end)

  it('correctly evaluates API code which calls luaeval', function()
    local str = (
      ([===[vim.api.nvim_eval([==[
      luaeval('vim.api.nvim_eval([=[
        luaeval("vim.api.nvim_eval([[
          luaeval(1)
        ]])")
      ]=])')
    ]==])]===]):gsub('\n', ' ')
    )
    eq(1, fn.luaeval(str))
  end)

  it('correctly converts from API objects', function()
    eq(1, fn.luaeval('vim.api.nvim_eval("1")'))
    eq('1', fn.luaeval([[vim.api.nvim_eval('"1"')]]))
    eq('Blobby', fn.luaeval('vim.api.nvim_eval("0z426c6f626279")'))
    eq({}, fn.luaeval('vim.api.nvim_eval("[]")'))
    eq({}, fn.luaeval('vim.api.nvim_eval("{}")'))
    eq(1, fn.luaeval('vim.api.nvim_eval("1.0")'))
    eq('\000', fn.luaeval('vim.api.nvim_eval("0z00")'))
    eq(true, fn.luaeval('vim.api.nvim_eval("v:true")'))
    eq(false, fn.luaeval('vim.api.nvim_eval("v:false")'))
    eq(NIL, fn.luaeval('vim.api.nvim_eval("v:null")'))

    eq(0, eval([[type(luaeval('vim.api.nvim_eval("1")'))]]))
    eq(1, eval([[type(luaeval('vim.api.nvim_eval("''1''")'))]]))
    eq(1, eval([[type(luaeval('vim.api.nvim_eval("0zbeef")'))]]))
    eq(3, eval([[type(luaeval('vim.api.nvim_eval("[]")'))]]))
    eq(4, eval([[type(luaeval('vim.api.nvim_eval("{}")'))]]))
    eq(5, eval([[type(luaeval('vim.api.nvim_eval("1.0")'))]]))
    eq(6, eval([[type(luaeval('vim.api.nvim_eval("v:true")'))]]))
    eq(6, eval([[type(luaeval('vim.api.nvim_eval("v:false")'))]]))
    eq(7, eval([[type(luaeval('vim.api.nvim_eval("v:null")'))]]))

    eq({ foo = 42 }, fn.luaeval([[vim.api.nvim_eval('{"foo": 42}')]]))
    eq({ 42 }, fn.luaeval([[vim.api.nvim_eval('[42]')]]))

    eq(
      { foo = { bar = 42 }, baz = 50 },
      fn.luaeval([[vim.api.nvim_eval('{"foo": {"bar": 42}, "baz": 50}')]])
    )
    eq({ { 42 }, {} }, fn.luaeval([=[vim.api.nvim_eval('[[42], []]')]=]))
  end)

  it('correctly converts to API objects', function()
    eq(1, fn.luaeval('vim.api.nvim__id(1)'))
    eq('1', fn.luaeval('vim.api.nvim__id("1")'))
    eq({ 1 }, fn.luaeval('vim.api.nvim__id({1})'))
    eq({ foo = 1 }, fn.luaeval('vim.api.nvim__id({foo=1})'))
    eq(1.5, fn.luaeval('vim.api.nvim__id(1.5)'))
    eq(true, fn.luaeval('vim.api.nvim__id(true)'))
    eq(false, fn.luaeval('vim.api.nvim__id(false)'))
    eq(NIL, fn.luaeval('vim.api.nvim__id(nil)'))

    -- API strings from Blobs can work as NUL-terminated C strings
    eq(
      'Vim(call):E5555: API call: Vim:E15: Invalid expression: ""',
      exc_exec('call nvim_eval(v:_null_blob)')
    )
    eq('Vim(call):E5555: API call: Vim:E15: Invalid expression: ""', exc_exec('call nvim_eval(0z)'))
    eq(1, eval('nvim_eval(0z31)'))

    eq(0, eval([[type(luaeval('vim.api.nvim__id(1)'))]]))
    eq(1, eval([[type(luaeval('vim.api.nvim__id("1")'))]]))
    eq(3, eval([[type(luaeval('vim.api.nvim__id({1})'))]]))
    eq(4, eval([[type(luaeval('vim.api.nvim__id({foo=1})'))]]))
    eq(5, eval([[type(luaeval('vim.api.nvim__id(1.5)'))]]))
    eq(6, eval([[type(luaeval('vim.api.nvim__id(true)'))]]))
    eq(6, eval([[type(luaeval('vim.api.nvim__id(false)'))]]))
    eq(7, eval([[type(luaeval('vim.api.nvim__id(nil)'))]]))

    eq(
      { foo = 1, bar = { 42, { { baz = true }, 5 } } },
      fn.luaeval('vim.api.nvim__id({foo=1, bar={42, {{baz=true}, 5}}})')
    )

    eq(true, fn.luaeval('vim.api.nvim__id(vim.api.nvim__id)(true)'))
    eq(
      42,
      exec_lua(function()
        local f = vim.api.nvim__id({ 42, vim.api.nvim__id })
        return f[2](f[1])
      end)
    )
  end)

  it('correctly converts container objects with type_idx to API objects', function()
    eq(
      5,
      eval('type(luaeval("vim.api.nvim__id({[vim.type_idx]=vim.types.float, [vim.val_idx]=0})"))')
    )
    eq(4, eval([[type(luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.dictionary})'))]]))
    eq(3, eval([[type(luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.array})'))]]))

    eq({}, fn.luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.array})'))

    -- Presence of type_idx makes Vim ignore some keys
    eq(
      { 42 },
      fn.luaeval(
        'vim.api.nvim__id({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'
      )
    )
    eq(
      { foo = 2 },
      fn.luaeval(
        'vim.api.nvim__id({[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'
      )
    )
    eq(
      10,
      fn.luaeval(
        'vim.api.nvim__id({[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'
      )
    )
    eq(
      {},
      fn.luaeval(
        'vim.api.nvim__id({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2})'
      )
    )
  end)

  it('correctly converts arrays with type_idx to API objects', function()
    eq(3, eval([[type(luaeval('vim.api.nvim__id_array({[vim.type_idx]=vim.types.array})'))]]))

    eq({}, fn.luaeval('vim.api.nvim__id_array({[vim.type_idx]=vim.types.array})'))

    eq(
      { 42 },
      fn.luaeval(
        'vim.api.nvim__id_array({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'
      )
    )
    eq(
      { { foo = 2 } },
      fn.luaeval(
        'vim.api.nvim__id_array({{[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}})'
      )
    )
    eq(
      { 10 },
      fn.luaeval(
        'vim.api.nvim__id_array({{[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}})'
      )
    )
    eq(
      {},
      fn.luaeval(
        'vim.api.nvim__id_array({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2})'
      )
    )

    eq({}, fn.luaeval('vim.api.nvim__id_array({})'))
    eq(3, eval([[type(luaeval('vim.api.nvim__id_array({})'))]]))
  end)

  it('correctly converts dictionaries with type_idx to API objects', function()
    eq(4, eval([[type(luaeval('vim.api.nvim__id_dict({[vim.type_idx]=vim.types.dictionary})'))]]))

    eq({}, fn.luaeval('vim.api.nvim__id_dict({[vim.type_idx]=vim.types.dictionary})'))

    eq(
      { v = { 42 } },
      fn.luaeval(
        'vim.api.nvim__id_dict({v={[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}})'
      )
    )
    eq(
      { foo = 2 },
      fn.luaeval(
        'vim.api.nvim__id_dict({[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'
      )
    )
    eq(
      { v = 10 },
      fn.luaeval(
        'vim.api.nvim__id_dict({v={[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}})'
      )
    )
    eq(
      { v = {} },
      fn.luaeval(
        'vim.api.nvim__id_dict({v={[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2}})'
      )
    )

    -- If API requests dict, then empty table will be the one. This is not
    -- the case normally because empty table is an empty array.
    eq({}, fn.luaeval('vim.api.nvim__id_dict({})'))
    eq(4, eval([[type(luaeval('vim.api.nvim__id_dict({})'))]]))
  end)

  it('converts booleans in positional args', function()
    eq({ '' }, exec_lua [[ return vim.api.nvim_buf_get_lines(0, 0, 10, false) ]])
    eq({ '' }, exec_lua [[ return vim.api.nvim_buf_get_lines(0, 0, 10, nil) ]])
    eq(
      'Index out of bounds',
      pcall_err(exec_lua, [[ return vim.api.nvim_buf_get_lines(0, 0, 10, true) ]])
    )
    eq(
      'Index out of bounds',
      pcall_err(exec_lua, [[ return vim.api.nvim_buf_get_lines(0, 0, 10, 1) ]])
    )

    -- this follows lua conventions for bools (not api convention for Boolean)
    eq(
      'Index out of bounds',
      pcall_err(exec_lua, [[ return vim.api.nvim_buf_get_lines(0, 0, 10, 0) ]])
    )
    eq(
      'Index out of bounds',
      pcall_err(exec_lua, [[ return vim.api.nvim_buf_get_lines(0, 0, 10, {}) ]])
    )
  end)

  it('converts booleans in optional args', function()
    eq({}, exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {output=false}) ]])
    eq({}, exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {}) ]]) -- same as {output=nil}

    -- API conventions (not lua conventions): zero is falsy
    eq({}, exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {output=0}) ]])

    eq(
      { output = 'foobar' },
      exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {output=true}) ]]
    )
    eq({ output = 'foobar' }, exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {output=1}) ]])
    eq(
      [[Invalid 'output': not a boolean]],
      pcall_err(exec_lua, [[ return vim.api.nvim_exec2("echo 'foobar'", {output={}}) ]])
    )
  end)

  it('errors out correctly when working with API', function()
    -- Conversion errors
    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'obj': Cannot convert given Lua table]],
      remove_trace(exc_exec([[call luaeval("vim.api.nvim__id({1, foo=42})")]]))
    )
    -- Errors in number of arguments
    eq(
      'Vim(call):E5108: Lua: [string "luaeval()"]:1: Expected 1 argument',
      remove_trace(exc_exec([[call luaeval("vim.api.nvim__id()")]]))
    )
    eq(
      'Vim(call):E5108: Lua: [string "luaeval()"]:1: Expected 1 argument',
      remove_trace(exc_exec([[call luaeval("vim.api.nvim__id(1, 2)")]]))
    )
    eq(
      'Vim(call):E5108: Lua: [string "luaeval()"]:1: Expected 2 arguments',
      remove_trace(exc_exec([[call luaeval("vim.api.nvim_set_var(1, 2, 3)")]]))
    )
    -- Error in argument types
    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'name': Expected Lua string]],
      remove_trace(exc_exec([[call luaeval("vim.api.nvim_set_var(1, 2)")]]))
    )

    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'start': Expected Lua number]],
      remove_trace(exc_exec([[call luaeval("vim.api.nvim_buf_get_lines(0, 'test', 1, false)")]]))
    )
    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'start': Number is not integral]],
      remove_trace(exc_exec([[call luaeval("vim.api.nvim_buf_get_lines(0, 1.5, 1, false)")]]))
    )
    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'window': Expected Lua number]],
      remove_trace(exc_exec([[call luaeval("vim.api.nvim_win_is_valid(nil)")]]))
    )

    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'flt': Expected Lua number]],
      remove_trace(exc_exec([[call luaeval("vim.api.nvim__id_float('test')")]]))
    )
    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'flt': Expected Float-like Lua table]],
      remove_trace(
        exc_exec([[call luaeval("vim.api.nvim__id_float({[vim.type_idx]=vim.types.dictionary})")]])
      )
    )

    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'arr': Expected Lua table]],
      remove_trace(exc_exec([[call luaeval("vim.api.nvim__id_array(1)")]]))
    )
    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'arr': Expected Array-like Lua table]],
      remove_trace(
        exc_exec([[call luaeval("vim.api.nvim__id_array({[vim.type_idx]=vim.types.dictionary})")]])
      )
    )

    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'dct': Expected Lua table]],
      remove_trace(exc_exec([[call luaeval("vim.api.nvim__id_dict(1)")]]))
    )
    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Invalid 'dct': Expected Dict-like Lua table]],
      remove_trace(
        exc_exec([[call luaeval("vim.api.nvim__id_dict({[vim.type_idx]=vim.types.array})")]])
      )
    )

    eq(
      [[Vim(call):E5108: Lua: [string "luaeval()"]:1: Expected Lua table]],
      remove_trace(exc_exec([[call luaeval("vim.api.nvim_set_keymap('', '', '', '')")]]))
    )

    -- TODO: check for errors with Tabpage argument
    -- TODO: check for errors with Window argument
    -- TODO: check for errors with Buffer argument
  end)

  it('accepts any value as API Boolean', function()
    eq('', fn.luaeval('vim.api.nvim_replace_termcodes("", vim, false, nil)'))
    eq('', fn.luaeval('vim.api.nvim_replace_termcodes("", 0, 1.5, "test")'))
    eq(
      '',
      fn.luaeval('vim.api.nvim_replace_termcodes("", true, {}, {[vim.type_idx]=vim.types.array})')
    )
  end)

  it('serializes sparse arrays in Lua', function()
    eq({ [1] = vim.NIL, [2] = 2 }, exec_lua [[ return { [2] = 2 } ]])
  end)
end)
