local t = require('test.functional.testutil')()
local Screen = require('test.functional.ui.screen')
local api = t.api
local clear = t.clear
local command = t.command
local fn = t.fn
local eq = t.eq
local feed = t.feed
local write_file = t.write_file
local pcall_err = t.pcall_err
local cursor = function()
  return t.api.nvim_win_get_cursor(0)
end

describe('named marks', function()
  local file1 = 'Xtestfile-functional-editor-marks'
  local file2 = 'Xtestfile-functional-editor-marks-2'
  before_each(function()
    clear()
    write_file(file1, '1test1\n1test2\n1test3\n1test4', false, false)
    write_file(file2, '2test1\n2test2\n2test3\n2test4', false, false)
  end)
  after_each(function()
    os.remove(file1)
    os.remove(file2)
  end)

  it('can be set', function()
    command('edit ' .. file1)
    command('mark a')
    eq({ 1, 0 }, api.nvim_buf_get_mark(0, 'a'))
    feed('jmb')
    eq({ 2, 0 }, api.nvim_buf_get_mark(0, 'b'))
    feed('jmB')
    eq({ 3, 0 }, api.nvim_buf_get_mark(0, 'B'))
    command('4kc')
    eq({ 4, 0 }, api.nvim_buf_get_mark(0, 'c'))
  end)

  it('errors when set out of range with :mark', function()
    command('edit ' .. file1)
    local err = pcall_err(t.exec_capture, '1000mark x')
    eq('nvim_exec2(): Vim(mark):E16: Invalid range: 1000mark x', err)
  end)

  it('errors when set out of range with :k', function()
    command('edit ' .. file1)
    local err = pcall_err(t.exec_capture, '1000kx')
    eq('nvim_exec2(): Vim(k):E16: Invalid range: 1000kx', err)
  end)

  it('errors on unknown mark name with :mark', function()
    command('edit ' .. file1)
    local err = pcall_err(t.exec_capture, 'mark #')
    eq('nvim_exec2(): Vim(mark):E191: Argument must be a letter or forward/backward quote', err)
  end)

  it("errors on unknown mark name with '", function()
    command('edit ' .. file1)
    local err = pcall_err(t.exec_capture, "normal! '#")
    eq('nvim_exec2(): Vim(normal):E78: Unknown mark', err)
  end)

  it('errors on unknown mark name with `', function()
    command('edit ' .. file1)
    local err = pcall_err(t.exec_capture, 'normal! `#')
    eq('nvim_exec2(): Vim(normal):E78: Unknown mark', err)
  end)

  it("errors when moving to a mark that is not set with '", function()
    command('edit ' .. file1)
    local err = pcall_err(t.exec_capture, "normal! 'z")
    eq('nvim_exec2(): Vim(normal):E20: Mark not set', err)
    err = pcall_err(t.exec_capture, "normal! '.")
    eq('nvim_exec2(): Vim(normal):E20: Mark not set', err)
  end)

  it('errors when moving to a mark that is not set with `', function()
    command('edit ' .. file1)
    local err = pcall_err(t.exec_capture, 'normal! `z')
    eq('nvim_exec2(): Vim(normal):E20: Mark not set', err)
    err = pcall_err(t.exec_capture, 'normal! `>')
    eq('nvim_exec2(): Vim(normal):E20: Mark not set', err)
  end)

  it("errors when moving to a global mark that is not set with '", function()
    command('edit ' .. file1)
    local err = pcall_err(t.exec_capture, "normal! 'Z")
    eq('nvim_exec2(): Vim(normal):E20: Mark not set', err)
  end)

  it('errors when moving to a global mark that is not set with `', function()
    command('edit ' .. file1)
    local err = pcall_err(t.exec_capture, 'normal! `Z')
    eq('nvim_exec2(): Vim(normal):E20: Mark not set', err)
  end)

  it("can move to them using '", function()
    command('args ' .. file1 .. ' ' .. file2)
    feed('j')
    feed('ma')
    feed("G'a")
    eq({ 2, 0 }, cursor())
    feed('mA')
    command('next')
    feed("'A")
    eq(1, api.nvim_get_current_buf())
    eq({ 2, 0 }, cursor())
  end)

  it('can move to them using `', function()
    command('args ' .. file1 .. ' ' .. file2)
    feed('jll')
    feed('ma')
    feed('G`a')
    eq({ 2, 2 }, cursor())
    feed('mA')
    command('next')
    feed('`A')
    eq(1, api.nvim_get_current_buf())
    eq({ 2, 2 }, cursor())
  end)

  it("can move to them using g'", function()
    command('args ' .. file1 .. ' ' .. file2)
    feed('jll')
    feed('ma')
    feed("Gg'a")
    eq({ 2, 0 }, cursor())
    feed('mA')
    command('next')
    feed("g'A")
    eq(1, api.nvim_get_current_buf())
    eq({ 2, 0 }, cursor())
  end)

  it('can move to them using g`', function()
    command('args ' .. file1 .. ' ' .. file2)
    feed('jll')
    feed('ma')
    feed('Gg`a')
    eq({ 2, 2 }, cursor())
    feed('mA')
    command('next')
    feed('g`A')
    eq(1, api.nvim_get_current_buf())
    eq({ 2, 2 }, cursor())
  end)

  it("can move to them using :'", function()
    command('args ' .. file1 .. ' ' .. file2)
    feed('j')
    feed('ma')
    feed('G')
    command("'a")
    eq({ 2, 0 }, cursor())
    feed('mA')
    command('next')
    command("'A")
    eq(1, api.nvim_get_current_buf())
    eq({ 2, 0 }, cursor())
  end)

  it("errors when it can't find the buffer", function()
    command('args ' .. file1 .. ' ' .. file2)
    feed('mA')
    command('next')
    command('bw! ' .. file1)
    local err = pcall_err(t.exec_capture, "normal! 'A")
    eq('nvim_exec2(): Vim(normal):E92: Buffer 1 not found', err)
    os.remove(file1)
  end)

  it('errors when using a mark in another buffer in command range', function()
    feed('ifoo<Esc>mA')
    command('enew')
    feed('ibar<Esc>')
    eq("Vim(print):E20: Mark not set: 'Aprint", pcall_err(command, [['Aprint]]))
  end)

  it("leave a context mark when moving with '", function()
    command('edit ' .. file1)
    feed('llmamA')
    feed('10j0') -- first col, last line
    local pos = cursor()
    feed("'a")
    feed('<C-o>')
    eq(pos, cursor())
    feed("'A")
    feed('<C-o>')
    eq(pos, cursor())
  end)

  it('leave a context mark when moving with `', function()
    command('edit ' .. file1)
    feed('llmamA')
    feed('10j0') -- first col, last line
    local pos = cursor()
    feed('`a')
    feed('<C-o>')
    eq(pos, cursor())
    feed('`A')
    feed('<C-o>')
    eq(pos, cursor())
  end)

  it("leave a context mark when the mark changes buffer with g'", function()
    command('args ' .. file1 .. ' ' .. file2)
    local pos
    feed('GmA')
    command('next')
    pos = cursor()
    command('clearjumps')
    feed("g'A") -- since the mark is in another buffer, it leaves a context mark
    feed('<C-o>')
    eq(pos, cursor())
  end)

  it('leave a context mark when the mark changes buffer with g`', function()
    command('args ' .. file1 .. ' ' .. file2)
    local pos
    feed('GmA')
    command('next')
    pos = cursor()
    command('clearjumps')
    feed('g`A') -- since the mark is in another buffer, it leaves a context mark
    feed('<C-o>')
    eq(pos, cursor())
  end)

  it("do not leave a context mark when moving with g'", function()
    command('edit ' .. file1)
    local pos
    feed('ma')
    pos = cursor() -- Mark pos
    feed('10j0') -- first col, last line
    feed("g'a")
    feed('<C-o>') -- should do nothing
    eq(pos, cursor())
    feed('mA')
    pos = cursor() -- Mark pos
    feed('10j0') -- first col, last line
    feed("g'a")
    feed('<C-o>') -- should do nothing
    eq(pos, cursor())
  end)

  it('do not leave a context mark when moving with g`', function()
    command('edit ' .. file1)
    local pos
    feed('ma')
    pos = cursor() -- Mark pos
    feed('10j0') -- first col, last line
    feed('g`a')
    feed('<C-o>') -- should do nothing
    eq(pos, cursor())
    feed('mA')
    pos = cursor() -- Mark pos
    feed('10j0') -- first col, last line
    feed("g'a")
    feed('<C-o>') -- should do nothing
    eq(pos, cursor())
  end)

  it('open folds when moving to them', function()
    command('edit ' .. file1)
    feed('jzfG') -- Fold from the second line to the end
    command('3mark a')
    feed('G') -- On top of the fold
    assert(fn.foldclosed('.') ~= -1) -- folded
    feed("'a")
    eq(-1, fn.foldclosed('.'))

    feed('zc')
    assert(fn.foldclosed('.') ~= -1) -- folded
    -- TODO: remove this workaround after fixing #15873
    feed('k`a')
    eq(-1, fn.foldclosed('.'))

    feed('zc')
    assert(fn.foldclosed('.') ~= -1) -- folded
    feed("kg'a")
    eq(-1, fn.foldclosed('.'))

    feed('zc')
    assert(fn.foldclosed('.') ~= -1) -- folded
    feed('kg`a')
    eq(-1, fn.foldclosed('.'))
  end)

  it("do not open folds when moving to them doesn't move the cursor", function()
    command('edit ' .. file1)
    feed('jzfG') -- Fold from the second line to the end
    assert(fn.foldclosed('.') == 2) -- folded
    feed('ma')
    feed("'a")
    feed('`a')
    feed("g'a")
    feed('g`a')
    -- should still be folded
    eq(2, fn.foldclosed('.'))
  end)

  it("getting '{ '} '( ') does not move cursor", function()
    api.nvim_buf_set_lines(0, 0, 0, true, { 'aaaaa', 'bbbbb', 'ccccc', 'ddddd', 'eeeee' })
    api.nvim_win_set_cursor(0, { 2, 0 })
    fn.getpos("'{")
    eq({ 2, 0 }, api.nvim_win_get_cursor(0))
    fn.getpos("'}")
    eq({ 2, 0 }, api.nvim_win_get_cursor(0))
    fn.getpos("'(")
    eq({ 2, 0 }, api.nvim_win_get_cursor(0))
    fn.getpos("')")
    eq({ 2, 0 }, api.nvim_win_get_cursor(0))
  end)

  it('in command range does not move cursor #19248', function()
    api.nvim_create_user_command('Test', ':', { range = true })
    api.nvim_buf_set_lines(0, 0, 0, true, { 'aaaaa', 'bbbbb', 'ccccc', 'ddddd', 'eeeee' })
    api.nvim_win_set_cursor(0, { 2, 0 })
    command([['{,'}Test]])
    eq({ 2, 0 }, api.nvim_win_get_cursor(0))
  end)
end)

describe('named marks view', function()
  local file1 = 'Xtestfile-functional-editor-marks'
  local file2 = 'Xtestfile-functional-editor-marks-2'
  local function content()
    local c = {}
    for i = 1, 30 do
      c[i] = i .. ' line'
    end
    return table.concat(c, '\n')
  end
  before_each(function()
    clear()
    write_file(file1, content(), false, false)
    write_file(file2, content(), false, false)
    command('set jumpoptions+=view')
  end)
  after_each(function()
    os.remove(file1)
    os.remove(file2)
  end)

  it('is restored in normal mode but not op-pending mode', function()
    local screen = Screen.new(5, 8)
    screen:attach()
    command('edit ' .. file1)
    feed('<C-e>jWma')
    feed("G'a")
    local expected = [[
      2 line      |
      ^3 line      |
      4 line      |
      5 line      |
      6 line      |
      7 line      |
      8 line      |
                  |
      ]]
    screen:expect({ grid = expected })
    feed('G`a')
    screen:expect([[
      2 line      |
      3 ^line      |
      4 line      |
      5 line      |
      6 line      |
      7 line      |
      8 line      |
                  |
      ]])
    -- not in op-pending mode #20886
    feed('ggj=`a')
    screen:expect([[
      1 line      |
      ^2 line      |
      3 line      |
      4 line      |
      5 line      |
      6 line      |
      7 line      |
                  |
      ]])
  end)

  it('is restored across files', function()
    local screen = Screen.new(5, 5)
    screen:attach()
    command('args ' .. file1 .. ' ' .. file2)
    feed('<C-e>mA')
    local mark_view = [[
    ^2 line      |
    3 line      |
    4 line      |
    5 line      |
                |
    ]]
    screen:expect(mark_view)
    command('next')
    screen:expect([[
    ^1 line      |
    2 line      |
    3 line      |
    4 line      |
                |
    ]])
    feed("'A")
    screen:expect(mark_view)
  end)

  it("fallback to standard behavior when view can't be recovered", function()
    local screen = Screen.new(10, 10)
    screen:attach()
    command('edit ' .. file1)
    feed('7GzbmaG') -- Seven lines from the top
    command('new') -- Screen size for window is now half the height can't be restored
    feed("<C-w>p'a")
    screen:expect([[
                  |
      {1:~           }|*3
      {2:[No Name]   }|
      6 line      |
      ^7 line      |
      8 line      |
      {3:<itor-marks }|
                  |
      ]])
  end)

  it('fallback to standard behavior when mark is loaded from shada', function()
    local screen = Screen.new(10, 6)
    screen:attach()
    command('edit ' .. file1)
    feed('G')
    feed('mA')
    screen:expect([[
      26 line     |
      27 line     |
      28 line     |
      29 line     |
      ^30 line     |
                  |
    ]])
    command('set shadafile=Xtestfile-functional-editor-marks-shada')
    finally(function()
      command('set shadafile=NONE')
      os.remove('Xtestfile-functional-editor-marks-shada')
    end)
    command('wshada!')
    command('bwipe!')
    screen:expect([[
      ^            |
      {1:~           }|*4
                  |
    ]])
    command('rshada!')
    command('edit ' .. file1)
    feed('`"')
    screen:expect([[
      26 line     |
      27 line     |
      28 line     |
      29 line     |
      ^30 line     |
                  |
    ]])
    feed('`A')
    screen:expect_unchanged()
  end)
end)
