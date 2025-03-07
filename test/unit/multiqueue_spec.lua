local t = require('test.unit.testutil')
local itp = t.gen_itp(it)

local child_call_once = t.child_call_once
local cimport = t.cimport
local ffi = t.ffi
local eq = t.eq

local multiqueue = cimport('./test/unit/fixtures/multiqueue.h')

describe('multiqueue (multi-level event-queue)', function()
  local parent, child1, child2, child3

  local function put(q, str)
    multiqueue.ut_multiqueue_put(q, str)
  end

  local function get(q)
    return ffi.string(multiqueue.ut_multiqueue_get(q))
  end

  local function free(q)
    multiqueue.multiqueue_free(q)
  end

  before_each(function()
    child_call_once(function()
      parent = multiqueue.multiqueue_new(ffi.NULL, ffi.NULL)
      child1 = multiqueue.multiqueue_new_child(parent)
      child2 = multiqueue.multiqueue_new_child(parent)
      child3 = multiqueue.multiqueue_new_child(parent)
      put(child1, 'c1i1')
      put(child1, 'c1i2')
      put(child2, 'c2i1')
      put(child1, 'c1i3')
      put(child2, 'c2i2')
      put(child2, 'c2i3')
      put(child2, 'c2i4')
      put(child3, 'c3i1')
      put(child3, 'c3i2')
    end)
  end)

  itp('keeps count of added events', function()
    eq(3, multiqueue.multiqueue_size(child1))
    eq(4, multiqueue.multiqueue_size(child2))
    eq(2, multiqueue.multiqueue_size(child3))
  end)

  itp('keeps count of removed events', function()
    multiqueue.multiqueue_get(child1)
    eq(2, multiqueue.multiqueue_size(child1))
    multiqueue.multiqueue_get(child1)
    eq(1, multiqueue.multiqueue_size(child1))
    multiqueue.multiqueue_get(child1)
    eq(0, multiqueue.multiqueue_size(child1))
    put(child1, 'c2ixx')
    eq(1, multiqueue.multiqueue_size(child1))
    multiqueue.multiqueue_get(child1)
    eq(0, multiqueue.multiqueue_size(child1))
    multiqueue.multiqueue_get(child1)
    eq(0, multiqueue.multiqueue_size(child1))
  end)

  itp('removing from parent removes from child', function()
    eq('c1i1', get(parent))
    eq('c1i2', get(parent))
    eq('c2i1', get(parent))
    eq('c1i3', get(parent))
    eq('c2i2', get(parent))
    eq('c2i3', get(parent))
    eq('c2i4', get(parent))
  end)

  itp('removing from child removes from parent', function()
    eq('c2i1', get(child2))
    eq('c2i2', get(child2))
    eq('c1i1', get(child1))
    eq('c1i2', get(parent))
    eq('c1i3', get(parent))
    eq('c2i3', get(parent))
    eq('c2i4', get(parent))
  end)

  itp('removing from child at the beginning of parent', function()
    eq('c1i1', get(child1))
    eq('c1i2', get(child1))
    eq('c2i1', get(parent))
  end)

  itp('removing from parent after get from parent and put to child', function()
    eq('c1i1', get(parent))
    eq('c1i2', get(parent))
    eq('c2i1', get(parent))
    eq('c1i3', get(parent))
    eq('c2i2', get(parent))
    eq('c2i3', get(parent))
    eq('c2i4', get(parent))
    eq('c3i1', get(parent))
    put(child1, 'c1i11')
    put(child1, 'c1i22')
    eq('c3i2', get(parent))
    eq('c1i11', get(parent))
    eq('c1i22', get(parent))
  end)

  itp('removing from parent after get and put to child', function()
    eq('c1i1', get(child1))
    eq('c1i2', get(child1))
    eq('c2i1', get(child2))
    eq('c1i3', get(child1))
    eq('c2i2', get(child2))
    eq('c2i3', get(child2))
    eq('c2i4', get(child2))
    eq('c3i1', get(child3))
    eq('c3i2', get(parent))
    put(child1, 'c1i11')
    put(child2, 'c2i11')
    put(child1, 'c1i12')
    eq('c2i11', get(child2))
    eq('c1i11', get(parent))
    eq('c1i12', get(parent))
  end)

  itp('put after removing from child at the end of parent', function()
    eq('c3i1', get(child3))
    eq('c3i2', get(child3))
    put(child1, 'c1i11')
    put(child2, 'c2i11')
    eq('c1i1', get(parent))
    eq('c1i2', get(parent))
    eq('c2i1', get(parent))
    eq('c1i3', get(parent))
    eq('c2i2', get(parent))
    eq('c2i3', get(parent))
    eq('c2i4', get(parent))
    eq('c1i11', get(parent))
    eq('c2i11', get(parent))
  end)

  itp('removes from parent queue when child is freed', function()
    free(child2)
    eq('c1i1', get(parent))
    eq('c1i2', get(parent))
    eq('c1i3', get(parent))
    eq('c3i1', get(child3))
    eq('c3i2', get(child3))
  end)
end)
