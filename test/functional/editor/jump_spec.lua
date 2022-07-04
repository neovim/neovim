local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local funcs = helpers.funcs
local feed = helpers.feed
local exec_capture = helpers.exec_capture
local write_file = helpers.write_file
local curbufmeths = helpers.curbufmeths

describe('jumplist', function()
  local fname1 = 'Xtest-functional-normal-jump'
  local fname2 = fname1..'2'
  before_each(clear)
  after_each(function()
    os.remove(fname1)
    os.remove(fname2)
  end)

  it('does not add a new entry on startup', function()
    eq('\n jump line  col file/text\n>', funcs.execute('jumps'))
  end)

  it('does not require two <C-O> strokes to jump back', function()
    write_file(fname1, 'first file contents')
    write_file(fname2, 'second file contents')

    command('args '..fname1..' '..fname2)
    local buf1 = funcs.bufnr(fname1)
    local buf2 = funcs.bufnr(fname2)

    command('next')
    feed('<C-O>')
    eq(buf1, funcs.bufnr('%'))

    command('first')
    command('snext')
    feed('<C-O>')
    eq(buf1, funcs.bufnr('%'))
    feed('<C-I>')
    eq(buf2, funcs.bufnr('%'))
    feed('<C-O>')
    eq(buf1, funcs.bufnr('%'))

    command('drop '..fname2)
    feed('<C-O>')
    eq(buf1, funcs.bufnr('%'))
  end)
end)

describe("jumpoptions=stack behaves like 'tagstack'", function()
  before_each(function()
    clear()
    feed(':clearjumps<cr>')

    -- Add lines so that we have locations to jump to.
    for i = 1,101,1
    do
        feed('iLine ' .. i .. '<cr><esc>')
    end

    -- Jump around to add some locations to the jump list.
    feed('0gg')
    feed('10gg')
    feed('20gg')
    feed('30gg')
    feed('40gg')
    feed('50gg')

    feed(':set jumpoptions=stack<cr>')
  end)

  after_each(function()
      feed('set jumpoptions=')
  end)

  it('discards the tail when navigating from the middle', function()
    feed('<C-O>')
    feed('<C-O>')

    eq(   ''
       .. ' jump line  col file/text\n'
       .. '   4   102    0 \n'
       .. '   3     1    0 Line 1\n'
       .. '   2    10    0 Line 10\n'
       .. '   1    20    0 Line 20\n'
       .. '>  0    30    0 Line 30\n'
       .. '   1    40    0 Line 40\n'
       .. '   2    50    0 Line 50',
       exec_capture('jumps'))

    feed('90gg')

    eq(   ''
       .. ' jump line  col file/text\n'
       .. '   5   102    0 \n'
       .. '   4     1    0 Line 1\n'
       .. '   3    10    0 Line 10\n'
       .. '   2    20    0 Line 20\n'
       .. '   1    30    0 Line 30\n'
       .. '>',
       exec_capture('jumps'))
  end)

  it('does not add the same location twice adjacently', function()
    feed('60gg')
    feed('60gg')

    eq(   ''
       .. ' jump line  col file/text\n'
       .. '   7   102    0 \n'
       .. '   6     1    0 Line 1\n'
       .. '   5    10    0 Line 10\n'
       .. '   4    20    0 Line 20\n'
       .. '   3    30    0 Line 30\n'
       .. '   2    40    0 Line 40\n'
       .. '   1    50    0 Line 50\n'
       .. '>',
       exec_capture('jumps'))
  end)

  it('does add the same location twice nonadjacently', function()
    feed('10gg')
    feed('20gg')

    eq(   ''
       .. ' jump line  col file/text\n'
       .. '   8   102    0 \n'
       .. '   7     1    0 Line 1\n'
       .. '   6    10    0 Line 10\n'
       .. '   5    20    0 Line 20\n'
       .. '   4    30    0 Line 30\n'
       .. '   3    40    0 Line 40\n'
       .. '   2    50    0 Line 50\n'
       .. '   1    10    0 Line 10\n'
       .. '>',
       exec_capture('jumps'))
  end)
end)

describe("jumpoptions=view", function()
  local file1 = 'Xtestfile-functional-editor-jumps'
  local file2 = 'Xtestfile-functional-editor-jumps-2'
  local function content()
    local c = {}
    for i=1,30 do
      c[i] = i .. " line"
    end
    return table.concat(c, "\n")
  end
  before_each(function()
    clear()
    write_file(file1, content(), false, false)
    write_file(file2, content(), false, false)
    command('set jumpoptions=view')
  end)
  after_each(function()
    os.remove(file1)
    os.remove(file2)
  end)

  it('restores the view', function()
    local screen = Screen.new(5, 8)
    screen:attach()
    command("edit " .. file1)
    feed("12Gztj")
    feed("gg<C-o>")
    screen:expect([[
    12 line     |
    ^13 line     |
    14 line     |
    15 line     |
    16 line     |
    17 line     |
    18 line     |
                |
    ]])
  end)

  it('restores the view across files', function()
    local screen = Screen.new(5, 5)
    screen:attach()
    command("args " .. file1 .. " " .. file2)
    feed("12Gzt")
    command("next")
    feed("G")
    screen:expect([[
    27 line     |
    28 line     |
    29 line     |
    ^30 line     |
                |
    ]])
    feed("<C-o><C-o>")
    screen:expect([[
    ^12 line     |
    13 line     |
    14 line     |
    15 line     |
                |
    ]])
  end)

  it('restores the view across files with <C-^>', function()
    local screen = Screen.new(5, 5)
    screen:attach()
    command("args " .. file1 .. " " .. file2)
    feed("12Gzt")
    command("next")
    feed("G")
    screen:expect([[
    27 line     |
    28 line     |
    29 line     |
    ^30 line     |
                |
    ]])
    feed("<C-^>")
    screen:expect([[
    ^12 line     |
    13 line     |
    14 line     |
    15 line     |
                |
    ]])
  end)

  it('falls back to standard behavior when view can\'t be recovered', function()
    local screen = Screen.new(5, 8)
    screen:attach()
    command("edit " .. file1)
    feed("7GzbG")
    curbufmeths.set_lines(0, 2, true, {})
    -- Move to line 7, and set it as the last line visible on the view with zb, meaning to recover
    -- the view it needs to put the cursor 7 lines from the top line. Then go to the end of the
    -- file, delete 2 lines before line 7, meaning the jump/mark is moved 2 lines up to line 5.
    -- Therefore when trying to jump back to it it's not possible to set a 7 line offset from the
    -- mark position to the top line, since there's only 5 lines from the mark position to line 0.
    -- Therefore falls back to standard behavior which is centering the view/line.
    feed("<C-o>")
    screen:expect([[
    4 line      |
    5 line      |
    6 line      |
    ^7 line      |
    8 line      |
    9 line      |
    10 line     |
                |
    ]])
  end)

  it('falls back to standard behavior for a mark without a view', function()
    local screen = Screen.new(5, 8)
    screen:attach()
    command('edit ' .. file1)
    feed('10ggzzvwy')
    screen:expect([[
      7 line      |
      8 line      |
      9 line      |
      ^10 line     |
      11 line     |
      12 line     |
      13 line     |
                  |
    ]])
    feed('`]')
    screen:expect([[
      7 line      |
      8 line      |
      9 line      |
      10 ^line     |
      11 line     |
      12 line     |
      13 line     |
                  |
    ]])
  end)
end)
