local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local request = helpers.request
local eq = helpers.eq
local ok = helpers.ok
local curbufmeths = helpers.curbufmeths
local pcall_err = helpers.pcall_err
local insert = helpers.insert
local feed = helpers.feed
local clear = helpers.clear
local command = helpers.command

local function check_undo_redo(ns, mark, sr, sc, er, ec) --s = start, e = end
  local rv = curbufmeths.get_extmark_by_id(ns, mark)
  eq({er, ec}, rv)
  feed("u")
  rv = curbufmeths.get_extmark_by_id(ns, mark)
  eq({sr, sc}, rv)
  feed("<c-r>")
  rv = curbufmeths.get_extmark_by_id(ns, mark)
  eq({er, ec}, rv)
end

local function set_extmark(ns_id, id, line, col, opts)
  if opts == nil then
    opts = {}
  end
  return curbufmeths.set_extmark(ns_id, id, line, col, opts)
end

local function get_extmarks(ns_id, start, end_, opts)
  if opts == nil then
    opts = {}
  end
  return curbufmeths.get_extmarks(ns_id, start, end_, opts)
end

describe('Extmarks buffer api', function()
  local screen
  local marks, positions, ns_string2, ns_string, init_text, row, col
  local ns, ns2

  before_each(function()
    -- Initialize some namespaces and insert 12345 into a buffer
    marks = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
    positions = {{0, 0,}, {0, 2}, {0, 3}}

    ns_string = "my-fancy-plugin"
    ns_string2 = "my-fancy-plugin2"
    init_text = "12345"
    row = 0
    col = 2

    clear()
    screen = Screen.new(15, 10)
    screen:attach()

    insert(init_text)
    ns = request('nvim_create_namespace', ns_string)
    ns2 = request('nvim_create_namespace', ns_string2)
  end)

  it('adds, updates  and deletes marks #extmarks', function()
    local rv = set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    eq(marks[1], rv)
    rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({positions[1][1], positions[1][2]}, rv)
    -- Test adding a second mark on same row works
    rv = set_extmark(ns, marks[2], positions[2][1], positions[2][2])
    eq(marks[2], rv)

    -- Test an update, (same pos)
    rv = set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    eq(marks[1], rv)
    rv = curbufmeths.get_extmark_by_id(ns, marks[2])
    eq({positions[2][1], positions[2][2]}, rv)
    -- Test an update, (new pos)
    row = positions[1][1]
    col = positions[1][2] + 1
    rv = set_extmark(ns, marks[1], row, col)
    eq(marks[1], rv)
    rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({row, col}, rv)

    -- remove the test marks
    eq(true, curbufmeths.del_extmark(ns, marks[1]))
    eq(false, curbufmeths.del_extmark(ns, marks[1]))
    eq(true, curbufmeths.del_extmark(ns, marks[2]))
    eq(false, curbufmeths.del_extmark(ns, marks[3]))
    eq(false, curbufmeths.del_extmark(ns, 1000))
  end)

  it('can clear a specific namespace range #extmarks', function()
    set_extmark(ns, 1, 0, 1)
    set_extmark(ns2, 1, 0, 1)
    -- force a new undo buffer
    feed('o<esc>')
    curbufmeths.clear_namespace(ns2, 0, -1)
    eq({{1, 0, 1}}, get_extmarks(ns, {0, 0}, {-1, -1}))
    eq({}, get_extmarks(ns2, {0, 0}, {-1, -1}))
    feed('u')
    eq({{1, 0, 1}}, get_extmarks(ns, {0, 0}, {-1, -1}))
    eq({{1, 0, 1}}, get_extmarks(ns2, {0, 0}, {-1, -1}))
    feed('<c-r>')
    eq({{1, 0, 1}}, get_extmarks(ns, {0, 0}, {-1, -1}))
    eq({}, get_extmarks(ns2, {0, 0}, {-1, -1}))
  end)

  it('can clear a namespace range using 0,-1 #extmarks', function()
    set_extmark(ns, 1, 0, 1)
    set_extmark(ns2, 1, 0, 1)
    -- force a new undo buffer
    feed('o<esc>')
    curbufmeths.clear_namespace(-1, 0, -1)
    eq({}, get_extmarks(ns, {0, 0}, {-1, -1}))
    eq({}, get_extmarks(ns2, {0, 0}, {-1, -1}))
    feed('u')
    eq({{1, 0, 1}}, get_extmarks(ns, {0, 0}, {-1, -1}))
    eq({{1, 0, 1}}, get_extmarks(ns2, {0, 0}, {-1, -1}))
    feed('<c-r>')
    eq({}, get_extmarks(ns, {0, 0}, {-1, -1}))
    eq({}, get_extmarks(ns2, {0, 0}, {-1, -1}))
  end)

  it('querying for information and ranges #extmarks', function()
    -- add some more marks
    for i, m in ipairs(marks) do
      if positions[i] ~= nil then
        local rv = set_extmark(ns, m, positions[i][1], positions[i][2])
        eq(m, rv)
      end
    end

    -- {0, 0} and {-1, -1} work as extreme values
    eq({{1, 0, 0}}, get_extmarks(ns, {0, 0}, {0, 0}))
    eq({}, get_extmarks(ns, {-1, -1}, {-1, -1}))
    local rv = get_extmarks(ns, {0, 0}, {-1, -1})
    for i, m in ipairs(marks) do
      if positions[i] ~= nil then
        eq({m, positions[i][1], positions[i][2]}, rv[i])
      end
    end

    -- 0 and -1 works as short hand extreme values
    eq({{1, 0, 0}}, get_extmarks(ns, 0, 0))
    eq({}, get_extmarks(ns, -1, -1))
    rv = get_extmarks(ns, 0, -1)
    for i, m in ipairs(marks) do
      if positions[i] ~= nil then
        eq({m, positions[i][1], positions[i][2]}, rv[i])
      end
    end

    -- next with mark id
    rv = get_extmarks(ns, marks[1], {-1, -1}, {amount=1})
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)
    rv = get_extmarks(ns, marks[2], {-1, -1}, {amount=1})
    eq({{marks[2], positions[2][1], positions[2][2]}}, rv)
    -- next with positional when mark exists at position
    rv = get_extmarks(ns, positions[1], {-1, -1}, {amount=1})
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)
    -- next with positional index (no mark at position)
    rv = get_extmarks(ns, {positions[1][1], positions[1][2] +1}, {-1, -1}, {amount=1})
    eq({{marks[2], positions[2][1], positions[2][2]}}, rv)
    -- next with Extremity index
    rv = get_extmarks(ns, {0,0}, {-1, -1}, {amount=1})
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)

    -- nextrange with mark id
    rv = get_extmarks(ns, marks[1], marks[3])
    eq({marks[1], positions[1][1], positions[1][2]}, rv[1])
    eq({marks[2], positions[2][1], positions[2][2]}, rv[2])
    -- nextrange with amount
    rv = get_extmarks(ns, marks[1], marks[3], {amount=2})
    eq(2, table.getn(rv))
    -- nextrange with positional when mark exists at position
    rv = get_extmarks(ns, positions[1], positions[3])
    eq({marks[1], positions[1][1], positions[1][2]}, rv[1])
    eq({marks[2], positions[2][1], positions[2][2]}, rv[2])
    rv = get_extmarks(ns, positions[2], positions[3])
    eq(2, table.getn(rv))
    -- nextrange with positional index (no mark at position)
    local lower = {positions[1][1], positions[2][2] -1}
    local upper = {positions[2][1], positions[3][2] - 1}
    rv = get_extmarks(ns, lower, upper)
    eq({{marks[2], positions[2][1], positions[2][2]}}, rv)
    lower = {positions[3][1], positions[3][2] + 1}
    upper = {positions[3][1], positions[3][2] + 2}
    rv = get_extmarks(ns, lower, upper)
    eq({}, rv)
    -- nextrange with extremity index
    lower = {positions[2][1], positions[2][2]+1}
    upper = {-1, -1}
    rv = get_extmarks(ns, lower, upper)
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)

    -- prev with mark id
    rv = get_extmarks(ns, marks[3], {0, 0}, {amount=1})
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)
    rv = get_extmarks(ns, marks[2], {0, 0}, {amount=1})
    eq({{marks[2], positions[2][1], positions[2][2]}}, rv)
    -- prev with positional when mark exists at position
    rv = get_extmarks(ns, positions[3], {0, 0}, {amount=1})
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)
    -- prev with positional index (no mark at position)
    rv = get_extmarks(ns, {positions[1][1], positions[1][2] +1}, {0, 0}, {amount=1})
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)
    -- prev with Extremity index
    rv = get_extmarks(ns, {-1,-1}, {0,0}, {amount=1})
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)

    -- prevrange with mark id
    rv = get_extmarks(ns, marks[3], marks[1])
    eq({marks[3], positions[3][1], positions[3][2]}, rv[1])
    eq({marks[2], positions[2][1], positions[2][2]}, rv[2])
    eq({marks[1], positions[1][1], positions[1][2]}, rv[3])
    -- prevrange with amount
    rv = get_extmarks(ns, marks[3], marks[1], {amount=2})
    eq(2, table.getn(rv))
    -- prevrange with positional when mark exists at position
    rv = get_extmarks(ns, positions[3], positions[1])
    eq({{marks[3], positions[3][1], positions[3][2]},
        {marks[2], positions[2][1], positions[2][2]},
        {marks[1], positions[1][1], positions[1][2]}}, rv)
    rv = get_extmarks(ns, positions[2], positions[1])
    eq(2, table.getn(rv))
    -- prevrange with positional index (no mark at position)
    lower = {positions[2][1], positions[2][2] + 1}
    upper = {positions[3][1], positions[3][2] + 1}
    rv = get_extmarks(ns, upper, lower)
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)
    lower = {positions[3][1], positions[3][2] + 1}
    upper = {positions[3][1], positions[3][2] + 2}
    rv = get_extmarks(ns, upper, lower)
    eq({}, rv)
    -- prevrange with extremity index
    lower = {0,0}
    upper = {positions[2][1], positions[2][2] - 1}
    rv = get_extmarks(ns, upper, lower)
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)
  end)

  it('querying for information with amount #extmarks', function()
    -- add some more marks
    for i, m in ipairs(marks) do
      if positions[i] ~= nil then
        local rv = set_extmark(ns, m, positions[i][1], positions[i][2])
        eq(m, rv)
      end
    end

    local rv = get_extmarks(ns, {0, 0}, {-1, -1}, {amount=1})
    eq(1, table.getn(rv))
    rv = get_extmarks(ns, {0, 0}, {-1, -1}, {amount=2})
    eq(2, table.getn(rv))
    rv = get_extmarks(ns, {0, 0}, {-1, -1}, {amount=3})
    eq(3, table.getn(rv))

    -- now in reverse
    rv = get_extmarks(ns, {0, 0}, {-1, -1}, {amount=1})
    eq(1, table.getn(rv))
    rv = get_extmarks(ns, {0, 0}, {-1, -1}, {amount=2})
    eq(2, table.getn(rv))
    rv = get_extmarks(ns, {0, 0}, {-1, -1}, {amount=3})
    eq(3, table.getn(rv))
  end)

  it('get_marks works when mark col > upper col #extmarks', function()
    feed('A<cr>12345<esc>')
    feed('A<cr>12345<esc>')
    set_extmark(ns, 10, 0, 2)       -- this shouldn't be found
    set_extmark(ns, 11, 2, 1)       -- this shouldn't be found
    set_extmark(ns, marks[1], 0, 4) -- check col > our upper bound
    set_extmark(ns, marks[2], 1, 1) -- check col < lower bound
    set_extmark(ns, marks[3], 2, 0) -- check is inclusive
    eq({{marks[1], 0, 4},
        {marks[2], 1, 1},
        {marks[3], 2, 0}},
       get_extmarks(ns, {0, 3}, {2, 0}))
  end)

  it('get_marks works in reverse when mark col < lower col #extmarks', function()
    feed('A<cr>12345<esc>')
    feed('A<cr>12345<esc>')
    set_extmark(ns, 10, 0, 1) -- this shouldn't be found
    set_extmark(ns, 11, 2, 4) -- this shouldn't be found
    set_extmark(ns, marks[1], 2, 1) -- check col < our lower bound
    set_extmark(ns, marks[2], 1, 4) -- check col > upper bound
    set_extmark(ns, marks[3], 0, 2) -- check is inclusive
    local rv = get_extmarks(ns, {2, 3}, {0, 2})
    eq({{marks[1], 2, 1},
        {marks[2], 1, 4},
        {marks[3], 0, 2}},
       rv)
  end)

  it('get_marks amount 0 returns nothing #extmarks', function()
    set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    local rv = get_extmarks(ns, {-1, -1}, {-1, -1}, {amount=0})
    eq({}, rv)
  end)


  it('marks move with line insertations #extmarks', function()
    set_extmark(ns, marks[1], 0, 0)
    feed("yyP")
    check_undo_redo(ns, marks[1], 0, 0, 1, 0)
  end)

  it('marks move with multiline insertations #extmarks', function()
    feed("a<cr>22<cr>33<esc>")
    set_extmark(ns, marks[1], 1, 1)
    feed('ggVGyP')
    check_undo_redo(ns, marks[1], 1, 1, 4, 1)
  end)

  it('marks move with line join #extmarks', function()
    -- do_join in ops.c
    feed("a<cr>222<esc>")
    set_extmark(ns, marks[1], 1, 0)
    feed('ggJ')
    check_undo_redo(ns, marks[1], 1, 0, 0, 6)
  end)

  it('join works when no marks are present #extmarks', function()
    feed("a<cr>1<esc>")
    feed('kJ')
    -- This shouldn't seg fault
    screen:expect([[
      12345^ 1        |
      ~              |
      ~              |
      ~              |
      ~              |
      ~              |
      ~              |
      ~              |
      ~              |
                     |
    ]])
  end)

  it('marks move with multiline join #extmarks', function()
    -- do_join in ops.c
    feed("a<cr>222<cr>333<cr>444<esc>")
    set_extmark(ns, marks[1], 3, 0)
    feed('2GVGJ')
    check_undo_redo(ns, marks[1], 3, 0, 1, 8)
  end)

  it('marks move with line deletes #extmarks', function()
    feed("a<cr>222<cr>333<cr>444<esc>")
    set_extmark(ns, marks[1], 2, 1)
    feed('ggjdd')
    check_undo_redo(ns, marks[1], 2, 1, 1, 1)
  end)

  it('marks move with multiline deletes #extmarks', function()
    feed("a<cr>222<cr>333<cr>444<esc>")
    set_extmark(ns, marks[1], 3, 0)
    feed('gg2dd')
    check_undo_redo(ns, marks[1], 3, 0, 1, 0)
    -- regression test, undoing multiline delete when mark is on row 1
    feed('ugg3dd')
    check_undo_redo(ns, marks[1], 3, 0, 0, 0)
  end)

  it('marks move with open line #extmarks', function()
    -- open_line in misc1.c
    -- testing marks below are also moved
    feed("yyP")
    set_extmark(ns, marks[1], 0, 4)
    set_extmark(ns, marks[2], 1, 4)
    feed('1G<s-o><esc>')
    check_undo_redo(ns, marks[1], 0, 4, 1, 4)
    check_undo_redo(ns, marks[2], 1, 4, 2, 4)
    feed('2Go<esc>')
    check_undo_redo(ns, marks[1], 1, 4, 1, 4)
    check_undo_redo(ns, marks[2], 2, 4, 3, 4)
  end)

  it('marks move with char inserts #extmarks', function()
    -- insertchar in edit.c (the ins_str branch)
    set_extmark(ns, marks[1], 0, 3)
    feed('0')
    insert('abc')
    screen:expect([[
      ab^c12345       |
      ~              |
      ~              |
      ~              |
      ~              |
      ~              |
      ~              |
      ~              |
      ~              |
                     |
    ]])
    local rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({0, 6}, rv)
    -- check_undo_redo(ns, marks[1], 0, 2, 0, 5)
  end)

  -- gravity right as definted in tk library
  it('marks have gravity right #extmarks', function()
    -- insertchar in edit.c (the ins_str branch)
    set_extmark(ns, marks[1], 0, 2)
    feed('03l')
    insert("X")
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)

    -- check multibyte chars
    feed('03l<esc>')
    insert("～～")
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
  end)

  it('we can insert multibyte chars #extmarks', function()
    -- insertchar in edit.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 2)
    -- Insert a fullwidth (two col) tilde, NICE
    feed('0i～<esc>')
    check_undo_redo(ns, marks[1], 1, 2, 1, 3)
  end)

  it('marks move with blockwise inserts #extmarks', function()
    -- op_insert in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 2)
    feed('0<c-v>lkI9<esc>')
    check_undo_redo(ns, marks[1], 1, 2, 1, 3)
  end)

  it('marks move with line splits (using enter) #extmarks', function()
    -- open_line in misc1.c
    -- testing marks below are also moved
    feed("yyP")
    set_extmark(ns, marks[1], 0, 4)
    set_extmark(ns, marks[2], 1, 4)
    feed('1Gla<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 4, 1, 2)
    check_undo_redo(ns, marks[2], 1, 4, 2, 4)
  end)

  it('marks at last line move on insert new line #extmarks', function()
    -- open_line in misc1.c
    set_extmark(ns, marks[1], 0, 4)
    feed('0i<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 4, 1, 4)
  end)

  it('yet again marks move with line splits #extmarks', function()
    -- the first test above wasn't catching all errors..
    feed("A67890<esc>")
    set_extmark(ns, marks[1], 0, 4)
    feed("04li<cr><esc>")
    check_undo_redo(ns, marks[1], 0, 4, 1, 0)
  end)

  it('and one last time line splits... #extmarks', function()
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 2)
    feed("02li<cr><esc>")
    check_undo_redo(ns, marks[1], 0, 1, 0, 1)
    check_undo_redo(ns, marks[2], 0, 2, 1, 0)
  end)

  it('multiple marks move with mark splits #extmarks', function()
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 3)
    feed("0li<cr><esc>")
    check_undo_redo(ns, marks[1], 0, 1, 1, 0)
    check_undo_redo(ns, marks[2], 0, 3, 1, 2)
  end)

  it('deleting on a mark works #extmarks', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 2)
    feed('02lx')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
  end)

  it('marks move with char deletes #extmarks', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 2)
    feed('02dl')
    check_undo_redo(ns, marks[1], 0, 2, 0, 0)
    -- from the other side (nothing should happen)
    feed('$x')
    check_undo_redo(ns, marks[1], 0, 0, 0, 0)
  end)

  it('marks move with char deletes over a range #extmarks', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    feed('0l3dl<esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 1)
    check_undo_redo(ns, marks[2], 0, 3, 0, 1)
    -- delete 1, nothing should happend to our marks
    feed('u')
    feed('$x')
    check_undo_redo(ns, marks[2], 0, 3, 0, 3)
  end)

  it('deleting marks at end of line works #extmarks', function()
    -- mark_extended.c/extmark_col_adjust_delete
    set_extmark(ns, marks[1], 0, 4)
    feed('$x')
    check_undo_redo(ns, marks[1], 0, 4, 0, 4)
    -- check the copy happened correctly on delete at eol
    feed('$x')
    check_undo_redo(ns, marks[1], 0, 4, 0, 3)
    feed('u')
    check_undo_redo(ns, marks[1], 0, 4, 0, 4)
  end)

  it('marks move with blockwise deletes #extmarks', function()
    -- op_delete in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 4)
    feed('h<c-v>hhkd')
    check_undo_redo(ns, marks[1], 1, 4, 1, 1)
  end)

  it('marks move with blockwise deletes over a range #extmarks', function()
    -- op_delete in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 1, 2)
    feed('0<c-v>k3lx')
    check_undo_redo(ns, marks[1], 0, 1, 0, 0)
    check_undo_redo(ns, marks[2], 0, 3, 0, 0)
    check_undo_redo(ns, marks[3], 1, 2, 1, 0)
    -- delete 1, nothing should happend to our marks
    feed('u')
    feed('$<c-v>jx')
    check_undo_redo(ns, marks[2], 0, 3, 0, 3)
    check_undo_redo(ns, marks[3], 1, 2, 1, 2)
  end)

  it('works with char deletes over multilines #extmarks', function()
    feed('a<cr>12345<cr>test-me<esc>')
    set_extmark(ns, marks[1], 2, 5)
    feed('gg')
    feed('dv?-m?<cr>')
    check_undo_redo(ns, marks[1], 2, 5, 0, 0)
  end)

  it('marks outside of deleted range move with visual char deletes #extmarks', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 3)
    feed('0vx<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 2)

    feed("u")
    feed('0vlx<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 1)

    feed("u")
    feed('0v2lx<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 0)

    -- from the other side (nothing should happen)
    feed('$vx')
    check_undo_redo(ns, marks[1], 0, 0, 0, 0)
  end)

  it('marks outside of deleted range move with char deletes #extmarks', function()
    -- op_delete in ops.c
    set_extmark(ns, marks[1], 0, 3)
    feed('0x<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 2)

    feed("u")
    feed('02x<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 1)

    feed("u")
    feed('0v3lx<esc>')
    check_undo_redo(ns, marks[1], 0, 3, 0, 0)

    -- from the other side (nothing should happen)
    feed("u")
    feed('$vx')
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
  end)

  it('marks move with P(backward) paste #extmarks', function()
    -- do_put in ops.c
    feed('0iabc<esc>')
    set_extmark(ns, marks[1], 0, 7)
    feed('0veyP')
    check_undo_redo(ns, marks[1], 0, 7, 0, 15)
  end)

  it('marks move with p(forward) paste #extmarks', function()
    -- do_put in ops.c
    feed('0iabc<esc>')
    set_extmark(ns, marks[1], 0, 7)
    feed('0veyp')
    check_undo_redo(ns, marks[1], 0, 7, 0, 14)
  end)

  it('marks move with blockwise P(backward) paste #extmarks', function()
    -- do_put in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 4)
    feed('<c-v>hhkyP<esc>')
    check_undo_redo(ns, marks[1], 1, 4, 1, 7)
  end)

  it('marks move with blockwise p(forward) paste #extmarks', function()
    -- do_put in ops.c
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 4)
    feed('<c-v>hhkyp<esc>')
    check_undo_redo(ns, marks[1], 1, 4, 1, 6)
  end)

  it('replace works #extmarks', function()
    set_extmark(ns, marks[1], 0, 2)
    feed('0r2')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
  end)

  it('blockwise replace works #extmarks', function()
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 0, 2)
    feed('0<c-v>llkr1<esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
  end)

  it('shift line #extmarks', function()
    -- shift_line in ops.c
    feed(':set shiftwidth=4<cr><esc>')
    set_extmark(ns, marks[1], 0, 2)
    feed('0>>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 6)

    feed('>>')
    check_undo_redo(ns, marks[1], 0, 6, 0, 10)

    feed('<LT><LT>') -- have to escape, same as <<
    check_undo_redo(ns, marks[1], 0, 10, 0, 6)
  end)

  it('blockwise shift #extmarks', function()
    -- shift_block in ops.c
    feed(':set shiftwidth=4<cr><esc>')
    feed('a<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 2)
    feed('0<c-v>k>')
    check_undo_redo(ns, marks[1], 1, 2, 1, 6)
    feed('<c-v>j>')
    check_undo_redo(ns, marks[1], 1, 6, 1, 10)

    feed('<c-v>j<LT>')
    check_undo_redo(ns, marks[1], 1, 10, 1, 6)
  end)

  it('tab works with expandtab #extmarks', function()
    -- ins_tab in edit.c
    feed(':set expandtab<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    set_extmark(ns, marks[1], 0, 2)
    feed('0i<tab><tab><esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 6)
  end)

  it('tabs work #extmarks', function()
    -- ins_tab in edit.c
    feed(':set noexpandtab<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed(':set softtabstop=2<cr><esc>')
    feed(':set tabstop=8<cr><esc>')
    set_extmark(ns, marks[1], 0, 2)
    feed('0i<tab><esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 4)
    feed('0iX<tab><esc>')
    check_undo_redo(ns, marks[1], 0, 4, 0, 6)
  end)

  it('marks move when using :move #extmarks', function()
    set_extmark(ns, marks[1], 0, 0)
    feed('A<cr>2<esc>:1move 2<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 0, 1, 0)
    -- test codepath when moving lines up
    feed(':2move 0<cr><esc>')
    check_undo_redo(ns, marks[1], 1, 0, 0, 0)
  end)

  it('marks move when using :move part 2 #extmarks', function()
    -- make sure we didn't get lucky with the math...
    feed('A<cr>2<cr>3<cr>4<cr>5<cr>6<esc>')
    set_extmark(ns, marks[1], 1, 0)
    feed(':2,3move 5<cr><esc>')
    check_undo_redo(ns, marks[1], 1, 0, 3, 0)
    -- test codepath when moving lines up
    feed(':4,5move 1<cr><esc>')
    check_undo_redo(ns, marks[1], 3, 0, 1, 0)
  end)

  it('undo and redo of set and unset marks #extmarks', function()
    -- Force a new undo head
    feed('o<esc>')
    set_extmark(ns, marks[1], 0, 1)
    feed('o<esc>')
    set_extmark(ns, marks[2], 0, -1)
    set_extmark(ns, marks[3], 0, -1)

    feed("u")
    local rv = get_extmarks(ns, {0, 0}, {-1, -1})
    eq(1, table.getn(rv))

    feed("<c-r>")
    rv = get_extmarks(ns, {0, 0}, {-1, -1})
    eq(3, table.getn(rv))

    -- Test updates
    feed('o<esc>')
    set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    rv = get_extmarks(ns, marks[1], marks[1], {amount=1})
    eq(1, table.getn(rv))
    feed("u")
    feed("<c-r>")
    check_undo_redo(ns, marks[1], 0, 1, positions[1][1], positions[1][2])

    -- Test unset
    feed('o<esc>')
    curbufmeths.del_extmark(ns, marks[3])
    feed("u")
    rv = get_extmarks(ns, {0, 0}, {-1, -1})
    eq(3, table.getn(rv))
    feed("<c-r>")
    rv = get_extmarks(ns, {0, 0}, {-1, -1})
    eq(2, table.getn(rv))
  end)

  it('undo and redo of marks deleted during edits #extmarks', function()
    -- test extmark_adjust
    feed('A<cr>12345<esc>')
    set_extmark(ns, marks[1], 1, 2)
    feed('dd')
    check_undo_redo(ns, marks[1], 1, 2, 1, 0)
  end)

  it('namespaces work properly #extmarks', function()
    local rv = set_extmark(ns, marks[1], positions[1][1], positions[1][2])
    eq(1, rv)
    rv = set_extmark(ns2, marks[1], positions[1][1], positions[1][2])
    eq(1, rv)
    rv = get_extmarks(ns, {0, 0}, {-1, -1})
    eq(1, table.getn(rv))
    rv = get_extmarks(ns2, {0, 0}, {-1, -1})
    eq(1, table.getn(rv))

    -- Set more marks for testing the ranges
    set_extmark(ns, marks[2], positions[2][1], positions[2][2])
    set_extmark(ns, marks[3], positions[3][1], positions[3][2])
    set_extmark(ns2, marks[2], positions[2][1], positions[2][2])
    set_extmark(ns2, marks[3], positions[3][1], positions[3][2])

    -- get_next (amount set)
    rv = get_extmarks(ns, {0, 0}, positions[2], {amount=1})
    eq(1, table.getn(rv))
    rv = get_extmarks(ns2, {0, 0}, positions[2], {amount=1})
    eq(1, table.getn(rv))
    -- get_prev (amount set)
    rv = get_extmarks(ns, positions[1], {0, 0}, {amount=1})
    eq(1, table.getn(rv))
    rv = get_extmarks(ns2, positions[1], {0, 0}, {amount=1})
    eq(1, table.getn(rv))

    -- get_next (amount not set)
    rv = get_extmarks(ns, positions[1], positions[2])
    eq(2, table.getn(rv))
    rv = get_extmarks(ns2, positions[1], positions[2])
    eq(2, table.getn(rv))
    -- get_prev (amount not set)
    rv = get_extmarks(ns, positions[2], positions[1])
    eq(2, table.getn(rv))
    rv = get_extmarks(ns2, positions[2], positions[1])
    eq(2, table.getn(rv))

    curbufmeths.del_extmark(ns, marks[1])
    rv = get_extmarks(ns, {0, 0}, {-1, -1})
    eq(2, table.getn(rv))
    curbufmeths.del_extmark(ns2, marks[1])
    rv = get_extmarks(ns2, {0, 0}, {-1, -1})
    eq(2, table.getn(rv))
  end)

  it('mark set can create unique identifiers #extmarks', function()
    -- create mark with id 1
    eq(1, set_extmark(ns, 1, positions[1][1], positions[1][2]))
    -- ask for unique id, it should be the next one, i e 2
    eq(2, set_extmark(ns, 0, positions[1][1], positions[1][2]))
    eq(3, set_extmark(ns, 3, positions[2][1], positions[2][2]))
    eq(4, set_extmark(ns, 0, positions[1][1], positions[1][2]))

    -- mixing manual and allocated id:s are not recommened, but it should
    -- do something reasonable
    eq(6, set_extmark(ns, 6, positions[2][1], positions[2][2]))
    eq(7, set_extmark(ns, 0, positions[1][1], positions[1][2]))
    eq(8, set_extmark(ns, 0, positions[1][1], positions[1][2]))
  end)

  it('auto indenting with enter works #extmarks', function()
    -- op_reindent in ops.c
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed("0iint <esc>A {1M1<esc>b<esc>")
    -- Set the mark on the M, should move..
    set_extmark(ns, marks[1], 0, 12)
    -- Set the mark before the cursor, should stay there
    set_extmark(ns, marks[2], 0, 10)
    feed("i<cr><esc>")
    local rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({1, 3}, rv)
    rv = curbufmeths.get_extmark_by_id(ns, marks[2])
    eq({0, 10}, rv)
    check_undo_redo(ns, marks[1], 0, 12, 1, 3)
  end)

  it('auto indenting entire line works #extmarks', function()
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    -- <c-f> will force an indent of 2
    feed("0iint <esc>A {<cr><esc>0i1M1<esc>")
    set_extmark(ns, marks[1], 1, 1)
    feed("0i<c-f><esc>")
    local rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({1, 3}, rv)
    check_undo_redo(ns, marks[1], 1, 1, 1, 3)
    -- now check when cursor at eol
    feed("uA<c-f><esc>")
    rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({1, 3}, rv)
  end)

  it('removing auto indenting with <C-D> works #extmarks', function()
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed("0i<tab><esc>")
    set_extmark(ns, marks[1], 0, 3)
    feed("bi<c-d><esc>")
    local rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({0, 1}, rv)
    check_undo_redo(ns, marks[1], 0, 3, 0, 1)
    -- check when cursor at eol
    feed("uA<c-d><esc>")
    rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({0, 1}, rv)
  end)

  it('indenting multiple lines with = works #extmarks', function()
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed("0iint <esc>A {<cr><bs>1M1<cr><bs>2M2<esc>")
    set_extmark(ns, marks[1], 1, 1)
    set_extmark(ns, marks[2], 2, 1)
    feed('=gg')
    check_undo_redo(ns, marks[1], 1, 1, 1, 3)
    check_undo_redo(ns, marks[2], 2, 1, 2, 5)
  end)

  it('substitutes by deleting inside the replace matches #extmarks_sub', function()
    -- do_sub in ex_cmds.c
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    feed(':s/34/xx<cr>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 4)
    check_undo_redo(ns, marks[2], 0, 3, 0, 4)
  end)

  it('substitutes when insert text > deleted #extmarks_sub', function()
    -- do_sub in ex_cmds.c
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    feed(':s/34/xxx<cr>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 5)
    check_undo_redo(ns, marks[2], 0, 3, 0, 5)
  end)

  it('substitutes when marks around eol #extmarks_sub', function()
    -- do_sub in ex_cmds.c
    set_extmark(ns, marks[1], 0, 4)
    set_extmark(ns, marks[2], 0, 5)
    feed(':s/5/xxx<cr>')
    check_undo_redo(ns, marks[1], 0, 4, 0, 7)
    check_undo_redo(ns, marks[2], 0, 5, 0, 7)
  end)

  it('substitutes over range insert text > deleted #extmarks_sub', function()
    -- do_sub in ex_cmds.c
    feed('A<cr>x34xx<esc>')
    feed('A<cr>xxx34<esc>')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 1, 1)
    set_extmark(ns, marks[3], 2, 4)
    feed(':1,3s/34/xxx<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 5)
    check_undo_redo(ns, marks[2], 1, 1, 1, 4)
    check_undo_redo(ns, marks[3], 2, 4, 2, 6)
  end)

  it('substitutes multiple matches in a line #extmarks_sub', function()
    -- do_sub in ex_cmds.c
    feed('ddi3x3x3<esc>')
    set_extmark(ns, marks[1], 0, 0)
    set_extmark(ns, marks[2], 0, 2)
    set_extmark(ns, marks[3], 0, 4)
    feed(':s/3/yy/g<cr><esc>')
    check_undo_redo(ns, marks[1], 0, 0, 0, 2)
    check_undo_redo(ns, marks[2], 0, 2, 0, 5)
    check_undo_redo(ns, marks[3], 0, 4, 0, 8)
  end)

  it('substitions over multiple lines with newline in pattern #extmarks_sub', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 1, 0)
    set_extmark(ns, marks[4], 1, 5)
    set_extmark(ns, marks[5], 2, 0)
    feed([[:1,2s:5\n:5 <cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 0, 6)
    check_undo_redo(ns, marks[3], 1, 0, 0, 6)
    check_undo_redo(ns, marks[4], 1, 5, 0, 11)
    check_undo_redo(ns, marks[5], 2, 0, 1, 0)
  end)

  it('inserting #extmarks_sub', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 1, 0)
    set_extmark(ns, marks[4], 1, 5)
    set_extmark(ns, marks[5], 2, 0)
    set_extmark(ns, marks[6], 1, 2)
    feed([[:1,2s:5\n67:X<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 0, 5)
    check_undo_redo(ns, marks[3], 1, 0, 0, 5)
    check_undo_redo(ns, marks[4], 1, 5, 0, 8)
    check_undo_redo(ns, marks[5], 2, 0, 1, 0)
    check_undo_redo(ns, marks[6], 1, 2, 0, 5)
  end)

  it('substitions with multiple newlines in pattern #extmarks_sub', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 4)
    set_extmark(ns, marks[2], 0, 5)
    set_extmark(ns, marks[3], 1, 0)
    set_extmark(ns, marks[4], 1, 5)
    set_extmark(ns, marks[5], 2, 0)
    feed([[:1,2s:\n.*\n:X<cr>]])
    check_undo_redo(ns, marks[1], 0, 4, 0, 4)
    check_undo_redo(ns, marks[2], 0, 5, 0, 6)
    check_undo_redo(ns, marks[3], 1, 0, 0, 6)
    check_undo_redo(ns, marks[4], 1, 5, 0, 6)
    check_undo_redo(ns, marks[5], 2, 0, 0, 6)
  end)

  it('substitions over multiple lines with replace in substition #extmarks_sub', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 2)
    set_extmark(ns, marks[3], 0, 4)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 2, 0)
    feed([[:1,2s:3:\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 1, 0, 1)
    check_undo_redo(ns, marks[2], 0, 2, 1, 0)
    check_undo_redo(ns, marks[3], 0, 4, 1, 1)
    check_undo_redo(ns, marks[4], 1, 0, 2, 0)
    check_undo_redo(ns, marks[5], 2, 0, 3, 0)
    feed('u')
    feed([[:1,2s:3:\rxx<cr>]])
    eq({1, 3}, curbufmeths.get_extmark_by_id(ns, marks[3]))
  end)

  it('substitions over multiple lines with replace in substition #extmarks_sub', function()
    feed('A<cr>x3<cr>xx<esc>')
    set_extmark(ns, marks[1], 1, 0)
    set_extmark(ns, marks[2], 1, 1)
    set_extmark(ns, marks[3], 1, 2)
    feed([[:2,2s:3:\r<cr>]])
    check_undo_redo(ns, marks[1], 1, 0, 1, 0)
    check_undo_redo(ns, marks[2], 1, 1, 2, 0)
    check_undo_redo(ns, marks[3], 1, 2, 2, 0)
  end)

  it('substitions over multiple lines with replace in substition #extmarks_sub', function()
    feed('A<cr>x3<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 1)
    set_extmark(ns, marks[2], 0, 2)
    set_extmark(ns, marks[3], 0, 4)
    set_extmark(ns, marks[4], 1, 1)
    set_extmark(ns, marks[5], 2, 0)
    feed([[:1,2s:3:\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 1, 0, 1)
    check_undo_redo(ns, marks[2], 0, 2, 1, 0)
    check_undo_redo(ns, marks[3], 0, 4, 1, 1)
    check_undo_redo(ns, marks[4], 1, 1, 3, 0)
    check_undo_redo(ns, marks[5], 2, 0, 4, 0)
    feed('u')
    feed([[:1,2s:3:\rxx<cr>]])
    check_undo_redo(ns, marks[3], 0, 4, 1, 3)
  end)

  it('substitions with newline in match and sub, delta is 0 #extmarks_sub', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 1, 5)
    set_extmark(ns, marks[6], 2, 0)
    feed([[:1,1s:5\n:\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 1, 0)
    check_undo_redo(ns, marks[3], 0, 5, 1, 0)
    check_undo_redo(ns, marks[4], 1, 0, 1, 0)
    check_undo_redo(ns, marks[5], 1, 5, 1, 5)
    check_undo_redo(ns, marks[6], 2, 0, 2, 0)
  end)

  it('substitions with newline in match and sub, delta > 0 #extmarks_sub', function()
    feed('A<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 1, 5)
    set_extmark(ns, marks[6], 2, 0)
    feed([[:1,1s:5\n:\r\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 2, 0)
    check_undo_redo(ns, marks[3], 0, 5, 2, 0)
    check_undo_redo(ns, marks[4], 1, 0, 2, 0)
    check_undo_redo(ns, marks[5], 1, 5, 2, 5)
    check_undo_redo(ns, marks[6], 2, 0, 3, 0)
  end)

  it('substitions with newline in match and sub, delta < 0 #extmarks_sub', function()
    feed('A<cr>67890<cr>xx<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 1, 5)
    set_extmark(ns, marks[6], 2, 1)
    set_extmark(ns, marks[7], 3, 0)
    feed([[:1,2s:5\n.*\n:\r<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 1, 0)
    check_undo_redo(ns, marks[3], 0, 5, 1, 0)
    check_undo_redo(ns, marks[4], 1, 0, 1, 0)
    check_undo_redo(ns, marks[5], 1, 5, 1, 0)
    check_undo_redo(ns, marks[6], 2, 1, 1, 1)
    check_undo_redo(ns, marks[7], 3, 0, 2, 0)
  end)

  it('substitions with backrefs, newline inserted into sub #extmarks_sub', function()
    feed('A<cr>67890<cr>xx<cr>xx<esc>')
    set_extmark(ns, marks[1], 0, 3)
    set_extmark(ns, marks[2], 0, 4)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 1, 0)
    set_extmark(ns, marks[5], 1, 5)
    set_extmark(ns, marks[6], 2, 0)
    feed([[:1,1s:5\(\n\):\0\1<cr>]])
    check_undo_redo(ns, marks[1], 0, 3, 0, 3)
    check_undo_redo(ns, marks[2], 0, 4, 2, 0)
    check_undo_redo(ns, marks[3], 0, 5, 2, 0)
    check_undo_redo(ns, marks[4], 1, 0, 2, 0)
    check_undo_redo(ns, marks[5], 1, 5, 2, 5)
    check_undo_redo(ns, marks[6], 2, 0, 3, 0)
  end)

  it('substitions a ^ #extmarks_sub', function()
    set_extmark(ns, marks[1], 0, 0)
    set_extmark(ns, marks[2], 0, 1)
    feed([[:s:^:x<cr>]])
    check_undo_redo(ns, marks[1], 0, 0, 0, 1)
    check_undo_redo(ns, marks[2], 0, 1, 0, 2)
  end)

  it('using <c-a> without increase in order of magnitude #extmarks_inc_dec', function()
    -- do_addsub in ops.c
    feed('ddiabc998xxx<esc>Tc')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 0, 6)
    set_extmark(ns, marks[5], 0, 7)
    feed('<c-a>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 6)
    check_undo_redo(ns, marks[3], 0, 5, 0, 6)
    check_undo_redo(ns, marks[4], 0, 6, 0, 6)
    check_undo_redo(ns, marks[5], 0, 7, 0, 7)
  end)

  it('using <c-a> when increase in order of magnitude #extmarks_inc_dec', function()
    -- do_addsub in ops.c
    feed('ddiabc999xxx<esc>Tc')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 0, 6)
    set_extmark(ns, marks[5], 0, 7)
    feed('<c-a>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 7)
    check_undo_redo(ns, marks[3], 0, 5, 0, 7)
    check_undo_redo(ns, marks[4], 0, 6, 0, 7)
    check_undo_redo(ns, marks[5], 0, 7, 0, 8)
  end)

  it('using <c-a> when negative and without decrease in order of magnitude #extmarks_inc_dec', function()
    feed('ddiabc-999xxx<esc>T-')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 6)
    set_extmark(ns, marks[4], 0, 7)
    set_extmark(ns, marks[5], 0, 8)
    feed('<c-a>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 7)
    check_undo_redo(ns, marks[3], 0, 6, 0, 7)
    check_undo_redo(ns, marks[4], 0, 7, 0, 7)
    check_undo_redo(ns, marks[5], 0, 8, 0, 8)
  end)

  it('using <c-a> when negative and decrease in order of magnitude #extmarks_inc_dec', function()
    feed('ddiabc-1000xxx<esc>T-')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 7)
    set_extmark(ns, marks[4], 0, 8)
    set_extmark(ns, marks[5], 0, 9)
    feed('<c-a>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 7)
    check_undo_redo(ns, marks[3], 0, 7, 0, 7)
    check_undo_redo(ns, marks[4], 0, 8, 0, 7)
    check_undo_redo(ns, marks[5], 0, 9, 0, 8)
  end)

  it('using <c-x> without decrease in order of magnitude #extmarks_inc_dec', function()
    -- do_addsub in ops.c
    feed('ddiabc999xxx<esc>Tc')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 5)
    set_extmark(ns, marks[4], 0, 6)
    set_extmark(ns, marks[5], 0, 7)
    feed('<c-x>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 6)
    check_undo_redo(ns, marks[3], 0, 5, 0, 6)
    check_undo_redo(ns, marks[4], 0, 6, 0, 6)
    check_undo_redo(ns, marks[5], 0, 7, 0, 7)
  end)

  it('using <c-x> when decrease in order of magnitude #extmarks_inc_dec', function()
    -- do_addsub in ops.c
    feed('ddiabc1000xxx<esc>Tc')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 6)
    set_extmark(ns, marks[4], 0, 7)
    set_extmark(ns, marks[5], 0, 8)
    feed('<c-x>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 6)
    check_undo_redo(ns, marks[3], 0, 6, 0, 6)
    check_undo_redo(ns, marks[4], 0, 7, 0, 6)
    check_undo_redo(ns, marks[5], 0, 8, 0, 7)
  end)

  it('using <c-x> when negative and without increase in order of magnitude #extmarks_inc_dec', function()
    feed('ddiabc-998xxx<esc>T-')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 6)
    set_extmark(ns, marks[4], 0, 7)
    set_extmark(ns, marks[5], 0, 8)
    feed('<c-x>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 7)
    check_undo_redo(ns, marks[3], 0, 6, 0, 7)
    check_undo_redo(ns, marks[4], 0, 7, 0, 7)
    check_undo_redo(ns, marks[5], 0, 8, 0, 8)
  end)

  it('using <c-x> when negative and increase in order of magnitude #extmarks_inc_dec', function()
    feed('ddiabc-999xxx<esc>T-')
    set_extmark(ns, marks[1], 0, 2)
    set_extmark(ns, marks[2], 0, 3)
    set_extmark(ns, marks[3], 0, 6)
    set_extmark(ns, marks[4], 0, 7)
    set_extmark(ns, marks[5], 0, 8)
    feed('<c-x>')
    check_undo_redo(ns, marks[1], 0, 2, 0, 2)
    check_undo_redo(ns, marks[2], 0, 3, 0, 8)
    check_undo_redo(ns, marks[3], 0, 6, 0, 8)
    check_undo_redo(ns, marks[4], 0, 7, 0, 8)
    check_undo_redo(ns, marks[5], 0, 8, 0, 9)
  end)

  it('throws consistent error codes', function()
    local ns_invalid = ns2 + 1
    eq("Invalid ns_id", pcall_err(set_extmark, ns_invalid, marks[1], positions[1][1], positions[1][2]))
    eq("Invalid ns_id", pcall_err(curbufmeths.del_extmark, ns_invalid, marks[1]))
    eq("Invalid ns_id", pcall_err(get_extmarks, ns_invalid, positions[1], positions[2]))
    eq("Invalid ns_id", pcall_err(curbufmeths.get_extmark_by_id, ns_invalid, marks[1]))
  end)

  it('when col = line-length, set the mark on eol #extmarks', function()
    set_extmark(ns, marks[1], 0, -1)
    local rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({0, init_text:len()}, rv)
    -- Test another
    set_extmark(ns, marks[1], 0, -1)
    rv = curbufmeths.get_extmark_by_id(ns, marks[1])
    eq({0, init_text:len()}, rv)
  end)

  it('when col = line-length, set the mark on eol #extmarks', function()
    local invalid_col = init_text:len() + 1
    eq("col value outside range", pcall_err(set_extmark, ns, marks[1], 0, invalid_col))
  end)

  it('when line > line_count, throw error #extmarks', function()
    local invalid_col = init_text:len() + 1
    local invalid_lnum = 3
    eq('line value outside range', pcall_err(set_extmark, ns, marks[1], invalid_lnum, invalid_col))
    eq({}, curbufmeths.get_extmark_by_id(ns, marks[1]))
  end)

  it('bug from check_col in extmark_set #extmarks_sub', function()
    -- This bug was caused by extmark_set always using
    -- check_col. check_col always uses the current buffer.
    -- This wasn't working during undo so we now use
    -- check_col and check_lnum only when they are required.
    feed('A<cr>67890<cr>xx<esc>')
    feed('A<cr>12345<cr>67890<cr>xx<esc>')
    set_extmark(ns, marks[1], 3, 4)
    feed([[:1,5s:5\n:5 <cr>]])
    check_undo_redo(ns, marks[1], 3, 4, 2, 6)
  end)

  it('in read-only buffer', function()
    command("view! runtime/doc/help.txt")
    eq(true, curbufmeths.get_option('ro'))
    local id = set_extmark(ns, 0, 0, 2)
    eq({{id, 0, 2}}, get_extmarks(ns,0, -1))
  end)
end)

describe('Extmarks buffer api with many marks', function()
  local ns1
  local ns2
  local ns_marks = {}
  before_each(function()
    clear()
    ns1 = request('nvim_create_namespace', "ns1")
    ns2 = request('nvim_create_namespace', "ns2")
    ns_marks = {[ns1]={}, [ns2]={}}
    local lines = {}
    for i = 1,30 do
      lines[#lines+1] = string.rep("x ",i)
    end
    curbufmeths.set_lines(0, -1, true, lines)
    local ns = ns1
    local q = 0
    for i = 0,29 do
      for j = 0,i do
        local id = set_extmark(ns,0, i,j)
        eq(nil, ns_marks[ns][id])
        ok(id > 0)
        ns_marks[ns][id] = {i,j}
        ns = ns1+ns2-ns
        q = q + 1
      end
    end
    eq(233, #ns_marks[ns1])
    eq(232, #ns_marks[ns2])

  end)

  local function get_marks(ns)
    local mark_list = get_extmarks(ns, 0, -1)
    local marks = {}
    for _, mark in ipairs(mark_list) do
      local id, row, col = unpack(mark)
      eq(nil, marks[id], "duplicate mark")
      marks[id] = {row,col}
    end
    return marks
  end

  it("can get marks #extmarks", function()
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
  end)

  it("can clear all marks in ns #extmarks", function()
    curbufmeths.clear_namespace(ns1, 0, -1)
    eq({}, get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
    curbufmeths.clear_namespace(ns2, 0, -1)
    eq({}, get_marks(ns1))
    eq({}, get_marks(ns2))
  end)

  it("can clear line range #extmarks", function()
    curbufmeths.clear_namespace(ns1, 10, 20)
    for id, mark in pairs(ns_marks[ns1]) do
      if 10 <= mark[1] and mark[1] < 20 then
        ns_marks[ns1][id] = nil
      end
    end
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
  end)

  it("can delete line #extmarks", function()
    feed('10Gdd')
    for _, marks in pairs(ns_marks) do
      for id, mark in pairs(marks) do
        if mark[1] == 9 then
          marks[id] = {9,0}
        elseif mark[1] >= 10 then
          mark[1] = mark[1] - 1
        end
      end
    end
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
  end)

  it("can delete lines #extmarks", function()
    feed('10G10dd')
    for _, marks in pairs(ns_marks) do
      for id, mark in pairs(marks) do
        if 9 <= mark[1] and mark[1] < 19 then
          marks[id] = {9,0}
        elseif mark[1] >= 19 then
          mark[1] = mark[1] - 10
        end
      end
    end
    eq(ns_marks[ns1], get_marks(ns1))
    eq(ns_marks[ns2], get_marks(ns2))
  end)

  it("can wipe buffer #extmarks", function()
    command('bwipe!')
    eq({}, get_marks(ns1))
    eq({}, get_marks(ns2))
  end)
end)
