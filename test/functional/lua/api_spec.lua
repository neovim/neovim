-- Test suite for testing interactions with API bindings
local helpers = require('test.functional.helpers')(after_each)

local exc_exec = helpers.exc_exec
local remove_trace = helpers.remove_trace
local funcs = helpers.funcs
local clear = helpers.clear
local eval = helpers.eval
local NIL = helpers.NIL
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local pcall_err = helpers.pcall_err

before_each(clear)

describe('luaeval(vim.api.…)', function()
  describe('with channel_id and buffer handle', function()
    describe('nvim_buf_get_lines', function()
      it('works', function()
        funcs.setline(1, {"abc", "def", "a\nb", "ttt"})
        eq({'a\000b'},
           funcs.luaeval('vim.api.nvim_buf_get_lines(1, 2, 3, false)'))
      end)
    end)
    describe('nvim_buf_set_lines', function()
      it('works', function()
        funcs.setline(1, {"abc", "def", "a\nb", "ttt"})
        eq(NIL, funcs.luaeval('vim.api.nvim_buf_set_lines(1, 1, 2, false, {"b\\0a"})'))
        eq({'abc', 'b\000a', 'a\000b', 'ttt'},
           funcs.luaeval('vim.api.nvim_buf_get_lines(1, 0, 4, false)'))
      end)
    end)
  end)
  describe('with errors', function()
    it('transforms API error from nvim_buf_set_lines into lua error', function()
      funcs.setline(1, {"abc", "def", "a\nb", "ttt"})
      eq({false, "'replacement string' item contains newlines"},
         funcs.luaeval('{pcall(vim.api.nvim_buf_set_lines, 1, 1, 2, false, {"b\\na"})}'))
    end)

    it('transforms API error from nvim_win_set_cursor into lua error', function()
      eq({false, 'Argument "pos" must be a [row, col] array'},
         funcs.luaeval('{pcall(vim.api.nvim_win_set_cursor, 0, {1, 2, 3})}'))
      -- Used to produce a memory leak due to a bug in nvim_win_set_cursor
      eq({false, 'Invalid window id: -1'},
         funcs.luaeval('{pcall(vim.api.nvim_win_set_cursor, -1, {1, 2, 3})}'))
    end)

    it('transforms API error from nvim_win_set_cursor + same array as in first test into lua error',
    function()
      eq({false, 'Argument "pos" must be a [row, col] array'},
         funcs.luaeval('{pcall(vim.api.nvim_win_set_cursor, 0, {"b\\na"})}'))
    end)
  end)

  it('correctly evaluates API code which calls luaeval', function()
    local str = (([===[vim.api.nvim_eval([==[
      luaeval('vim.api.nvim_eval([=[
        luaeval("vim.api.nvim_eval([[
          luaeval(1)
        ]])")
      ]=])')
    ]==])]===]):gsub('\n', ' '))
    eq(1, funcs.luaeval(str))
  end)

  it('correctly converts from API objects', function()
    eq(1, funcs.luaeval('vim.api.nvim_eval("1")'))
    eq('1', funcs.luaeval([[vim.api.nvim_eval('"1"')]]))
    eq('Blobby', funcs.luaeval('vim.api.nvim_eval("0z426c6f626279")'))
    eq({}, funcs.luaeval('vim.api.nvim_eval("[]")'))
    eq({}, funcs.luaeval('vim.api.nvim_eval("{}")'))
    eq(1, funcs.luaeval('vim.api.nvim_eval("1.0")'))
    eq('\000', funcs.luaeval('vim.api.nvim_eval("0z00")'))
    eq(true, funcs.luaeval('vim.api.nvim_eval("v:true")'))
    eq(false, funcs.luaeval('vim.api.nvim_eval("v:false")'))
    eq(NIL, funcs.luaeval('vim.api.nvim_eval("v:null")'))

    eq(0, eval([[type(luaeval('vim.api.nvim_eval("1")'))]]))
    eq(1, eval([[type(luaeval('vim.api.nvim_eval("''1''")'))]]))
    eq(1, eval([[type(luaeval('vim.api.nvim_eval("0zbeef")'))]]))
    eq(3, eval([[type(luaeval('vim.api.nvim_eval("[]")'))]]))
    eq(4, eval([[type(luaeval('vim.api.nvim_eval("{}")'))]]))
    eq(5, eval([[type(luaeval('vim.api.nvim_eval("1.0")'))]]))
    eq(6, eval([[type(luaeval('vim.api.nvim_eval("v:true")'))]]))
    eq(6, eval([[type(luaeval('vim.api.nvim_eval("v:false")'))]]))
    eq(7, eval([[type(luaeval('vim.api.nvim_eval("v:null")'))]]))

    eq({foo=42}, funcs.luaeval([[vim.api.nvim_eval('{"foo": 42}')]]))
    eq({42}, funcs.luaeval([[vim.api.nvim_eval('[42]')]]))

    eq({foo={bar=42}, baz=50}, funcs.luaeval([[vim.api.nvim_eval('{"foo": {"bar": 42}, "baz": 50}')]]))
    eq({{42}, {}}, funcs.luaeval([=[vim.api.nvim_eval('[[42], []]')]=]))
  end)

  it('correctly converts to API objects', function()
    eq(1, funcs.luaeval('vim.api.nvim__id(1)'))
    eq('1', funcs.luaeval('vim.api.nvim__id("1")'))
    eq({1}, funcs.luaeval('vim.api.nvim__id({1})'))
    eq({foo=1}, funcs.luaeval('vim.api.nvim__id({foo=1})'))
    eq(1.5, funcs.luaeval('vim.api.nvim__id(1.5)'))
    eq(true, funcs.luaeval('vim.api.nvim__id(true)'))
    eq(false, funcs.luaeval('vim.api.nvim__id(false)'))
    eq(NIL, funcs.luaeval('vim.api.nvim__id(nil)'))

    -- API strings from Blobs can work as NUL-terminated C strings
    eq('Vim(call):E5555: API call: Vim:E15: Invalid expression: ""',
       exc_exec('call nvim_eval(v:_null_blob)'))
    eq('Vim(call):E5555: API call: Vim:E15: Invalid expression: ""',
       exc_exec('call nvim_eval(0z)'))
    eq(1, eval('nvim_eval(0z31)'))

    eq(0, eval([[type(luaeval('vim.api.nvim__id(1)'))]]))
    eq(1, eval([[type(luaeval('vim.api.nvim__id("1")'))]]))
    eq(3, eval([[type(luaeval('vim.api.nvim__id({1})'))]]))
    eq(4, eval([[type(luaeval('vim.api.nvim__id({foo=1})'))]]))
    eq(5, eval([[type(luaeval('vim.api.nvim__id(1.5)'))]]))
    eq(6, eval([[type(luaeval('vim.api.nvim__id(true)'))]]))
    eq(6, eval([[type(luaeval('vim.api.nvim__id(false)'))]]))
    eq(7, eval([[type(luaeval('vim.api.nvim__id(nil)'))]]))

    eq({foo=1, bar={42, {{baz=true}, 5}}}, funcs.luaeval('vim.api.nvim__id({foo=1, bar={42, {{baz=true}, 5}}})'))

    eq(true, funcs.luaeval('vim.api.nvim__id(vim.api.nvim__id)(true)'))
    eq(42, exec_lua [[
      local f = vim.api.nvim__id({42, vim.api.nvim__id})
      return f[2](f[1])
    ]])
  end)

  it('correctly converts container objects with type_idx to API objects', function()
    eq(5, eval('type(luaeval("vim.api.nvim__id({[vim.type_idx]=vim.types.float, [vim.val_idx]=0})"))'))
    eq(4, eval([[type(luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.dictionary})'))]]))
    eq(3, eval([[type(luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.array})'))]]))

    eq({}, funcs.luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.array})'))

    -- Presence of type_idx makes Vim ignore some keys
    eq({42}, funcs.luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'))
    eq({foo=2}, funcs.luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'))
    eq(10, funcs.luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'))
    eq({}, funcs.luaeval('vim.api.nvim__id({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2})'))
  end)

  it('correctly converts arrays with type_idx to API objects', function()
    eq(3, eval([[type(luaeval('vim.api.nvim__id_array({[vim.type_idx]=vim.types.array})'))]]))

    eq({}, funcs.luaeval('vim.api.nvim__id_array({[vim.type_idx]=vim.types.array})'))

    eq({42}, funcs.luaeval('vim.api.nvim__id_array({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'))
    eq({{foo=2}}, funcs.luaeval('vim.api.nvim__id_array({{[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}})'))
    eq({10}, funcs.luaeval('vim.api.nvim__id_array({{[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}})'))
    eq({}, funcs.luaeval('vim.api.nvim__id_array({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2})'))

    eq({}, funcs.luaeval('vim.api.nvim__id_array({})'))
    eq(3, eval([[type(luaeval('vim.api.nvim__id_array({})'))]]))
  end)

  it('correctly converts dictionaries with type_idx to API objects', function()
    eq(4, eval([[type(luaeval('vim.api.nvim__id_dictionary({[vim.type_idx]=vim.types.dictionary})'))]]))

    eq({}, funcs.luaeval('vim.api.nvim__id_dictionary({[vim.type_idx]=vim.types.dictionary})'))

    eq({v={42}}, funcs.luaeval('vim.api.nvim__id_dictionary({v={[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}})'))
    eq({foo=2}, funcs.luaeval('vim.api.nvim__id_dictionary({[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'))
    eq({v=10}, funcs.luaeval('vim.api.nvim__id_dictionary({v={[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}})'))
    eq({v={}}, funcs.luaeval('vim.api.nvim__id_dictionary({v={[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2}})'))

    -- If API requests dictionary, then empty table will be the one. This is not
    -- the case normally because empty table is an empty array.
    eq({}, funcs.luaeval('vim.api.nvim__id_dictionary({})'))
    eq(4, eval([[type(luaeval('vim.api.nvim__id_dictionary({})'))]]))
  end)

  it('converts booleans in positional args', function()
    eq({''}, exec_lua [[ return vim.api.nvim_buf_get_lines(0, 0, 10, false) ]])
    eq({''}, exec_lua [[ return vim.api.nvim_buf_get_lines(0, 0, 10, nil) ]])
    eq('Index out of bounds', pcall_err(exec_lua, [[ return vim.api.nvim_buf_get_lines(0, 0, 10, true) ]]))
    eq('Index out of bounds', pcall_err(exec_lua, [[ return vim.api.nvim_buf_get_lines(0, 0, 10, 1) ]]))

    -- this follows lua conventions for bools (not api convention for Boolean)
    eq('Index out of bounds', pcall_err(exec_lua, [[ return vim.api.nvim_buf_get_lines(0, 0, 10, 0) ]]))
    eq('Index out of bounds', pcall_err(exec_lua, [[ return vim.api.nvim_buf_get_lines(0, 0, 10, {}) ]]))
  end)

  it('converts booleans in optional args', function()
    eq({}, exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {output=false}) ]])
    eq({}, exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {}) ]]) -- same as {output=nil}

    -- API conventions (not lua conventions): zero is falsy
    eq({}, exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {output=0}) ]])

    eq({output='foobar'}, exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {output=true}) ]])
    eq({output='foobar'}, exec_lua [[ return vim.api.nvim_exec2("echo 'foobar'", {output=1}) ]])
    eq([[Invalid 'output': not a boolean]], pcall_err(exec_lua, [[ return vim.api.nvim_exec2("echo 'foobar'", {output={}}) ]]))
  end)

  it('errors out correctly when working with API', function()
    -- Conversion errors
    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'obj': Cannot convert given Lua table]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim__id({1, foo=42})")]])))
    -- Errors in number of arguments
    eq('Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Expected 1 argument',
       remove_trace(exc_exec([[call luaeval("vim.api.nvim__id()")]])))
    eq('Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Expected 1 argument',
       remove_trace(exc_exec([[call luaeval("vim.api.nvim__id(1, 2)")]])))
    eq('Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Expected 2 arguments',
       remove_trace(exc_exec([[call luaeval("vim.api.nvim_set_var(1, 2, 3)")]])))
    -- Error in argument types
    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'name': Expected Lua string]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim_set_var(1, 2)")]])))

    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'start': Expected Lua number]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim_buf_get_lines(0, 'test', 1, false)")]])))
    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'start': Number is not integral]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim_buf_get_lines(0, 1.5, 1, false)")]])))
    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'window': Expected Lua number]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim_win_is_valid(nil)")]])))

    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'flt': Expected Lua number]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim__id_float('test')")]])))
    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'flt': Expected Float-like Lua table]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim__id_float({[vim.type_idx]=vim.types.dictionary})")]])))

    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'arr': Expected Lua table]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim__id_array(1)")]])))
    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'arr': Expected Array-like Lua table]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim__id_array({[vim.type_idx]=vim.types.dictionary})")]])))

    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'dct': Expected Lua table]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim__id_dictionary(1)")]])))
    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Invalid 'dct': Expected Dict-like Lua table]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim__id_dictionary({[vim.type_idx]=vim.types.array})")]])))

    eq([[Vim(call):E5108: Error executing lua [string "luaeval()"]:1: Expected Lua table]],
       remove_trace(exc_exec([[call luaeval("vim.api.nvim_set_keymap('', '', '', '')")]])))

    -- TODO: check for errors with Tabpage argument
    -- TODO: check for errors with Window argument
    -- TODO: check for errors with Buffer argument
  end)

  it('accepts any value as API Boolean', function()
    eq('', funcs.luaeval('vim.api.nvim_replace_termcodes("", vim, false, nil)'))
    eq('', funcs.luaeval('vim.api.nvim_replace_termcodes("", 0, 1.5, "test")'))
    eq('', funcs.luaeval('vim.api.nvim_replace_termcodes("", true, {}, {[vim.type_idx]=vim.types.array})'))
  end)
end)
