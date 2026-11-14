local t = require('test.unit.testutil')
local describe = t.describe
local itp = t.gen_itp(t.it)

local eq = t.eq
local ffi = t.ffi
local cimport = t.cimport
local NULL = t.NULL

if not t.paths.is_numstore then
  describe('nsfile', function()
    t.pending('needs a build with -DENABLE_NUMSTORE=ON', function() end)
  end)
  return
end

local m = cimport('./src/nvim/nsfile.h')

local path = 'Xtest-unit-nsfile.db'

--- Remove the database. Run at the start and end of each test.
local function cleanup()
  m.nsf_cleanup(path)
end

--- Open the database and the u8 variable "text" in it.
local function open()
  local err = ffi.new('char[256]')
  if m.nsf_db_open(path, err, 256) ~= 1 then
    error('nsf_db_open failed: ' .. ffi.string(err))
  end
  local f = m.nsf_open('text', err, 256)
  if f == NULL then
    error('nsf_open failed: ' .. ffi.string(err))
  end
  return f
end

--- Close the variable and the database.
local function close(f)
  m.nsf_close(f)
  m.nsf_db_close()
end

local function errmsg(f)
  return ffi.string(m.nsf_errmsg(f))
end

local function get(f, lnum)
  local len = ffi.new('size_t[1]')
  local p = m.nsf_get(f, lnum, len)
  if p == NULL then
    return nil
  end
  return ffi.string(p, len[0])
end

local function ok(f, ret)
  eq(1, ret, errmsg(f))
end

