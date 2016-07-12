local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local neq = helpers.neq
local NIL = helpers.NIL
local eval = helpers.eval
local clear = helpers.clear
local funcs = helpers.funcs
local meths = helpers.meths
local exc_exec = helpers.exc_exec
local redir_exec = helpers.redir_exec

local function startswith(expected, actual)
  eq(expected, actual:sub(1, #expected))
end

before_each(clear)

describe('luaeval() function', function()
  local nested_by_level = {}
  local nested = {}
  local nested_s = '{}'
  for i=1,100 do
    if i % 2 == 0 then
      nested = {nested}
      nested_s = '{' .. nested_s .. '}'
    else
      nested = {nested=nested}
      nested_s = '{nested=' .. nested_s .. '}'
    end
    nested_by_level[i] = {o=nested, s=nested_s}
  end

  it('correctly evaluates scalars', function()
    eq(1, funcs.luaeval('1'))
    eq(0, eval('type(luaeval("1"))'))

    eq(1.5, funcs.luaeval('1.5'))
    eq(5, eval('type(luaeval("1.5"))'))

    eq("test", funcs.luaeval('"test"'))
    eq(1, eval('type(luaeval("\'test\'"))'))

    eq('', funcs.luaeval('""'))
    eq({_TYPE={}, _VAL={'\n'}}, funcs.luaeval([['\0']]))
    eq({_TYPE={}, _VAL={'\n', '\n'}}, funcs.luaeval([['\0\n\0']]))
    eq(1, eval([[luaeval('"\0\n\0"')._TYPE is v:msgpack_types.binary]]))

    eq(true, funcs.luaeval('true'))
    eq(false, funcs.luaeval('false'))
    eq(NIL, funcs.luaeval('nil'))
  end)

  it('correctly evaluates containers', function()
    eq({}, funcs.luaeval('{}'))
    eq(3, eval('type(luaeval("{}"))'))

    eq({test=1, foo=2}, funcs.luaeval('{test=1, foo=2}'))
    eq(4, eval('type(luaeval("{test=1, foo=2}"))'))

    eq({4, 2}, funcs.luaeval('{4, 2}'))
    eq(3, eval('type(luaeval("{4, 2}"))'))

    local level = 30
    eq(nested_by_level[level].o, funcs.luaeval(nested_by_level[level].s))

    eq({_TYPE={}, _VAL={{{_TYPE={}, _VAL={'\n', '\n'}}, {_TYPE={}, _VAL={'\n', '\n\n'}}}}},
       funcs.luaeval([[{['\0\n\0']='\0\n\0\0'}]]))
    eq(1, eval([[luaeval('{["\0\n\0"]="\0\n\0\0"}')._TYPE is v:msgpack_types.map]]))
    eq(1, eval([[luaeval('{["\0\n\0"]="\0\n\0\0"}')._VAL[0][0]._TYPE is v:msgpack_types.string]]))
    eq(1, eval([[luaeval('{["\0\n\0"]="\0\n\0\0"}')._VAL[0][1]._TYPE is v:msgpack_types.binary]]))
    eq({nested={{_TYPE={}, _VAL={{{_TYPE={}, _VAL={'\n', '\n'}}, {_TYPE={}, _VAL={'\n', '\n\n'}}}}}}},
       funcs.luaeval([[{nested={{['\0\n\0']='\0\n\0\0'}}}]]))
  end)

  it('correctly passes scalars as argument', function()
    eq(1, funcs.luaeval('_A', 1))
    eq(1.5, funcs.luaeval('_A', 1.5))
    eq('', funcs.luaeval('_A', ''))
    eq('test', funcs.luaeval('_A', 'test'))
    eq(NIL, funcs.luaeval('_A', NIL))
    eq(true, funcs.luaeval('_A', true))
    eq(false, funcs.luaeval('_A', false))
  end)

  it('correctly passes containers as argument', function()
    eq({}, funcs.luaeval('_A', {}))
    eq({test=1}, funcs.luaeval('_A', {test=1}))
    eq({4, 2}, funcs.luaeval('_A', {4, 2}))
    local level = 28
    eq(nested_by_level[level].o, funcs.luaeval('_A', nested_by_level[level].o))
  end)

  local function sp(typ, val)
    return ('{"_TYPE": v:msgpack_types.%s, "_VAL": %s}'):format(typ, val)
  end
  local function mapsp(...)
    local val = ''
    for i=1,(select('#', ...)/2) do
      val = ('%s[%s,%s],'):format(val, select(i * 2 - 1, ...),
                                  select(i * 2, ...))
    end
    return sp('map', '[' .. val .. ']')
  end
  local function luaevalarg(argexpr, expr)
    return eval(([=[
      [
        extend(g:, {'_ret': luaeval(%s, %s)})._ret,
        type(g:_ret)==type({})&&has_key(g:_ret, '_TYPE')
        ? [
          get(keys(filter(copy(v:msgpack_types), 'v:val is g:_ret._TYPE')), 0,
              g:_ret._TYPE),
          get(g:_ret, '_VAL', g:_ret)
        ]
        : [0, g:_ret]][1]
    ]=]):format(expr or '"_A"', argexpr):gsub('\n', ''))
  end

  it('correctly passes special dictionaries', function()
    eq({'binary', {'\n', '\n'}}, luaevalarg(sp('binary', '["\\n", "\\n"]')))
    eq({'binary', {'\n', '\n'}}, luaevalarg(sp('string', '["\\n", "\\n"]')))
    eq({0, true}, luaevalarg(sp('boolean', 1)))
    eq({0, false}, luaevalarg(sp('boolean', 0)))
    eq({0, NIL}, luaevalarg(sp('nil', 0)))
    eq({0, {[""]=""}}, luaevalarg(mapsp(sp('binary', '[""]'), '""')))
    eq({0, {[""]=""}}, luaevalarg(mapsp(sp('string', '[""]'), '""')))
  end)

  it('issues an error in some cases', function()
    eq("Vim(call):E5100: Cannot convert given lua table: table should either have a sequence of positive integer keys or contain only string keys",
       exc_exec('call luaeval("{1, foo=2}")'))
    eq("Vim(call):E5101: Cannot convert given lua type",
       exc_exec('call luaeval("vim.api.buffer_get_line_slice")'))
    startswith("Vim(call):E5107: Error while creating lua chunk for luaeval(): ",
               exc_exec('call luaeval("1, 2, 3")'))
    startswith("Vim(call):E5108: Error while calling lua chunk for luaeval(): ",
               exc_exec('call luaeval("(nil)()")'))

    -- The following should not crash: conversion error happens inside
    eq("Vim(call):E5101: Cannot convert given lua type",
       exc_exec('call luaeval("vim.api")'))
    -- The following should not show internal error
    eq("\nE5101: Cannot convert given lua type\n0",
       redir_exec('echo luaeval("vim.api")'))
  end)

  it('correctly converts containers with type_idx', function()
    eq(5, eval('type(luaeval("{[vim.type_idx]=vim.types.float, [vim.val_idx]=0}"))'))
    eq(4, eval([[type(luaeval('{[vim.type_idx]=vim.types.dictionary}'))]]))
    eq(3, eval([[type(luaeval('{[vim.type_idx]=vim.types.array}'))]]))

    eq({}, funcs.luaeval('{[vim.type_idx]=vim.types.array}'))

    -- Presence of type_idx makes Vim ignore some keys
    eq({42}, funcs.luaeval('{[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}'))
    eq({foo=2}, funcs.luaeval('{[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}'))
    eq(10, funcs.luaeval('{[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42}'))

    -- The following should not crash
    eq({}, funcs.luaeval('{[vim.type_idx]=vim.types.dictionary}'))
  end)

  it('correctly converts from API objects', function()
    eq(1, funcs.luaeval('vim.api.vim_eval("1")'))
    eq('1', funcs.luaeval([[vim.api.vim_eval('"1"')]]))
    eq({}, funcs.luaeval('vim.api.vim_eval("[]")'))
    eq({}, funcs.luaeval('vim.api.vim_eval("{}")'))
    eq(1, funcs.luaeval('vim.api.vim_eval("1.0")'))
    eq(true, funcs.luaeval('vim.api.vim_eval("v:true")'))
    eq(false, funcs.luaeval('vim.api.vim_eval("v:false")'))
    eq(NIL, funcs.luaeval('vim.api.vim_eval("v:null")'))

    eq(0, eval([[type(luaeval('vim.api.vim_eval("1")'))]]))
    eq(1, eval([[type(luaeval('vim.api.vim_eval("''1''")'))]]))
    eq(3, eval([[type(luaeval('vim.api.vim_eval("[]")'))]]))
    eq(4, eval([[type(luaeval('vim.api.vim_eval("{}")'))]]))
    eq(5, eval([[type(luaeval('vim.api.vim_eval("1.0")'))]]))
    eq(6, eval([[type(luaeval('vim.api.vim_eval("v:true")'))]]))
    eq(6, eval([[type(luaeval('vim.api.vim_eval("v:false")'))]]))
    eq(7, eval([[type(luaeval('vim.api.vim_eval("v:null")'))]]))

    eq({foo=42}, funcs.luaeval([[vim.api.vim_eval('{"foo": 42}')]]))
    eq({42}, funcs.luaeval([[vim.api.vim_eval('[42]')]]))

    eq({foo={bar=42}, baz=50}, funcs.luaeval([[vim.api.vim_eval('{"foo": {"bar": 42}, "baz": 50}')]]))
    eq({{42}, {}}, funcs.luaeval([=[vim.api.vim_eval('[[42], []]')]=]))
  end)

  it('correctly converts to API objects', function()
    eq(1, funcs.luaeval('vim.api._vim_id(1)'))
    eq('1', funcs.luaeval('vim.api._vim_id("1")'))
    eq({1}, funcs.luaeval('vim.api._vim_id({1})'))
    eq({foo=1}, funcs.luaeval('vim.api._vim_id({foo=1})'))
    eq(1.5, funcs.luaeval('vim.api._vim_id(1.5)'))
    eq(true, funcs.luaeval('vim.api._vim_id(true)'))
    eq(false, funcs.luaeval('vim.api._vim_id(false)'))
    eq(NIL, funcs.luaeval('vim.api._vim_id(nil)'))

    eq(0, eval([[type(luaeval('vim.api._vim_id(1)'))]]))
    eq(1, eval([[type(luaeval('vim.api._vim_id("1")'))]]))
    eq(3, eval([[type(luaeval('vim.api._vim_id({1})'))]]))
    eq(4, eval([[type(luaeval('vim.api._vim_id({foo=1})'))]]))
    eq(5, eval([[type(luaeval('vim.api._vim_id(1.5)'))]]))
    eq(6, eval([[type(luaeval('vim.api._vim_id(true)'))]]))
    eq(6, eval([[type(luaeval('vim.api._vim_id(false)'))]]))
    eq(7, eval([[type(luaeval('vim.api._vim_id(nil)'))]]))

    eq({foo=1, bar={42, {{baz=true}, 5}}}, funcs.luaeval('vim.api._vim_id({foo=1, bar={42, {{baz=true}, 5}}})'))
  end)

  it('correctly converts containers with type_idx to API objects', function()
    -- TODO: Similar tests with _vim_array_id and _vim_dictionary_id, that will
    -- follow slightly different code paths.
    eq(5, eval('type(luaeval("vim.api._vim_id({[vim.type_idx]=vim.types.float, [vim.val_idx]=0})"))'))
    eq(4, eval([[type(luaeval('vim.api._vim_id({[vim.type_idx]=vim.types.dictionary})'))]]))
    eq(3, eval([[type(luaeval('vim.api._vim_id({[vim.type_idx]=vim.types.array})'))]]))

    eq({}, funcs.luaeval('vim.api._vim_id({[vim.type_idx]=vim.types.array})'))

    -- Presence of type_idx makes Vim ignore some keys
    eq({42}, funcs.luaeval('vim.api._vim_id({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'))
    eq({foo=2}, funcs.luaeval('vim.api._vim_id({[vim.type_idx]=vim.types.dictionary, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'))
    eq(10, funcs.luaeval('vim.api._vim_id({[vim.type_idx]=vim.types.float, [vim.val_idx]=10, [5]=1, foo=2, [1]=42})'))
    eq({}, funcs.luaeval('vim.api._vim_id({[vim.type_idx]=vim.types.array, [vim.val_idx]=10, [5]=1, foo=2})'))
  end)
  -- TODO: check what happens when it errors out on second list item
  -- TODO: check what happens if API function receives wrong number of
  -- arguments.
  -- TODO: check what happens if API function receives wrong argument types.

  it('correctly converts self-containing containers', function()
    meths.set_var('l', {})
    eval('add(l, l)')
    eq(true, eval('luaeval("_A == _A[1]", l)'))
    eq(true, eval('luaeval("_A[1] == _A[1][1]", [l])'))
    eq(true, eval('luaeval("_A.d == _A.d[1]", {"d": l})'))
    eq(true, eval('luaeval("_A ~= _A[1]", [l])'))

    meths.set_var('d', {foo=42})
    eval('extend(d, {"d": d})')
    eq(true, eval('luaeval("_A == _A.d", d)'))
    eq(true, eval('luaeval("_A[1] == _A[1].d", [d])'))
    eq(true, eval('luaeval("_A.d == _A.d.d", {"d": d})'))
    eq(true, eval('luaeval("_A ~= _A.d", {"d": d})'))
  end)
end)
