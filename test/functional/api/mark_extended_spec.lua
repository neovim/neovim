-- TODO(timeyyy): go through todo's lol
-- change representation of stored marks to have location start at 0
-- check with memsan, asan etc

local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local request = helpers.request
local eq = helpers.eq
local buffer = helpers.buffer
local insert = helpers.insert
local feed = helpers.feed

local SCREEN_WIDTH = 15
local TO_START = {-1, -1}
local TO_END = {-1, -1}
local ALL = -1
local RANDOM_MARK_ID = 0

local rv = nil
local rv1 = nil
local rv2 = nil
local buf = nil

local function check_undo_redo(buf, ns, mark, sr, sc, er, ec) --s = start, e = end
  feed("u")
  rv = buffer('lookup_mark', buf, ns, mark)
  eq(sr, rv[2])
  eq(sc, rv[3])
  feed("<c-r>")
  rv = buffer('lookup_mark', buf, ns, mark)
  eq(er, rv[2])
  eq(ec, rv[3])
end

local function check_undo(buf, ns, mark, sr, sc, er, ec) --s = start, e = end
  feed("u")
  rv = buffer('lookup_mark', buf, ns, mark)
  eq(sr, rv[2])
  eq(sc, rv[3])
  -- feed("<c-r>")
  -- rv = buffer('lookup_mark', buf, ns, mark)
  -- eq(er, rv[2])
  -- eq(ec, rv[3])
end

