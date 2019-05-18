local bit = require('bit')
local helpers = require('test.unit.helpers')(after_each)
local eval_helpers = require('test.unit.eval.helpers')

local itp = helpers.gen_itp(it)

local OK = helpers.OK
local eq = helpers.eq
local neq = helpers.neq
local ffi = helpers.ffi
local FAIL = helpers.FAIL
local NULL = helpers.NULL
local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local alloc_log_new = helpers.alloc_log_new
local concat_tables = helpers.concat_tables
local map = helpers.map

local a = eval_helpers.alloc_logging_helpers
local int = eval_helpers.int
local list = eval_helpers.list
local dict = eval_helpers.dict
local eval0 = eval_helpers.eval0
local lst2tbl = eval_helpers.lst2tbl
local dct2tbl = eval_helpers.dct2tbl
local typvalt = eval_helpers.typvalt
local type_key = eval_helpers.type_key
local li_alloc = eval_helpers.li_alloc
local first_di = eval_helpers.first_di
local nil_value = eval_helpers.nil_value
local func_type = eval_helpers.func_type
local null_list = eval_helpers.null_list
local null_dict = eval_helpers.null_dict
local dict_items = eval_helpers.dict_items
local list_items = eval_helpers.list_items
local empty_list = eval_helpers.empty_list
local lua2typvalt = eval_helpers.lua2typvalt
local typvalt2lua = eval_helpers.typvalt2lua
local null_string = eval_helpers.null_string
local callback2tbl = eval_helpers.callback2tbl
local tbl2callback = eval_helpers.tbl2callback
local dict_watchers = eval_helpers.dict_watchers

local lib = cimport('./src/nvim/eval/typval.h', './src/nvim/memory.h',
                    './src/nvim/mbyte.h', './src/nvim/garray.h',
                    './src/nvim/eval.h', './src/nvim/vim.h',
                    './src/nvim/globals.h')

local function vimconv_alloc()
  return ffi.gc(
    ffi.cast('vimconv_T*', lib.xcalloc(1, ffi.sizeof('vimconv_T'))),
    function(vc)
      lib.convert_setup(vc, nil, nil)
      lib.xfree(vc)
    end)
end

local function list_watch_alloc(li)
  return ffi.cast('listwatch_T*', ffi.new('listwatch_T[1]', {{lw_item=li}}))
end

local function list_watch(l, li)
  local lw = list_watch_alloc(li or l.lv_first)
  lib.tv_list_watch_add(l, lw)
  return lw
end

