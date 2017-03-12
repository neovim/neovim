local helpers = require('test.unit.helpers')(after_each)
local eval_helpers = require('test.unit.eval.helpers')

local itp = helpers.gen_itp(it)

local eq = helpers.eq
local neq = helpers.neq
local ffi = helpers.ffi
local NULL = helpers.NULL
local cimport = helpers.cimport
local alloc_log_new = helpers.alloc_log_new

local a = eval_helpers.alloc_logging_helpers
local list = eval_helpers.list
local lst2tbl = eval_helpers.lst2tbl
local type_key  = eval_helpers.type_key
local dict_type  = eval_helpers.dict_type
local lua2typvalt  = eval_helpers.lua2typvalt

local lib = cimport('./src/nvim/eval/typval.h', './src/nvim/memory.h')

local function li_alloc(nogc)
  local gcfunc = lib.tv_list_item_free
  if nogc then gcfunc = nil end
  local li = ffi.gc(lib.tv_list_item_alloc(), gcfunc)
  li.li_next = nil
  li.li_prev = nil
  li.li_tv = {v_type=lib.VAR_UNKNOWN, v_lock=lib.VAR_UNLOCKED}
  return li
end

local function list_index(l, idx)
  return tv_list_find(l, idx)
end

local function list_items(l)
  local lis = {}
  local li = l.lv_first
  for i = 1, l.lv_len do
    lis[i] = li
    li = li.li_next
  end
  return lis
end

local function list_watch(li)
  return ffi.new('listwatch_T', {lw_item=li})
end

local alloc_log
local restore_allocators

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
          l = list()
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
          local lws = {list_watch(lis[1]), list_watch(lis[4]), list_watch(lis[7])}
          lib.tv_list_watch_add(l, lws[1])
          lib.tv_list_watch_add(l, lws[2])
          lib.tv_list_watch_add(l, lws[3])

          lib.tv_list_item_remove(l, lis[4])
          eq({lis[1], lis[5], lis[7]}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item})

          lib.tv_list_item_remove(l, lis[2])
          eq({lis[1], lis[5], lis[7]}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item})

          lib.tv_list_item_remove(l, lis[7])
          eq({lis[1], lis[5], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

          lib.tv_list_item_remove(l, lis[1])
          eq({lis[3], lis[5], nil}, {lws[1].lw_item, lws[2].lw_item, lws[3].lw_item == nil and nil})

          lib.tv_list_free(l)
        end)
      end)
    end)
  end)
end)
