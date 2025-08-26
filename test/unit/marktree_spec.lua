local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local ffi = t.ffi
local eq = t.eq
local ok = t.ok

local lib = t.cimport('./src/nvim/marktree.h')

local function tablelength(tbl)
  local count = 0
  for _ in pairs(tbl) do
    count = count + 1
  end
  return count
end

local function pos_leq(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] <= b[2])
end

-- Checks that shadow and tree is consistent, and optionally
-- return the order
local function shadoworder(tree, shadow, iter, giveorder)
  ok(iter ~= nil)
  local status = lib.marktree_itr_first(tree, iter)
  local count = 0
  local pos2id, id2pos = {}, {}
  local last
  if not status and next(shadow) == nil then
    return pos2id, id2pos
  end
  repeat
    local mark = lib.marktree_itr_current(iter)
    local id = tonumber(mark.id)
    local spos = shadow[id]
    eq(mark.pos.row, spos[1], mark.id)
    eq(mark.pos.col, spos[2], mark.id)
    if lib.mt_right_test(mark) ~= spos[3] then
      error('invalid gravity for ' .. id .. ':(' .. mark.pos.row .. ', ' .. mark.pos.col .. ')')
    end
    if count > 0 then
      if not pos_leq(last, spos) then
        error('DISORDER')
      end
    end
    count = count + 1
    last = spos
    if giveorder then
      pos2id[count] = id
      id2pos[id] = count
    end
  until not lib.marktree_itr_next(tree, iter)
  local shadowlen = tablelength(shadow)
  if shadowlen ~= count then
    error('missed some keys? (shadow ' .. shadowlen .. ', tree ' .. count .. ')')
  end
  return id2pos, pos2id
end

local function shadowsplice(shadow, start, old_extent, new_extent)
  local old_end = {
    start[1] + old_extent[1],
    (old_extent[1] == 0 and start[2] or 0) + old_extent[2],
  }
  local new_end = {
    start[1] + new_extent[1],
    (new_extent[1] == 0 and start[2] or 0) + new_extent[2],
  }
  local delta = { new_end[1] - old_end[1], new_end[2] - old_end[2] }
  for _, pos in pairs(shadow) do
    if pos_leq(start, pos) then
      if pos_leq(pos, old_end) then
        -- delete region
        if pos[3] then -- right gravity
          pos[1], pos[2] = new_end[1], new_end[2]
        else
          pos[1], pos[2] = start[1], start[2]
        end
      else
        if pos[1] == old_end[1] then
          pos[2] = pos[2] + delta[2]
        end
        pos[1] = pos[1] + delta[1]
      end
    end
  end
end

local function dosplice(tree, shadow, start, old, new)
  lib.marktree_splice(tree, start[1], start[2], old[1], old[2], new[1], new[2])
  shadowsplice(shadow, start, old, new)
end

local ns = 10
local last_id = nil

local function put(tree, row, col, gravity, end_row, end_col, end_gravity)
  last_id = last_id + 1
  local my_id = last_id

  end_row = end_row or -1
  end_col = end_col or -1
  end_gravity = end_gravity or false

  lib.marktree_put_test(tree, ns, my_id, row, col, gravity, end_row, end_col, end_gravity, false)
  return my_id
end

local function put_meta(tree, row, col, gravitate, meta)
  last_id = last_id + 1
  local my_id = last_id

  lib.marktree_put_test(tree, ns, my_id, row, col, gravitate, -1, -1, false, meta)
  return my_id
end

