-- Test for benchmarking list implementation.

local helpers = require('test.functional.helpers')(after_each)

local funcs = helpers.funcs
local meths = helpers.meths
local clear = helpers.clear
local command = helpers.command
local write_file = helpers.write_file

local result_file = 'Xtest-benchmark-list'

describe('Lists implementation', function()
  -- The test cases rely on a temporary result file, which we prepare and write
  -- to disk.
  setup(function()
    write_file(result_file,
               '################ Benchmark results: ################\n')
  end)

  -- At the end of the test run we just print the contents of the result file
  -- for human inspection and promptly delete the file.
  teardown(function()
    for line in io.lines(result_file) do
      print(line)
    end
    os.remove(result_file)
  end)

  before_each(clear)

  local function get_i_list(num_items, elem)
    local list = {}
    for i = 1, num_items do
      list[i] = elem or i
    end
    return list
  end

  local function test_list_map(msg, setup_cmd, expr, num_items, num_ll_items,
                               file_msg)
    local list = get_i_list(num_items)
    local long_list = get_i_list(num_ll_items, 0)

    it(msg:format(num_items), function()
      meths.set_var('l', list)
      meths.set_var('ll', long_list)
      command(([[
        %s
        let st = reltime()
        call map(ll, %s)
        let et = reltime(st)
        let dur = reltimestr(et)
      ]]):format(setup_cmd, funcs.string(expr)))
      write_file(
        result_file, file_msg:format(num_items, meths.get_var('dur')),
        true, true)
    end)
  end

  -- Note: llc list present in some benchmarks is normally present solely for
  -- the purpose of holding references to tested lists to prevent both freeing
  -- those lists and making temporary lists.

  local function test_list_alloc(num_items)
    test_list_map('allocates lists with %u items', '', 'copy(l)', num_items,
                  100000, 'alloc %5u: %s\n')
  end

  local function test_list_append(num_items)
    test_list_map('appends to lists with %u items', 'call map(ll, "copy(l)")',
                  'add(v:val, 0)', num_items,
                  100000, '1->$  %5u: %s\n')
  end

  local function test_list_pop(num_items)
    if num_items < 1 then
      return
    end
    test_list_map('pops from a list with %u items',
                  'call map(ll, "copy(l)")|let llc=copy(ll)',
                  'remove(v:val, -1)',
                  num_items,
                  100000, '1<-$  %5u: %s\n')
  end

  local function test_list_insert(num_items)
    test_list_map('inserts to the start of the list with %u items',
                  'call map(ll, "copy(l)")',
                  'insert(v:val, 0)',
                  num_items,
                  100000, '1->^  %5u: %s\n')
  end

  local function test_list_remove(num_items)
    if num_items < 1 then
      return
    end
    test_list_map('removes from the start of a list with %u items',
                  'call map(ll, "copy(l)")|let llc=copy(ll)',
                  'remove(v:val, 0)',
                  num_items,
                  100000, '1<-^  %5u: %s\n')
  end

  local function test_list_insert_middle(num_items)
    if num_items < 2 then
      return
    end
    test_list_map('inserts to the middle of the list with %u items',
                  'call map(ll, "copy(l)")',
                  ('insert(v:val, 0, %u)'):format(num_items / 2),
                  num_items,
                  100000, '1->/2 %5u: %s\n')
  end

  local function test_list_pop_17(num_items)
    if num_items < 17 then
      return
    end
    test_list_map('pops 17 elements from a list with %u elements',
                  'call map(ll, "copy(l)")|let llc=copy(ll)',
                  'remove(v:val, -17, -1)',
                  num_items,
                  100000, '17<-$ %5u: %s\n')
  end

  local function test_list_remove_17(num_items)
    if num_items < 17 then
      return
    end
    test_list_map('pops 17 elements from a list with %u elements',
                  'call map(ll, "copy(l)")|let llc=copy(ll)',
                  'remove(v:val, 0, 16)',
                  num_items,
                  100000, '17<-^ %5u: %s\n')
  end

  local function test_list_double(num_items)
    test_list_map('extends %u-element list with itself',
                  'call map(ll, "copy(l)")',
                  'extend(v:val, v:val)',
                  num_items,
                  100000, 'l->l  %5u: %s\n')
  end

  local function test_list_double_dup(num_items)
    test_list_map('extends %u-element list with copy of itself',
                  'call map(ll, "copy(l)")|let llc=deepcopy(ll)',
                  'extend(v:val, llc[v:key])',
                  num_items,
                  100000, 'm->l  %5u: %s\n')
  end

  local function test_list_dealloc(num_items)
    test_list_map('drops a list with %u items',
                  'call map(ll, "copy(l)")',
                  '0',
                  num_items,
                  100000,
                  '  -l- %5u: %s\n')
  end

  local function test_list_index_start(num_items)
    if num_items < 1 then
      return
    end
    test_list_map('indexes start of a list with %u items',
                  'call map(ll, "copy(l)")|let llc=copy(ll)',
                  'v:val[0]',
                  num_items,
                  100000,
                  'l[0]  %5u: %s\n')
  end

  local function test_list_index_end(num_items)
    if num_items < 1 then
      return
    end
    test_list_map('indexes end of a list with %u items',
                  'call map(ll, "copy(l)")|let llc=copy(ll)',
                  'v:val[-1]',
                  num_items,
                  100000,
                  'l[$]  %5u: %s\n')
  end

  local function test_list_index_middle(num_items)
    if num_items < 1 then
      return
    end
    test_list_map('indexes middle of a list with %u items',
                  'call map(ll, "copy(l)")|let llc=copy(ll)',
                  ('v:val[%u]'):format(num_items/2),
                  num_items,
                  100000,
                  'l[/2] %5u: %s\n')
  end

  local function test_list_iter(num_items)
    test_list_map('map()s list with %u items',
                  'call map(ll, "copy(l)")',
                  'map(v:val, "v:key")',
                  num_items,
                  100000,
                  '*l    %5u: %s\n')
  end

  local function test_list_iter(num_items)
    test_list_map('map()s list with %u items using builtin function',
                  'call map(ll, "copy(l)")|let F=function("and")',
                  'map(v:val, F)',
                  num_items,
                  100000,
                  'e*l   %5u: %s\n')
  end

  local function test_list_iter_far(num_items)
    test_list_map('map()s list with far away %u items using builtin function',
                  [[
                    call map(ll, "[]")
                    call map(l, "map(ll, 'add(v:val, '.string(v:val).')')")
                    let F=function("and")
                  ]],
                  'map(v:val, F)',
                  num_items,
                  100000,
                  'e*lx  %5u: %s\n')
  end

  local function test_list_filter(num_items)
    test_list_map('filter()s out all elements of list with %u items',
                  'call map(ll, "copy(l)")',
                  'filter(v:val, "v:false")',
                  num_items,
                  100000,
                  '*?l   %5u: %s\n')
  end

  local function test_list_num_sort(num_items)
    test_list_map('sort(,"n")s all elements of list with %u items',
                  'call map(ll, "copy(l)")',
                  'sort(v:val, "n")',
                  num_items,
                  100000,
                  'n>(l) %5u: %s\n')
  end

  for _, f in ipairs({
    test_list_alloc,
    test_list_append,
    test_list_insert,
    test_list_insert_middle,
    test_list_pop,
    test_list_remove,
    test_list_pop_17,
    test_list_remove_17,
    test_list_double,
    test_list_double_dup,
    test_list_dealloc,
    test_list_index_start,
    test_list_index_end,
    test_list_index_middle,
    test_list_iter,
    test_list_iter_far,
    test_list_filter,
    test_list_num_sort,
  }) do
    for _, n in ipairs({
      0,
      1,
      2,
      3,
      4,
      5,
      7,
      8,
      9,
      15,
      16,
      17,
      18,
      127,
      128,
      129,
      255,
      256,
      257,
    }) do
      f(n)
    end
  end

end)