local function get_alloc_rets(exp_log, res)
  setmetatable(res, {
    __index={
      freed=function(r, n) return {func='free', args={r[n]}} end
    }
  })
  for i = 1,#exp_log do
    if ({malloc=true, calloc=true})[exp_log[i].func] then
      res[#res + 1] = exp_log[i].ret
    end
  end
  return exp_log
end

local alloc_log = alloc_log_new()

before_each(function()
  alloc_log:before_each()
end)

after_each(function()
  alloc_log:after_each()
end)

local function ga_alloc(itemsize, growsize)
  local ga = ffi.gc(ffi.cast('garray_T*', ffi.new('garray_T[1]', {})),
                    lib.ga_clear)
  lib.ga_init(ga, itemsize or 1, growsize or 80)
  return ga
end

local function check_emsg(f, msg)
  local saved_last_msg_hist = lib.last_msg_hist
  if saved_last_msg_hist == nil then
    saved_last_msg_hist = nil
  end
  local ret = {f()}
  if msg ~= nil then
    eq(msg, ffi.string(lib.last_msg_hist.msg))
    neq(saved_last_msg_hist, lib.last_msg_hist)
  else
    if saved_last_msg_hist ~= lib.last_msg_hist then
      eq(nil, ffi.string(lib.last_msg_hist.msg))
    else
      eq(saved_last_msg_hist, lib.last_msg_hist)
    end
  end
  return unpack(ret)
end

describe('typval.c', function()
  describe('list', function()
    describe('item', function()
      describe('remove()', function()
        itp('works', function()
          local l = list(1, 2, 3, 4, 5, 6, 7)
          neq(nil, l)
          local lis = list_items(l)
          alloc_log:check({
            a.list(l),
            a.li(lis[1]),
            a.li(lis[2]),
            a.li(lis[3]),
            a.li(lis[4]),
            a.li(lis[5]),
            a.li(lis[6]),
            a.li(lis[7]),
          })

          eq(lis[2], lib.tv_list_item_remove(l, lis[1]))
          alloc_log:check({
            a.freed(table.remove(lis, 1)),
          })
          eq(lis, list_items(l))

          eq(lis[7], lib.tv_list_item_remove(l, lis[6]))
          alloc_log:check({
            a.freed(table.remove(lis)),
          })
          eq(lis, list_items(l))

          eq(lis[4], lib.tv_list_item_remove(l, lis[3]))
          alloc_log:check({
            a.freed(table.remove(lis, 3)),
          })
          eq(lis, list_items(l))
        end)
        itp('also frees the value', function()
          local l = list('a', 'b', 'c', 'd')
          neq(nil, l)
          local lis = list_items(l)
          alloc_log:check({
            a.list(l),
            a.str(lis[1].li_tv.vval.v_string, 1),
            a.li(lis[1]),
            a.str(lis[2].li_tv.vval.v_string, 1),
            a.li(lis[2]),
            a.str(lis[3].li_tv.vval.v_string, 1),
            a.li(lis[3]),
            a.str(lis[4].li_tv.vval.v_string, 1),
            a.li(lis[4]),
          })
          local strings = map(function(li) return li.li_tv.vval.v_string end,
                              lis)

          eq(lis[2], lib.tv_list_item_remove(l, lis[1]))
          alloc_log:check({
            a.freed(table.remove(strings, 1)),
            a.freed(table.remove(lis, 1)),
          })
          eq(lis, list_items(l))

          eq(lis[3], lib.tv_list_item_remove(l, lis[2]))
          alloc_log:check({
            a.freed(table.remove(strings, 2)),
            a.freed(table.remove(lis, 2)),
          })
          eq(lis, list_items(l))

          eq(nil, lib.tv_list_item_remove(l, lis[2]))
          alloc_log:check({
            a.freed(table.remove(strings, 2)),
            a.freed(table.remove(lis, 2)),
          })
          eq(lis, list_items(l))
        end)
        itp('works and adjusts watchers correctly', function()
          local l = ffi.gc(list(1, 2, 3, 4, 5, 6, 7), nil)
          neq(nil, l)
          local lis = list_items(l)
          -- Three watchers: pointing to first, middle and last elements.
          local lws = {
            list_watch(l, lis[1]),
            list_watch(l, lis[4]),
            list_watch(l, lis[7]),
          }
          alloc_log:check({
            a.list(l),
            a.li(lis[1]),
            a.li(lis[2]),
            a.li(lis[3]),
            a.li(lis[4]),
            a.li(lis[5]),
            a.li(lis[6]),
            a.li(lis[7]),
          })

          eq(lis[5], lib.tv_list_item_remove(l, lis[4]))
          alloc_log:check({a.freed(lis[4])})
          eq({lis[1], lis[5], lis[7]}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item})

          eq(lis[3], lib.tv_list_item_remove(l, lis[2]))
          alloc_log:check({a.freed(lis[2])})
          eq({lis[1], lis[5], lis[7]}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item})

          eq(nil, lib.tv_list_item_remove(l, lis[7]))
          alloc_log:check({a.freed(lis[7])})
          eq({lis[1], lis[5], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

          eq(lis[3], lib.tv_list_item_remove(l, lis[1]))
          alloc_log:check({a.freed(lis[1])})
          eq({lis[3], lis[5], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

          lib.tv_list_watch_remove(l, lws[2])
          lib.tv_list_watch_remove(l, lws[3])
          lib.tv_list_watch_remove(l, lws[1])
          lib.tv_list_free(l)
          alloc_log:check({
            a.freed(lis[3]),
            a.freed(lis[5]),
            a.freed(lis[6]),
            a.freed(l),
          })
        end)
      end)
    end)
    describe('watch', function()
      describe('remove()', function()
        itp('works', function()
          local l = ffi.gc(list(1, 2, 3, 4, 5, 6, 7), nil)
          eq(nil, l.lv_watch)
          local lw = list_watch(l)
          neq(nil, l.lv_watch)
          alloc_log:clear()
          lib.tv_list_watch_remove(l, lw)
          eq(nil, l.lv_watch)
          alloc_log:check({
            -- Does not free anything.
          })
          local lws = { list_watch(l), list_watch(l), list_watch(l) }
          alloc_log:clear()
          lib.tv_list_watch_remove(l, lws[2])
          eq(lws[3], l.lv_watch)
          eq(lws[1], l.lv_watch.lw_next)
          lib.tv_list_watch_remove(l, lws[1])
          eq(lws[3], l.lv_watch)
          eq(nil, l.lv_watch.lw_next)
          lib.tv_list_watch_remove(l, lws[3])
          eq(nil, l.lv_watch)
          alloc_log:check({
            -- Does not free anything.
          })
        end)
        itp('ignores not found watchers', function()
          local l = list(1, 2, 3, 4, 5, 6, 7)
          local lw = list_watch_alloc()
          lib.tv_list_watch_remove(l, lw)
        end)
      end)
    end)
    -- add() and fix() were tested when testing tv_list_item_remove()
    describe('free()', function()
      itp('recursively frees list', function()
        local l1 = ffi.gc(list(1, 'abc'), nil)
        local l2 = ffi.gc(list({}), nil)
        local l3 = ffi.gc(list(empty_list), nil)
        local alloc_rets = {}
        alloc_log:check(get_alloc_rets({
          a.list(l1),
          a.li(l1.lv_first),
          a.str(l1.lv_last.li_tv.vval.v_string, #('abc')),
          a.li(l1.lv_last),
          a.list(l2),
          a.dict(l2.lv_first.li_tv.vval.v_dict),
          a.li(l2.lv_first),
          a.list(l3),
          a.list(l3.lv_first.li_tv.vval.v_list),
          a.li(l3.lv_first),
        }, alloc_rets))
        lib.tv_list_free(l1)
        alloc_log:check({
          alloc_rets:freed(2),
          alloc_rets:freed(3),
          alloc_rets:freed(4),
          alloc_rets:freed(1),
        })
        lib.tv_list_free(l2)
        alloc_log:check({
          alloc_rets:freed(6),
          alloc_rets:freed(7),
          alloc_rets:freed(5),
        })
        lib.tv_list_free(l3)
        alloc_log:check({
          alloc_rets:freed(9),
          alloc_rets:freed(10),
          alloc_rets:freed(8),
        })
      end)
    end)
    describe('free_list()', function()
      itp('does not free list contents', function()
        local l1 = ffi.gc(list(1, 'abc'), nil)
        local l2 = ffi.gc(list({}), nil)
        local l3 = ffi.gc(list(empty_list), nil)
        local alloc_rets = {}
        alloc_log:check(get_alloc_rets({
          a.list(l1),
          a.li(l1.lv_first),
          a.str(l1.lv_last.li_tv.vval.v_string, #('abc')),
          a.li(l1.lv_last),
          a.list(l2),
          a.dict(l2.lv_first.li_tv.vval.v_dict),
          a.li(l2.lv_first),
          a.list(l3),
          a.list(l3.lv_first.li_tv.vval.v_list),
          a.li(l3.lv_first),
        }, alloc_rets))
        lib.tv_list_free_list(l1)
        alloc_log:check({
          alloc_rets:freed(1),
        })
        lib.tv_list_free_list(l2)
        alloc_log:check({
          alloc_rets:freed(5),
        })
        lib.tv_list_free_list(l3)
        alloc_log:check({
          alloc_rets:freed(8),
        })
      end)
    end)
    describe('free_contents()', function()
      itp('recursively frees list, except for the list structure itself',
      function()
        local l1 = ffi.gc(list(1, 'abc'), nil)
        local l2 = ffi.gc(list({}), nil)
        local l3 = ffi.gc(list(empty_list), nil)
        local alloc_rets = {}
        alloc_log:check(get_alloc_rets({
          a.list(l1),
          a.li(l1.lv_first),
          a.str(l1.lv_last.li_tv.vval.v_string, #('abc')),
          a.li(l1.lv_last),
          a.list(l2),
          a.dict(l2.lv_first.li_tv.vval.v_dict),
          a.li(l2.lv_first),
          a.list(l3),
          a.list(l3.lv_first.li_tv.vval.v_list),
          a.li(l3.lv_first),
        }, alloc_rets))
        lib.tv_list_free_contents(l1)
        alloc_log:check({
          alloc_rets:freed(2),
          alloc_rets:freed(3),
          alloc_rets:freed(4),
        })
        lib.tv_list_free_contents(l2)
        alloc_log:check({
          alloc_rets:freed(6),
          alloc_rets:freed(7),
        })
        lib.tv_list_free_contents(l3)
        alloc_log:check({
          alloc_rets:freed(9),
          alloc_rets:freed(10),
        })
      end)
    end)
    describe('unref()', function()
      itp('recursively frees list when reference count goes to 0', function()
        local l = ffi.gc(list(empty_list), nil)
        local alloc_rets = {}
        alloc_log:check(get_alloc_rets({
          a.list(l),
          a.list(l.lv_first.li_tv.vval.v_list),
          a.li(l.lv_first),
        }, alloc_rets))
        l.lv_refcount = 2
        lib.tv_list_unref(l)
        alloc_log:check({})
        lib.tv_list_unref(l)
        alloc_log:check({
          alloc_rets:freed(2),
          alloc_rets:freed(3),
          alloc_rets:freed(1),
        })
      end)
    end)
    describe('drop_items()', function()
      itp('works', function()
        local l_tv = lua2typvalt({1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13})
        local l = l_tv.vval.v_list
        local lis = list_items(l)
        -- Three watchers: pointing to first, middle and last elements.
        local lws = {
          list_watch(l, lis[1]),
          list_watch(l, lis[7]),
          list_watch(l, lis[13]),
        }
        alloc_log:clear()

        lib.tv_list_drop_items(l, lis[1], lis[3])
        eq({4, 5, 6, 7, 8, 9, 10, 11, 12, 13}, typvalt2lua(l_tv))
        eq({lis[4], lis[7], lis[13]}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item})

        lib.tv_list_drop_items(l, lis[11], lis[13])
        eq({4, 5, 6, 7, 8, 9, 10}, typvalt2lua(l_tv))
        eq({lis[4], lis[7], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

        lib.tv_list_drop_items(l, lis[6], lis[8])
        eq({4, 5, 9, 10}, typvalt2lua(l_tv))
        eq({lis[4], lis[9], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

        lib.tv_list_drop_items(l, lis[4], lis[10])
        eq(empty_list, typvalt2lua(l_tv))
        eq({true, true, true}, {lws[1].lw_item == nil, lws[2].lw_item == nil, lws[3].lw_item == nil})

        lib.tv_list_watch_remove(l, lws[1])
        lib.tv_list_watch_remove(l, lws[2])
        lib.tv_list_watch_remove(l, lws[3])

        alloc_log:check({})
      end)
    end)
    describe('remove_items()', function()
      itp('works', function()
        local l_tv = lua2typvalt({'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13'})
        local l = l_tv.vval.v_list
        local lis = list_items(l)
        local strings = map(function(li) return li.li_tv.vval.v_string end, lis)
        -- Three watchers: pointing to first, middle and last elements.
        local lws = {
          list_watch(l, lis[1]),
          list_watch(l, lis[7]),
          list_watch(l, lis[13]),
        }
        alloc_log:clear()

        lib.tv_list_remove_items(l, lis[1], lis[3])
        eq({'4', '5', '6', '7', '8', '9', '10', '11', '12', '13'}, typvalt2lua(l_tv))
        eq({lis[4], lis[7], lis[13]}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item})
        alloc_log:check({
          a.freed(strings[1]),
          a.freed(lis[1]),
          a.freed(strings[2]),
          a.freed(lis[2]),
          a.freed(strings[3]),
          a.freed(lis[3]),
        })

        lib.tv_list_remove_items(l, lis[11], lis[13])
        eq({'4', '5', '6', '7', '8', '9', '10'}, typvalt2lua(l_tv))
        eq({lis[4], lis[7], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})
        alloc_log:check({
          a.freed(strings[11]),
          a.freed(lis[11]),
          a.freed(strings[12]),
          a.freed(lis[12]),
          a.freed(strings[13]),
          a.freed(lis[13]),
        })

        lib.tv_list_remove_items(l, lis[6], lis[8])
        eq({'4', '5', '9', '10'}, typvalt2lua(l_tv))
        eq({lis[4], lis[9], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})
        alloc_log:check({
          a.freed(strings[6]),
          a.freed(lis[6]),
          a.freed(strings[7]),
          a.freed(lis[7]),
          a.freed(strings[8]),
          a.freed(lis[8]),
        })

        lib.tv_list_remove_items(l, lis[4], lis[10])
        eq(empty_list, typvalt2lua(l_tv))
        eq({true, true, true}, {lws[1].lw_item == nil, lws[2].lw_item == nil, lws[3].lw_item == nil})
        alloc_log:check({
          a.freed(strings[4]),
          a.freed(lis[4]),
          a.freed(strings[5]),
          a.freed(lis[5]),
          a.freed(strings[9]),
          a.freed(lis[9]),
          a.freed(strings[10]),
          a.freed(lis[10]),
        })

        lib.tv_list_watch_remove(l, lws[1])
        lib.tv_list_watch_remove(l, lws[2])
        lib.tv_list_watch_remove(l, lws[3])

        alloc_log:check({})
      end)
    end)
    describe('insert', function()
      describe('()', function()
        itp('works', function()
          local l_tv = lua2typvalt({1, 2, 3, 4, 5, 6, 7})
          local l = l_tv.vval.v_list
          local lis = list_items(l)
          local li

          li = li_alloc(true)
          li.li_tv = {v_type=lib.VAR_FLOAT, vval={v_float=100500}}
          lib.tv_list_insert(l, li, nil)
          eq(l.lv_last, li)
          eq({1, 2, 3, 4, 5, 6, 7, 100500}, typvalt2lua(l_tv))

          li = li_alloc(true)
          li.li_tv = {v_type=lib.VAR_FLOAT, vval={v_float=0}}
          lib.tv_list_insert(l, li, lis[1])
          eq(l.lv_first, li)
          eq({0, 1, 2, 3, 4, 5, 6, 7, 100500}, typvalt2lua(l_tv))

          li = li_alloc(true)
          li.li_tv = {v_type=lib.VAR_FLOAT, vval={v_float=4.5}}
          lib.tv_list_insert(l, li, lis[5])
          eq(list_items(l)[6], li)
          eq({0, 1, 2, 3, 4, 4.5, 5, 6, 7, 100500}, typvalt2lua(l_tv))
        end)
        itp('works with an empty list', function()
          local l_tv = lua2typvalt(empty_list)
          local l = l_tv.vval.v_list

          eq(nil, l.lv_first)
          eq(nil, l.lv_last)

          local li = li_alloc(true)
          li.li_tv = {v_type=lib.VAR_FLOAT, vval={v_float=100500}}
          lib.tv_list_insert(l, li, nil)
          eq(l.lv_last, li)
          eq({100500}, typvalt2lua(l_tv))
        end)
      end)
      describe('tv()', function()
        itp('works', function()
          local l_tv = lua2typvalt(empty_list)
          local l = l_tv.vval.v_list

          local l_l_tv = lua2typvalt(empty_list)
          alloc_log:clear()
          local l_l = l_l_tv.vval.v_list
          eq(1, l_l.lv_refcount)
          lib.tv_list_insert_tv(l, l_l_tv, nil)
          eq(2, l_l.lv_refcount)
          eq(l_l, l.lv_first.li_tv.vval.v_list)
          alloc_log:check({
            a.li(l.lv_first),
          })

          local l_s_tv = lua2typvalt('test')
          alloc_log:check({
            a.str(l_s_tv.vval.v_string, 'test'),
          })
          lib.tv_list_insert_tv(l, l_s_tv, l.lv_first)
          alloc_log:check({
            a.li(l.lv_first),
            a.str(l.lv_first.li_tv.vval.v_string, 'test'),
          })

          eq({'test', empty_list}, typvalt2lua(l_tv))
        end)
      end)
    end)
    describe('append', function()
      describe('list()', function()
        itp('works', function()
          local l_tv = lua2typvalt(empty_list)
          local l = l_tv.vval.v_list

          local l_l = list(1)
          alloc_log:clear()
          eq(1, l_l.lv_refcount)
          lib.tv_list_append_list(l, l_l)
          eq(2, l_l.lv_refcount)
          eq(l_l, l.lv_first.li_tv.vval.v_list)
          alloc_log:check({
            a.li(l.lv_last),
          })

          lib.tv_list_append_list(l, nil)
          alloc_log:check({
            a.li(l.lv_last),
          })

          eq({{1}, null_list}, typvalt2lua(l_tv))
        end)
      end)
      describe('dict()', function()
        itp('works', function()
          local l_tv = lua2typvalt(empty_list)
          local l = l_tv.vval.v_list

          local l_d_tv = lua2typvalt({test=1})
          local l_d = l_d_tv.vval.v_dict
          alloc_log:clear()
          eq(1, l_d.dv_refcount)
          lib.tv_list_append_dict(l, l_d)
          eq(2, l_d.dv_refcount)
          eq(l_d, l.lv_first.li_tv.vval.v_list)
          alloc_log:check({
            a.li(l.lv_last),
          })

          lib.tv_list_append_dict(l, nil)
          alloc_log:check({
            a.li(l.lv_last),
          })

          eq({{test=1}, null_dict}, typvalt2lua(l_tv))
        end)
      end)
      describe('string()', function()
        itp('works', function()
          local l_tv = lua2typvalt(empty_list)
          local l = l_tv.vval.v_list

          alloc_log:clear()
          lib.tv_list_append_string(l, 'test', 3)
          alloc_log:check({
            a.str(l.lv_last.li_tv.vval.v_string, 'tes'),
            a.li(l.lv_last),
          })

          lib.tv_list_append_string(l, nil, 0)
          alloc_log:check({
            a.li(l.lv_last),
          })

          lib.tv_list_append_string(l, nil, -1)
          alloc_log:check({
            a.li(l.lv_last),
          })

          lib.tv_list_append_string(l, 'test', -1)
          alloc_log:check({
            a.str(l.lv_last.li_tv.vval.v_string, 'test'),
            a.li(l.lv_last),
          })

          eq({'tes', null_string, null_string, 'test'}, typvalt2lua(l_tv))
        end)
      end)
      describe('allocated string()', function()
        itp('works', function()
          local l_tv = lua2typvalt(empty_list)
          local l = l_tv.vval.v_list

          local s = lib.xstrdup('test')
          alloc_log:clear()
          lib.tv_list_append_allocated_string(l, s)
          alloc_log:check({
            a.li(l.lv_last),
          })

          lib.tv_list_append_allocated_string(l, nil)
          alloc_log:check({
            a.li(l.lv_last),
          })

          lib.tv_list_append_allocated_string(l, nil)
          alloc_log:check({
            a.li(l.lv_last),
          })

          eq({'test', null_string, null_string}, typvalt2lua(l_tv))
        end)
      end)
      describe('number()', function()
        itp('works', function()
          local l_tv = lua2typvalt(empty_list)
          local l = l_tv.vval.v_list

          alloc_log:clear()
          lib.tv_list_append_number(l, -100500)
          alloc_log:check({
            a.li(l.lv_last),
          })

          lib.tv_list_append_number(l, 100500)
          alloc_log:check({
            a.li(l.lv_last),
          })

          eq({int(-100500), int(100500)}, typvalt2lua(l_tv))
        end)
      end)
      describe('tv()', function()
        itp('works', function()
          local l_tv = lua2typvalt(empty_list)
          local l = l_tv.vval.v_list

          local l_l_tv = lua2typvalt(empty_list)
          alloc_log:clear()
          local l_l = l_l_tv.vval.v_list
          eq(1, l_l.lv_refcount)
          lib.tv_list_append_tv(l, l_l_tv)
          eq(2, l_l.lv_refcount)
          eq(l_l, l.lv_first.li_tv.vval.v_list)
          alloc_log:check({
            a.li(l.lv_first),
          })

          local l_s_tv = lua2typvalt('test')
          alloc_log:check({
            a.str(l_s_tv.vval.v_string, 'test'),
          })
          lib.tv_list_append_tv(l, l_s_tv)
          alloc_log:check({
            a.li(l.lv_last),
            a.str(l.lv_last.li_tv.vval.v_string, 'test'),
          })

          eq({empty_list, 'test'}, typvalt2lua(l_tv))
        end)
      end)
      describe('owned tv()', function()
        itp('works', function()
          local l_tv = lua2typvalt(empty_list)
          local l = l_tv.vval.v_list

          local l_l_tv = lua2typvalt(empty_list)
          alloc_log:clear()
          local l_l = l_l_tv.vval.v_list
          eq(1, l_l.lv_refcount)
          lib.tv_list_append_owned_tv(l, l_l_tv)
          eq(1, l_l.lv_refcount)
          l_l.lv_refcount = l_l.lv_refcount + 1
          eq(l_l, l.lv_first.li_tv.vval.v_list)
          alloc_log:check({
            a.li(l.lv_first),
          })

          local l_s_tv = ffi.gc(lua2typvalt('test'), nil)
          alloc_log:check({
            a.str(l_s_tv.vval.v_string, 'test'),
          })
          lib.tv_list_append_owned_tv(l, l_s_tv)
          eq(l_s_tv.vval.v_string, l.lv_last.li_tv.vval.v_string)
          l_s_tv.vval.v_string = nil
          alloc_log:check({
            a.li(l.lv_last),
          })

          eq({empty_list, 'test'}, typvalt2lua(l_tv))
        end)
      end)
    end)
    describe('copy()', function()
      local function tv_list_copy(...)
        return ffi.gc(lib.tv_list_copy(...), lib.tv_list_unref)
      end
      itp('copies NULL correctly', function()
        eq(nil, lib.tv_list_copy(nil, nil, true, 0))
        eq(nil, lib.tv_list_copy(nil, nil, false, 0))
        eq(nil, lib.tv_list_copy(nil, nil, true, 1))
        eq(nil, lib.tv_list_copy(nil, nil, false, 1))
      end)
      itp('copies list correctly without converting items', function()
        do
          local v = {{['«']='»'}, {'„'}, 1, '“', null_string, null_list, null_dict}
          local l_tv = lua2typvalt(v)
          local l = l_tv.vval.v_list
          local lis = list_items(l)
          alloc_log:clear()

          eq(1, lis[1].li_tv.vval.v_dict.dv_refcount)
          eq(1, lis[2].li_tv.vval.v_list.lv_refcount)
          local l_copy1 = tv_list_copy(nil, l, false, 0)
          eq(2, lis[1].li_tv.vval.v_dict.dv_refcount)
          eq(2, lis[2].li_tv.vval.v_list.lv_refcount)
          local lis_copy1 = list_items(l_copy1)
          eq(lis[1].li_tv.vval.v_dict, lis_copy1[1].li_tv.vval.v_dict)
          eq(lis[2].li_tv.vval.v_list, lis_copy1[2].li_tv.vval.v_list)
          eq(v, lst2tbl(l_copy1))
          alloc_log:check({
            a.list(l_copy1),
            a.li(lis_copy1[1]),
            a.li(lis_copy1[2]),
            a.li(lis_copy1[3]),
            a.li(lis_copy1[4]),
            a.str(lis_copy1[4].li_tv.vval.v_string, #v[4]),
            a.li(lis_copy1[5]),
            a.li(lis_copy1[6]),
            a.li(lis_copy1[7]),
          })
          lib.tv_list_free(ffi.gc(l_copy1, nil))
          alloc_log:clear()

          eq(1, lis[1].li_tv.vval.v_dict.dv_refcount)
          eq(1, lis[2].li_tv.vval.v_list.lv_refcount)
          local l_deepcopy1 = tv_list_copy(nil, l, true, 0)
          neq(nil, l_deepcopy1)
          eq(1, lis[1].li_tv.vval.v_dict.dv_refcount)
          eq(1, lis[2].li_tv.vval.v_list.lv_refcount)
          local lis_deepcopy1 = list_items(l_deepcopy1)
          neq(lis[1].li_tv.vval.v_dict, lis_deepcopy1[1].li_tv.vval.v_dict)
          neq(lis[2].li_tv.vval.v_list, lis_deepcopy1[2].li_tv.vval.v_list)
          eq(v, lst2tbl(l_deepcopy1))
          local di_deepcopy1 = first_di(lis_deepcopy1[1].li_tv.vval.v_dict)
          alloc_log:check({
            a.list(l_deepcopy1),
            a.li(lis_deepcopy1[1]),
            a.dict(lis_deepcopy1[1].li_tv.vval.v_dict),
            a.di(di_deepcopy1, #('«')),
            a.str(di_deepcopy1.di_tv.vval.v_string, #v[1]['«']),
            a.li(lis_deepcopy1[2]),
            a.list(lis_deepcopy1[2].li_tv.vval.v_list),
            a.li(lis_deepcopy1[2].li_tv.vval.v_list.lv_first),
            a.str(lis_deepcopy1[2].li_tv.vval.v_list.lv_first.li_tv.vval.v_string, #v[2][1]),
            a.li(lis_deepcopy1[3]),
            a.li(lis_deepcopy1[4]),
            a.str(lis_deepcopy1[4].li_tv.vval.v_string, #v[4]),
            a.li(lis_deepcopy1[5]),
            a.li(lis_deepcopy1[6]),
            a.li(lis_deepcopy1[7]),
          })
        end
        collectgarbage()
      end)
      itp('copies list correctly and converts items', function()
        local vc = vimconv_alloc()
        -- UTF-8 ↔ latin1 conversions needs no iconv
        eq(OK, lib.convert_setup(vc, to_cstr('utf-8'), to_cstr('latin1')))

        local v = {{['«']='»'}, {'„'}, 1, '“', null_string, null_list, null_dict}
        local l_tv = lua2typvalt(v)
        local l = l_tv.vval.v_list
        local lis = list_items(l)
        alloc_log:clear()

        eq(1, lis[1].li_tv.vval.v_dict.dv_refcount)
        eq(1, lis[2].li_tv.vval.v_list.lv_refcount)
        local l_deepcopy1 = tv_list_copy(vc, l, true, 0)
        neq(nil, l_deepcopy1)
        eq(1, lis[1].li_tv.vval.v_dict.dv_refcount)
        eq(1, lis[2].li_tv.vval.v_list.lv_refcount)
        local lis_deepcopy1 = list_items(l_deepcopy1)
        neq(lis[1].li_tv.vval.v_dict, lis_deepcopy1[1].li_tv.vval.v_dict)
        neq(lis[2].li_tv.vval.v_list, lis_deepcopy1[2].li_tv.vval.v_list)
        eq({{['\171']='\187'}, {'\191'}, 1, '\191', null_string, null_list, null_dict},
           lst2tbl(l_deepcopy1))
        local di_deepcopy1 = first_di(lis_deepcopy1[1].li_tv.vval.v_dict)
        alloc_log:clear_tmp_allocs()
        alloc_log:check({
          a.list(l_deepcopy1),
          a.li(lis_deepcopy1[1]),
          a.dict(lis_deepcopy1[1].li_tv.vval.v_dict),
          a.di(di_deepcopy1, 1),
          a.str(di_deepcopy1.di_tv.vval.v_string, 2),
          a.li(lis_deepcopy1[2]),
          a.list(lis_deepcopy1[2].li_tv.vval.v_list),
          a.li(lis_deepcopy1[2].li_tv.vval.v_list.lv_first),
          a.str(lis_deepcopy1[2].li_tv.vval.v_list.lv_first.li_tv.vval.v_string, #v[2][1]),
          a.li(lis_deepcopy1[3]),
          a.li(lis_deepcopy1[4]),
          a.str(lis_deepcopy1[4].li_tv.vval.v_string, #v[4]),
          a.li(lis_deepcopy1[5]),
          a.li(lis_deepcopy1[6]),
          a.li(lis_deepcopy1[7]),
        })
      end)
      itp('returns different/same containers with(out) copyID', function()
        local l_inner_tv = lua2typvalt(empty_list)
        local l_tv = lua2typvalt({l_inner_tv, l_inner_tv})
        eq(3, l_inner_tv.vval.v_list.lv_refcount)
        local l = l_tv.vval.v_list
        eq(l.lv_first.li_tv.vval.v_list, l.lv_last.li_tv.vval.v_list)

        local l_copy1 = tv_list_copy(nil, l, true, 0)
        neq(l_copy1.lv_first.li_tv.vval.v_list, l_copy1.lv_last.li_tv.vval.v_list)
        eq({empty_list, empty_list}, lst2tbl(l_copy1))

        local l_copy2 = tv_list_copy(nil, l, true, 2)
        eq(l_copy2.lv_first.li_tv.vval.v_list, l_copy2.lv_last.li_tv.vval.v_list)
        eq({empty_list, empty_list}, lst2tbl(l_copy2))

        eq(3, l_inner_tv.vval.v_list.lv_refcount)
      end)
      itp('works with self-referencing list with copyID', function()
        local l_tv = lua2typvalt(empty_list)
        local l = l_tv.vval.v_list
        eq(1, l.lv_refcount)
        lib.tv_list_append_list(l, l)
        eq(2, l.lv_refcount)

        local l_copy1 = tv_list_copy(nil, l, true, 2)
        eq(2, l_copy1.lv_refcount)
        local v = {}
        v[1] = v
        eq(v, lst2tbl(l_copy1))

        local lis = list_items(l)
        lib.tv_list_item_remove(l, lis[1])
        eq(1, l.lv_refcount)

        local lis_copy1 = list_items(l_copy1)
        lib.tv_list_item_remove(l_copy1, lis_copy1[1])
        eq(1, l_copy1.lv_refcount)
      end)
    end)
    describe('extend()', function()
      itp('can extend list with itself', function()
        local l

        l = list(1, {})
        alloc_log:clear()
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        lib.tv_list_extend(l, l, nil)
        alloc_log:check({
          a.li(l.lv_last.li_prev),
          a.li(l.lv_last),
        })
        eq(1, l.lv_refcount)
        eq(2, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq({1, {}, 1, {}}, lst2tbl(l))

        l = list(1, {})
        alloc_log:clear()
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        lib.tv_list_extend(l, l, l.lv_last)
        alloc_log:check({
          a.li(l.lv_last.li_prev.li_prev),
          a.li(l.lv_last.li_prev),
        })
        eq({1, 1, {}, {}}, lst2tbl(l))
        eq(1, l.lv_refcount)
        eq(2, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        l = list(1, {})
        alloc_log:clear()
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        lib.tv_list_extend(l, l, l.lv_first)
        alloc_log:check({
          a.li(l.lv_first),
          a.li(l.lv_first.li_next),
        })
        eq({1, {}, 1, {}}, lst2tbl(l))
        eq(1, l.lv_refcount)
        eq(2, l.lv_last.li_tv.vval.v_dict.dv_refcount)
      end)
      itp('can extend list with an empty list', function()
        local l = list(1, {})
        local el = list()
        alloc_log:clear()
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, el.lv_refcount)

        lib.tv_list_extend(l, el, nil)
        alloc_log:check({
        })
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, el.lv_refcount)
        eq({1, {}}, lst2tbl(l))

        lib.tv_list_extend(l, el, l.lv_first)
        alloc_log:check({
        })
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, el.lv_refcount)
        eq({1, {}}, lst2tbl(l))

        lib.tv_list_extend(l, el, l.lv_last)
        alloc_log:check({
        })
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, el.lv_refcount)
        eq({1, {}}, lst2tbl(l))
      end)
      itp('can extend list with another non-empty list', function()
        local l
        local l2 = list(42, empty_list)
        eq(1, l2.lv_refcount)
        eq(1, l2.lv_last.li_tv.vval.v_list.lv_refcount)

        l = ffi.gc(list(1, {}), nil)
        alloc_log:clear()
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        lib.tv_list_extend(l, l2, nil)
        alloc_log:check({
          a.li(l.lv_last.li_prev),
          a.li(l.lv_last),
        })
        eq(1, l2.lv_refcount)
        eq(2, l2.lv_last.li_tv.vval.v_list.lv_refcount)
        eq({1, {}, 42, empty_list}, lst2tbl(l))
        lib.tv_list_free(l)
        eq(1, l2.lv_last.li_tv.vval.v_list.lv_refcount)

        l = ffi.gc(list(1, {}), nil)
        alloc_log:clear()
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        lib.tv_list_extend(l, l2, l.lv_first)
        alloc_log:check({
          a.li(l.lv_first),
          a.li(l.lv_first.li_next),
        })
        eq(1, l2.lv_refcount)
        eq(2, l2.lv_last.li_tv.vval.v_list.lv_refcount)
        eq({42, empty_list, 1, {}}, lst2tbl(l))
        lib.tv_list_free(l)
        eq(1, l2.lv_last.li_tv.vval.v_list.lv_refcount)

        l = ffi.gc(list(1, {}), nil)
        alloc_log:clear()
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        lib.tv_list_extend(l, l2, l.lv_last)
        alloc_log:check({
          a.li(l.lv_first.li_next),
          a.li(l.lv_first.li_next.li_next),
        })
        eq(1, l2.lv_refcount)
        eq(2, l2.lv_last.li_tv.vval.v_list.lv_refcount)
        eq({1, 42, empty_list, {}}, lst2tbl(l))
        lib.tv_list_free(l)
        eq(1, l2.lv_last.li_tv.vval.v_list.lv_refcount)
      end)
    end)
    describe('concat()', function()
      itp('works with NULL lists', function()
        local l = list(1, {})
        alloc_log:clear()
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        local rettv1 = typvalt()
        eq(OK, lib.tv_list_concat(nil, l, rettv1))
        eq(1, l.lv_refcount)
        eq(tonumber(lib.VAR_LIST), tonumber(rettv1.v_type))
        eq({1, {}}, typvalt2lua(rettv1))
        eq(1, rettv1.vval.v_list.lv_refcount)
        alloc_log:check({
          a.list(rettv1.vval.v_list),
          a.li(rettv1.vval.v_list.lv_first),
          a.li(rettv1.vval.v_list.lv_last),
        })
        eq(2, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        local rettv2 = typvalt()
        eq(OK, lib.tv_list_concat(l, nil, rettv2))
        eq(1, l.lv_refcount)
        eq(tonumber(lib.VAR_LIST), tonumber(rettv2.v_type))
        eq({1, {}}, typvalt2lua(rettv2))
        eq(1, rettv2.vval.v_list.lv_refcount)
        alloc_log:check({
          a.list(rettv2.vval.v_list),
          a.li(rettv2.vval.v_list.lv_first),
          a.li(rettv2.vval.v_list.lv_last),
        })
        eq(3, l.lv_last.li_tv.vval.v_dict.dv_refcount)

        local rettv3 = typvalt()
        eq(OK, lib.tv_list_concat(nil, nil, rettv3))
        eq(tonumber(lib.VAR_LIST), tonumber(rettv3.v_type))
        eq(null_list, typvalt2lua(rettv3))
        alloc_log:check({})
      end)
      itp('works with two different lists', function()
        local l1 = list(1, {})
        local l2 = list(3, empty_list)
        eq(1, l1.lv_refcount)
        eq(1, l1.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, l2.lv_refcount)
        eq(1, l2.lv_last.li_tv.vval.v_list.lv_refcount)
        alloc_log:clear()

        local rettv = typvalt()
        eq(OK, lib.tv_list_concat(l1, l2, rettv))
        eq(1, l1.lv_refcount)
        eq(2, l1.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, l2.lv_refcount)
        eq(2, l2.lv_last.li_tv.vval.v_list.lv_refcount)
        alloc_log:check({
          a.list(rettv.vval.v_list),
          a.li(rettv.vval.v_list.lv_first),
          a.li(rettv.vval.v_list.lv_first.li_next),
          a.li(rettv.vval.v_list.lv_last.li_prev),
          a.li(rettv.vval.v_list.lv_last),
        })
        eq({1, {}, 3, empty_list}, typvalt2lua(rettv))
      end)
      itp('can concatenate list with itself', function()
        local l = list(1, {})
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        alloc_log:clear()

        local rettv = typvalt()
        eq(OK, lib.tv_list_concat(l, l, rettv))
        eq(1, l.lv_refcount)
        eq(3, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        alloc_log:check({
          a.list(rettv.vval.v_list),
          a.li(rettv.vval.v_list.lv_first),
          a.li(rettv.vval.v_list.lv_first.li_next),
          a.li(rettv.vval.v_list.lv_last.li_prev),
          a.li(rettv.vval.v_list.lv_last),
        })
        eq({1, {}, 1, {}}, typvalt2lua(rettv))
      end)
      itp('can concatenate empty non-NULL lists', function()
        local l = list(1, {})
        local le = list()
        local le2 = list()
        eq(1, l.lv_refcount)
        eq(1, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, le.lv_refcount)
        eq(1, le2.lv_refcount)
        alloc_log:clear()

        local rettv1 = typvalt()
        eq(OK, lib.tv_list_concat(l, le, rettv1))
        eq(1, l.lv_refcount)
        eq(2, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, le.lv_refcount)
        eq(1, le2.lv_refcount)
        alloc_log:check({
          a.list(rettv1.vval.v_list),
          a.li(rettv1.vval.v_list.lv_first),
          a.li(rettv1.vval.v_list.lv_last),
        })
        eq({1, {}}, typvalt2lua(rettv1))

        local rettv2 = typvalt()
        eq(OK, lib.tv_list_concat(le, l, rettv2))
        eq(1, l.lv_refcount)
        eq(3, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, le.lv_refcount)
        eq(1, le2.lv_refcount)
        alloc_log:check({
          a.list(rettv2.vval.v_list),
          a.li(rettv2.vval.v_list.lv_first),
          a.li(rettv2.vval.v_list.lv_last),
        })
        eq({1, {}}, typvalt2lua(rettv2))

        local rettv3 = typvalt()
        eq(OK, lib.tv_list_concat(le, le, rettv3))
        eq(1, l.lv_refcount)
        eq(3, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, le.lv_refcount)
        eq(1, le2.lv_refcount)
        alloc_log:check({
          a.list(rettv3.vval.v_list),
        })
        eq(empty_list, typvalt2lua(rettv3))

        local rettv4 = typvalt()
        eq(OK, lib.tv_list_concat(le, le2, rettv4))
        eq(1, l.lv_refcount)
        eq(3, l.lv_last.li_tv.vval.v_dict.dv_refcount)
        eq(1, le.lv_refcount)
        eq(1, le2.lv_refcount)
        alloc_log:check({
          a.list(rettv4.vval.v_list),
        })
        eq(empty_list, typvalt2lua(rettv4))
      end)
    end)
    describe('join()', function()
      local function list_join(l, sep, join_ret)
        local ga = ga_alloc()
        eq(join_ret or OK, lib.tv_list_join(ga, l, sep))
        local ret = ''
        if ga.ga_data ~= nil then
          ret = ffi.string(ga.ga_data)
        end
        -- For some reason this is not working well in GC
        lib.ga_clear(ffi.gc(ga, nil))
        return ret
      end
      itp('works', function()
        local l
        l = list('boo', 'far')
        eq('boo far', list_join(l, ' '))
        eq('boofar', list_join(l, ''))

        l = list('boo')
        eq('boo', list_join(l, ' '))

        l = list()
        eq('', list_join(l, ' '))

        l = list({}, 'far')
        eq('{} far', list_join(l, ' '))

        local recursive_list = {}
        recursive_list[1] = recursive_list
        l = ffi.gc(list(recursive_list, 'far'), nil)
        eq('[[...@0]] far', list_join(l, ' '))

        local recursive_l = l.lv_first.li_tv.vval.v_list
        local recursive_li = recursive_l.lv_first
        lib.tv_list_item_remove(recursive_l, recursive_li)
        lib.tv_list_free(l)
      end)
    end)
    describe('equal()', function()
      itp('compares empty and NULL lists correctly', function()
        local l = list()
        local l2 = list()

        -- NULL lists are not equal to empty lists
        eq(false, lib.tv_list_equal(l, nil, true, false))
        eq(false, lib.tv_list_equal(nil, l, false, false))
        eq(false, lib.tv_list_equal(nil, l, false, true))
        eq(false, lib.tv_list_equal(l, nil, true, true))

        -- Yet NULL lists are equal themselves
        eq(true, lib.tv_list_equal(nil, nil, true, false))
        eq(true, lib.tv_list_equal(nil, nil, false, false))
        eq(true, lib.tv_list_equal(nil, nil, false, true))
        eq(true, lib.tv_list_equal(nil, nil, true, true))

        -- As well as empty lists
        eq(true, lib.tv_list_equal(l, l, true, false))
        eq(true, lib.tv_list_equal(l, l2, false, false))
        eq(true, lib.tv_list_equal(l2, l, false, true))
        eq(true, lib.tv_list_equal(l2, l2, true, true))
      end)
      -- Must not use recursive=true argument in the following tests because it
      -- indicates that tv_equal_recurse_limit and recursive_cnt were set which
      -- is essential. This argument will be set when comparing inner lists.
      itp('compares lists correctly when case is not ignored', function()
        local l1 = list('abc', {1, 2, 'Abc'}, 'def')
        local l2 = list('abc', {1, 2, 'Abc'})
        local l3 = list('abc', {1, 2, 'Abc'}, 'Def')
        local l4 = list('abc', {1, 2, 'Abc', 4}, 'def')
        local l5 = list('Abc', {1, 2, 'Abc'}, 'def')
        local l6 = list('abc', {1, 2, 'Abc'}, 'def')
        local l7 = list('abc', {1, 2, 'abc'}, 'def')
        local l8 = list('abc', nil, 'def')
        local l9 = list('abc', {1, 2, nil}, 'def')

        eq(true, lib.tv_list_equal(l1, l1, false, false))
        eq(false, lib.tv_list_equal(l1, l2, false, false))
        eq(false, lib.tv_list_equal(l1, l3, false, false))
        eq(false, lib.tv_list_equal(l1, l4, false, false))
        eq(false, lib.tv_list_equal(l1, l5, false, false))
        eq(true, lib.tv_list_equal(l1, l6, false, false))
        eq(false, lib.tv_list_equal(l1, l7, false, false))
        eq(false, lib.tv_list_equal(l1, l8, false, false))
        eq(false, lib.tv_list_equal(l1, l9, false, false))
      end)
      itp('compares lists correctly when case is ignored', function()
        local l1 = list('abc', {1, 2, 'Abc'}, 'def')
        local l2 = list('abc', {1, 2, 'Abc'})
        local l3 = list('abc', {1, 2, 'Abc'}, 'Def')
        local l4 = list('abc', {1, 2, 'Abc', 4}, 'def')
        local l5 = list('Abc', {1, 2, 'Abc'}, 'def')
        local l6 = list('abc', {1, 2, 'Abc'}, 'def')
        local l7 = list('abc', {1, 2, 'abc'}, 'def')
        local l8 = list('abc', nil, 'def')
        local l9 = list('abc', {1, 2, nil}, 'def')

        eq(true, lib.tv_list_equal(l1, l1, true, false))
        eq(false, lib.tv_list_equal(l1, l2, true, false))
        eq(true, lib.tv_list_equal(l1, l3, true, false))
        eq(false, lib.tv_list_equal(l1, l4, true, false))
        eq(true, lib.tv_list_equal(l1, l5, true, false))
        eq(true, lib.tv_list_equal(l1, l6, true, false))
        eq(true, lib.tv_list_equal(l1, l7, true, false))
        eq(false, lib.tv_list_equal(l1, l8, true, false))
        eq(false, lib.tv_list_equal(l1, l9, true, false))
      end)
    end)
    describe('find', function()
      describe('()', function()
        itp('correctly indexes list', function()
          local l = list(1, 2, 3, 4, 5)
          local lis = list_items(l)
          alloc_log:clear()

          eq(nil, lib.tv_list_find(nil, -1))
          eq(nil, lib.tv_list_find(nil, 0))
          eq(nil, lib.tv_list_find(nil, 1))

          eq(nil, lib.tv_list_find(l, 5))
          eq(nil, lib.tv_list_find(l, -6))
          eq(lis[1], lib.tv_list_find(l, -5))
          eq(lis[5], lib.tv_list_find(l, 4))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[3], lib.tv_list_find(l, -3))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[3], lib.tv_list_find(l, -3))

          l.lv_idx_item = nil
          eq(lis[1], lib.tv_list_find(l, -5))
          l.lv_idx_item = nil
          eq(lis[5], lib.tv_list_find(l, 4))
          l.lv_idx_item = nil
          eq(lis[3], lib.tv_list_find(l, 2))
          l.lv_idx_item = nil
          eq(lis[3], lib.tv_list_find(l, -3))
          l.lv_idx_item = nil
          eq(lis[3], lib.tv_list_find(l, 2))
          l.lv_idx_item = nil
          eq(lis[3], lib.tv_list_find(l, 2))
          l.lv_idx_item = nil
          eq(lis[3], lib.tv_list_find(l, -3))

          l.lv_idx_item = nil
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[1], lib.tv_list_find(l, -5))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[5], lib.tv_list_find(l, 4))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[3], lib.tv_list_find(l, -3))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[3], lib.tv_list_find(l, 2))
          eq(lis[3], lib.tv_list_find(l, -3))

          alloc_log:check({})
        end)
      end)
      describe('nr()', function()
        local function tv_list_find_nr(l, n, msg)
          return check_emsg(function()
            local err = ffi.new('bool[1]', {false})
            local ret = lib.tv_list_find_nr(l, n, err)
            return (err[0] == true), ret
          end, msg)
        end
        itp('returns correct number', function()
          local l = list(int(1), int(2), int(3), int(4), int(5))
          alloc_log:clear()

          eq({false, 1}, {tv_list_find_nr(l, -5)})
          eq({false, 5}, {tv_list_find_nr(l, 4)})
          eq({false, 3}, {tv_list_find_nr(l, 2)})
          eq({false, 3}, {tv_list_find_nr(l, -3)})

          alloc_log:check({})
        end)
        itp('returns correct number when given a string', function()
          local l = list('1', '2', '3', '4', '5')
          alloc_log:clear()

          eq({false, 1}, {tv_list_find_nr(l, -5)})
          eq({false, 5}, {tv_list_find_nr(l, 4)})
          eq({false, 3}, {tv_list_find_nr(l, 2)})
          eq({false, 3}, {tv_list_find_nr(l, -3)})

          alloc_log:check({})
        end)
        itp('returns zero when given a NULL string', function()
          local l = list(null_string)
          alloc_log:clear()

          eq({false, 0}, {tv_list_find_nr(l, 0)})

          alloc_log:check({})
        end)
        itp('errors out on NULL lists', function()
          eq({true, -1}, {tv_list_find_nr(nil, -5)})
          eq({true, -1}, {tv_list_find_nr(nil, 4)})
          eq({true, -1}, {tv_list_find_nr(nil, 2)})
          eq({true, -1}, {tv_list_find_nr(nil, -3)})

          alloc_log:check({})
        end)
        itp('errors out on out-of-range indexes', function()
          local l = list(int(1), int(2), int(3), int(4), int(5))
          alloc_log:clear()

          eq({true, -1}, {tv_list_find_nr(l, -6)})
          eq({true, -1}, {tv_list_find_nr(l, 5)})

          alloc_log:check({})
        end)
        itp('errors out on invalid types', function()
          local l = list(1, empty_list, {})

          eq({true, 0}, {tv_list_find_nr(l, 0, 'E805: Using a Float as a Number')})
          eq({true, 0}, {tv_list_find_nr(l, 1, 'E745: Using a List as a Number')})
          eq({true, 0}, {tv_list_find_nr(l, 2, 'E728: Using a Dictionary as a Number')})
          eq({true, 0}, {tv_list_find_nr(l, -1, 'E728: Using a Dictionary as a Number')})
          eq({true, 0}, {tv_list_find_nr(l, -2, 'E745: Using a List as a Number')})
          eq({true, 0}, {tv_list_find_nr(l, -3, 'E805: Using a Float as a Number')})
        end)
      end)
      local function tv_list_find_str(l, n, msg)
        return check_emsg(function()
          local ret = lib.tv_list_find_str(l, n)
          local s = nil
          if ret ~= nil then
            s = ffi.string(ret)
          end
          return s
        end, msg)
      end
      describe('str()', function()
        itp('returns correct string', function()
          local l = list(int(1), int(2), int(3), int(4), int(5))
          alloc_log:clear()

          eq('1', tv_list_find_str(l, -5))
          eq('5', tv_list_find_str(l, 4))
          eq('3', tv_list_find_str(l, 2))
          eq('3', tv_list_find_str(l, -3))

          alloc_log:check({})
        end)
        itp('returns string when used with VAR_STRING items', function()
          local l = list('1', '2', '3', '4', '5')
          alloc_log:clear()

          eq('1', tv_list_find_str(l, -5))
          eq('5', tv_list_find_str(l, 4))
          eq('3', tv_list_find_str(l, 2))
          eq('3', tv_list_find_str(l, -3))

          alloc_log:check({})
        end)
        itp('returns empty when used with NULL string', function()
          local l = list(null_string)
          alloc_log:clear()

          eq('', tv_list_find_str(l, 0))

          alloc_log:check({})
        end)
        itp('fails with error message when index is out of range', function()
          local l = list(int(1), int(2), int(3), int(4), int(5))

          eq(nil, tv_list_find_str(l, -6, 'E684: list index out of range: -6'))
          eq(nil, tv_list_find_str(l, 5, 'E684: list index out of range: 5'))
        end)
        itp('fails with error message on invalid types', function()
          local l = list(1, empty_list, {})

          eq('', tv_list_find_str(l, 0, 'E806: using Float as a String'))
          eq('', tv_list_find_str(l, 1, 'E730: using List as a String'))
          eq('', tv_list_find_str(l, 2, 'E731: using Dictionary as a String'))
          eq('', tv_list_find_str(l, -1, 'E731: using Dictionary as a String'))
          eq('', tv_list_find_str(l, -2, 'E730: using List as a String'))
          eq('', tv_list_find_str(l, -3, 'E806: using Float as a String'))
        end)
      end)
    end)
    describe('idx_of_item()', function()
      itp('works', function()
        local l = list(1, 2, 3, 4, 5)
        local l2 = list(42, empty_list)
        local lis = list_items(l)
        local lis2 = list_items(l2)

        for i, li in ipairs(lis) do
          eq(i - 1, lib.tv_list_idx_of_item(l, li))
        end
        eq(-1, lib.tv_list_idx_of_item(l, lis2[1]))
        eq(-1, lib.tv_list_idx_of_item(l, nil))
        eq(-1, lib.tv_list_idx_of_item(nil, nil))
        eq(-1, lib.tv_list_idx_of_item(nil, lis[1]))
      end)
    end)
  end)
  describe('dict', function()
    describe('watcher', function()
      describe('add()/remove()', function()
        itp('works with an empty key', function()
          local d = dict({})
          eq({}, dict_watchers(d))
          local cb = ffi.gc(tbl2callback({type='none'}), nil)
          alloc_log:clear()
          lib.tv_dict_watcher_add(d, '*', 0, cb[0])
          local ws, qs = dict_watchers(d)
          local key_p = qs[1].key_pattern
          alloc_log:check({
            a.dwatcher(qs[1]),
            a.str(key_p, 0),
          })
          eq({{busy=false, cb={type='none'}, pat=''}}, ws)
          eq(true, lib.tv_dict_watcher_remove(d, 'x', 0, cb[0]))
          alloc_log:check({
            a.freed(key_p),
            a.freed(qs[1]),
          })
          eq({}, dict_watchers(d))
        end)
        itp('works with multiple callbacks', function()
          local d = dict({})
          eq({}, dict_watchers(d))
          alloc_log:check({a.dict(d)})
          local cbs = {}
          cbs[1] = {'te', ffi.gc(tbl2callback({type='none'}), nil)}
          alloc_log:check({})
          cbs[2] = {'foo', ffi.gc(tbl2callback({type='fref', fref='tr'}), nil)}
          alloc_log:check({
            a.str(cbs[2][2].data.funcref, #('tr')),
          })
          cbs[3] = {'te', ffi.gc(tbl2callback({type='pt', fref='tr', pt={
            value='tr',
            args={'test'},
            dict={},
          }}), nil)}
          local pt3 = cbs[3][2].data.partial
          local pt3_argv = pt3.pt_argv
          local pt3_dict = pt3.pt_dict
          local pt3_name = pt3.pt_name
          local pt3_str_arg = pt3.pt_argv[0].vval.v_string
          alloc_log:check({
            a.lua_pt(pt3),
            a.lua_tvs(pt3_argv, pt3.pt_argc),
            a.str(pt3_str_arg, #('test')),
            a.dict(pt3_dict),
            a.str(pt3_name, #('tr')),
          })
          for _, v in ipairs(cbs) do
            lib.tv_dict_watcher_add(d, v[1], #(v[1]), v[2][0])
          end
          local ws, qs, kps = dict_watchers(d)
          eq({{busy=false, pat=cbs[1][1], cb={type='none'}},
              {busy=false, pat=cbs[2][1], cb={type='fref', fref='tr'}},
              {busy=false, pat=cbs[3][1], cb={type='pt', fref='tr', pt={
                [type_key]=func_type,
                value='tr',
                args={'test'},
                dict={},
          }}}}, ws)
          alloc_log:check({
            a.dwatcher(qs[1]),
            a.str(kps[1][1], kps[1][2]),
            a.dwatcher(qs[2]),
            a.str(kps[2][1], kps[2][2]),
            a.dwatcher(qs[3]),
            a.str(kps[3][1], kps[3][2]),
          })
          eq(true, lib.tv_dict_watcher_remove(d, cbs[2][1], #cbs[2][1], cbs[2][2][0]))
          alloc_log:check({
            a.freed(cbs[2][2].data.funcref),
            a.freed(kps[2][1]),
            a.freed(qs[2]),
          })
          eq(false, lib.tv_dict_watcher_remove(d, cbs[2][1], #cbs[2][1], cbs[2][2][0]))
          eq({{busy=false, pat=cbs[1][1], cb={type='none'}},
              {busy=false, pat=cbs[3][1], cb={type='pt', fref='tr', pt={
                [type_key]=func_type,
                value='tr',
                args={'test'},
                dict={},
          }}}}, dict_watchers(d))
          eq(true, lib.tv_dict_watcher_remove(d, cbs[3][1], #cbs[3][1], cbs[3][2][0]))
          alloc_log:check({
            a.freed(pt3_str_arg),
            a.freed(pt3_argv),
            a.freed(pt3_dict),
            a.freed(pt3_name),
            a.freed(pt3),
            a.freed(kps[3][1]),
            a.freed(qs[3]),
          })
          eq(false, lib.tv_dict_watcher_remove(d, cbs[3][1], #cbs[3][1], cbs[3][2][0]))
          eq({{busy=false, pat=cbs[1][1], cb={type='none'}}}, dict_watchers(d))
          eq(true, lib.tv_dict_watcher_remove(d, cbs[1][1], #cbs[1][1], cbs[1][2][0]))
          alloc_log:check({
            a.freed(kps[1][1]),
            a.freed(qs[1]),
          })
          eq(false, lib.tv_dict_watcher_remove(d, cbs[1][1], #cbs[1][1], cbs[1][2][0]))
          eq({}, dict_watchers(d))
        end)
      end)
      describe('notify', function()
        -- Way too hard to test it here, functional tests in
        -- dict_notifications_spec.lua.
      end)
    end)
    describe('item', function()
      describe('alloc()/free()', function()
        local function check_tv_dict_item_alloc_len(s, len, tv, more_frees)
          local di
          if len == nil then
            di = ffi.gc(lib.tv_dict_item_alloc(s), nil)
            len = #s
          else
            di = ffi.gc(lib.tv_dict_item_alloc_len(s, len or #s), nil)
          end
          eq(s:sub(1, len), ffi.string(di.di_key))
          alloc_log:check({a.di(di, len)})
          if tv then
            di.di_tv = ffi.gc(tv, nil)
          else
            di.di_tv.v_type = lib.VAR_UNKNOWN
          end
          lib.tv_dict_item_free(di)
          alloc_log:check(concat_tables(more_frees, {a.freed(di)}))
        end
        local function check_tv_dict_item_alloc(s, tv, more_frees)
          return check_tv_dict_item_alloc_len(s, nil, tv, more_frees)
        end
        itp('works', function()
          check_tv_dict_item_alloc('')
          check_tv_dict_item_alloc('t')
          check_tv_dict_item_alloc('TEST')
          check_tv_dict_item_alloc_len('', 0)
          check_tv_dict_item_alloc_len('TEST', 2)
          local tv = lua2typvalt('test')
          alloc_log:check({a.str(tv.vval.v_string, #('test'))})
          check_tv_dict_item_alloc('', tv, {a.freed(tv.vval.v_string)})
          tv = lua2typvalt('test')
          alloc_log:check({a.str(tv.vval.v_string, #('test'))})
          check_tv_dict_item_alloc_len('', 0, tv, {a.freed(tv.vval.v_string)})
        end)
      end)
      describe('add()/remove()', function()
        itp('works', function()
          local d = dict()
          eq({}, dct2tbl(d))
          alloc_log:check({a.dict(d)})
          local di = ffi.gc(lib.tv_dict_item_alloc(''), nil)
          local tv = lua2typvalt('test')
          di.di_tv = ffi.gc(tv, nil)
          alloc_log:check({a.di(di, ''), a.str(tv.vval.v_string, 'test')})
          eq(OK, lib.tv_dict_add(d, di))
          alloc_log:check({})
          eq(FAIL, check_emsg(function() return lib.tv_dict_add(d, di) end,
                              'E685: Internal error: hash_add()'))
          alloc_log:clear()
          lib.tv_dict_item_remove(d, di)
          alloc_log:check({
            a.freed(tv.vval.v_string),
            a.freed(di),
          })
        end)
      end)
    end)
    describe('indexing', function()
      describe('find()', function()
        local function tv_dict_find(d, key, key_len)
          local di = lib.tv_dict_find(d, key, key_len or #key)
          if di == nil then
            return nil, nil, nil
          end
          return typvalt2lua(di.di_tv), ffi.string(di.di_key), di
        end
        itp('works with NULL dict', function()
          eq(nil, lib.tv_dict_find(nil, '', 0))
          eq(nil, lib.tv_dict_find(nil, 'test', -1))
          eq(nil, lib.tv_dict_find(nil, nil, 0))
        end)
        itp('works with NULL key', function()
          local lua_d = {
            ['']=0,
            t=1,
            te=2,
            tes=3,
            test=4,
            testt=5,
          }
          local d = dict(lua_d)
          alloc_log:clear()
          eq(lua_d, dct2tbl(d))
          alloc_log:check({})
          local dis = dict_items(d)
          eq({0, '', dis['']}, {tv_dict_find(d, '', 0)})
          eq({0, '', dis['']}, {tv_dict_find(d, nil, 0)})
        end)
        itp('works with len properly', function()
          local lua_d = {
            ['']=0,
            t=1,
            te=2,
            tes=3,
            test=4,
            testt=5,
          }
          local d = dict(lua_d)
          alloc_log:clear()
          eq(lua_d, dct2tbl(d))
          alloc_log:check({})
          for i = 0, 5 do
            local v, k = tv_dict_find(d, 'testt', i)
            eq({i, ('testt'):sub(1, i)}, {v, k})
          end
          eq(nil, tv_dict_find(d, 'testt', 6))  -- Should take NUL byte
          eq(5, tv_dict_find(d, 'testt', -1))
          alloc_log:check({})
        end)
      end)
      describe('get_number()', function()
        itp('works with NULL dict', function()
          eq(0, check_emsg(function() return lib.tv_dict_get_number(nil, 'test') end,
                           nil))
        end)
        itp('works', function()
          local d = ffi.gc(dict({test={}}), nil)
          eq(0, check_emsg(function() return lib.tv_dict_get_number(d, 'test') end,
                           'E728: Using a Dictionary as a Number'))
          d = ffi.gc(dict({tes=int(42), t=44, te='43'}), nil)
          alloc_log:clear()
          eq(0, check_emsg(function() return lib.tv_dict_get_number(d, 'test') end,
                           nil))
          eq(42, check_emsg(function() return lib.tv_dict_get_number(d, 'tes') end,
                            nil))
          eq(43, check_emsg(function() return lib.tv_dict_get_number(d, 'te') end,
                            nil))
          alloc_log:check({})
          eq(0, check_emsg(function() return lib.tv_dict_get_number(d, 't') end,
                           'E805: Using a Float as a Number'))
        end)
      end)
      describe('get_string()', function()
        itp('works with NULL dict', function()
          eq(nil, check_emsg(function() return lib.tv_dict_get_string(nil, 'test', false) end,
                             nil))
        end)
        itp('works', function()
          local d = ffi.gc(dict({test={}}), nil)
          eq('', ffi.string(check_emsg(function() return lib.tv_dict_get_string(d, 'test', false) end,
                                       'E731: using Dictionary as a String')))
          d = ffi.gc(dict({tes=int(42), t=44, te='43', xx=int(45)}), nil)
          alloc_log:clear()
          local dis = dict_items(d)
          eq(nil, check_emsg(function() return lib.tv_dict_get_string(d, 'test', false) end,
                             nil))
          local s42 = check_emsg(function() return lib.tv_dict_get_string(d, 'tes', false) end,
                                 nil)
          eq('42', ffi.string(s42))
          local s45 = check_emsg(function() return lib.tv_dict_get_string(d, 'xx', false) end,
                                 nil)
          eq(s42, s45)
          eq('45', ffi.string(s45))
          eq('45', ffi.string(s42))
          local s43 = check_emsg(function() return lib.tv_dict_get_string(d, 'te', false) end,
                                 nil)
          eq('43', ffi.string(s43))
          neq(s42, s43)
          eq(s43, dis.te.di_tv.vval.v_string)
          alloc_log:check({})
          eq('', ffi.string(check_emsg(function() return lib.tv_dict_get_string(d, 't', false) end,
                                       'E806: using Float as a String')))
        end)
        itp('allocates a string copy when requested', function()
          local function tv_dict_get_string_alloc(d, key, emsg)
            alloc_log:clear()
            local ret = check_emsg(function() return lib.tv_dict_get_string(d, key, true) end,
                                   emsg)
            local s_ret = (ret ~= nil) and ffi.string(ret) or nil
            if not emsg then
              if s_ret then
                alloc_log:check({a.str(ret, s_ret)})
              else
                alloc_log:check({})
              end
            end
            lib.xfree(ret)
            return s_ret
          end
          local d = ffi.gc(dict({test={}}), nil)
          eq('', tv_dict_get_string_alloc(d, 'test', 'E731: using Dictionary as a String'))
          d = ffi.gc(dict({tes=int(42), t=44, te='43', xx=int(45)}), nil)
          alloc_log:clear()
          eq(nil, tv_dict_get_string_alloc(d, 'test'))
          eq('42', tv_dict_get_string_alloc(d, 'tes'))
          eq('45', tv_dict_get_string_alloc(d, 'xx'))
          eq('43', tv_dict_get_string_alloc(d, 'te'))
          eq('', tv_dict_get_string_alloc(d, 't', 'E806: using Float as a String'))
        end)
      end)
      describe('get_string_buf()', function()
        local function tv_dict_get_string_buf(d, key, buf, emsg)
          buf = buf or ffi.gc(lib.xmalloc(lib.NUMBUFLEN), lib.xfree)
          alloc_log:clear()
          local ret = check_emsg(function() return lib.tv_dict_get_string_buf(d, key, buf) end,
                                 emsg)
          local s_ret = (ret ~= nil) and ffi.string(ret) or nil
          if not emsg then
            alloc_log:check({})
          end
          return s_ret, ret, buf
        end
        itp('works with NULL dict', function()
          eq(nil, tv_dict_get_string_buf(nil, 'test'))
        end)
        itp('works', function()
          local lua_d = {
            ['']={},
            t=1,
            te=int(2),
            tes=empty_list,
            test='tset',
            testt=5,
          }
          local d = dict(lua_d)
          alloc_log:clear()
          eq(lua_d, dct2tbl(d))
          alloc_log:check({})
          local s, r, b
          s, r, b = tv_dict_get_string_buf(d, 'test')
          neq(r, b)
          eq('tset', s)
          s, r, b = tv_dict_get_string_buf(d, 't', nil, 'E806: using Float as a String')
          neq(r, b)
          eq('', s)
          s, r, b = tv_dict_get_string_buf(d, 'te')
          eq(r, b)
          eq('2', s)
        end)
      end)
      describe('get_string_buf_chk()', function()
        local function tv_dict_get_string_buf_chk(d, key, len, buf, def, emsg)
          buf = buf or ffi.gc(lib.xmalloc(lib.NUMBUFLEN), lib.xfree)
          def = def or ffi.gc(lib.xstrdup('DEFAULT'), lib.xfree)
          len = len or #key
          alloc_log:clear()
          local ret = check_emsg(function() return lib.tv_dict_get_string_buf_chk(d, key, len, buf, def) end,
                                 emsg)
          local s_ret = (ret ~= nil) and ffi.string(ret) or nil
          if not emsg then
            alloc_log:check({})
          end
          return s_ret, ret, buf, def
        end
        itp('works with NULL dict', function()
          eq('DEFAULT', tv_dict_get_string_buf_chk(nil, 'test'))
        end)
        itp('works', function()
          local lua_d = {
            ['']={},
            t=1,
            te=int(2),
            tes=empty_list,
            test='tset',
            testt=5,
          }
          local d = dict(lua_d)
          alloc_log:clear()
          eq(lua_d, dct2tbl(d))
          alloc_log:check({})
          local s, r, b, def
          s, r, b, def = tv_dict_get_string_buf_chk(d, 'test')
          neq(r, b)
          neq(r, def)
          eq('tset', s)
          s, r, b, def = tv_dict_get_string_buf_chk(d, 'test', 1, nil, nil, 'E806: using Float as a String')
          neq(r, b)
          neq(r, def)
          eq(nil, s)
          s, r, b, def = tv_dict_get_string_buf_chk(d, 'te')
          eq(r, b)
          neq(r, def)
          eq('2', s)
          s, r, b, def = tv_dict_get_string_buf_chk(d, 'TEST')
          eq(r, def)
          neq(r, b)
          eq('DEFAULT', s)
        end)
      end)
      describe('get_callback()', function()
        local function tv_dict_get_callback(d, key, key_len, emsg)
          key_len = key_len or #key
          local cb = ffi.gc(ffi.cast('Callback*', lib.xmalloc(ffi.sizeof('Callback'))), lib.callback_free)
          alloc_log:clear()
          local ret = check_emsg(function()
            return lib.tv_dict_get_callback(d, key, key_len, cb)
          end, emsg)
          local cb_lua = callback2tbl(cb[0])
          return cb_lua, ret
        end
        itp('works with NULL dict', function()
          eq({{type='none'}, true}, {tv_dict_get_callback(nil, '')})
        end)
        itp('works', function()
          local lua_d = {
            ['']='tr',
            t=int(1),
            te={[type_key]=func_type, value='tr'},
            tes={[type_key]=func_type, value='tr', args={'a', 'b'}},
            test={[type_key]=func_type, value='Test', dict={test=1}, args={}},
            testt={[type_key]=func_type, value='Test', dict={test=1}, args={1}},
          }
          local d = dict(lua_d)
          eq(lua_d, dct2tbl(d))
          eq({{type='fref', fref='tr'}, true},
             {tv_dict_get_callback(d, nil, 0)})
          eq({{type='fref', fref='tr'}, true},
             {tv_dict_get_callback(d, '', -1)})
          eq({{type='none'}, true},
             {tv_dict_get_callback(d, 'x', -1)})
          eq({{type='fref', fref='tr'}, true},
             {tv_dict_get_callback(d, 'testt', 0)})
          eq({{type='none'}, false},
             {tv_dict_get_callback(d, 'test', 1, 'E6000: Argument is not a function or function name')})
          eq({{type='fref', fref='tr'}, true},
             {tv_dict_get_callback(d, 'testt', 2)})
          eq({{ type='pt', fref='tr', pt={ [type_key]=func_type, value='tr', args={ 'a', 'b' } } }, true},
             {tv_dict_get_callback(d, 'testt', 3)})
          eq({{ type='pt', fref='Test', pt={ [type_key]=func_type, value='Test', dict={ test=1 }, args={} } }, true},
             {tv_dict_get_callback(d, 'testt', 4)})
          eq({{ type='pt', fref='Test', pt={ [type_key]=func_type, value='Test', dict={ test=1 }, args={1} } }, true},
             {tv_dict_get_callback(d, 'testt', 5)})
        end)
      end)
    end)
    describe('add', function()
      describe('()', function()
        itp('works', function()
          local di = lib.tv_dict_item_alloc_len('t-est', 5)
          alloc_log:check({a.di(di, 't-est')})
          di.di_tv.v_type = lib.VAR_NUMBER
          di.di_tv.vval.v_number = 42
          local d = dict({test=10})
          local dis = dict_items(d)
          alloc_log:check({
            a.dict(d),
            a.di(dis.test, 'test')
          })
          eq({test=10}, dct2tbl(d))
          alloc_log:clear()
          eq(OK, lib.tv_dict_add(d, di))
          alloc_log:check({})
          eq({test=10, ['t-est']=int(42)}, dct2tbl(d))
          eq(FAIL, check_emsg(function() return lib.tv_dict_add(d, di) end,
                              'E685: Internal error: hash_add()'))
        end)
      end)
      describe('list()', function()
        itp('works', function()
          local l = list(1, 2, 3)
          alloc_log:clear()
          eq(1, l.lv_refcount)
          local d = dict({test=10})
          alloc_log:clear()
          eq({test=10}, dct2tbl(d))
          eq(OK, lib.tv_dict_add_list(d, 'testt', 3, l))
          local dis = dict_items(d)
          alloc_log:check({a.di(dis.tes, 'tes')})
          eq({test=10, tes={1, 2, 3}}, dct2tbl(d))
          eq(2, l.lv_refcount)
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_list(d, 'testt', 3, l) end,
                              'E685: Internal error: hash_add()'))
          eq(2, l.lv_refcount)
          alloc_log:clear()
          lib.emsg_skip = lib.emsg_skip + 1
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_list(d, 'testt', 3, l) end,
                              nil))
          eq(2, l.lv_refcount)
          lib.emsg_skip = lib.emsg_skip - 1
          alloc_log:clear_tmp_allocs()
          alloc_log:check({})
        end)
      end)
      describe('dict()', function()
        itp('works', function()
          local d2 = dict({foo=42})
          alloc_log:clear()
          eq(1, d2.dv_refcount)
          local d = dict({test=10})
          alloc_log:clear()
          eq({test=10}, dct2tbl(d))
          eq(OK, lib.tv_dict_add_dict(d, 'testt', 3, d2))
          local dis = dict_items(d)
          alloc_log:check({a.di(dis.tes, 'tes')})
          eq({test=10, tes={foo=42}}, dct2tbl(d))
          eq(2, d2.dv_refcount)
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_dict(d, 'testt', 3, d2) end,
                              'E685: Internal error: hash_add()'))
          eq(2, d2.dv_refcount)
          alloc_log:clear()
          lib.emsg_skip = lib.emsg_skip + 1
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_dict(d, 'testt', 3, d2) end,
                              nil))
          eq(2, d2.dv_refcount)
          lib.emsg_skip = lib.emsg_skip - 1
          alloc_log:clear_tmp_allocs()
          alloc_log:check({})
        end)
      end)
      describe('nr()', function()
        itp('works', function()
          local d = dict({test=10})
          alloc_log:clear()
          eq({test=10}, dct2tbl(d))
          eq(OK, lib.tv_dict_add_nr(d, 'testt', 3, 2))
          local dis = dict_items(d)
          alloc_log:check({a.di(dis.tes, 'tes')})
          eq({test=10, tes=int(2)}, dct2tbl(d))
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_nr(d, 'testt', 3, 2) end,
                              'E685: Internal error: hash_add()'))
          alloc_log:clear()
          lib.emsg_skip = lib.emsg_skip + 1
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_nr(d, 'testt', 3, 2) end,
                              nil))
          lib.emsg_skip = lib.emsg_skip - 1
          alloc_log:clear_tmp_allocs()
          alloc_log:check({})
        end)
      end)
      describe('str()', function()
        itp('works', function()
          local d = dict({test=10})
          alloc_log:clear()
          eq({test=10}, dct2tbl(d))
          eq(OK, lib.tv_dict_add_str(d, 'testt', 3, 'TEST'))
          local dis = dict_items(d)
          alloc_log:check({
            a.str(dis.tes.di_tv.vval.v_string, 'TEST'),
            a.di(dis.tes, 'tes'),
          })
          eq({test=10, tes='TEST'}, dct2tbl(d))
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_str(d, 'testt', 3, 'TEST') end,
                              'E685: Internal error: hash_add()'))
          alloc_log:clear()
          lib.emsg_skip = lib.emsg_skip + 1
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_str(d, 'testt', 3, 'TEST') end,
                              nil))
          lib.emsg_skip = lib.emsg_skip - 1
          alloc_log:clear_tmp_allocs()
          alloc_log:check({})
        end)
      end)
      describe('allocated_str()', function()
        itp('works', function()
          local d = dict({test=10})
          eq({test=10}, dct2tbl(d))
          alloc_log:clear()
          local s1 = lib.xstrdup('TEST')
          local s2 = lib.xstrdup('TEST')
          local s3 = lib.xstrdup('TEST')
          alloc_log:check({
            a.str(s1, 'TEST'),
            a.str(s2, 'TEST'),
            a.str(s3, 'TEST'),
          })
          eq(OK, lib.tv_dict_add_allocated_str(d, 'testt', 3, s1))
          local dis = dict_items(d)
          alloc_log:check({
            a.di(dis.tes, 'tes'),
          })
          eq({test=10, tes='TEST'}, dct2tbl(d))
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_allocated_str(d, 'testt', 3, s2) end,
                              'E685: Internal error: hash_add()'))
          alloc_log:clear()
          lib.emsg_skip = lib.emsg_skip + 1
          eq(FAIL, check_emsg(function() return lib.tv_dict_add_allocated_str(d, 'testt', 3, s3) end,
                              nil))
          lib.emsg_skip = lib.emsg_skip - 1
          alloc_log:clear_tmp_allocs()
          alloc_log:check({
            a.freed(s3),
          })
        end)
      end)
    end)
    describe('clear()', function()
      itp('works', function()
        local d = dict()
        alloc_log:check({a.dict(d)})
        eq({}, dct2tbl(d))
        lib.tv_dict_clear(d)
        eq({}, dct2tbl(d))
        lib.tv_dict_add_str(d, 'TEST', 3, 'tEsT')
        local dis = dict_items(d)
        local di = dis.TES
        local di_s = di.di_tv.vval.v_string
        alloc_log:check({a.str(di_s), a.di(di)})
        eq({TES='tEsT'}, dct2tbl(d))
        lib.tv_dict_clear(d)
        alloc_log:check({a.freed(di_s), a.freed(di)})
        eq({}, dct2tbl(d))
      end)
    end)
    describe('extend()', function()
      local function tv_dict_extend(d1, d2, action, emsg)
        action = action or "force"
        check_emsg(function() return lib.tv_dict_extend(d1, d2, action) end, emsg)
      end
      itp('works', function()
        local d1 = dict()
        alloc_log:check({a.dict(d1)})
        eq({}, dct2tbl(d1))
        local d2 = dict()
        alloc_log:check({a.dict(d2)})
        eq({}, dct2tbl(d2))
        tv_dict_extend(d1, d2, 'error')
        tv_dict_extend(d1, d2, 'keep')
        tv_dict_extend(d1, d2, 'force')
        alloc_log:check({})

        d1 = dict({a='TEST'})
        eq({a='TEST'}, dct2tbl(d1))
        local dis1 = dict_items(d1)
        local a1_s = dis1.a.di_tv.vval.v_string
        alloc_log:clear_tmp_allocs()
        alloc_log:check({
          a.dict(d1),
          a.di(dis1.a),
          a.str(a1_s),
        })
        d2 = dict({a='TSET'})
        eq({a='TSET'}, dct2tbl(d2))
        local dis2 = dict_items(d2)
        local a2_s = dis2.a.di_tv.vval.v_string
        alloc_log:clear_tmp_allocs()
        alloc_log:check({
          a.dict(d2),
          a.di(dis2.a),
          a.str(a2_s),
        })

        tv_dict_extend(d1, d2, 'error', 'E737: Key already exists: a')
        eq({a='TEST'}, dct2tbl(d1))
        eq({a='TSET'}, dct2tbl(d2))
        alloc_log:clear()

        tv_dict_extend(d1, d2, 'keep')
        alloc_log:check({})
        eq({a='TEST'}, dct2tbl(d1))
        eq({a='TSET'}, dct2tbl(d2))

        tv_dict_extend(d1, d2, 'force')
        alloc_log:check({
          a.freed(a1_s),
          a.str(dis1.a.di_tv.vval.v_string),
        })
        eq({a='TSET'}, dct2tbl(d1))
        eq({a='TSET'}, dct2tbl(d2))
      end)
      itp('disallows overriding builtin or user functions', function()
        local d = dict()
        d.dv_scope = lib.VAR_DEF_SCOPE
        local f_lua = {
          [type_key]=func_type,
          value='tr',
        }
        local f_tv = lua2typvalt(f_lua)
        local p_lua = {
          [type_key]=func_type,
          value='tr',
          args={1},
        }
        local p_tv = lua2typvalt(p_lua)
        eq(lib.VAR_PARTIAL, p_tv.v_type)
        local d2 = dict({tr=f_tv})
        local d3 = dict({tr=p_tv})
        local d4 = dict({['TEST:THIS']=p_tv})
        local d5 = dict({Test=f_tv})
        local d6 = dict({Test=p_tv})
        eval0([[execute("function Test()\nendfunction")]])
        tv_dict_extend(d, d2, 'force',
                       'E704: Funcref variable name must start with a capital: tr')
        tv_dict_extend(d, d3, 'force',
                       'E704: Funcref variable name must start with a capital: tr')
        tv_dict_extend(d, d4, 'force',
                       'E461: Illegal variable name: TEST:THIS')
        tv_dict_extend(d, d5, 'force',
                       'E705: Variable name conflicts with existing function: Test')
        tv_dict_extend(d, d6, 'force',
                       'E705: Variable name conflicts with existing function: Test')
        eq({}, dct2tbl(d))
        d.dv_scope = lib.VAR_SCOPE
        tv_dict_extend(d, d4, 'force',
                       'E461: Illegal variable name: TEST:THIS')
        eq({}, dct2tbl(d))
        tv_dict_extend(d, d2, 'force')
        eq({tr=f_lua}, dct2tbl(d))
        tv_dict_extend(d, d3, 'force')
        eq({tr=p_lua}, dct2tbl(d))
        tv_dict_extend(d, d5, 'force')
        eq({tr=p_lua, Test=f_lua}, dct2tbl(d))
        tv_dict_extend(d, d6, 'force')
        eq({tr=p_lua, Test=p_lua}, dct2tbl(d))
      end)
      itp('cares about locks and read-only items', function()
        local d_lua = {tv_locked=1, tv_fixed=2, di_ro=3, di_ro_sbx=4}
        local d = dict(d_lua)
        local dis = dict_items(d)
        dis.tv_locked.di_tv.v_lock = lib.VAR_LOCKED
        dis.tv_fixed.di_tv.v_lock = lib.VAR_FIXED
        dis.di_ro.di_flags = bit.bor(dis.di_ro.di_flags, lib.DI_FLAGS_RO)
        dis.di_ro_sbx.di_flags = bit.bor(dis.di_ro_sbx.di_flags, lib.DI_FLAGS_RO_SBX)
        lib.sandbox = true
        local d1 = dict({tv_locked=41})
        local d2 = dict({tv_fixed=42})
        local d3 = dict({di_ro=43})
        local d4 = dict({di_ro_sbx=44})
        tv_dict_extend(d, d1, 'force', 'E741: Value is locked: extend() argument')
        tv_dict_extend(d, d2, 'force', 'E742: Cannot change value of extend() argument')
        tv_dict_extend(d, d3, 'force', 'E46: Cannot change read-only variable "extend() argument"')
        tv_dict_extend(d, d4, 'force', 'E794: Cannot set variable in the sandbox: "extend() argument"')
        eq(d_lua, dct2tbl(d))
        lib.sandbox = false
        tv_dict_extend(d, d4, 'force')
        d_lua.di_ro_sbx = 44
        eq(d_lua, dct2tbl(d))
      end)
    end)
    describe('equal()', function()
      local function tv_dict_equal(d1, d2, ic, recursive)
        return lib.tv_dict_equal(d1, d2, ic or false, recursive or false)
      end
      itp('works', function()
        eq(true, tv_dict_equal(nil, nil))
        local d1 = dict()
        alloc_log:check({a.dict(d1)})
        eq(1, d1.dv_refcount)
        eq(false, tv_dict_equal(nil, d1))
        eq(false, tv_dict_equal(d1, nil))
        eq(true, tv_dict_equal(d1, d1))
        eq(1, d1.dv_refcount)
        alloc_log:check({})
        local d_upper = dict({a='TEST'})
        local dis_upper = dict_items(d_upper)
        local d_lower = dict({a='test'})
        local dis_lower = dict_items(d_lower)
        local d_kupper_upper = dict({A='TEST'})
        local dis_kupper_upper = dict_items(d_kupper_upper)
        local d_kupper_lower = dict({A='test'})
        local dis_kupper_lower = dict_items(d_kupper_lower)
        alloc_log:clear_tmp_allocs()
        alloc_log:check({
          a.dict(d_upper),
          a.di(dis_upper.a),
          a.str(dis_upper.a.di_tv.vval.v_string),

          a.dict(d_lower),
          a.di(dis_lower.a),
          a.str(dis_lower.a.di_tv.vval.v_string),

          a.dict(d_kupper_upper),
          a.di(dis_kupper_upper.A),
          a.str(dis_kupper_upper.A.di_tv.vval.v_string),

          a.dict(d_kupper_lower),
          a.di(dis_kupper_lower.A),
          a.str(dis_kupper_lower.A.di_tv.vval.v_string),
        })
        eq(true, tv_dict_equal(d_upper, d_upper))
        eq(true, tv_dict_equal(d_upper, d_upper, true))
        eq(false, tv_dict_equal(d_upper, d_lower, false))
        eq(true, tv_dict_equal(d_upper, d_lower, true))
        eq(true, tv_dict_equal(d_kupper_upper, d_kupper_lower, true))
        eq(false, tv_dict_equal(d_kupper_upper, d_lower, true))
        eq(false, tv_dict_equal(d_kupper_upper, d_upper, true))
        eq(true, tv_dict_equal(d_upper, d_upper, true, true))
        alloc_log:check({})
      end)
    end)
    describe('copy()', function()
      local function tv_dict_copy(...)
        return ffi.gc(lib.tv_dict_copy(...), lib.tv_dict_unref)
      end
      itp('copies NULL correctly', function()
        eq(nil, lib.tv_dict_copy(nil, nil, true, 0))
        eq(nil, lib.tv_dict_copy(nil, nil, false, 0))
        eq(nil, lib.tv_dict_copy(nil, nil, true, 1))
        eq(nil, lib.tv_dict_copy(nil, nil, false, 1))
      end)
      itp('copies dict correctly without converting items', function()
        do
          local v = {a={['«']='»'}, b={'„'}, ['1']=1, ['«»']='“', ns=null_string, nl=null_list, nd=null_dict}
          local d_tv = lua2typvalt(v)
          local d = d_tv.vval.v_dict
          local dis = dict_items(d)
          alloc_log:clear()

          eq(1, dis.a.di_tv.vval.v_dict.dv_refcount)
          eq(1, dis.b.di_tv.vval.v_list.lv_refcount)
          local d_copy1 = tv_dict_copy(nil, d, false, 0)
          eq(2, dis.a.di_tv.vval.v_dict.dv_refcount)
          eq(2, dis.b.di_tv.vval.v_list.lv_refcount)
          local dis_copy1 = dict_items(d_copy1)
          eq(dis.a.di_tv.vval.v_dict, dis_copy1.a.di_tv.vval.v_dict)
          eq(dis.b.di_tv.vval.v_list, dis_copy1.b.di_tv.vval.v_list)
          eq(v, dct2tbl(d_copy1))
          alloc_log:clear()
          lib.tv_dict_free(ffi.gc(d_copy1, nil))
          alloc_log:clear()

          eq(1, dis.a.di_tv.vval.v_dict.dv_refcount)
          eq(1, dis.b.di_tv.vval.v_list.lv_refcount)
          local d_deepcopy1 = tv_dict_copy(nil, d, true, 0)
          neq(nil, d_deepcopy1)
          eq(1, dis.a.di_tv.vval.v_dict.dv_refcount)
          eq(1, dis.b.di_tv.vval.v_list.lv_refcount)
          local dis_deepcopy1 = dict_items(d_deepcopy1)
          neq(dis.a.di_tv.vval.v_dict, dis_deepcopy1.a.di_tv.vval.v_dict)
          neq(dis.b.di_tv.vval.v_list, dis_deepcopy1.b.di_tv.vval.v_list)
          eq(v, dct2tbl(d_deepcopy1))
          alloc_log:clear()
        end
        collectgarbage()
      end)
      itp('copies dict correctly and converts items', function()
        local vc = vimconv_alloc()
        -- UTF-8 ↔ latin1 conversions need no iconv
        eq(OK, lib.convert_setup(vc, to_cstr('utf-8'), to_cstr('latin1')))

        local v = {a={['«']='»'}, b={'„'}, ['1']=1, ['«»']='“', ns=null_string, nl=null_list, nd=null_dict}
        local d_tv = lua2typvalt(v)
        local d = d_tv.vval.v_dict
        local dis = dict_items(d)
        alloc_log:clear()

        eq(1, dis.a.di_tv.vval.v_dict.dv_refcount)
        eq(1, dis.b.di_tv.vval.v_list.lv_refcount)
        local d_deepcopy1 = tv_dict_copy(vc, d, true, 0)
        neq(nil, d_deepcopy1)
        eq(1, dis.a.di_tv.vval.v_dict.dv_refcount)
        eq(1, dis.b.di_tv.vval.v_list.lv_refcount)
        local dis_deepcopy1 = dict_items(d_deepcopy1)
        neq(dis.a.di_tv.vval.v_dict, dis_deepcopy1.a.di_tv.vval.v_dict)
        neq(dis.b.di_tv.vval.v_list, dis_deepcopy1.b.di_tv.vval.v_list)
        eq({a={['\171']='\187'}, b={'\191'}, ['1']=1, ['\171\187']='\191', ns=null_string, nl=null_list, nd=null_dict},
           dct2tbl(d_deepcopy1))
        alloc_log:clear_tmp_allocs()
        alloc_log:clear()
      end)
      itp('returns different/same containers with(out) copyID', function()
        local d_inner_tv = lua2typvalt({})
        local d_tv = lua2typvalt({a=d_inner_tv, b=d_inner_tv})
        eq(3, d_inner_tv.vval.v_dict.dv_refcount)
        local d = d_tv.vval.v_dict
        local dis = dict_items(d)
        eq(dis.a.di_tv.vval.v_dict, dis.b.di_tv.vval.v_dict)

        local d_copy1 = tv_dict_copy(nil, d, true, 0)
        local dis_copy1 = dict_items(d_copy1)
        neq(dis_copy1.a.di_tv.vval.v_dict, dis_copy1.b.di_tv.vval.v_dict)
        eq({a={}, b={}}, dct2tbl(d_copy1))

        local d_copy2 = tv_dict_copy(nil, d, true, 2)
        local dis_copy2 = dict_items(d_copy2)
        eq(dis_copy2.a.di_tv.vval.v_dict, dis_copy2.b.di_tv.vval.v_dict)
        eq({a={}, b={}}, dct2tbl(d_copy2))

        eq(3, d_inner_tv.vval.v_dict.dv_refcount)
      end)
      itp('works with self-referencing dict with copyID', function()
        local d_tv = lua2typvalt({})
        local d = d_tv.vval.v_dict
        eq(1, d.dv_refcount)
        lib.tv_dict_add_dict(d, 'test', 4, d)
        eq(2, d.dv_refcount)

        local d_copy1 = tv_dict_copy(nil, d, true, 2)
        eq(2, d_copy1.dv_refcount)
        local v = {}
        v.test = v
        eq(v, dct2tbl(d_copy1))

        lib.tv_dict_clear(d)
        eq(1, d.dv_refcount)

        lib.tv_dict_clear(d_copy1)
        eq(1, d_copy1.dv_refcount)
      end)
    end)
    describe('set_keys_readonly()', function()
      itp('works', function()
        local d = dict({a=true})
        local dis = dict_items(d)
        alloc_log:check({a.dict(d), a.di(dis.a)})
        eq(0, bit.band(dis.a.di_flags, lib.DI_FLAGS_RO))
        eq(0, bit.band(dis.a.di_flags, lib.DI_FLAGS_FIX))
        lib.tv_dict_set_keys_readonly(d)
        alloc_log:check({})
        eq(lib.DI_FLAGS_RO, bit.band(dis.a.di_flags, lib.DI_FLAGS_RO))
        eq(lib.DI_FLAGS_FIX, bit.band(dis.a.di_flags, lib.DI_FLAGS_FIX))
      end)
    end)
  end)
  describe('tv', function()
    describe('alloc', function()
      describe('list ret()', function()
        itp('works', function()
          local rettv = typvalt(lib.VAR_UNKNOWN)
          local l = lib.tv_list_alloc_ret(rettv, 0)
          eq(empty_list, typvalt2lua(rettv))
          eq(rettv.vval.v_list, l)
        end)
      end)
      describe('dict ret()', function()
        itp('works', function()
          local rettv = typvalt(lib.VAR_UNKNOWN)
          lib.tv_dict_alloc_ret(rettv)
          eq({}, typvalt2lua(rettv))
        end)
      end)
    end)
    local function defalloc()
      return {}
    end
    describe('clear()', function()
      itp('works', function()
        local function deffrees(alloc_rets)
          local ret = {}
          for i = #alloc_rets, 1, -1 do
            ret[#alloc_rets - i + 1] = alloc_rets:freed(i)
          end
          return ret
        end
        alloc_log:check({})
        lib.tv_clear(nil)
        alloc_log:check({})
        local ll = {}
        local ll_l = nil
        ll[1] = ll
        local dd = {}
        local dd_d = nil
        dd.dd = dd
        for _, v in ipairs({
          {nil_value},
          {null_string, nil, function() return {a.freed(alloc_log.null)} end},
          {0},
          {int(0)},
          {true},
          {false},
          {'true', function(tv) return {a.str(tv.vval.v_string)} end},
          {{}, function(tv) return {a.dict(tv.vval.v_dict)} end},
          {empty_list, function(tv) return {a.list(tv.vval.v_list)} end},
          {ll, function(tv)
            ll_l = tv.vval.v_list
            return {a.list(tv.vval.v_list), a.li(tv.vval.v_list.lv_first)}
          end, defalloc},
          {dd, function(tv)
            dd_d = tv.vval.v_dict
            return {a.dict(tv.vval.v_dict), a.di(first_di(tv.vval.v_dict))}
          end, defalloc},
        }) do
          local tv = lua2typvalt(v[1])
          local alloc_rets = {}
          alloc_log:check(get_alloc_rets((v[2] or defalloc)(tv), alloc_rets))
          lib.tv_clear(tv)
          alloc_log:check((v[3] or deffrees)(alloc_rets))
        end
        eq(1, ll_l.lv_refcount)
        eq(1, dd_d.dv_refcount)
      end)
    end)
    describe('copy()', function()
      itp('works', function()
        local function strallocs(tv)
          return {a.str(tv.vval.v_string)}
        end
        for _, v in ipairs({
          {nil_value},
          {null_string},
          {0},
          {int(0)},
          {true},
          {false},
          {{}, function(tv) return {a.dict(tv.vval.v_dict)} end, nil, function(from, to)
            eq(2, to.vval.v_dict.dv_refcount)
            eq(to.vval.v_dict, from.vval.v_dict)
          end},
          {empty_list, function(tv) return {a.list(tv.vval.v_list)} end, nil, function(from, to)
            eq(2, to.vval.v_list.lv_refcount)
            eq(to.vval.v_list, from.vval.v_list)
          end},
          {'test', strallocs, strallocs, function(from, to)
            neq(to.vval.v_string, from.vval.v_string)
          end},
        }) do
          local from = lua2typvalt(v[1])
          alloc_log:check((v[2] or defalloc)(from))
          local to = typvalt(lib.VAR_UNKNOWN)
          lib.tv_copy(from, to)
          local res = v[1]
          eq(res, typvalt2lua(to))
          alloc_log:check((v[3] or defalloc)(to))
          if v[4] then
            v[4](from, to)
          end
        end
      end)
    end)
    describe('item_lock()', function()
      itp('does not alter VAR_PARTIAL', function()
        local p_tv = lua2typvalt({
          [type_key]=func_type,
          value='tr',
          dict={},
        })
        lib.tv_item_lock(p_tv, -1, true)
        eq(lib.VAR_UNLOCKED, p_tv.vval.v_partial.pt_dict.dv_lock)
      end)
      itp('does not change VAR_FIXED values', function()
        local d_tv = lua2typvalt({})
        local l_tv = lua2typvalt(empty_list)
        alloc_log:clear()
        d_tv.v_lock = lib.VAR_FIXED
        d_tv.vval.v_dict.dv_lock = lib.VAR_FIXED
        l_tv.v_lock = lib.VAR_FIXED
        l_tv.vval.v_list.lv_lock = lib.VAR_FIXED
        lib.tv_item_lock(d_tv, 1, true)
        lib.tv_item_lock(l_tv, 1, true)
        eq(lib.VAR_FIXED, d_tv.v_lock)
        eq(lib.VAR_FIXED, l_tv.v_lock)
        eq(lib.VAR_FIXED, d_tv.vval.v_dict.dv_lock)
        eq(lib.VAR_FIXED, l_tv.vval.v_list.lv_lock)
        lib.tv_item_lock(d_tv, 1, false)
        lib.tv_item_lock(l_tv, 1, false)
        eq(lib.VAR_FIXED, d_tv.v_lock)
        eq(lib.VAR_FIXED, l_tv.v_lock)
        eq(lib.VAR_FIXED, d_tv.vval.v_dict.dv_lock)
        eq(lib.VAR_FIXED, l_tv.vval.v_list.lv_lock)
        alloc_log:check({})
      end)
      itp('works with NULL values', function()
        local l_tv = lua2typvalt(null_list)
        local d_tv = lua2typvalt(null_dict)
        local s_tv = lua2typvalt(null_string)
        alloc_log:clear()
        lib.tv_item_lock(l_tv, 1, true)
        lib.tv_item_lock(d_tv, 1, true)
        lib.tv_item_lock(s_tv, 1, true)
        eq(null_list, typvalt2lua(l_tv))
        eq(null_dict, typvalt2lua(d_tv))
        eq(null_string, typvalt2lua(s_tv))
        eq(lib.VAR_LOCKED, d_tv.v_lock)
        eq(lib.VAR_LOCKED, l_tv.v_lock)
        eq(lib.VAR_LOCKED, s_tv.v_lock)
        alloc_log:check({})
      end)
    end)
    describe('islocked()', function()
      itp('works with NULL values', function()
        local l_tv = lua2typvalt(null_list)
        local d_tv = lua2typvalt(null_dict)
        eq(false, lib.tv_islocked(l_tv))
        eq(false, lib.tv_islocked(d_tv))
      end)
      itp('works', function()
        local tv = lua2typvalt()
        local d_tv = lua2typvalt({})
        local l_tv = lua2typvalt(empty_list)
        alloc_log:clear()
        eq(false, lib.tv_islocked(tv))
        eq(false, lib.tv_islocked(l_tv))
        eq(false, lib.tv_islocked(d_tv))
        d_tv.vval.v_dict.dv_lock = lib.VAR_LOCKED
        l_tv.vval.v_list.lv_lock = lib.VAR_LOCKED
        eq(true, lib.tv_islocked(l_tv))
        eq(true, lib.tv_islocked(d_tv))
        tv.v_lock = lib.VAR_LOCKED
        d_tv.v_lock = lib.VAR_LOCKED
        l_tv.v_lock = lib.VAR_LOCKED
        eq(true, lib.tv_islocked(tv))
        eq(true, lib.tv_islocked(l_tv))
        eq(true, lib.tv_islocked(d_tv))
        d_tv.vval.v_dict.dv_lock = lib.VAR_UNLOCKED
        l_tv.vval.v_list.lv_lock = lib.VAR_UNLOCKED
        eq(true, lib.tv_islocked(tv))
        eq(true, lib.tv_islocked(l_tv))
        eq(true, lib.tv_islocked(d_tv))
        tv.v_lock = lib.VAR_FIXED
        d_tv.v_lock = lib.VAR_FIXED
        l_tv.v_lock = lib.VAR_FIXED
        eq(false, lib.tv_islocked(tv))
        eq(false, lib.tv_islocked(l_tv))
        eq(false, lib.tv_islocked(d_tv))
        d_tv.vval.v_dict.dv_lock = lib.VAR_LOCKED
        l_tv.vval.v_list.lv_lock = lib.VAR_LOCKED
        eq(true, lib.tv_islocked(l_tv))
        eq(true, lib.tv_islocked(d_tv))
        d_tv.vval.v_dict.dv_lock = lib.VAR_FIXED
        l_tv.vval.v_list.lv_lock = lib.VAR_FIXED
        eq(false, lib.tv_islocked(l_tv))
        eq(false, lib.tv_islocked(d_tv))
        alloc_log:check({})
      end)
    end)
    describe('check_lock()', function()
      local function tv_check_lock(lock, name, name_len, emsg)
        return check_emsg(function()
          return lib.tv_check_lock(lock, name, name_len)
        end, emsg)
      end
      itp('works', function()
        eq(false, tv_check_lock(lib.VAR_UNLOCKED, 'test', 3))
        eq(true, tv_check_lock(lib.VAR_LOCKED, 'test', 3,
                               'E741: Value is locked: tes'))
        eq(true, tv_check_lock(lib.VAR_FIXED, 'test', 3,
                               'E742: Cannot change value of tes'))
        eq(true, tv_check_lock(lib.VAR_LOCKED, nil, 0,
                               'E741: Value is locked: Unknown'))
        eq(true, tv_check_lock(lib.VAR_FIXED, nil, 0,
                               'E742: Cannot change value of Unknown'))
        eq(true, tv_check_lock(lib.VAR_LOCKED, nil, lib.kTVCstring,
                               'E741: Value is locked: Unknown'))
        eq(true, tv_check_lock(lib.VAR_FIXED, 'test', lib.kTVCstring,
                               'E742: Cannot change value of test'))
      end)
    end)
    describe('equal()', function()
      itp('compares empty and NULL lists correctly', function()
        local l = lua2typvalt(empty_list)
        local l2 = lua2typvalt(empty_list)
        local nl = lua2typvalt(null_list)

        -- NULL lists are not equal to empty lists
        eq(false, lib.tv_equal(l, nl, true, false))
        eq(false, lib.tv_equal(nl, l, false, false))
        eq(false, lib.tv_equal(nl, l, false, true))
        eq(false, lib.tv_equal(l, nl, true, true))

        -- Yet NULL lists are equal themselves
        eq(true, lib.tv_equal(nl, nl, true, false))
        eq(true, lib.tv_equal(nl, nl, false, false))
        eq(true, lib.tv_equal(nl, nl, false, true))
        eq(true, lib.tv_equal(nl, nl, true, true))

        -- As well as empty lists
        eq(true, lib.tv_equal(l, l, true, false))
        eq(true, lib.tv_equal(l, l2, false, false))
        eq(true, lib.tv_equal(l2, l, false, true))
        eq(true, lib.tv_equal(l2, l2, true, true))
      end)
      -- Must not use recursive=true argument in the following tests because it
      -- indicates that tv_equal_recurse_limit and recursive_cnt were set which
      -- is essential. This argument will be set when comparing inner lists.
      itp('compares lists correctly when case is not ignored', function()
        local l1 = lua2typvalt({'abc', {1, 2, 'Abc'}, 'def'})
        local l2 = lua2typvalt({'abc', {1, 2, 'Abc'}})
        local l3 = lua2typvalt({'abc', {1, 2, 'Abc'}, 'Def'})
        local l4 = lua2typvalt({'abc', {1, 2, 'Abc', 4}, 'def'})
        local l5 = lua2typvalt({'Abc', {1, 2, 'Abc'}, 'def'})
        local l6 = lua2typvalt({'abc', {1, 2, 'Abc'}, 'def'})
        local l7 = lua2typvalt({'abc', {1, 2, 'abc'}, 'def'})
        local l8 = lua2typvalt({'abc', nil, 'def'})
        local l9 = lua2typvalt({'abc', {1, 2, nil}, 'def'})

        eq(true, lib.tv_equal(l1, l1, false, false))
        eq(false, lib.tv_equal(l1, l2, false, false))
        eq(false, lib.tv_equal(l1, l3, false, false))
        eq(false, lib.tv_equal(l1, l4, false, false))
        eq(false, lib.tv_equal(l1, l5, false, false))
        eq(true, lib.tv_equal(l1, l6, false, false))
        eq(false, lib.tv_equal(l1, l7, false, false))
        eq(false, lib.tv_equal(l1, l8, false, false))
        eq(false, lib.tv_equal(l1, l9, false, false))
      end)
      itp('compares lists correctly when case is ignored', function()
        local l1 = lua2typvalt({'abc', {1, 2, 'Abc'}, 'def'})
        local l2 = lua2typvalt({'abc', {1, 2, 'Abc'}})
        local l3 = lua2typvalt({'abc', {1, 2, 'Abc'}, 'Def'})
        local l4 = lua2typvalt({'abc', {1, 2, 'Abc', 4}, 'def'})
        local l5 = lua2typvalt({'Abc', {1, 2, 'Abc'}, 'def'})
        local l6 = lua2typvalt({'abc', {1, 2, 'Abc'}, 'def'})
        local l7 = lua2typvalt({'abc', {1, 2, 'abc'}, 'def'})
        local l8 = lua2typvalt({'abc', nil, 'def'})
        local l9 = lua2typvalt({'abc', {1, 2, nil}, 'def'})

        eq(true, lib.tv_equal(l1, l1, true, false))
        eq(false, lib.tv_equal(l1, l2, true, false))
        eq(true, lib.tv_equal(l1, l3, true, false))
        eq(false, lib.tv_equal(l1, l4, true, false))
        eq(true, lib.tv_equal(l1, l5, true, false))
        eq(true, lib.tv_equal(l1, l6, true, false))
        eq(true, lib.tv_equal(l1, l7, true, false))
        eq(false, lib.tv_equal(l1, l8, true, false))
        eq(false, lib.tv_equal(l1, l9, true, false))
      end)
      local function tv_equal(d1, d2, ic, recursive)
        return lib.tv_equal(d1, d2, ic or false, recursive or false)
      end
      itp('works with dictionaries', function()
        local nd = lua2typvalt(null_dict)
        eq(true, tv_equal(nd, nd))
        alloc_log:check({})
        local d1 = lua2typvalt({})
        alloc_log:check({a.dict(d1.vval.v_dict)})
        eq(1, d1.vval.v_dict.dv_refcount)
        eq(false, tv_equal(nd, d1))
        eq(false, tv_equal(d1, nd))
        eq(true, tv_equal(d1, d1))
        eq(1, d1.vval.v_dict.dv_refcount)
        alloc_log:check({})
        local d_upper = lua2typvalt({a='TEST'})
        local dis_upper = dict_items(d_upper.vval.v_dict)
        local d_lower = lua2typvalt({a='test'})
        local dis_lower = dict_items(d_lower.vval.v_dict)
        local d_kupper_upper = lua2typvalt({A='TEST'})
        local dis_kupper_upper = dict_items(d_kupper_upper.vval.v_dict)
        local d_kupper_lower = lua2typvalt({A='test'})
        local dis_kupper_lower = dict_items(d_kupper_lower.vval.v_dict)
        alloc_log:clear_tmp_allocs()
        alloc_log:check({
          a.dict(d_upper.vval.v_dict),
          a.di(dis_upper.a),
          a.str(dis_upper.a.di_tv.vval.v_string),

          a.dict(d_lower.vval.v_dict),
          a.di(dis_lower.a),
          a.str(dis_lower.a.di_tv.vval.v_string),

          a.dict(d_kupper_upper.vval.v_dict),
          a.di(dis_kupper_upper.A),
          a.str(dis_kupper_upper.A.di_tv.vval.v_string),

          a.dict(d_kupper_lower.vval.v_dict),
          a.di(dis_kupper_lower.A),
          a.str(dis_kupper_lower.A.di_tv.vval.v_string),
        })
        eq(true, tv_equal(d_upper, d_upper))
        eq(true, tv_equal(d_upper, d_upper, true))
        eq(false, tv_equal(d_upper, d_lower, false))
        eq(true, tv_equal(d_upper, d_lower, true))
        eq(true, tv_equal(d_kupper_upper, d_kupper_lower, true))
        eq(false, tv_equal(d_kupper_upper, d_lower, true))
        eq(false, tv_equal(d_kupper_upper, d_upper, true))
        eq(true, tv_equal(d_upper, d_upper, true, true))
        alloc_log:check({})
      end)
    end)
    describe('check', function()
      describe('str_or_nr()', function()
        itp('works', function()
          local tv = typvalt()
          local mem = lib.xmalloc(1)
          tv.vval.v_list = mem  -- Should crash when actually accessed
          alloc_log:clear()
          for _, v in ipairs({
            {lib.VAR_NUMBER, nil},
            {lib.VAR_FLOAT, 'E805: Expected a Number or a String, Float found'},
            {lib.VAR_PARTIAL, 'E703: Expected a Number or a String, Funcref found'},
            {lib.VAR_FUNC, 'E703: Expected a Number or a String, Funcref found'},
            {lib.VAR_LIST, 'E745: Expected a Number or a String, List found'},
            {lib.VAR_DICT, 'E728: Expected a Number or a String, Dictionary found'},
            {lib.VAR_SPECIAL, 'E5300: Expected a Number or a String'},
            {lib.VAR_UNKNOWN, 'E685: Internal error: tv_check_str_or_nr(UNKNOWN)'},
          }) do
            local typ = v[1]
            local emsg = v[2]
            local ret = true
            if emsg then ret = false end
            tv.v_type = typ
            eq(ret, check_emsg(function() return lib.tv_check_str_or_nr(tv) end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
      describe('num()', function()
        itp('works', function()
          local tv = typvalt()
          local mem = lib.xmalloc(1)
          tv.vval.v_list = mem  -- Should crash when actually accessed
          alloc_log:clear()
          for _, v in ipairs({
            {lib.VAR_NUMBER, nil},
            {lib.VAR_FLOAT, 'E805: Using a Float as a Number'},
            {lib.VAR_PARTIAL, 'E703: Using a Funcref as a Number'},
            {lib.VAR_FUNC, 'E703: Using a Funcref as a Number'},
            {lib.VAR_LIST, 'E745: Using a List as a Number'},
            {lib.VAR_DICT, 'E728: Using a Dictionary as a Number'},
            {lib.VAR_SPECIAL, nil},
            {lib.VAR_UNKNOWN, 'E685: using an invalid value as a Number'},
          }) do
            local typ = v[1]
            local emsg = v[2]
            local ret = true
            if emsg then ret = false end
            tv.v_type = typ
            eq(ret, check_emsg(function() return lib.tv_check_num(tv) end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
      describe('str()', function()
        itp('works', function()
          local tv = typvalt()
          local mem = lib.xmalloc(1)
          tv.vval.v_list = mem  -- Should crash when actually accessed
          alloc_log:clear()
          for _, v in ipairs({
            {lib.VAR_NUMBER, nil},
            {lib.VAR_FLOAT, 'E806: using Float as a String'},
            {lib.VAR_PARTIAL, 'E729: using Funcref as a String'},
            {lib.VAR_FUNC, 'E729: using Funcref as a String'},
            {lib.VAR_LIST, 'E730: using List as a String'},
            {lib.VAR_DICT, 'E731: using Dictionary as a String'},
            {lib.VAR_SPECIAL, nil},
            {lib.VAR_UNKNOWN, 'E908: using an invalid value as a String'},
          }) do
            local typ = v[1]
            local emsg = v[2]
            local ret = true
            if emsg then ret = false end
            tv.v_type = typ
            eq(ret, check_emsg(function() return lib.tv_check_str(tv) end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
    end)
    describe('get', function()
      describe('number()', function()
        itp('works', function()
          for _, v in ipairs({
            {lib.VAR_NUMBER, {v_number=42}, nil, 42},
            {lib.VAR_STRING, {v_string=to_cstr('100500')}, nil, 100500},
            {lib.VAR_FLOAT, {v_float=42.53}, 'E805: Using a Float as a Number', 0},
            {lib.VAR_PARTIAL, {v_partial=NULL}, 'E703: Using a Funcref as a Number', 0},
            {lib.VAR_FUNC, {v_string=NULL}, 'E703: Using a Funcref as a Number', 0},
            {lib.VAR_LIST, {v_list=NULL}, 'E745: Using a List as a Number', 0},
            {lib.VAR_DICT, {v_dict=NULL}, 'E728: Using a Dictionary as a Number', 0},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarNull}, nil, 0},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarTrue}, nil, 1},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarFalse}, nil, 0},
            {lib.VAR_UNKNOWN, nil, 'E685: Internal error: tv_get_number(UNKNOWN)', 0},
          }) do
            -- Using to_cstr, cannot free with tv_clear
            local tv = ffi.gc(typvalt(v[1], v[2]), nil)
            alloc_log:check({})
            local emsg = v[3]
            local ret = v[4]
            eq(ret, check_emsg(function() return lib.tv_get_number(tv) end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
      describe('number_chk()', function()
        itp('works', function()
          for _, v in ipairs({
            {lib.VAR_NUMBER, {v_number=42}, nil, 42},
            {lib.VAR_STRING, {v_string=to_cstr('100500')}, nil, 100500},
            {lib.VAR_FLOAT, {v_float=42.53}, 'E805: Using a Float as a Number', 0},
            {lib.VAR_PARTIAL, {v_partial=NULL}, 'E703: Using a Funcref as a Number', 0},
            {lib.VAR_FUNC, {v_string=NULL}, 'E703: Using a Funcref as a Number', 0},
            {lib.VAR_LIST, {v_list=NULL}, 'E745: Using a List as a Number', 0},
            {lib.VAR_DICT, {v_dict=NULL}, 'E728: Using a Dictionary as a Number', 0},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarNull}, nil, 0},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarTrue}, nil, 1},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarFalse}, nil, 0},
            {lib.VAR_UNKNOWN, nil, 'E685: Internal error: tv_get_number(UNKNOWN)', 0},
          }) do
            -- Using to_cstr, cannot free with tv_clear
            local tv = ffi.gc(typvalt(v[1], v[2]), nil)
            alloc_log:check({})
            local emsg = v[3]
            local ret = {v[4], not not emsg}
            eq(ret, check_emsg(function()
              local err = ffi.new('bool[1]', {false})
              local res = lib.tv_get_number_chk(tv, err)
              return {res, err[0]}
            end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
      describe('lnum()', function()
        itp('works', function()
          for _, v in ipairs({
            {lib.VAR_NUMBER, {v_number=42}, nil, 42},
            {lib.VAR_STRING, {v_string=to_cstr('100500')}, nil, 100500},
            {lib.VAR_STRING, {v_string=to_cstr('.')}, nil, 46},
            {lib.VAR_FLOAT, {v_float=42.53}, 'E805: Using a Float as a Number', -1},
            {lib.VAR_PARTIAL, {v_partial=NULL}, 'E703: Using a Funcref as a Number', -1},
            {lib.VAR_FUNC, {v_string=NULL}, 'E703: Using a Funcref as a Number', -1},
            {lib.VAR_LIST, {v_list=NULL}, 'E745: Using a List as a Number', -1},
            {lib.VAR_DICT, {v_dict=NULL}, 'E728: Using a Dictionary as a Number', -1},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarNull}, nil, 0},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarTrue}, nil, 1},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarFalse}, nil, 0},
            {lib.VAR_UNKNOWN, nil, 'E685: Internal error: tv_get_number(UNKNOWN)', -1},
          }) do
            lib.curwin.w_cursor.lnum = 46
            -- Using to_cstr, cannot free with tv_clear
            local tv = ffi.gc(typvalt(v[1], v[2]), nil)
            alloc_log:check({})
            local emsg = v[3]
            local ret = v[4]
            eq(ret, check_emsg(function() return lib.tv_get_lnum(tv) end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
      describe('float()', function()
        itp('works', function()
          for _, v in ipairs({
            {lib.VAR_NUMBER, {v_number=42}, nil, 42},
            {lib.VAR_STRING, {v_string=to_cstr('100500')}, 'E892: Using a String as a Float', 0},
            {lib.VAR_FLOAT, {v_float=42.53}, nil, 42.53},
            {lib.VAR_PARTIAL, {v_partial=NULL}, 'E891: Using a Funcref as a Float', 0},
            {lib.VAR_FUNC, {v_string=NULL}, 'E891: Using a Funcref as a Float', 0},
            {lib.VAR_LIST, {v_list=NULL}, 'E893: Using a List as a Float', 0},
            {lib.VAR_DICT, {v_dict=NULL}, 'E894: Using a Dictionary as a Float', 0},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarNull}, 'E907: Using a special value as a Float', 0},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarTrue}, 'E907: Using a special value as a Float', 0},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarFalse}, 'E907: Using a special value as a Float', 0},
            {lib.VAR_UNKNOWN, nil, 'E685: Internal error: tv_get_float(UNKNOWN)', 0},
          }) do
            -- Using to_cstr, cannot free with tv_clear
            local tv = ffi.gc(typvalt(v[1], v[2]), nil)
            alloc_log:check({})
            local emsg = v[3]
            local ret = v[4]
            eq(ret, check_emsg(function() return lib.tv_get_float(tv) end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
      describe('string()', function()
        itp('works', function()
          local buf = lib.tv_get_string(lua2typvalt(int(1)))
          local buf_chk = lib.tv_get_string_chk(lua2typvalt(int(1)))
          neq(buf, buf_chk)
          for _, v in ipairs({
            {lib.VAR_NUMBER, {v_number=42}, nil, '42'},
            {lib.VAR_STRING, {v_string=to_cstr('100500')}, nil, '100500'},
            {lib.VAR_FLOAT, {v_float=42.53}, 'E806: using Float as a String', ''},
            {lib.VAR_PARTIAL, {v_partial=NULL}, 'E729: using Funcref as a String', ''},
            {lib.VAR_FUNC, {v_string=NULL}, 'E729: using Funcref as a String', ''},
            {lib.VAR_LIST, {v_list=NULL}, 'E730: using List as a String', ''},
            {lib.VAR_DICT, {v_dict=NULL}, 'E731: using Dictionary as a String', ''},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarNull}, nil, 'null'},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarTrue}, nil, 'true'},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarFalse}, nil, 'false'},
            {lib.VAR_UNKNOWN, nil, 'E908: using an invalid value as a String', ''},
          }) do
            -- Using to_cstr in place of Neovim allocated string, cannot
            -- tv_clear() that.
            local tv = ffi.gc(typvalt(v[1], v[2]), nil)
            alloc_log:check({})
            local emsg = v[3]
            local ret = v[4]
            eq(ret, check_emsg(function()
              local res = lib.tv_get_string(tv)
              if tv.v_type == lib.VAR_NUMBER or tv.v_type == lib.VAR_SPECIAL then
                eq(buf, res)
              else
                neq(buf, res)
              end
              if res ~= nil then
                return ffi.string(res)
              else
                return nil
              end
            end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
      describe('string_chk()', function()
        itp('works', function()
          local buf = lib.tv_get_string_chk(lua2typvalt(int(1)))
          for _, v in ipairs({
            {lib.VAR_NUMBER, {v_number=42}, nil, '42'},
            {lib.VAR_STRING, {v_string=to_cstr('100500')}, nil, '100500'},
            {lib.VAR_FLOAT, {v_float=42.53}, 'E806: using Float as a String', nil},
            {lib.VAR_PARTIAL, {v_partial=NULL}, 'E729: using Funcref as a String', nil},
            {lib.VAR_FUNC, {v_string=NULL}, 'E729: using Funcref as a String', nil},
            {lib.VAR_LIST, {v_list=NULL}, 'E730: using List as a String', nil},
            {lib.VAR_DICT, {v_dict=NULL}, 'E731: using Dictionary as a String', nil},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarNull}, nil, 'null'},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarTrue}, nil, 'true'},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarFalse}, nil, 'false'},
            {lib.VAR_UNKNOWN, nil, 'E908: using an invalid value as a String', nil},
          }) do
            -- Using to_cstr, cannot free with tv_clear
            local tv = ffi.gc(typvalt(v[1], v[2]), nil)
            alloc_log:check({})
            local emsg = v[3]
            local ret = v[4]
            eq(ret, check_emsg(function()
              local res = lib.tv_get_string_chk(tv)
              if tv.v_type == lib.VAR_NUMBER or tv.v_type == lib.VAR_SPECIAL then
                eq(buf, res)
              else
                neq(buf, res)
              end
              if res ~= nil then
                return ffi.string(res)
              else
                return nil
              end
            end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
      describe('string_buf()', function()
        itp('works', function()
          for _, v in ipairs({
            {lib.VAR_NUMBER, {v_number=42}, nil, '42'},
            {lib.VAR_STRING, {v_string=to_cstr('100500')}, nil, '100500'},
            {lib.VAR_FLOAT, {v_float=42.53}, 'E806: using Float as a String', ''},
            {lib.VAR_PARTIAL, {v_partial=NULL}, 'E729: using Funcref as a String', ''},
            {lib.VAR_FUNC, {v_string=NULL}, 'E729: using Funcref as a String', ''},
            {lib.VAR_LIST, {v_list=NULL}, 'E730: using List as a String', ''},
            {lib.VAR_DICT, {v_dict=NULL}, 'E731: using Dictionary as a String', ''},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarNull}, nil, 'null'},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarTrue}, nil, 'true'},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarFalse}, nil, 'false'},
            {lib.VAR_UNKNOWN, nil, 'E908: using an invalid value as a String', ''},
          }) do
            -- Using to_cstr, cannot free with tv_clear
            local tv = ffi.gc(typvalt(v[1], v[2]), nil)
            alloc_log:check({})
            local emsg = v[3]
            local ret = v[4]
            eq(ret, check_emsg(function()
              local buf = ffi.new('char[?]', lib.NUMBUFLEN, {0})
              local res = lib.tv_get_string_buf(tv, buf)
              if tv.v_type == lib.VAR_NUMBER or tv.v_type == lib.VAR_SPECIAL then
                eq(buf, res)
              else
                neq(buf, res)
              end
              if res ~= nil then
                return ffi.string(res)
              else
                return nil
              end
            end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
      describe('string_buf_chk()', function()
        itp('works', function()
          for _, v in ipairs({
            {lib.VAR_NUMBER, {v_number=42}, nil, '42'},
            {lib.VAR_STRING, {v_string=to_cstr('100500')}, nil, '100500'},
            {lib.VAR_FLOAT, {v_float=42.53}, 'E806: using Float as a String', nil},
            {lib.VAR_PARTIAL, {v_partial=NULL}, 'E729: using Funcref as a String', nil},
            {lib.VAR_FUNC, {v_string=NULL}, 'E729: using Funcref as a String', nil},
            {lib.VAR_LIST, {v_list=NULL}, 'E730: using List as a String', nil},
            {lib.VAR_DICT, {v_dict=NULL}, 'E731: using Dictionary as a String', nil},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarNull}, nil, 'null'},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarTrue}, nil, 'true'},
            {lib.VAR_SPECIAL, {v_special=lib.kSpecialVarFalse}, nil, 'false'},
            {lib.VAR_UNKNOWN, nil, 'E908: using an invalid value as a String', nil},
          }) do
            -- Using to_cstr, cannot free with tv_clear
            local tv = ffi.gc(typvalt(v[1], v[2]), nil)
            alloc_log:check({})
            local emsg = v[3]
            local ret = v[4]
            eq(ret, check_emsg(function()
              local buf = ffi.new('char[?]', lib.NUMBUFLEN, {0})
              local res = lib.tv_get_string_buf_chk(tv, buf)
              if tv.v_type == lib.VAR_NUMBER or tv.v_type == lib.VAR_SPECIAL then
                eq(buf, res)
              else
                neq(buf, res)
              end
              if res ~= nil then
                return ffi.string(res)
              else
                return nil
              end
            end, emsg))
            if emsg then
              alloc_log:clear()
            else
              alloc_log:check({})
            end
          end
        end)
      end)
    end)
  end)
end)
