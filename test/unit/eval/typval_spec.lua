local helpers = require('test.unit.helpers')(after_each)
local eval_helpers = require('test.unit.eval.helpers')

local itp = helpers.gen_itp(it)

local eq = helpers.eq
local neq = helpers.neq
local ffi = helpers.ffi
local cimport = helpers.cimport
local alloc_log_new = helpers.alloc_log_new

local a = eval_helpers.alloc_logging_helpers
local list = eval_helpers.list
local type_key  = eval_helpers.type_key
local li_alloc  = eval_helpers.li_alloc
local int_type  = eval_helpers.int_type
local dict_type  = eval_helpers.dict_type
local list_type  = eval_helpers.list_type
local null_list  = eval_helpers.null_list
local null_dict  = eval_helpers.null_dict
local lua2typvalt  = eval_helpers.lua2typvalt
local typvalt2lua  = eval_helpers.typvalt2lua
local null_string  = eval_helpers.null_string

local lib = cimport('./src/nvim/eval/typval.h', './src/nvim/memory.h')

local function list_items(l)
  local lis = {}
  local li = l.lv_first
  for i = 1, l.lv_len do
    lis[i] = ffi.gc(li, nil)
    li = li.li_next
  end
  return lis
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
  for i = 1,#exp_log do
    if ({malloc=true, calloc=true})[exp_log[i].func] then
      res[#res + 1] = exp_log[i].ret
    end
  end
  res.freed = function(r, n) return {func='free', args={r[n]}} end
  return exp_log
end

local to_cstr_nofree = function(v) return lib.xstrdup(v) end

local alloc_log = alloc_log_new()

before_each(function()
  alloc_log:before_each()
end)

after_each(function()
  alloc_log:after_each()
end)

describe('typval.c', function()
  describe('list', function()
    describe('item', function()
      describe('alloc()/free()', function()
        itp('works', function()
          local li = li_alloc(true)
          neq(nil, li)
          lib.tv_list_item_free(li)
          alloc_log:check({
            a.li(li),
            a.freed(li),
          })
        end)
        itp('also frees the value', function()
          local li
          local s
          local l
          local tv
          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_NUMBER
          li.li_tv.vval.v_number = 10
          lib.tv_list_item_free(li)
          alloc_log:check({
            a.li(li),
            a.freed(li),
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_FLOAT
          li.li_tv.vval.v_float = 10.5
          lib.tv_list_item_free(li)
          alloc_log:check({
            a.li(li),
            a.freed(li),
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_STRING
          li.li_tv.vval.v_string = nil
          lib.tv_list_item_free(li)
          alloc_log:check({
            a.li(li),
            a.freed(alloc_log.null),
            a.freed(li),
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_STRING
          s = to_cstr_nofree('test')
          li.li_tv.vval.v_string = s
          lib.tv_list_item_free(li)
          alloc_log:check({
            a.li(li),
            a.str(s, #('test')),
            a.freed(s),
            a.freed(li),
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_LIST
          l = ffi.gc(list(), nil)
          l.lv_refcount = 2
          li.li_tv.vval.v_list = l
          lib.tv_list_item_free(li)
          alloc_log:check({
            a.li(li),
            a.list(l),
            a.freed(li),
          })
          eq(1, l.lv_refcount)

          li = li_alloc(true)
          tv = lua2typvalt({[type_key]=dict_type})
          tv.vval.v_dict.dv_refcount = 2
          li.li_tv = tv
          lib.tv_list_item_free(li)
          alloc_log:check({
            a.li(li),
            a.dict(tv.vval.v_dict),
            a.freed(li),
          })
          eq(1, tv.vval.v_dict.dv_refcount)
        end)
      end)
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

          lib.tv_list_item_remove(l, lis[1])
          alloc_log:check({
            a.freed(table.remove(lis, 1)),
          })
          eq(lis, list_items(l))

          lib.tv_list_item_remove(l, lis[6])
          alloc_log:check({
            a.freed(table.remove(lis)),
          })
          eq(lis, list_items(l))

          lib.tv_list_item_remove(l, lis[3])
          alloc_log:check({
            a.freed(table.remove(lis, 3)),
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

          lib.tv_list_item_remove(l, lis[4])
          ffi.gc(lis[4], lib.tv_list_item_free)
          eq({lis[1], lis[5], lis[7]}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item})

          lib.tv_list_item_remove(l, lis[2])
          ffi.gc(lis[2], lib.tv_list_item_free)
          eq({lis[1], lis[5], lis[7]}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item})

          lib.tv_list_item_remove(l, lis[7])
          ffi.gc(lis[7], lib.tv_list_item_free)
          eq({lis[1], lis[5], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

          lib.tv_list_item_remove(l, lis[1])
          ffi.gc(lis[1], lib.tv_list_item_free)
          eq({lis[3], lis[5], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

          alloc_log:clear()
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
    describe('alloc()/free()', function()
      itp('recursively frees list with', function()
        local l1 = ffi.gc(list(1, 'abc'), nil)
        local l2 = ffi.gc(list({[type_key]=dict_type}), nil)
        local l3 = ffi.gc(list({[type_key]=list_type}), nil)
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
      itp('frees all containers inside a list', function()
        local l1 = ffi.gc(list('abc', {[type_key]=dict_type}, {[type_key]=list_type}), nil)
        local alloc_rets = {}
        alloc_log:check(get_alloc_rets({
          a.list(l1),
          a.str(l1.lv_first.li_tv.vval.v_string, #('abc')),
          a.li(l1.lv_first),
          a.dict(l1.lv_first.li_next.li_tv.vval.v_dict),
          a.li(l1.lv_first.li_next),
          a.list(l1.lv_last.li_tv.vval.v_list),
          a.li(l1.lv_last),
        }, alloc_rets))
        lib.tv_list_free(l1)
        alloc_log:check({
          alloc_rets:freed(2),
          alloc_rets:freed(3),
          alloc_rets:freed(4),
          alloc_rets:freed(5),
          alloc_rets:freed(6),
          alloc_rets:freed(7),
          alloc_rets:freed(1),
        })
      end)
    end)
    describe('unref()', function()
      itp('recursively frees list when reference count goes to 0', function()
        local l = ffi.gc(list({[type_key]=list_type}), nil)
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
    describe('remove_items()', function()
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

        lib.tv_list_remove_items(l, lis[1], lis[3])
        eq({4, 5, 6, 7, 8, 9, 10, 11, 12, 13}, typvalt2lua(l_tv))
        eq({lis[4], lis[7], lis[13]}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item})

        lib.tv_list_remove_items(l, lis[11], lis[13])
        eq({4, 5, 6, 7, 8, 9, 10}, typvalt2lua(l_tv))
        eq({lis[4], lis[7], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

        lib.tv_list_remove_items(l, lis[6], lis[8])
        eq({4, 5, 9, 10}, typvalt2lua(l_tv))
        eq({lis[4], lis[9], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

        lib.tv_list_remove_items(l, lis[4], lis[10])
        eq({[type_key]=list_type}, typvalt2lua(l_tv))
        eq({true, true, true}, {lws[1].lw_item == nil, lws[2].lw_item == nil, lws[3].lw_item == nil})

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
          local l_tv = lua2typvalt({[type_key]=list_type})
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
          local l_tv = lua2typvalt({[type_key]=list_type})
          local l = l_tv.vval.v_list

          local l_l_tv = lua2typvalt({[type_key]=list_type})
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

          eq({'test', {[type_key]=list_type}}, typvalt2lua(l_tv))
        end)
      end)
    end)
    describe('append', function()
      describe('list()', function()
        itp('works', function()
          local l_tv = lua2typvalt({[type_key]=list_type})
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
          local l_tv = lua2typvalt({[type_key]=list_type})
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
          local l_tv = lua2typvalt({[type_key]=list_type})
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
          local l_tv = lua2typvalt({[type_key]=list_type})
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
          local l_tv = lua2typvalt({[type_key]=list_type})
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

          eq({{[type_key]=int_type, value=-100500},
              {[type_key]=int_type, value=100500}}, typvalt2lua(l_tv))
        end)
      end)
    end)
  end)
end)