describe('Extmarks buffer api', function()
  local screen
  local marks, positions, ns_string2, ns_string, init_text, row, col
  local ns, ns2

  before_each(function()
    -- Initialize some namespaces and insert 12345 into a buffer
    marks = {1, 2, 3}
    positions = {{1, 1,}, {1, 3}, {1, 4}}

    ns_string = "my-fancy-plugin"
    ns_string2 = "my-fancy-plugin2"
    init_text = "12345"
    row = 0
    col = 2

    helpers.clear()
    helpers.nvim('set_option', 'shell', helpers.nvim_dir .. '/shell-test')
    helpers.nvim('set_option', 'shellcmdflag', 'EXE')
    screen = Screen.new(SCREEN_WIDTH, 10)
    screen:attach()

    insert(init_text)
    buf = request('vim_get_current_buffer')

    ns = 0
    -- 'add and query namespaces', these are required for marks to be created
    if ns == 0 then
      ns = request('nvim_create_namespace', ns_string)
      eq(1, ns)
      ns2 = request('nvim_create_namespace', ns_string2)
      eq(2, ns2)
      rv = request('nvim_get_namespaces')
      eq(ns_string, rv[1])
      eq(ns_string2, rv[2])
    end
  end)

  it('adds, updates  and deletes marks #extmarks', function()
    rv = buffer('set_mark', buf, ns, marks[1], positions[1][1], positions[1][2])
    eq(1, rv)
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], positions[1][1], positions[1][2]}, rv)
    -- Test adding a second mark on same row works
    rv = buffer('set_mark', buf, ns, marks[2], positions[2][1], positions[2][2])
    eq(1, rv)
    -- Test a second mark on a different line
    rv = buffer('set_mark', buf, ns, marks[3], positions[1][1] + 1, positions[1][2])
    eq(1, rv)
    -- Test an update, (same pos)
    rv = buffer('set_mark', buf, ns, marks[1], positions[1][1], positions[1][2])
    eq(2, rv)
    rv = buffer('lookup_mark', buf, ns, marks[2])
    eq({marks[2], positions[2][1], positions[2][2]}, rv)
    -- Test an update, (new pos)
    row = positions[1][1]
    col = positions[1][2] + 1
    rv = buffer('set_mark', buf, ns, marks[1], row, col)
    eq(2, rv)
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], row, col}, rv)

    -- remove the test marks
    rv = buffer('del_mark', buf, ns, marks[1])
    eq(1, rv)
    rv = buffer('del_mark', buf, ns, marks[2])
    eq(1, rv)
    rv = buffer('del_mark', buf, ns, marks[3])
    eq(1, rv)
  end)

  it('querying for information and ranges #extmarks', function()
    -- add some more marks
    for i, m in ipairs(marks) do
        rv = buffer('set_mark', buf, ns, m, positions[i][1], positions[i][2])
        eq(1, rv)
    end

    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    for i, m in ipairs(marks) do
        eq({m, positions[i][1], positions[i][2]}, rv[i])
    end

    -- next with mark id
    rv = buffer('get_marks', buf, ns, marks[1], TO_END, 1, 0)
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)
    rv = buffer('get_marks', buf, ns, marks[2], TO_END, 1, 0)
    eq({{marks[2], positions[2][1], positions[2][2]}}, rv)
    -- next with positional when mark exists at position
    rv = buffer('get_marks', buf, ns, positions[1], TO_END, 1, 0)
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)
    -- next with positional index (no mark at position)
    rv = buffer('get_marks', buf, ns, {positions[1][1], positions[1][2] +1}, TO_END, 1, 0)
    eq({{marks[2], positions[2][1], positions[2][2]}}, rv)
    -- next with Extremity index
    rv = buffer('get_marks', buf, ns, -1, -1, 1, 0)
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)

    -- nextrange with mark id
    rv = buffer('get_marks', buf, ns, marks[1], marks[3], ALL, 0)
    eq({marks[1], positions[1][1], positions[1][2]}, rv[1])
    eq({marks[2], positions[2][1], positions[2][2]}, rv[2])
    eq({marks[3], positions[3][1], positions[3][2]}, rv[3])
    -- nextrange with amount
    rv = buffer('get_marks', buf, ns, marks[1], marks[3], 2, 0)
    eq(2, table.getn(rv))
    -- nextrange with positional when mark exists at position
    rv = buffer('get_marks', buf, ns, positions[1], positions[3], ALL, 0)
    eq({marks[1], positions[1][1], positions[1][2]}, rv[1])
    eq({marks[2], positions[2][1], positions[2][2]}, rv[2])
    eq({marks[3], positions[3][1], positions[3][2]}, rv[3])
    rv = buffer('get_marks', buf, ns, positions[2], positions[3], ALL, 0)
    eq(2, table.getn(rv))
    -- nextrange with positional index (no mark at position)
    local lower = {positions[1][1], positions[2][2] -1}
    local upper = {positions[2][1], positions[3][2] - 1}
    rv = buffer('get_marks', buf, ns, lower, upper, ALL, 0)
    eq({{marks[2], positions[2][1], positions[2][2]}}, rv)
    lower = {positions[3][1], positions[3][2] + 1}
    upper = {positions[3][1], positions[3][2] + 2}
    rv = buffer('get_marks', buf, ns, lower, upper, ALL, 0)
    eq({}, rv)
    -- nextrange with extremity index
    lower = {positions[2][1], positions[2][2]+1}
    upper = -1
    rv = buffer('get_marks', buf, ns, lower, upper, ALL, 0)
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)

    -- prev with mark id
    rv = buffer('get_marks', buf, ns, TO_START, marks[3], 1, 1)
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)
    rv = buffer('get_marks', buf, ns, TO_START, marks[2], 1, 1)
    eq({{marks[2], positions[2][1], positions[2][2]}}, rv)
    -- prev with positional when mark exists at position
    rv = buffer('get_marks', buf, ns, TO_START, positions[3], 1, 1)
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)
    -- prev with positional index (no mark at position)
    rv = buffer('get_marks', buf, ns, TO_START, {positions[1][1], positions[1][2] +1}, 1, 1)
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)
    -- prev with Extremity index
    rv = buffer('get_marks', buf, ns, -1, -1, 1, 1)
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)

    -- prevrange with mark id
    rv = buffer('get_marks', buf, ns, marks[1], marks[3], ALL, 1)
    eq({marks[3], positions[3][1], positions[3][2]}, rv[1])
    eq({marks[2], positions[2][1], positions[2][2]}, rv[2])
    eq({marks[1], positions[1][1], positions[1][2]}, rv[3])
    -- prevrange with amount
    rv = buffer('get_marks', buf, ns, marks[1], marks[3], 2, 1)
    eq(2, table.getn(rv))
    -- prevrange with positional when mark exists at position
    rv = buffer('get_marks', buf, ns, positions[1], positions[3], ALL, 1)
    eq({marks[3], positions[3][1], positions[3][2]}, rv[1])
    eq({marks[2], positions[2][1], positions[2][2]}, rv[2])
    eq({marks[1], positions[1][1], positions[1][2]}, rv[3])
    rv = buffer('get_marks', buf, ns, positions[1], positions[2], ALL, 1)
    eq(2, table.getn(rv))
    -- prevrange with positional index (no mark at position)
    lower = {positions[2][1], positions[2][2] + 1}
    upper = {positions[3][1], positions[3][2] + 1}
    rv = buffer('get_marks', buf, ns, lower, upper, ALL, 1)
    eq({{marks[3], positions[3][1], positions[3][2]}}, rv)
    lower = {positions[3][1], positions[3][2] + 1}
    upper = {positions[3][1], positions[3][2] + 2}
    rv = buffer('get_marks', buf, ns, lower, upper, ALL, 1)
    eq({}, rv)
    -- prevrange with extremity index
    lower = -1
    upper = {positions[2][1], positions[2][2] - 1}
    rv = buffer('get_marks', buf, ns, lower, upper, ALL, 1)
    eq({{marks[1], positions[1][1], positions[1][2]}}, rv)
  end)

  it('querying for information with amount #extmarks', function()
    -- add some more marks
    for i, m in ipairs(marks) do
        rv = buffer('set_mark', buf, ns, m, positions[i][1], positions[i][2])
        eq(1, rv)
    end

    rv = buffer('get_marks', buf, ns, TO_START, TO_END, 1, 0)
    eq(1, table.getn(rv))
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, 2, 0)
    eq(2, table.getn(rv))
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, 3, 0)
    eq(3, table.getn(rv))

    -- now in reverse
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, 1, 0)
    eq(1, table.getn(rv))
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, 2, 0)
    eq(2, table.getn(rv))
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, 3, 0)
    eq(3, table.getn(rv))
  end)

  it('get_marks works when mark col > upper col #extmarks', function()
    feed('A<cr>12345<esc>')
    feed('A<cr>12345<esc>')
    buffer('set_mark', buf, ns, 10, 1, 3)       -- this shouldn't be found
    buffer('set_mark', buf, ns, 11, 3, 2)       -- this shouldn't be found
    buffer('set_mark', buf, ns, marks[1], 1, 5) -- check col > our upper bound
    buffer('set_mark', buf, ns, marks[2], 2, 2) -- check col < lower bound
    buffer('set_mark', buf, ns, marks[3], 3, 1) -- check is inclusive
    rv = buffer('get_marks', buf, ns, {1, 4}, {3, 1}, -1, 0)
    eq({{marks[1], 1, 5},
        {marks[2], 2, 2},
        {marks[3], 3, 1}},
       rv)
  end)

  it('get_marks works in reverse when mark col < lower col #extmarks', function()
    feed('A<cr>12345<esc>')
    feed('A<cr>12345<esc>')
    buffer('set_mark', buf, ns, 10, 1, 2) -- this shouldn't be found
    buffer('set_mark', buf, ns, 11, 3, 5) -- this shouldn't be found
    buffer('set_mark', buf, ns, marks[1], 3, 2) -- check col < our lower bound
    buffer('set_mark', buf, ns, marks[2], 2, 5) -- check col > upper bound
    buffer('set_mark', buf, ns, marks[3], 1, 3) -- check is inclusive
    rv = buffer('get_marks', buf, ns, {1, 3}, {3, 4}, -1, 1)
    eq({{marks[1], 3, 2},
        {marks[2], 2, 5},
        {marks[3], 1, 3}},
       rv)
  end)

  it('get_marks amount 0 returns nothing #extmarks', function()
    buffer('set_mark', buf, ns, marks[1], positions[1][1], positions[1][2])
    rv = buffer('get_marks', buf, ns, {-1, -1}, {-1, -1}, 0, 0)
    eq({}, rv)
  end)


  it('marks move with line insertations #extmarks', function()
    buffer('set_mark', buf, ns, marks[1], 1, 1)
    feed("yyP")
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(1, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 1, 2, 1)
  end)

  it('marks move with multiline insertations #extmarks', function()
    feed("a<cr>22<cr>33<esc>")
    buffer('set_mark', buf, ns, marks[1], 2, 2)
    feed('ggVGyP')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(5, rv[1][2])
    eq(2, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 2, 5, 2)
  end)

  it('marks move with line join #extmarks', function()
    -- do_join in ops.c
    feed("a<cr>222<esc>")
    buffer('set_mark', buf, ns, marks[1], 2, 1)
    feed('ggJ')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(7, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 1, 1, 7)
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
    buffer('set_mark', buf, ns, marks[1], 4, 1)
    feed('2GVGJ')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(9, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 4, 1, 2, 9)
  end)

  it('marks move with line deletes #extmarks', function()
    feed("a<cr>222<cr>333<cr>444<esc>")
    buffer('set_mark', buf, ns, marks[1], 3, 2)
    feed('ggjdd')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(2, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 3, 2, 2, 2)
  end)

  it('marks move with multiline deletes #extmarks', function()
    feed("a<cr>222<cr>333<cr>444<esc>")
    buffer('set_mark', buf, ns, marks[1], 4, 1)
    feed('gg2dd')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(1, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 4, 1, 2, 1)
    -- regression test, undoing multiline delete when mark is on row 1
    feed('ugg3dd')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(1, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 4, 1, 1, 1)
  end)

  it('marks move with open line #extmarks', function()
    -- open_line in misc1.c
    -- testing marks below are also moved
    feed("yyP")
    buffer('set_mark', buf, ns, marks[1], 1, 5)
    buffer('set_mark', buf, ns, marks[2], 2, 5)
    feed('1G<s-o><esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    rv = buffer('get_marks', buf, ns, marks[2], marks[2], 1, 0)
    eq(3, rv[1][2])
    check_undo_redo(buf, ns, marks[1], 1, 5, 2, 5)
    feed('2Go<esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    rv = buffer('get_marks', buf, ns, marks[2], marks[2], 1, 0)
    eq(4, rv[1][2])
    check_undo_redo(buf, ns, marks[1], 2, 5, 2, 5)
    check_undo_redo(buf, ns, marks[2], 3, 5, 4, 5)
  end)

  -- NO idea why this doesn't work... works in program
  pending('marks move with char inserts #extmarks', function()
    -- insertchar in edit.c (the ins_str branch)
    buffer('set_mark', buf, ns, marks[1], 1, 3)
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
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(6, rv[3])
    -- check_undo_redo(buf, ns, marks[1], 1, 3, 1, 6)
  end)

  -- gravity right as definted in tk library
  it('marks have gravity right #extmarks', function()
    -- insertchar in edit.c (the ins_str branch)
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    feed('03l')
    insert("X")
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(3, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 3)

    -- check multibyte chars
    feed('03l<esc>')
    insert("～～")
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(3, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 3)
  end)

  it('we can insert multibyte chars #extmarks', function()
    -- insertchar in edit.c
    feed('a<cr>12345<esc>')
    buffer('set_mark', buf, ns, marks[1], 2, 3)
    -- Insert a fullwidth (two col) tilde, NICE
    feed('0i～<esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(4, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 3, 2, 4)
  end)

  it('marks move with blockwise inserts #extmarks', function()
    -- op_insert in ops.c
    feed('a<cr>12345<esc>')
    buffer('set_mark', buf, ns, marks[1], 2, 3)
    feed('0<c-v>lkI9<esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(4, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 3, 2, 4)
  end)

  it('marks move with line splits (using enter) #extmarks', function()
    -- open_line in misc1.c
    -- testing marks below are also moved
    feed("yyP")
    buffer('set_mark', buf, ns, marks[1], 1, 5)
    buffer('set_mark', buf, ns, marks[2], 2, 5)
    feed('1Gla<cr><esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(3, rv[1][3])
    rv = buffer('get_marks', buf, ns, marks[2], marks[2], 1, 0)
    eq(3, rv[1][2])
    eq(5, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 5, 2, 3)
    check_undo_redo(buf, ns, marks[2], 2, 5, 3, 5)
  end)

  -- TODO mark_col_adjust for normal marks fails in vim/neovim
  -- because flags is 9 in: if (flags & OPENLINE_MARKFIX) {
  it('marks at last line move on insert new line #extmarks', function()
    -- open_line in misc1.c
    buffer('set_mark', buf, ns, marks[1], 1, 5)
    feed('0i<cr><esc>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(2, rv[2])
    eq(5, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 5, 2, 5)
  end)

  it('yet again marks move with line splits #extmarks', function()
    -- the first test above wasn't catching all errors..
    feed("A67890<esc>")
    buffer('set_mark', buf, ns, marks[1], 1, 5)
    feed("04li<cr><esc>")
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(1, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 5, 2, 1)
  end)

  it('and one last time line splits... #extmarks', function()
    buffer('set_mark', buf, ns, marks[1], 1, 2)
    buffer('set_mark', buf, ns, marks[2], 1, 3)
    feed("02li<cr><esc>")
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(2, rv[1][3])
    rv2 = buffer('get_marks', buf, ns, marks[2], marks[2], 1, 0)
    eq(2, rv2[1][2])
    eq(1, rv2[1][3])
  end)

  it('multiple marks move with mark splits #extmarks', function()
    buffer('set_mark', buf, ns, marks[1], 1, 2)
    buffer('set_mark', buf, ns, marks[2], 1, 4)
    feed("0li<cr><esc>")
    rv1 = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    rv2 = buffer('get_marks', buf, ns, marks[2], marks[2], 1, 0)
    eq(2, rv1[1][2])
    eq(1, rv1[1][3])
    eq(2, rv2[1][2])
    eq(3, rv2[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 2, 2, 1)
    check_undo_redo(buf, ns, marks[2], 1, 4, 2, 3)
  end)

  it('deleting on a mark works #extmarks', function()
    -- op_delete in ops.c
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    feed('02lx')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(3, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 3)
  end)

  it('marks move with char deletes #extmarks', function()
    -- op_delete in ops.c
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    feed('02dl')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(1, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 1)
    -- from the other side (nothing should happen)
    feed('$x')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(1, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 1, 1, 1)
  end)

  it('marks move with char deletes over a range #extmarks', function()
    -- op_delete in ops.c
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    buffer('set_mark', buf, ns, marks[2], 1, 4)
    feed('0l3dl<esc>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(2, rv[3])
    rv = buffer('lookup_mark', buf, ns, marks[2])
    eq(1, rv[2])
    eq(2, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 2)
    check_undo_redo(buf, ns, marks[2], 1, 4, 1, 2)
    -- delete 1, nothing should happend to our marks
    feed('u')
    feed('$x')
    rv = buffer('lookup_mark', buf, ns, marks[2])
    eq(1, rv[2])
    eq(4, rv[3])
    check_undo_redo(buf, ns, marks[2], 1, 4, 1, 4)
  end)

  it('deleting marks at end of line works #extmarks', function()
    -- mark_extended.c/extmark_col_adjust_delete
    buffer('set_mark', buf, ns, marks[1], 1, 5)
    feed('$x')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    -- This remains where it is because marks exist
    eq(4, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 5, 1, 4)
  end)

  it('marks move with blockwise deletes #extmarks', function()
    -- op_delete in ops.c
    feed('a<cr>12345<esc>')
    buffer('set_mark', buf, ns, marks[1], 2, 5)
    feed('h<c-v>hhkd')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(2, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 5, 2, 2)
  end)

  it('marks move with blockwise deletes over a range #extmarks', function()
    -- op_delete in ops.c
    feed('a<cr>12345<esc>')
    buffer('set_mark', buf, ns, marks[1], 1, 2)
    buffer('set_mark', buf, ns, marks[2], 1, 4)
    buffer('set_mark', buf, ns, marks[3], 2, 3)
    feed('0<c-v>k3lx')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(1, rv[3])
    rv = buffer('lookup_mark', buf, ns, marks[2])
    eq(1, rv[2])
    eq(1, rv[3])
    rv = buffer('lookup_mark', buf, ns, marks[3])
    eq(2, rv[2])
    eq(1, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 2, 1, 1)
    check_undo_redo(buf, ns, marks[2], 1, 4, 1, 1)
    check_undo_redo(buf, ns, marks[3], 2, 3, 2, 1)
    -- delete 1, nothing should happend to our marks
    feed('u')
    feed('$<c-v>jx')
    rv = buffer('lookup_mark', buf, ns, marks[2])
    eq(1, rv[2])
    eq(4, rv[3])
    rv = buffer('lookup_mark', buf, ns, marks[3])
    eq(2, rv[2])
    eq(3, rv[3])
    check_undo_redo(buf, ns, marks[2], 1, 4, 1, 4)
    check_undo_redo(buf, ns, marks[3], 2, 3, 2, 3)
  end)

  it('works with char deletes over multilines #extmarks', function()
    feed('a<cr>12345<cr>test-me<esc>')
    buffer('set_mark', buf, ns, marks[1], 3, 6)
    feed('gg')
    feed('dv?-m?<cr>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(1, rv[3])
    check_undo_redo(buf, ns, marks[1], 3, 6, 1, 1)
  end)

  it('marks outside of deleted range move with visual char deletes #extmarks', function()
    -- op_delete in ops.c
    buffer('set_mark', buf, ns, marks[1], 1, 4)
    feed('0vx<esc>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(3, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 4, 1, 3)

    feed("u")
    feed('0vlx<esc>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(2, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 4, 1, 2)

    feed("u")
    feed('0v2lx<esc>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(1, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 4, 1, 1)

    -- from the other side (nothing should happen)
    feed('$vx')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(1, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 1, 1, 1)
  end)

  it('marks outside of deleted range move with char deletes #extmarks', function()
    -- op_delete in ops.c
    buffer('set_mark', buf, ns, marks[1], 1, 4)
    feed('0x<esc>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(3, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 4, 1, 3)

    feed("u")
    feed('02x<esc>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(2, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 4, 1, 2)

    feed("u")
    feed('0v3lx<esc>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(1, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 4, 1, 1)

    -- from the other side (nothing should happen)
    feed("u")
    feed('$vx')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq(1, rv[2])
    eq(4, rv[3])
    check_undo_redo(buf, ns, marks[1], 1, 4, 1, 4)
  end)

  it('marks move with P(backward) paste #extmarks', function()
    -- do_put in ops.c
    feed('0iabc<esc>')
    buffer('set_mark', buf, ns, marks[1], 1, 8)
    feed('0veyP')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(16, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 8, 1, 16)
  end)

  it('marks move with p(forward) paste #extmarks', function()
    -- do_put in ops.c
    feed('0iabc<esc>')
    buffer('set_mark', buf, ns, marks[1], 1, 8)
    feed('0veyp')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(15, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 8, 1, 15)
  end)

  it('marks move with blockwise P(backward) paste #extmarks', function()
    -- do_put in ops.c
    feed('a<cr>12345<esc>')
    buffer('set_mark', buf, ns, marks[1], 2, 5)
    feed('<c-v>hhkyP<esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(8, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 5, 2, 8)
  end)

  it('marks move with blockwise p(forward) paste #extmarks', function()
    -- do_put in ops.c
    feed('a<cr>12345<esc>')
    buffer('set_mark', buf, ns, marks[1], 2, 5)
    feed('<c-v>hhkyp<esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(7, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 5, 2, 7)
  end)

  it('replace works #extmarks', function()
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    feed('0r2')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(3, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 3)
  end)

  it('blockwise replace works #extmarks', function()
    feed('a<cr>12345<esc>')
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    feed('0<c-v>llkr1<esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(3, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 3)
  end)

  it('shift line #extmarks', function()
    -- shift_line in ops.c
    feed(':set shiftwidth=4<cr><esc>')
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    feed('0>>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(7, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 7)

    feed('>>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(11, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 7, 1, 11)

    feed('<LT><LT>') -- have to escape, same as <<
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(7, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 11, 1, 7)
  end)

  it('blockwise shift #extmarks', function()
    -- shift_block in ops.c
    feed(':set shiftwidth=4<cr><esc>')
    feed('a<cr>12345<esc>')
    buffer('set_mark', buf, ns, marks[1], 2, 3)
    feed('0<c-v>k>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(7, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 3, 2, 7)
    feed('<c-v>j>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(11, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 7, 2, 11)

    feed('<c-v>j<LT>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(7, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 11, 2, 7)
  end)

  it('tab works with expandtab #extmarks', function()
    -- ins_tab in edit.c
    feed(':set expandtab<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    feed('0i<tab><tab><esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(7, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 7)
  end)

  it('tabs work #extmarks', function()
    -- ins_tab in edit.c
    feed(':set noexpandtab<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed(':set softtabstop=2<cr><esc>')
    feed(':set tabstop=8<cr><esc>')
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    feed('0i<tab><esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(5, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 5)
    -- insert a char before FIXME, #manualgood..
    feed('0iX<tab><esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(7, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 5, 1, 7)
  end)

  it('marks move when using :move #extmarks', function()
    buffer('set_mark', buf, ns, marks[1], 1, 1)
    feed('A<cr>2<esc>:1move 2<cr><esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(1, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 1, 1, 2, 1)
    -- test codepath when moving lines up
    feed(':2move 0<cr><esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(1, rv[1][2])
    eq(1, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 1, 1, 1)
  end)

  it('marks move when using :move part 2 #extmarks', function()
    -- make sure we didn't get lucky with the math...
    feed('A<cr>2<cr>3<cr>4<cr>5<cr>6<esc>')
    buffer('set_mark', buf, ns, marks[1], 2, 1)
    feed(':2,3move 5<cr><esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(4, rv[1][2])
    eq(1, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 2, 1, 4, 1)
    -- test codepath when moving lines up
    feed(':4,5move 1<cr><esc>')
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    eq(2, rv[1][2])
    eq(1, rv[1][3])
    check_undo_redo(buf, ns, marks[1], 4, 1, 2, 1)
  end)

  it('undo and redo of set and unset marks #extmarks', function()
    -- Force a new undo head
    feed('o<esc>')
    buffer('set_mark', buf, ns, marks[1], 1, 2)
    feed('o<esc>')
    buffer('set_mark', buf, ns, marks[2], 1, 8)
    buffer('set_mark', buf, ns, marks[3], 1, 9)
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)

    feed("u")
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    eq(1, table.getn(rv))

    feed("<c-r>")
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    eq(3, table.getn(rv))

    -- Test updates
    feed('o<esc>')
    buffer('set_mark', buf, ns, marks[1], positions[1][1], positions[1][2])
    rv = buffer('get_marks', buf, ns, marks[1], marks[1], 1, 0)
    feed("u")
    feed("<c-r>")
    check_undo_redo(buf, ns, marks[1], 1, 2, positions[1][1], positions[1][2])

    -- Test unset
    feed('o<esc>')
    buffer('del_mark', buf, ns, marks[3])
    feed("u")
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    eq(3, table.getn(rv))
    feed("<c-r>")
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    eq(2, table.getn(rv))
  end)

  it('undo and redo of marks deleted during edits #extmarks', function()
    -- test extmark_adjust
    feed('A<cr>12345<esc>')
    buffer('set_mark', buf, ns, marks[1], 2, 3)
    feed('dd')
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    eq(0, table.getn(rv))
    feed("u")
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    eq(1, table.getn(rv))
    feed("<c-r>")
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    eq(0, table.getn(rv))
  end)

  it('namespaces work properly #extmarks', function()
    rv = buffer('set_mark', buf, ns, marks[1], positions[1][1], positions[1][2])
    eq(1, rv)
    rv = buffer('set_mark', buf, ns2, marks[1], positions[1][1], positions[1][2])
    eq(1, rv)
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    eq(1, table.getn(rv))
    rv = buffer('get_marks', buf, ns2, TO_START, TO_END, ALL, 0)
    eq(1, table.getn(rv))

    -- Set more marks for testing the ranges
    rv = buffer('set_mark', buf, ns, marks[2], positions[2][1], positions[2][2])
    rv = buffer('set_mark', buf, ns, marks[3], positions[3][1], positions[3][2])
    rv = buffer('set_mark', buf, ns2, marks[2], positions[2][1], positions[2][2])
    rv = buffer('set_mark', buf, ns2, marks[3], positions[3][1], positions[3][2])

    -- get_next (amount set)
    rv = buffer('get_marks', buf, ns, TO_START, positions[2], 1, 0)
    eq(1, table.getn(rv))
    rv = buffer('get_marks', buf, ns2, TO_START, positions[2], 1, 0)
    eq(1, table.getn(rv))
    -- get_prev (amount set)
    rv = buffer('get_marks', buf, ns, TO_START, positions[1], 1, 1)
    eq(1, table.getn(rv))
    rv = buffer('get_marks', buf, ns2, TO_START, positions[1], 1, 1)
    eq(1, table.getn(rv))

    -- get_next (amount not set)
    rv = buffer('get_marks', buf, ns, positions[1], positions[2], ALL, 0)
    eq(2, table.getn(rv))
    rv = buffer('get_marks', buf, ns2, positions[1], positions[2], ALL, 0)
    eq(2, table.getn(rv))
    -- get_prev (amount not set)
    rv = buffer('get_marks', buf, ns, positions[1], positions[2], ALL, 1)
    eq(2, table.getn(rv))
    rv = buffer('get_marks', buf, ns2, positions[1], positions[2], ALL, 1)
    eq(2, table.getn(rv))

    buffer('del_mark', buf, ns, marks[1])
    rv = buffer('get_marks', buf, ns, TO_START, TO_END, ALL, 0)
    eq(2, table.getn(rv))
    buffer('del_mark', buf, ns2, marks[1])
    rv = buffer('get_marks', buf, ns2, TO_START, TO_END, ALL, 0)
    eq(2, table.getn(rv))
  end)

  it('mark set can create unique identifiers #extmarks', function()
    local id = 0;
    -- id is 0
    rv = buffer('set_mark', buf, ns, marks[1], positions[1][1], positions[1][2])
    eq(1, rv)
    -- id should be + 1
    id = buffer('set_mark', buf, ns, RANDOM_MARK_ID, positions[1][1], positions[1][2])
    eq(1 + 1, id)
    -- id is 3
    rv = buffer('set_mark', buf, ns, 3, positions[2][1], positions[2][2])
    eq(1, rv)
    id = buffer('set_mark', buf, ns, RANDOM_MARK_ID, positions[1][1], positions[1][2])
    eq(1 + 3, id)
  end)

  it('auto indenting with enter works #extmarks', function()
    -- op_reindent in ops.c
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed("0iint <esc>A {1M1<esc>b<esc>")
    -- Set the mark on the M, should move..
    buffer('set_mark', buf, ns, marks[1], 1, 13)
    -- Set the mark before the cursor, should stay there
    buffer('set_mark', buf, ns, marks[2], 1, 11)
    feed("i<cr><esc>")
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 2, 4}, rv)
    rv = buffer('lookup_mark', buf, ns, marks[2])
    eq({marks[2], 1, 11}, rv)
    check_undo_redo(buf, ns, marks[1], 1, 13, 2, 4)
  end)

  it('auto indenting entire line works #extmarks', function()
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    -- <c-f> will force an indent of 2
    feed("0iint <esc>A {<cr><esc>0i1M1<esc>")
    buffer('set_mark', buf, ns, marks[1], 2, 2)
    feed("0i<c-f><esc>")
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 2, 4}, rv)
    check_undo_redo(buf, ns, marks[1], 2, 2, 2, 4)
    -- now check when cursor at eol
    feed("uA<c-f><esc>")
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 2, 4}, rv)
  end)

  it('removing auto indenting with <C-D> works #extmarks', function()
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed("0i<tab><esc>")
    buffer('set_mark', buf, ns, marks[1], 1, 4)
    feed("bi<c-d><esc>")
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 1, 2}, rv)
    check_undo_redo(buf, ns, marks[1], 1, 4, 1, 2)
    -- check when cursor at eol
    feed("uA<c-d><esc>")
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 1, 2}, rv)
  end)

  it('indenting multiple lines with = works #extmarks', function()
    feed(':set cindent<cr><esc>')
    feed(':set autoindent<cr><esc>')
    feed(':set shiftwidth=2<cr><esc>')
    feed("0iint <esc>A {<cr><bs>1M1<cr><bs>2M2<esc>")
    buffer('set_mark', buf, ns, marks[1], 2, 2)
    buffer('set_mark', buf, ns, marks[2], 3, 2)
    feed('=gg')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 2, 4}, rv)
    rv = buffer('lookup_mark', buf, ns, marks[2])
    eq({marks[2], 3, 6}, rv)
    check_undo_redo(buf, ns, marks[1], 2, 2, 2, 4)
  end)

  -- How should substitue of marks be implemented so that
  -- tagging of a range is substitued like libre? Just delete all?
  --   mm so i guess if an on insert autocmd is used, it would be possible
  --   to reapply the tag on the range.
  it('substitutes by deleting inside the replace matches #extmarks', function()
    -- do_sub in ex_cmds.c
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    buffer('set_mark', buf, ns, marks[2], 1, 4)
    feed(':s/34/xx<cr>')
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 5)
    check_undo_redo(buf, ns, marks[2], 1, 4, 1, 5)
  end)

  it('substitutes when insert text > deleted #extmarks', function()
    -- do_sub in ex_cmds.c
    buffer('set_mark', buf, ns, marks[1], 1, 3)
    buffer('set_mark', buf, ns, marks[2], 1, 4)
    feed(':s/34/xxx<cr>')
    check_undo_redo(buf, ns, marks[1], 1, 3, 1, 6)
    check_undo_redo(buf, ns, marks[2], 1, 4, 1, 6)
  end)

  it('using <c-a> when increase in order of magnitude #extmarks', function()
    -- do_addsub in ops.c
    feed('ddi9 abc<esc>H')
    -- when going from 9 to 10, mark on 9 shouldn't move
    buffer('set_mark', buf, ns, marks[1], 1, 1)
    -- but things after the inserted number should be moved
    buffer('set_mark', buf, ns, marks[2], 1, 3)
    feed('<c-a>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 1, 1}, rv)
    rv = buffer('lookup_mark', buf, ns, marks[2])
    eq({marks[2], 1, 4}, rv)
    check_undo_redo(buf, ns, marks[2], 1, 3, 1, 4)
  end)

  it('using <c-x> when decrease in order of magnitude #extmarks', function()
    -- do_addsub in ops.c
    feed('ddiab.10<esc>')
    -- when going from 10 to 9, mark on 0 should move
    buffer('set_mark', buf, ns, marks[1], 1, 5)
    -- the mark before hsouldn't move
    buffer('set_mark', buf, ns, marks[2], 1, 3)
    feed('b<c-x>')
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 1, 4}, rv)
    rv = buffer('lookup_mark', buf, ns, marks[2])
    eq({marks[2], 1, 3}, rv)
    check_undo_redo(buf, ns, marks[1], 1, 5, 1, 4)
  end)

  -- TODO catch exceptions
  pending('throws consistent error codes #todo', function()
    local buf_invalid = 9
    local ns_invalid = ns2 + 1
    rv = buffer('set_mark', buf_invalid, ns, marks[1], positions[1][1], positions[1][2])
    rv = buffer('del_mark', buf_invalid, ns, marks[1])
    rv = buffer('get_marks', buf_invalid, ns, positions[1], positions[2], ALL, 0)
    rv = buffer('lookup_mark', buf_invalid, ns, marks[1])
    rv = buffer('set_mark', buf, ns_invalid, marks[1], positions[1][1], positions[1][2])
    rv = buffer('del_mark', buf, ns_invalid, marks[1])
    rv = buffer('get_marks', buf, ns_invalid, positions[1], positions[2], ALL, 0)
    rv = buffer('lookup_mark', buf, ns_invalid, marks[1])

  end)

  it('when col > line-length, set the mark on eol #extmarks', function()
    local invalid_col = init_text:len() + 1
    buffer('set_mark', buf, ns, marks[1], 1, invalid_col)
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 1, init_text:len() + 1}, rv)
    -- Test another
    local invalid_col = init_text:len() + 2
    buffer('set_mark', buf, ns, marks[1], 1, invalid_col)
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 1, init_text:len() + 1}, rv)
  end)

  it('when line > line, set the mark on end of buffer #extmarks', function()
    local invalid_col = init_text:len() + 1
    local invalid_lnum = 3 -- line1 ends in an eol. so line 2 contains a valid position (eol)?
    buffer('set_mark', buf, ns, marks[1], invalid_lnum, invalid_col)
    rv = buffer('lookup_mark', buf, ns, marks[1])
    eq({marks[1], 2, 1}, rv)
  end)

end)
