local helpers = require('test.unit.helpers')
local eval_helpers = require('test.unit.eval.helpers')

local eq = helpers.eq
local neq = helpers.neq
local ffi = helpers.ffi
local NULL = helpers.NULL
local cimport = helpers.cimport
local set_logging_allocator = helpers.set_logging_allocator

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

local void_ptr = ffi.typeof('void *')
local v = function(a) return ffi.cast(void_ptr, a) end

local to_cstr_nofree = function(v) return lib.xstrdup(v) end

before_each(function()
  alloc_log, restore_allocators = set_logging_allocator()
end)

local function check_alloc_log(exp)
  eq(exp, alloc_log.log)
  alloc_log.log = {}
end

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
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(li)},
            {func='free', args={v(li)}},
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
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(li)},
            {func='free', args={v(li)}},
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_FLOAT
          li.li_tv.vval.v_float = 10.5
          lib.tv_list_item_free(li)
          check_alloc_log({
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(li)},
            {func='free', args={v(li)}},
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_STRING
          li.li_tv.vval.v_string = nil
          lib.tv_list_item_free(li)
          check_alloc_log({
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(li)},
            {func='free', args={nil}},
            {func='free', args={v(li)}},
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_STRING
          s = to_cstr_nofree('test')
          li.li_tv.vval.v_string = s
          lib.tv_list_item_free(li)
          check_alloc_log({
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(li)},
            {func='malloc', args={5}, ret=v(s)},
            {func='free', args={s}},
            {func='free', args={v(li)}},
          })

          li = li_alloc(true)
          li.li_tv.v_type = lib.VAR_LIST
          l = list()
          l.lv_refcount = 2
          li.li_tv.vval.v_list = l
          lib.tv_list_item_free(li)
          check_alloc_log({
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(li)},
            {func='calloc', args={1, ffi.sizeof('list_T')}, ret=v(l)},
            {func='free', args={v(li)}},
          })
          eq(1, l.lv_refcount)

          li = li_alloc(true)
          tv = lua2typvalt({[type_key]=dict_type})
          tv.vval.v_dict.dv_refcount = 2
          li.li_tv = tv
          lib.tv_list_item_free(li)
          check_alloc_log({
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(li)},
            {func='malloc', args={ffi.sizeof('dict_T')}, ret=v(tv.vval.v_dict)},
            {func='free', args={v(li)}},
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
            {func='calloc', args={1, ffi.sizeof('list_T')}, ret=v(l)},
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(lis[1])},
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(lis[2])},
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(lis[3])},
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(lis[4])},
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(lis[5])},
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(lis[6])},
            {func='malloc', args={ffi.sizeof('listitem_T')}, ret=v(lis[7])},
          })

          lib.tv_list_item_remove(l, lis[1])
          check_alloc_log({
            {func='free', args={v(table.remove(lis, 1))}},
          })
          eq(lis, list_items(l))

          lib.tv_list_item_remove(l, lis[6])
          check_alloc_log({
            {func='free', args={v(table.remove(lis))}},
          })
          eq(lis, list_items(l))

          lib.tv_list_item_remove(l, lis[3])
          check_alloc_log({
            {func='free', args={v(table.remove(lis, 3))}},
          })
          eq(lis, list_items(l))
        end)
        it('works and adjusts watchers correctly', function()
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

          lib.tv_list_free(l, true)
        end)
      end)
    end)
  end)
end)
