local helpers = require('test.unit.helpers')
local eval_helpers = require('test.unit.eval.helpers')

local OK = helpers.OK
local eq = helpers.eq
local neq = helpers.neq
local ffi = helpers.ffi
local NULL = helpers.NULL
local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local set_logging_allocator = helpers.set_logging_allocator

local list = eval_helpers.list
local lst2tbl = eval_helpers.lst2tbl
local type_key  = eval_helpers.type_key
local li_alloc  = eval_helpers.li_alloc
local int_type  = eval_helpers.int_type
local first_di  = eval_helpers.first_di
local dict_type  = eval_helpers.dict_type
local list_type  = eval_helpers.list_type
local null_list  = eval_helpers.null_list
local null_dict  = eval_helpers.null_dict
local lua2typvalt  = eval_helpers.lua2typvalt
local typvalt2lua  = eval_helpers.typvalt2lua
local null_string  = eval_helpers.null_string

local lib = cimport('./src/nvim/eval/typval.h', './src/nvim/memory.h',
                    './src/nvim/mbyte.h')

local function list_index(l, idx)
  return tv_list_find(l, idx)
end

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
  res.freed = function(res, n) return {func='free', args={res[n]}} end
  return exp_log
end

local alloc_log
local restore_allocators

local void_ptr = ffi.typeof('void *')
local v = function(a) return ffi.cast(void_ptr, a) end

local to_cstr_nofree = function(v) return lib.xstrdup(v) end

before_each(function()
  alloc_log, restore_allocators = set_logging_allocator()
end)

local function clear_alloc_log()
  alloc_log.log = {}
end

local function check_alloc_log(exp)
  eq(exp, alloc_log.log)
  clear_alloc_log()
end