describe('marktree', function()
  before_each(function()
    last_id = 0
  end)

  itp('works', function()
    local tree = ffi.new('MarkTree[1]') -- zero initialized by luajit
    local shadow = {}
    local iter = ffi.new('MarkTreeIter[1]')
    local iter2 = ffi.new('MarkTreeIter[1]')

    for i = 1, 100 do
      for j = 1, 100 do
        local gravitate = (i % 2) > 0
        local id = put(tree, j, i, gravitate)
        ok(id > 0)
        eq(nil, shadow[id])
        shadow[id] = { j, i, gravitate }
      end
      -- checking every insert is too slow, but this is ok
      lib.marktree_check(tree)
    end

    -- ss = lib.mt_inspect_rec(tree)
    -- io.stdout:write(ffi.string(ss))
    -- io.stdout:flush()

    local id2pos, pos2id = shadoworder(tree, shadow, iter)
    eq({}, pos2id) -- not set if not requested
    eq({}, id2pos)

    for i, ipos in pairs(shadow) do
      local p = lib.marktree_lookup_ns(tree, ns, i, false, iter)
      eq(ipos[1], p.pos.row)
      eq(ipos[2], p.pos.col)
      local k = lib.marktree_itr_current(iter)
      eq(ipos[1], k.pos.row)
      eq(ipos[2], k.pos.col, ipos[1])
      lib.marktree_itr_next(tree, iter)
      -- TODO(bfredl): use id2pos to check neighbour?
      -- local k2 = lib.marktree_itr_current(iter)
    end

    for i, ipos in pairs(shadow) do
      lib.marktree_itr_get(tree, ipos[1], ipos[2], iter)
      local k = lib.marktree_itr_current(iter)
      eq(i, tonumber(k.id))
      eq(ipos[1], k.pos.row)
      eq(ipos[2], k.pos.col)
    end

    ok(lib.marktree_itr_first(tree, iter))
    local del = lib.marktree_itr_current(iter)

    lib.marktree_del_itr(tree, iter, false)
    shadow[tonumber(del.id)] = nil
    shadoworder(tree, shadow, iter)

    for _, ci in ipairs({ 0, -1, 1, -2, 2, -10, 10 }) do
      for i = 1, 100 do
        lib.marktree_itr_get(tree, i, 50 + ci, iter)
        local k = lib.marktree_itr_current(iter)
        local id = tonumber(k.id)
        eq(shadow[id][1], k.pos.row)
        eq(shadow[id][2], k.pos.col)
        lib.marktree_del_itr(tree, iter, false)
        shadow[id] = nil
      end
      lib.marktree_check(tree)
      shadoworder(tree, shadow, iter)
    end

    -- NB: this is quite rudimentary. We rely on
    -- functional tests exercising splicing quite a bit
    lib.marktree_check(tree)
    dosplice(tree, shadow, { 2, 2 }, { 0, 5 }, { 1, 2 })
    lib.marktree_check(tree)
    shadoworder(tree, shadow, iter)
    dosplice(tree, shadow, { 30, 2 }, { 30, 5 }, { 1, 2 })
    lib.marktree_check(tree)
    shadoworder(tree, shadow, iter)

    dosplice(tree, shadow, { 5, 3 }, { 0, 2 }, { 0, 5 })
    shadoworder(tree, shadow, iter)
    lib.marktree_check(tree)

    -- build then burn (HOORAY! HOORAY!)
    while next(shadow) do
      lib.marktree_itr_first(tree, iter)
      -- delete every other key for fun and profit
      while true do
        local k = lib.marktree_itr_current(iter)
        lib.marktree_del_itr(tree, iter, false)
        ok(shadow[tonumber(k.id)] ~= nil)
        shadow[tonumber(k.id)] = nil
        local stat = lib.marktree_itr_next(tree, iter)
        if not stat then
          break
        end
      end
      lib.marktree_check(tree)
      shadoworder(tree, shadow, iter2)
    end

    -- Check iterator validity for 2 specific edge cases:
    -- https://github.com/neovim/neovim/pull/14719
    lib.marktree_clear(tree)
    for i = 1, 20 do
      put(tree, i, i, false)
    end

    lib.marktree_itr_get(tree, 10, 10, iter)
    lib.marktree_del_itr(tree, iter, false)
    eq(11, iter[0].x.key[iter[0].i].pos.col)

    lib.marktree_itr_get(tree, 11, 11, iter)
    lib.marktree_del_itr(tree, iter, false)
    eq(12, iter[0].x.key[iter[0].i].pos.col)
  end)

  itp("'intersect_mov' function works correctly", function()
    local function mov(x, y, w)
      local xa = ffi.new('uint64_t[?]', #x)
      for i, xi in ipairs(x) do
        xa[i - 1] = xi
      end
      local ya = ffi.new('uint64_t[?]', #y)
      for i, yi in ipairs(y) do
        ya[i - 1] = yi
      end
      local wa = ffi.new('uint64_t[?]', #w)
      for i, wi in ipairs(w) do
        wa[i - 1] = wi
      end

      local dummy_size = #x + #y + #w
      local wouta = ffi.new('uint64_t[?]', dummy_size)
      local douta = ffi.new('uint64_t[?]', dummy_size)
      local wsize = ffi.new('size_t[1]')
      wsize[0] = dummy_size
      local dsize = ffi.new('size_t[1]')
      dsize[0] = dummy_size

      local status = lib.intersect_mov_test(xa, #x, ya, #y, wa, #w, wouta, wsize, douta, dsize)
      if status == 0 then
        error 'wowza'
      end

      local wout, dout = {}, {}
      for i = 0, tonumber(wsize[0]) - 1 do
        table.insert(wout, tonumber(wouta[i]))
      end
      for i = 0, tonumber(dsize[0]) - 1 do
        table.insert(dout, tonumber(douta[i]))
      end
      return { wout, dout }
    end

    eq({ {}, {} }, mov({}, { 2, 3 }, { 2, 3 }))
    eq({ { 2, 3 }, {} }, mov({}, {}, { 2, 3 }))
    eq({ { 2, 3 }, {} }, mov({ 2, 3 }, {}, {}))
    eq({ {}, { 2, 3 } }, mov({}, { 2, 3 }, {}))

    eq({ { 1, 5 }, {} }, mov({ 1, 2, 5 }, { 2, 3 }, { 3 }))
    eq({ { 1, 2 }, {} }, mov({ 1, 2, 5 }, { 5, 10 }, { 10 }))
    eq({ { 1, 2 }, { 5 } }, mov({ 1, 2 }, { 5, 10 }, { 10 }))
    eq({ { 1, 3, 5, 7, 9 }, { 2, 4, 6, 8, 10 } }, mov({ 1, 3, 5, 7, 9 }, { 2, 4, 6, 8, 10 }, {}))
    eq({ { 1, 3, 5, 7, 9 }, { 2, 6, 10 } }, mov({ 1, 3, 5, 7, 9 }, { 2, 4, 6, 8, 10 }, { 4, 8 }))
    eq({ { 1, 4, 7 }, { 2, 5, 8 } }, mov({ 1, 3, 4, 6, 7, 9 }, { 2, 3, 5, 6, 8, 9 }, {}))
    eq({ { 1, 4, 7 }, {} }, mov({ 1, 3, 4, 6, 7, 9 }, { 2, 3, 5, 6, 8, 9 }, { 2, 5, 8 }))
    eq(
      { { 0, 1, 4, 7, 10 }, {} },
      mov({ 1, 3, 4, 6, 7, 9 }, { 2, 3, 5, 6, 8, 9 }, { 0, 2, 5, 8, 10 })
    )
  end)

  local function check_intersections(tree)
    lib.marktree_check(tree)
    -- to debug stuff disable this branch
    if true == true then
      ok(lib.marktree_check_intersections(tree))
      return
    end

    local str1 = lib.mt_inspect(tree, true, true)
    local dot1 = ffi.string(str1.data, str1.size)

    local val = lib.marktree_check_intersections(tree)
    if not val then
      local str2 = lib.mt_inspect(tree, true, true)
      local dot2 = ffi.string(str2.data, str2.size)
      print('actual:\n\n' .. 'Xafile.dot' .. '\n\nexpected:\n\n' .. 'Xefile.dot' .. '\n')
      print('nivå', tree[0].root.level)
      io.stdout:flush()
      local afil = io.open('Xafile.dot', 'wb')
      afil:write(dot1)
      afil:close()
      local efil = io.open('Xefile.dot', 'wb')
      efil:write(dot2)
      efil:close()
      ok(false)
    else
      ffi.C.xfree(str1.data)
    end
  end

  itp('works with intersections', function()
    local tree = ffi.new('MarkTree[1]') -- zero initialized by luajit

    local ids = {}

    for i = 1, 80 do
      table.insert(ids, put(tree, 1, i, false, 2, 100 - i, false))
      check_intersections(tree)
    end
    for i = 1, 80 do
      lib.marktree_del_pair_test(tree, ns, ids[i])
      check_intersections(tree)
    end
    ids = {}

    for i = 1, 80 do
      table.insert(ids, put(tree, 1, i, false, 2, 100 - i, false))
      check_intersections(tree)
    end

    for i = 1, 10 do
      for j = 1, 8 do
        local ival = (j - 1) * 10 + i
        lib.marktree_del_pair_test(tree, ns, ids[ival])
        check_intersections(tree)
      end
    end
  end)

  itp('works with intersections with a big tree', function()
    local tree = ffi.new('MarkTree[1]') -- zero initialized by luajit

    local ids = {}

    for i = 1, 1000 do
      table.insert(ids, put(tree, 1, i, false, 2, 1000 - i, false))
      if i % 10 == 1 then
        check_intersections(tree)
      end
    end

    check_intersections(tree)
    eq(2000, tree[0].n_keys)
    ok(tree[0].root.level >= 2)

    local iter = ffi.new('MarkTreeIter[1]')

    local k = 0
    for i = 1, 20 do
      for j = 1, 50 do
        k = k + 1
        local ival = (j - 1) * 20 + i
        if false == true then -- if there actually is a failure, this branch will fail out at the actual spot of the error
          lib.marktree_lookup_ns(tree, ns, ids[ival], false, iter)
          lib.marktree_del_itr(tree, iter, false)
          check_intersections(tree)

          lib.marktree_lookup_ns(tree, ns, ids[ival], true, iter)
          lib.marktree_del_itr(tree, iter, false)
          check_intersections(tree)
        else
          lib.marktree_del_pair_test(tree, ns, ids[ival])
          if k % 5 == 1 then
            check_intersections(tree)
          end
        end
      end
    end

    eq(0, tree[0].n_keys)
  end)

  itp('works with intersections and marktree_splice', function()
    local tree = ffi.new('MarkTree[1]') -- zero initialized by luajit

    for i = 1, 1000 do
      put(tree, 1, i, false, 2, 1000 - i, false)
      if i % 10 == 1 then
        check_intersections(tree)
      end
    end

    check_intersections(tree)
    eq(2000, tree[0].n_keys)
    ok(tree[0].root.level >= 2)

    for _ = 1, 10 do
      lib.marktree_splice(tree, 0, 0, 0, 100, 0, 0)
      check_intersections(tree)
    end
  end)

  itp('marktree_move should preserve key order', function()
    local tree = ffi.new('MarkTree[1]') -- zero initialized by luajit
    local iter = ffi.new('MarkTreeIter[1]')
    local ids = {}

    -- new index and old index look the same, but still have to move because
    -- pos will get updated
    table.insert(ids, put(tree, 1, 1, false, 1, 3, false))
    table.insert(ids, put(tree, 1, 3, false, 1, 3, false))
    table.insert(ids, put(tree, 1, 3, false, 1, 3, false))
    table.insert(ids, put(tree, 1, 3, false, 1, 3, false))

    lib.marktree_lookup_ns(tree, ns, ids[3], false, iter)
    lib.marktree_move(tree, iter, 1, 2)

    check_intersections(tree)
  end)

  itp('works with intersections and marktree_move', function()
    local tree = ffi.new('MarkTree[1]') -- zero initialized by luajit

    local ids = {}

    for i = 1, 1000 do
      table.insert(ids, put(tree, 1, i, false, 2, 1000 - i, false))
      if i % 10 == 1 then
        check_intersections(tree)
      end
    end

    local iter = ffi.new('MarkTreeIter[1]')
    for i = 1, 1000 do
      local which = i % 2
      lib.marktree_lookup_ns(tree, ns, ids[i], which, iter)
      lib.marktree_move(tree, iter, 1 + which, 500 + i)
      if i % 10 == 1 then
        check_intersections(tree)
      end
    end
  end)

  itp('works with intersections with a even bigger tree', function()
    local tree = ffi.new('MarkTree[1]') -- zero initialized by luajit

    local ids = {}

    -- too much overhead on ASAN
    local size_factor = t.is_asan() and 3 or 10

    local at_row = {}
    for i = 1, 10 do
      at_row[i] = {}
    end

    local size = 1000 * size_factor
    local k = 1
    while k <= size do
      for row1 = 1, 9 do
        for row2 = row1, 10 do -- note row2 can be == row1, leads to empty ranges being tested when k > size/2
          if k > size then
            break
          end
          local id = put(tree, row1, k, false, row2, size - k, false)
          table.insert(ids, id)
          for i = row1 + 1, row2 do
            table.insert(at_row[i], id)
          end
          --if tree[0].root.level == 4 then error("kk"..k) end
          if k % 100 * size_factor == 1 or (k < 2000 and k % 100 == 1) then
            check_intersections(tree)
          end
          k = k + 1
        end
      end
    end

    eq(2 * size, tree[0].n_keys)
    ok(tree[0].root.level >= 3)
    check_intersections(tree)

    local iter = ffi.new('MarkTreeIter[1]')
    local pair = ffi.new('MTPair[1]')
    for i = 1, 10 do
      -- use array as set and not {[id]=true} map, to detect duplicates
      local set = {}
      eq(true, ffi.C.marktree_itr_get_overlap(tree, i, 0, iter))
      while ffi.C.marktree_itr_step_overlap(tree, iter, pair) do
        local id = tonumber(pair[0].start.id)
        table.insert(set, id)
      end
      table.sort(set)
      eq(at_row[i], set)
    end

    k = 0
    for i = 1, 100 do
      for j = 1, (10 * size_factor) do
        k = k + 1
        local ival = (j - 1) * 100 + i
        lib.marktree_del_pair_test(tree, ns, ids[ival])
        -- just a few stickprov, if there is trouble we need to check
        -- everyone using the code in the "big tree" case above
        if k % 100 * size_factor == 0 or (k > 3000 and k % 200 == 0) then
          check_intersections(tree)
        end
      end
    end

    eq(0, tree[0].n_keys)
  end)

  itp('works with intersections with a even bigger tree and splice', function()
    local tree = ffi.new('MarkTree[1]') -- zero initialized by luajit

    -- too much overhead on ASAN
    local size_factor = t.is_asan() and 3 or 10

    local at_row = {}
    for i = 1, 10 do
      at_row[i] = {}
    end

    local size = 1000 * size_factor
    local k = 1
    while k <= size do
      for row1 = 1, 9 do
        for row2 = row1, 10 do -- note row2 can be == row1, leads to empty ranges being tested when k > size/2
          if k > size then
            break
          end
          local id = put(tree, row1, k, false, row2, size - k, false)
          for i = row1 + 1, row2 do
            table.insert(at_row[i], id)
          end
          --if tree[0].root.level == 4 then error("kk"..k) end
          if k % 100 * size_factor == 1 or (k < 2000 and k % 100 == 1) then
            check_intersections(tree)
          end
          k = k + 1
        end
      end
    end

    eq(2 * size, tree[0].n_keys)
    ok(tree[0].root.level >= 3)
    check_intersections(tree)

    for _ = 1, 10 do
      for j = 3, 8 do
        lib.marktree_splice(tree, j, 0, 0, 200, 0, 0)
        check_intersections(tree)
      end
    end
  end)

  itp('works with meta counts', function()
    local tree = ffi.new('MarkTree[1]') -- zero initialized by luajit

    -- add
    local shadow = {}
    for i = 1, 100 do
      for j = 1, 100 do
        local gravitate = (i % 2) > 0
        local inline = (j == 3 or j == 50 or j == 51 or j == 55) and i % 11 == 1
        inline = inline or ((j >= 80 and j < 85) and i % 3 == 1)
        local id = put_meta(tree, j, i, gravitate, inline)
        if inline then
          shadow[id] = { j, i, gravitate }
        end
      end
      -- checking every insert is too slow, but this is ok
      lib.marktree_check(tree)
    end

    lib.marktree_check(tree)
    local iter = ffi.new('MarkTreeIter[1]')
    local filter = ffi.new('uint32_t[4]')
    filter[0] = -1ULL
    ok(lib.marktree_itr_get_filter(tree, 0, 0, 101, 0, filter, iter))
    local seen = {}
    repeat
      local mark = lib.marktree_itr_current(iter)
      eq(nil, seen[mark.id])
      seen[mark.id] = true
      eq(mark.pos.row, shadow[mark.id][1])
      eq(mark.pos.col, shadow[mark.id][2])
    until not lib.marktree_itr_next_filter(tree, iter, 101, 0, filter)
    eq(tablelength(seen), tablelength(shadow))

    -- test skipping subtrees to find the filtered mark at line 50
    for i = 4, 50 do
      ok(lib.marktree_itr_get_filter(tree, i, 0, 60, 0, filter, iter))
      local mark = lib.marktree_itr_current(iter)
      eq({ 50, 50, 1 }, { mark.id, mark.pos.row, mark.pos.col })
    end

    -- delete
    for id = 1, 10000, 2 do
      lib.marktree_lookup_ns(tree, ns, id, false, iter)
      if shadow[id] then
        local mark = lib.marktree_itr_current(iter)
        eq(mark.pos.row, shadow[id][1])
        eq(mark.pos.col, shadow[id][2])
        shadow[id] = nil
      end
      lib.marktree_del_itr(tree, iter, false)
      if id % 100 == 1 then
        lib.marktree_check(tree)
      end
    end

    -- Splice!
    dosplice(tree, shadow, { 82, 0 }, { 0, 50 }, { 0, 0 })
    lib.marktree_check(tree)

    dosplice(tree, shadow, { 81, 50 }, { 2, 50 }, { 1, 0 })
    lib.marktree_check(tree)

    dosplice(tree, shadow, { 2, 50 }, { 1, 50 }, { 0, 10 })
    lib.marktree_check(tree)

    ok(lib.marktree_itr_get_filter(tree, 0, 0, 101, 0, filter, iter))
    seen = {}
    repeat
      local mark = lib.marktree_itr_current(iter)
      eq(nil, seen[mark.id])
      seen[mark.id] = true
      eq(mark.pos.row, shadow[mark.id][1])
      eq(mark.pos.col, shadow[mark.id][2])
    until not lib.marktree_itr_next_filter(tree, iter, 101, 0, filter)
    eq(tablelength(seen), tablelength(shadow))
  end)
end)
