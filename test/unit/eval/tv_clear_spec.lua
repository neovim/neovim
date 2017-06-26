local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)
local eval_helpers = require('test.unit.eval.helpers')

local alloc_log_new = helpers.alloc_log_new
local cimport = helpers.cimport
local ffi = helpers.ffi
local eq = helpers.eq

local a = eval_helpers.alloc_logging_helpers
local type_key = eval_helpers.type_key
local list_type = eval_helpers.list_type
local list_items = eval_helpers.list_items
local dict_items = eval_helpers.dict_items
local lua2typvalt = eval_helpers.lua2typvalt

local lib = cimport('./src/nvim/eval/typval.h', './src/nvim/eval.h')

local alloc_log = alloc_log_new()

before_each(function()
  alloc_log:before_each()
end)

after_each(function()
  alloc_log:after_each()
end)

describe('tv_clear()', function()
  itp('successfully frees all lists in [&l [1], *l, *l]', function()
    local l_inner = {1}
    local list = {l_inner, l_inner, l_inner}
    local list_tv = ffi.gc(lua2typvalt(list), nil)
    local list_p = list_tv.vval.v_list
    local lis = list_items(list_p)
    local list_inner_p = lis[1].li_tv.vval.v_list
    local lis_inner = list_items(list_inner_p)
    alloc_log:check({
      a.list(list_p),
      a.list(list_inner_p),
      a.li(lis_inner[1]),
      a.li(lis[1]),
      a.li(lis[2]),
      a.li(lis[3]),
    })
    eq(3, list_inner_p.lv_refcount)
    lib.tv_clear(list_tv)
    alloc_log:check({
      a.freed(lis_inner[1]),
      a.freed(list_inner_p),
      a.freed(lis[1]),
      a.freed(lis[2]),
      a.freed(lis[3]),
      a.freed(list_p),
    })
  end)
  itp('successfully frees all lists in [&l [], *l, *l]', function()
    local l_inner = {[type_key]=list_type}
    local list = {l_inner, l_inner, l_inner}
    local list_tv = ffi.gc(lua2typvalt(list), nil)
    local list_p = list_tv.vval.v_list
    local lis = list_items(list_p)
    local list_inner_p = lis[1].li_tv.vval.v_list
    alloc_log:check({
      a.list(list_p),
      a.list(list_inner_p),
      a.li(lis[1]),
      a.li(lis[2]),
      a.li(lis[3]),
    })
    eq(3, list_inner_p.lv_refcount)
    lib.tv_clear(list_tv)
    alloc_log:check({
      a.freed(list_inner_p),
      a.freed(lis[1]),
      a.freed(lis[2]),
      a.freed(lis[3]),
      a.freed(list_p),
    })
  end)
  itp('successfully frees all dictionaries in [&d {}, *d]', function()
    local d_inner = {}
    local list = {d_inner, d_inner}
    local list_tv = ffi.gc(lua2typvalt(list), nil)
    local list_p = list_tv.vval.v_list
    local lis = list_items(list_p)
    local dict_inner_p = lis[1].li_tv.vval.v_dict
    alloc_log:check({
      a.list(list_p),
      a.dict(dict_inner_p),
      a.li(lis[1]),
      a.li(lis[2]),
    })
    eq(2, dict_inner_p.dv_refcount)
    lib.tv_clear(list_tv)
    alloc_log:check({
      a.freed(dict_inner_p),
      a.freed(lis[1]),
      a.freed(lis[2]),
      a.freed(list_p),
    })
  end)
  itp('successfully frees all dictionaries in [&d {a: 1}, *d]', function()
    local d_inner = {a=1}
    local list = {d_inner, d_inner}
    local list_tv = ffi.gc(lua2typvalt(list), nil)
    local list_p = list_tv.vval.v_list
    local lis = list_items(list_p)
    local dict_inner_p = lis[1].li_tv.vval.v_dict
    local dis = dict_items(dict_inner_p)
    alloc_log:check({
      a.list(list_p),
      a.dict(dict_inner_p),
      a.di(dis.a, 1),
      a.li(lis[1]),
      a.li(lis[2]),
    })
    eq(2, dict_inner_p.dv_refcount)
    lib.tv_clear(list_tv)
    alloc_log:check({
      a.freed(dis.a),
      a.freed(dict_inner_p),
      a.freed(lis[1]),
      a.freed(lis[2]),
      a.freed(list_p),
    })
  end)
end)