local function insert(f, after, s)
  ok(f, m.nsf_insert(f, after, s, #s))
end

local function replace(f, lnum, s)
  ok(f, m.nsf_replace(f, lnum, s, #s))
end

local function delete(f, lnum)
  ok(f, m.nsf_delete(f, lnum))
end

local function set_eol(f, eol)
  ok(f, m.nsf_set_eol(f, eol))
end

local function validate(f)
  eq(true, m.nsf_validate(f), errmsg(f))
end

--- All lines of the file, in memory format.
local function lines(f)
  local ret = {}
  for i = 1, m.nsf_line_count(f) do
    ret[i] = get(f, i)
  end
  return ret
end

--- The bytes the file should hold for "ls" (memory format) and "eol".
local function file_bytes(ls, eol)
  if #ls == 0 then
    return ''
  end
  local parts = {}
  for i, l in ipairs(ls) do
    parts[i] = (l:gsub('\n', '\0'))
  end
  local s = table.concat(parts, '\n')
  if eol then
    s = s .. '\n'
  end
  return s
end

--- Check the file against the model "ls" / "eol".
local function check(f, ls, eol)
  validate(f)
  eq(ls, lines(f))
  eq(#ls, m.nsf_line_count(f))
  eq(not eol and #ls > 0, m.nsf_noeol(f))
  local bytes = file_bytes(ls, eol)
  eq(#bytes, tonumber(m.nsf_size(f)))
  -- Line offsets must match the model.
  local off = 0
  for i, l in ipairs(ls) do
    eq(off, tonumber(m.nsf_line_offset(f, i)))
    eq(#l, tonumber(m.nsf_line_len(f, i)))
    if #l > 0 then
      local col = ffi.new('size_t[1]')
      eq(i, m.nsf_offset_line(f, off + #l - 1, col))
      eq(#l - 1, tonumber(col[0]))
    end
    off = off + #l + 1
  end
  eq(#bytes, tonumber(m.nsf_line_offset(f, #ls + 1)))
end

describe('nsfile', function()
  itp('starts empty', function()
    cleanup()
    local f = open()
    check(f, {}, true)
    eq(nil, get(f, 1))
    eq(0, m.nsf_delete(f, 1))
    close(f)
    cleanup()
  end)

  itp('inserts, replaces and deletes lines', function()
    cleanup()
    local f = open()
    insert(f, 0, 'two')
    insert(f, 0, 'one')
    insert(f, 2, 'four')
    insert(f, 2, 'three')
    check(f, { 'one', 'two', 'three', 'four' }, true)

    replace(f, 2, 'TWO') -- same length
    replace(f, 3, 'three-and-a-bit') -- longer, common prefix
    replace(f, 4, 'r') -- shorter, common suffix
    replace(f, 1, '') -- empty
    check(f, { '', 'TWO', 'three-and-a-bit', 'r' }, true)

    delete(f, 1)
    delete(f, 3)
    check(f, { 'TWO', 'three-and-a-bit' }, true)
    delete(f, 1)
    delete(f, 1)
    check(f, {}, true)
    close(f)
    cleanup()
  end)

  itp('keeps changes after close and open', function()
    cleanup()
    local f = open()
    insert(f, 0, 'hello')
    insert(f, 1, 'world')
    replace(f, 1, 'Hello,')
    set_eol(f, false)
    close(f)

    f = open()
    check(f, { 'Hello,', 'world' }, false)
    close(f)
    cleanup()
  end)

  itp('stores NL in memory as NUL in the file', function()
    cleanup()
    local f = open()
    insert(f, 0, 'a\nb')
    check(f, { 'a\nb' }, true)
    replace(f, 1, 'a\n\nb')
    check(f, { 'a\n\nb' }, true)
    close(f)
    cleanup()
  end)

  itp('handles a last line with no newline', function()
    cleanup()
    local f = open()
    insert(f, 0, 'a')
    insert(f, 1, 'b')
    set_eol(f, false)
    check(f, { 'a', 'b' }, false)

    -- Append after a noeol last line: the new line is the noeol one.
    insert(f, 2, 'c')
    check(f, { 'a', 'b', 'c' }, false)

    -- Delete the noeol last line: the line before becomes noeol.
    delete(f, 3)
    check(f, { 'a', 'b' }, false)

    -- An empty last line cannot be noeol: the newline comes back.
    replace(f, 2, '')
    check(f, { 'a', '' }, true)
    set_eol(f, false)
    check(f, { 'a', '' }, true)

    insert(f, 2, 'x')
    set_eol(f, false)
    insert(f, 3, '')
    check(f, { 'a', '', 'x', '' }, true)

    set_eol(f, true)
    replace(f, 4, 'y')
    set_eol(f, false)
    delete(f, 1)
    delete(f, 1)
    delete(f, 1)
    check(f, { 'y' }, false)
    delete(f, 1)
    check(f, {}, true)
    close(f)
    cleanup()
  end)

  itp('handles many lines (chunk split and removal)', function()
    cleanup()
    local f = open()
    local ls = {}
    for i = 1, 2000 do
      local s = 'line ' .. i
      insert(f, i - 1, s)
      ls[i] = s
    end
    -- Insert in the middle to split full chunks.
    for i = 1, 600 do
      local at = (i * 7) % #ls
      local s = 'mid ' .. i
      insert(f, at, s)
      table.insert(ls, at + 1, s)
    end
    check(f, ls, true)
    -- Delete a large block to empty whole chunks.
    for _ = 1, 1500 do
      delete(f, 100)
      table.remove(ls, 100)
    end
    check(f, ls, true)
    close(f)

    f = open()
    check(f, ls, true)
    close(f)
    cleanup()
  end)

  itp('matches a model under random operations', function()
    cleanup()
    math.randomseed(42)
    local alphabet = { 'a', 'b', 'c', '\n', ' ' }
    local function rstr()
      local n = math.random(0, 12)
      local s = {}
      for i = 1, n do
        s[i] = alphabet[math.random(#alphabet)]
      end
      return table.concat(s)
    end

    local f = open()
    local ls = {}
    local eol = true

    local function normalize()
      if #ls == 0 then
        eol = true
      elseif not eol and ls[#ls] == '' then
        eol = true
      end
    end

    for step = 1, 3000 do
      local r = math.random(100)
      if r <= 40 or #ls == 0 then
        local after = math.random(0, #ls)
        local s = rstr()
        insert(f, after, s)
        table.insert(ls, after + 1, s)
      elseif r <= 70 then
        local lnum = math.random(#ls)
        -- Often change only a part of the line, as typing does.
        local old = ls[lnum]
        local s
        if math.random(2) == 1 and #old > 0 then
          local p = math.random(0, #old)
          s = old:sub(1, p) .. rstr() .. old:sub(p + 1 + math.random(0, 2))
        else
          s = rstr()
        end
        replace(f, lnum, s)
        ls[lnum] = s
      elseif r <= 95 then
        local lnum = math.random(#ls)
        delete(f, lnum)
        table.remove(ls, lnum)
      else
        local want = math.random(2) == 1
        set_eol(f, want)
        if #ls > 0 and not (not want and ls[#ls] == '') then
          eol = want
        end
      end
      normalize()

      if step % 50 == 0 then
        check(f, ls, eol)
      else
        validate(f)
      end
      if step % 500 == 0 then
        close(f)
        f = open()
        check(f, ls, eol)
      end
    end
    close(f)
    cleanup()
  end)

  itp('commits and rolls back transactions', function()
    cleanup()
    local f = open()
    insert(f, 0, 'base')
    ok(f, m.nsf_begin(f))
    eq(true, m.nsf_in_txn(f))
    insert(f, 1, 'gone')
    replace(f, 1, 'changed')
    check(f, { 'changed', 'gone' }, true)
    ok(f, m.nsf_rollback(f))
    eq(false, m.nsf_in_txn(f))
    check(f, { 'base' }, true)

    ok(f, m.nsf_begin(f))
    insert(f, 1, 'kept')
    ok(f, m.nsf_commit(f))
    close(f)
    f = open()
    check(f, { 'base', 'kept' }, true)

    -- Close with an open transaction commits it.
    ok(f, m.nsf_begin(f))
    delete(f, 1)
    close(f)
    f = open()
    check(f, { 'kept' }, true)
    close(f)
    cleanup()
  end)

  itp('replace() accepts the buffer returned by get()', function()
    cleanup()
    local f = open()
    insert(f, 0, 'abcdef')
    local len = ffi.new('size_t[1]')
    local p = m.nsf_get(f, 1, len)
    p[2] = string.byte('X') -- change the cached line in place
    ok(f, m.nsf_replace(f, 1, p, len[0]))
    check(f, { 'abXdef' }, true)
    close(f)
    cleanup()
  end)

  itp('keeps variables apart in one database', function()
    cleanup()
    local f = open()
    local err = ffi.new('char[256]')
    local g = m.nsf_open('other', err, 256)
    eq(false, g == NULL, ffi.string(err))
    insert(f, 0, 'in text')
    insert(g, 0, 'in other')
    check(f, { 'in text' }, true)
    check(g, { 'in other' }, true)

    -- A change of "g" commits the transaction of "f" first: a rollback of
    -- "f" then has nothing to drop.
    ok(f, m.nsf_begin(f))
    ok(g, m.nsf_begin(g))
    insert(f, 1, 'f kept')
    insert(g, 1, 'g dropped')
    ok(g, m.nsf_rollback(g))
    ok(f, m.nsf_rollback(f))
    check(f, { 'in text', 'f kept' }, true)
    check(g, { 'in other' }, true)
    m.nsf_close(g)
    close(f)
    cleanup()
  end)

  itp('refuses a variable that is not u8 or has a bad name', function()
    cleanup()
    local f = open()
    local err = ffi.new('char[256]')
    eq(true, m.nsf_open('a.b', err, 256) == NULL)
    eq(true, ffi.string(err):find('create') ~= nil)
    close(f)
    cleanup()
  end)
end)