local function clear_tmp_allocs()
  local toremove = {}
  local allocs = {}
  for i, v in ipairs(alloc_log.log) do
    if v.func == 'malloc' or v.func == 'calloc' then
      allocs[tostring(v.ret)] = i
    elseif v.func == 'realloc' or v.func == 'free' then
      if allocs[tostring(v.args[1])] then
        toremove[#toremove + 1] = allocs[tostring(v.args[1])]
        if v.func == 'free' then
          toremove[#toremove + 1] = i
        end
      end
      if v.func == 'realloc' then
        allocs[tostring(v.ret)] = i
      end
    end
  end
  table.sort(toremove)
  for i = #toremove,1,-1 do
    table.remove(alloc_log.log, toremove[i])
  end
end

local a = {
  list = function(l) return {func='calloc', args={1, ffi.sizeof('list_T')}, ret=v(l)} end,
  li = function(li) return {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(li)} end,
  dict = function(d) return {func='malloc', args={ffi.sizeof('dict_T')}, ret=v(d)} end,
  di = function(di, size)
    return {func='malloc', args={ffi.offsetof('dictitem_T', 'di_key') + size + 1}, ret=v(di)}
  end,
  str = function(s, size) return {func='malloc', args={size + 1}, ret=v(s)} end,

  freed = function(p) return {func='free', args={p and v(p)}} end,
}

after_each(function()
  restore_allocators()
end)

describe('typval.c', function()
  describe('list', function()
    describe('item', function()
      describe('alloc()/free()', function()
        it('works', function()
          local li = li_alloc(true)
          neq(nil, li)
          lib.tv_list_item_free(li)
          check_alloc_log({
            a.li(li),
            a.freed(li),
          })
        end)
        it('also frees the value', function()
          local li
          local s
          local l
          local tv
          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_NUMBER
          li.li_tv.vval.v_number = 10
          lib.tv_list_item_free(li)
          check_alloc_log({
            a.li(li),
            a.freed(li),
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_FLOAT
          li.li_tv.vval.v_float = 10.5
          lib.tv_list_item_free(li)
          check_alloc_log({
            a.li(li),
            a.freed(li),
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_STRING
          li.li_tv.vval.v_string = nil
          lib.tv_list_item_free(li)
          check_alloc_log({
            a.li(li),
            a.freed(nil),
            a.freed(li),
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_STRING
          s = to_cstr_nofree('test')
          li.li_tv.vval.v_string = s
          lib.tv_list_item_free(li)
          check_alloc_log({
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
          check_alloc_log({
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
          check_alloc_log({
            a.li(li),
            a.dict(tv.vval.v_dict),
            a.freed(li),
          })
          eq(1, tv.vval.v_dict.dv_refcount)
        end)
      end)
      describe('remove()', function()
        it('works', function()
          local l = list(1, 2, 3, 4, 5, 6, 7)
          neq(nil, l)
          local lis = list_items(l)
          check_alloc_log({
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
          check_alloc_log({
            a.freed(table.remove(lis, 1)),
          })
          eq(lis, list_items(l))

          lib.tv_list_item_remove(l, lis[6])
          check_alloc_log({
            a.freed(table.remove(lis)),
          })
          eq(lis, list_items(l))

          lib.tv_list_item_remove(l, lis[3])
          check_alloc_log({
            a.freed(table.remove(lis, 3)),
          })
          eq(lis, list_items(l))
        end)
        it('works and adjusts watchers correctly', function()
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

          clear_alloc_log()
          lib.tv_list_free(l, true)
          check_alloc_log({
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
        it('works', function()
          local l = ffi.gc(list(1, 2, 3, 4, 5, 6, 7), nil)
          eq(nil, l.lv_watch)
          local lw = list_watch(l)
          neq(nil, l.lv_watch)
          clear_alloc_log()
          lib.tv_list_watch_remove(l, lw)
          eq(nil, l.lv_watch)
          check_alloc_log({
            -- Does not free anything.
          })
          local lws = { list_watch(l), list_watch(l), list_watch(l) }
          clear_alloc_log()
          lib.tv_list_watch_remove(l, lws[2])
          eq(lws[3], l.lv_watch)
          eq(lws[1], l.lv_watch.lw_next)
          lib.tv_list_watch_remove(l, lws[1])
          eq(lws[3], l.lv_watch)
          eq(nil, l.lv_watch.lw_next)
          lib.tv_list_watch_remove(l, lws[3])
          eq(nil, l.lv_watch)
          check_alloc_log({
            -- Does not free anything.
          })
        end)
        it('ignores not found watchers', function()
          local l = list(1, 2, 3, 4, 5, 6, 7)
          local lw = list_watch_alloc()
          lib.tv_list_watch_remove(l, lw)
        end)
      end)
    end)
    -- add() and fix() were tested when testing tv_list_item_remove()
    describe('alloc()/free()', function()
      it('recursively frees list with recurse=true', function()
        local l1 = ffi.gc(list(1, 'abc'), nil)
        local l2 = ffi.gc(list({[type_key]=dict_type}), nil)
        local l3 = ffi.gc(list({[type_key]=list_type}), nil)
        local alloc_rets = {}
        check_alloc_log(get_alloc_rets({
          a.list(l1),
          a.li(l1.lv_first),
          a.str(l1.lv_last.li_tv.vval.v_string, 3),
          a.li(l1.lv_last),
          a.list(l2),
          a.dict(l2.lv_first.li_tv.vval.v_dict),
          a.li(l2.lv_first),
          a.list(l3),
          a.list(l3.lv_first.li_tv.vval.v_list),
          a.li(l3.lv_first),
        }, alloc_rets))
        lib.tv_list_free(l1, true)
        check_alloc_log({
          alloc_rets:freed(2),
          alloc_rets:freed(3),
          alloc_rets:freed(4),
          alloc_rets:freed(1),
        })
        lib.tv_list_free(l2, true)
        check_alloc_log({
          alloc_rets:freed(6),
          alloc_rets:freed(7),
          alloc_rets:freed(5),
        })
        lib.tv_list_free(l3, true)
        check_alloc_log({
          alloc_rets:freed(9),
          alloc_rets:freed(10),
          alloc_rets:freed(8),
        })
      end)
      it('does not free container items with recurse=false', function()
        local l1 = ffi.gc(list('abc', {[type_key]=dict_type}, {[type_key]=list_type}), nil)
        local alloc_rets = {}
        check_alloc_log(get_alloc_rets({
          a.list(l1),
          a.str(l1.lv_first.li_tv.vval.v_string, 3),
          a.li(l1.lv_first),
          a.dict(l1.lv_first.li_next.li_tv.vval.v_dict),
          a.li(l1.lv_first.li_next),
          a.list(l1.lv_last.li_tv.vval.v_list),
          a.li(l1.lv_last),
        }, alloc_rets))
        lib.tv_list_free(l1, false)
        check_alloc_log({
          alloc_rets:freed(2),
          alloc_rets:freed(3),
          alloc_rets:freed(5),
          alloc_rets:freed(7),
          alloc_rets:freed(1),
        })
        lib.tv_dict_free(alloc_rets[4], true)
        lib.tv_list_free(alloc_rets[6], true)
      end)
    end)
    describe('unref()', function()
      it('recursively frees list when reference count goes to 0', function()
        local l = ffi.gc(list({[type_key]=list_type}), nil)
        local alloc_rets = {}
        check_alloc_log(get_alloc_rets({
          a.list(l),
          a.list(l.lv_first.li_tv.vval.v_list),
          a.li(l.lv_first),
        }, alloc_rets))
        l.lv_refcount = 2
        lib.tv_list_unref(l)
        check_alloc_log({})
        lib.tv_list_unref(l)
        check_alloc_log({
          alloc_rets:freed(2),
          alloc_rets:freed(3),
          alloc_rets:freed(1),
        })
      end)
    end)
    describe('remove_items()', function()
      it('works', function()
        local l_tv = lua2typvalt({1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13})
        local l = l_tv.vval.v_list
        local lis = list_items(l)
        -- Three watchers: pointing to first, middle and last elements.
        local lws = {
          list_watch(l, lis[1]),
          list_watch(l, lis[7]),
          list_watch(l, lis[13]),
        }
        clear_alloc_log()

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

        check_alloc_log({})
      end)
    end)
    describe('insert', function()
      describe('()', function()
        it('works', function()
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
        it('works with an empty list', function()
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
        it('works', function()
          local l_tv = lua2typvalt({[type_key]=list_type})
          local l = l_tv.vval.v_list

          local l_l_tv = lua2typvalt({[type_key]=list_type})
          clear_alloc_log()
          local l_l = l_l_tv.vval.v_list
          eq(1, l_l.lv_refcount)
          lib.tv_list_insert_tv(l, l_l_tv, nil)
          eq(2, l_l.lv_refcount)
          eq(l_l, l.lv_first.li_tv.vval.v_list)
          check_alloc_log({
            a.li(l.lv_first),
          })

          local l_s_tv = lua2typvalt('test')
          check_alloc_log({
            a.str(l_s_tv.vval.v_string, 4),
          })
          lib.tv_list_insert_tv(l, l_s_tv, l.lv_first)
          check_alloc_log({
            a.li(l.lv_first),
            a.str(l.lv_first.li_tv.vval.v_string, 4),
          })

          eq({'test', {[type_key]=list_type}}, typvalt2lua(l_tv))
        end)
      end)
    end)
    describe('append', function()
      describe('list()', function()
        it('works', function()
          local l_tv = lua2typvalt({[type_key]=list_type})
          local l = l_tv.vval.v_list

          local l_l = list(1)
          clear_alloc_log()
          eq(1, l_l.lv_refcount)
          lib.tv_list_append_list(l, l_l)
          eq(2, l_l.lv_refcount)
          eq(l_l, l.lv_first.li_tv.vval.v_list)
          check_alloc_log({
            a.li(l.lv_last),
          })

          lib.tv_list_append_list(l, nil)
          check_alloc_log({
            a.li(l.lv_last),
          })

          eq({{1}, null_list}, typvalt2lua(l_tv))
        end)
      end)
      describe('dict()', function()
        it('works', function()
          local l_tv = lua2typvalt({[type_key]=list_type})
          local l = l_tv.vval.v_list

          local l_d_tv = lua2typvalt({test=1})
          local l_d = l_d_tv.vval.v_dict
          clear_alloc_log()
          eq(1, l_d.dv_refcount)
          lib.tv_list_append_dict(l, l_d)
          eq(2, l_d.dv_refcount)
          eq(l_d, l.lv_first.li_tv.vval.v_list)
          check_alloc_log({
            a.li(l.lv_last),
          })

          lib.tv_list_append_dict(l, nil)
          check_alloc_log({
            a.li(l.lv_last),
          })

          eq({{test=1}, null_dict}, typvalt2lua(l_tv))
        end)
      end)
      describe('string()', function()
        it('works', function()
          local l_tv = lua2typvalt({[type_key]=list_type})
          local l = l_tv.vval.v_list

          clear_alloc_log()
          lib.tv_list_append_string(l, 'test', 3)
          check_alloc_log({
            a.str(l.lv_last.li_tv.vval.v_string, 3),
            a.li(l.lv_last),
          })

          lib.tv_list_append_string(l, nil, 0)
          check_alloc_log({
            a.li(l.lv_last),
          })

          lib.tv_list_append_string(l, nil, -1)
          check_alloc_log({
            a.li(l.lv_last),
          })

          lib.tv_list_append_string(l, 'test', -1)
          check_alloc_log({
            a.str(l.lv_last.li_tv.vval.v_string, 4),
            a.li(l.lv_last),
          })

          eq({'tes', null_string, null_string, 'test'}, typvalt2lua(l_tv))
        end)
      end)
      describe('allocated string()', function()
        it('works', function()
          local l_tv = lua2typvalt({[type_key]=list_type})
          local l = l_tv.vval.v_list

          local s = lib.xstrdup('test')
          clear_alloc_log()
          lib.tv_list_append_allocated_string(l, s)
          check_alloc_log({
            a.li(l.lv_last),
          })

          lib.tv_list_append_allocated_string(l, nil)
          check_alloc_log({
            a.li(l.lv_last),
          })

          lib.tv_list_append_allocated_string(l, nil)
          check_alloc_log({
            a.li(l.lv_last),
          })

          eq({'test', null_string, null_string}, typvalt2lua(l_tv))
        end)
      end)
      describe('number()', function()
        it('works', function()
          local l_tv = lua2typvalt({[type_key]=list_type})
          local l = l_tv.vval.v_list

          clear_alloc_log()
          lib.tv_list_append_number(l, -100500)
          check_alloc_log({
            a.li(l.lv_last),
          })

          lib.tv_list_append_number(l, 100500)
          check_alloc_log({
            a.li(l.lv_last),
          })

          eq({{[type_key]=int_type, value=-100500},
              {[type_key]=int_type, value=100500}}, typvalt2lua(l_tv))
        end)
      end)
    end)
    describe('copy()', function()
      local function tv_list_copy(...)
        return ffi.gc(lib.tv_list_copy(...), lib.tv_list_unref)
      end
      it('copies NULL correctly', function()
        eq(nil, lib.tv_list_copy(nil, nil, true, 0))
        eq(nil, lib.tv_list_copy(nil, nil, false, 0))
        eq(nil, lib.tv_list_copy(nil, nil, true, 1))
        eq(nil, lib.tv_list_copy(nil, nil, false, 1))
      end)
      it('copies list correctly without converting items', function()
        local v = {{['«']='»'}, {'„'}, 1, '“', null_string, null_list, null_dict}
        local l_tv = lua2typvalt(v)
        local l = l_tv.vval.v_list
        local lis = list_items(l)
        clear_alloc_log()

        eq(1, lis[1].li_tv.vval.v_dict.dv_refcount)
        eq(1, lis[2].li_tv.vval.v_list.lv_refcount)
        local l_copy1 = tv_list_copy(nil, l, false, 0)
        eq(2, lis[1].li_tv.vval.v_dict.dv_refcount)
        eq(2, lis[2].li_tv.vval.v_list.lv_refcount)
        local lis_copy1 = list_items(l_copy1)
        eq(lis[1].li_tv.vval.v_dict, lis_copy1[1].li_tv.vval.v_dict)
        eq(lis[2].li_tv.vval.v_list, lis_copy1[2].li_tv.vval.v_list)
        eq(v, lst2tbl(l_copy1))
        check_alloc_log({
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
        lib.tv_list_free(ffi.gc(l_copy1, nil), true)
        clear_alloc_log()

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
        check_alloc_log({
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
      end)
      it('copies list correctly and converts items', function()
        local vc = ffi.gc(ffi.new('vimconv_T[1]'), function(vc)
          lib.convert_setup(vc, nil, nil)
        end)
        -- UTF-8 ↔ latin1 conversions need no iconv
        eq(OK, lib.convert_setup(vc, to_cstr('utf-8'), to_cstr('latin1')))

        local v = {{['«']='»'}, {'„'}, 1, '“', null_string, null_list, null_dict}
        local l_tv = lua2typvalt(v)
        local l = l_tv.vval.v_list
        local lis = list_items(l)
        clear_alloc_log()

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
        clear_tmp_allocs()
        check_alloc_log({
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
      it('returns different/same containers with(out) copyID', function()
        local l_inner_tv = lua2typvalt({[type_key]=list_type})
        local l_tv = lua2typvalt({l_inner_tv, l_inner_tv})
        eq(3, l_inner_tv.vval.v_list.lv_refcount)
        local l = l_tv.vval.v_list
        eq(l.lv_first.li_tv.vval.v_list, l.lv_last.li_tv.vval.v_list)

        local l_copy1 = tv_list_copy(nil, l, true, 0)
        neq(l_copy1.lv_first.li_tv.vval.v_list, l_copy1.lv_last.li_tv.vval.v_list)
        eq({{[type_key]=list_type}, {[type_key]=list_type}}, lst2tbl(l_copy1))

        local l_copy2 = tv_list_copy(nil, l, true, 2)
        eq(l_copy2.lv_first.li_tv.vval.v_list, l_copy2.lv_last.li_tv.vval.v_list)
        eq({{[type_key]=list_type}, {[type_key]=list_type}}, lst2tbl(l_copy2))

        eq(3, l_inner_tv.vval.v_list.lv_refcount)
      end)
      it('works with self-referencing list with copyID', function()
        local l_tv = lua2typvalt({[type_key]=list_type})
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
  end)
end)
