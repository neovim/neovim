local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local clear = n.clear
local command = n.command
local dedent = t.dedent
local eq = t.eq
local fn = n.fn
local feed = n.feed
local exec_capture = n.exec_capture
local write_file = t.write_file
local api = n.api

describe('jumplist', function()
  local fname1 = 'Xtest-functional-normal-jump'
  local fname2 = fname1 .. '2'
  before_each(clear)
  after_each(function()
    os.remove(fname1)
    os.remove(fname2)
  end)

  it('does not add a new entry on startup', function()
    eq('\n jump line  col file/text\n>', fn.execute('jumps'))
  end)

  it('does not require two <C-O> strokes to jump back', function()
    write_file(fname1, 'first file contents')
    write_file(fname2, 'second file contents')

    command('args ' .. fname1 .. ' ' .. fname2)
    local buf1 = fn.bufnr(fname1)
    local buf2 = fn.bufnr(fname2)

    command('next')
    feed('<C-O>')
    eq(buf1, fn.bufnr('%'))

    command('first')
    command('snext')
    feed('<C-O>')
    eq(buf1, fn.bufnr('%'))
    feed('<C-I>')
    eq(buf2, fn.bufnr('%'))
    feed('<C-O>')
    eq(buf1, fn.bufnr('%'))

    command('drop ' .. fname2)
    feed('<C-O>')
    eq(buf1, fn.bufnr('%'))
  end)

  it('<C-O> scrolls cursor halfway when switching buffer #25763', function()
    write_file(fname1, ('foobar\n'):rep(100))
    write_file(fname2, 'baz')

    local screen = Screen.new(5, 25)
    command('set number')
    command('edit ' .. fname1)
    feed('35gg')
    command('edit ' .. fname2)
    feed('<C-O>')
    screen:expect {
      grid = [[
      {1: 24 }foobar  |
      {1: 25 }foobar  |
      {1: 26 }foobar  |
      {1: 27 }foobar  |
      {1: 28 }foobar  |
      {1: 29 }foobar  |
      {1: 30 }foobar  |
      {1: 31 }foobar  |
      {1: 32 }foobar  |
      {1: 33 }foobar  |
      {1: 34 }foobar  |
      {1: 35 }^foobar  |
      {1: 36 }foobar  |
      {1: 37 }foobar  |
      {1: 38 }foobar  |
      {1: 39 }foobar  |
      {1: 40 }foobar  |
      {1: 41 }foobar  |
      {1: 42 }foobar  |
      {1: 43 }foobar  |
      {1: 44 }foobar  |
      {1: 45 }foobar  |
      {1: 46 }foobar  |
      {1: 47 }foobar  |
                  |
    ]],
      attr_ids = {
        [1] = { foreground = Screen.colors.Brown },
      },
    }
  end)
end)

describe("jumpoptions=stack behaves like 'tagstack'", function()
  before_each(function()
    clear()
    feed(':clearjumps<cr>')

    -- Add lines so that we have locations to jump to.
    for i = 1, 101, 1 do
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

    eq(
      ''
        .. ' jump line  col file/text\n'
        .. '   4   102    0 \n'
        .. '   3     1    0 Line 1\n'
        .. '   2    10    0 Line 10\n'
        .. '   1    20    0 Line 20\n'
        .. '>  0    30    0 Line 30\n'
        .. '   1    40    0 Line 40\n'
        .. '   2    50    0 Line 50',
      exec_capture('jumps')
    )

    feed('90gg')

    eq(
      ''
        .. ' jump line  col file/text\n'
        .. '   5   102    0 \n'
        .. '   4     1    0 Line 1\n'
        .. '   3    10    0 Line 10\n'
        .. '   2    20    0 Line 20\n'
        .. '   1    30    0 Line 30\n'
        .. '>',
      exec_capture('jumps')
    )
  end)

  it('does not add the same location twice adjacently', function()
    feed('60gg')
    feed('60gg')

    eq(
      ''
        .. ' jump line  col file/text\n'
        .. '   7   102    0 \n'
        .. '   6     1    0 Line 1\n'
        .. '   5    10    0 Line 10\n'
        .. '   4    20    0 Line 20\n'
        .. '   3    30    0 Line 30\n'
        .. '   2    40    0 Line 40\n'
        .. '   1    50    0 Line 50\n'
        .. '>',
      exec_capture('jumps')
    )
  end)

  it('does add the same location twice nonadjacently', function()
    feed('10gg')
    feed('20gg')

    eq(
      ''
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
      exec_capture('jumps')
    )
  end)
end)

describe('buffer deletion with jumpoptions+=clean', function()
  local base_file = 'Xtest-functional-buffer-deletion'
  local file1 = base_file .. '1'
  local file2 = base_file .. '2'
  local file3 = base_file .. '3'
  local base_content = 'text'
  local content1 = base_content .. '1'
  local content2 = base_content .. '2'
  local content3 = base_content .. '3'

  local function format_jumplist(input)
    return dedent(input)
      :gsub('%{file1%}', file1)
      :gsub('%{file2%}', file2)
      :gsub('%{file3%}', file3)
      :gsub('%{content1%}', content1)
      :gsub('%{content2%}', content2)
      :gsub('%{content3%}', content3)
  end

  before_each(function()
    clear()
    command('clearjumps')

    write_file(file1, content1, false, false)
    write_file(file2, content2, false, false)
    write_file(file3, content3, false, false)

    command('edit ' .. file1)
    command('edit ' .. file2)
    command('edit ' .. file3)
  end)

  after_each(function()
    os.remove(file1)
    os.remove(file2)
    os.remove(file3)
  end)

  it('deletes jump list entries when the current buffer is deleted', function()
    command('edit ' .. file1)

    eq(
      format_jumplist([[
       jump line  col file/text
         3     1    0 {content1}
         2     1    0 {file2}
         1     1    0 {file3}
      >]]),
      exec_capture('jumps')
    )

    command('bwipeout')

    eq(
      format_jumplist([[
       jump line  col file/text
         1     1    0 {file2}
      >  0     1    0 {content3}]]),
      exec_capture('jumps')
    )
  end)

  it('deletes jump list entries when another buffer is deleted', function()
    eq(
      format_jumplist([[
       jump line  col file/text
         2     1    0 {file1}
         1     1    0 {file2}
      >]]),
      exec_capture('jumps')
    )

    command('bwipeout ' .. file2)

    eq(
      format_jumplist([[
       jump line  col file/text
         1     1    0 {file1}
      >]]),
      exec_capture('jumps')
    )
  end)

  it('sets the correct jump index when the current buffer is deleted', function()
    feed('<C-O>')

    eq(
      format_jumplist([[
       jump line  col file/text
         1     1    0 {file1}
      >  0     1    0 {content2}
         1     1    0 {file3}]]),
      exec_capture('jumps')
    )

    command('bw')

    eq(
      format_jumplist([[
       jump line  col file/text
         1     1    0 {file1}
      >  0     1    0 {content3}]]),
      exec_capture('jumps')
    )
  end)

  it('sets the correct jump index when the another buffer is deleted', function()
    feed('<C-O>')

    eq(
      format_jumplist([[
       jump line  col file/text
         1     1    0 {file1}
      >  0     1    0 {content2}
         1     1    0 {file3}]]),
      exec_capture('jumps')
    )

    command('bwipeout ' .. file1)

    eq(
      format_jumplist([[
       jump line  col file/text
      >  0     1    0 {content2}
         1     1    0 {file3}]]),
      exec_capture('jumps')
    )
  end)
end)

describe('buffer deletion with jumpoptions-=clean', function()
  local base_file = 'Xtest-functional-buffer-deletion'
  local file1 = base_file .. '1'
  local file2 = base_file .. '2'
  local base_content = 'text'
  local content1 = base_content .. '1'
  local content2 = base_content .. '2'

  before_each(function()
    clear()
    command('clearjumps')
    command('set jumpoptions-=clean')

    write_file(file1, content1, false, false)
    write_file(file2, content2, false, false)

    command('edit ' .. file1)
    command('edit ' .. file2)
  end)

  after_each(function()
    os.remove(file1)
    os.remove(file2)
  end)

  it('Ctrl-O reopens previous buffer with :bunload or :bdelete #28968', function()
    eq(file2, fn.bufname(''))
    command('bunload')
    eq(file1, fn.bufname(''))
    feed('<C-O>')
    eq(file2, fn.bufname(''))
    command('bdelete')
    eq(file1, fn.bufname(''))
    feed('<C-O>')
    eq(file2, fn.bufname(''))
  end)
end)

describe('jumpoptions=view', function()
  local file1 = 'Xtestfile-functional-editor-jumps'
  local file2 = 'Xtestfile-functional-editor-jumps-2'
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
    command('set jumpoptions=view')
  end)
  after_each(function()
    os.remove(file1)
    os.remove(file2)
  end)

  it('restores the view', function()
    local screen = Screen.new(5, 8)
    command('edit ' .. file1)
    feed('12Gztj')
    feed('gg<C-o>')
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
    command('args ' .. file1 .. ' ' .. file2)
    feed('12Gzt')
    command('next')
    feed('G')
    screen:expect([[
    27 line     |
    28 line     |
    29 line     |
    ^30 line     |
                |
    ]])
    feed('<C-o><C-o>')
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
    command('args ' .. file1 .. ' ' .. file2)
    feed('12Gzt')
    command('next')
    feed('G')
    screen:expect([[
    27 line     |
    28 line     |
    29 line     |
    ^30 line     |
                |
    ]])
    feed('<C-^>')
    screen:expect([[
    ^12 line     |
    13 line     |
    14 line     |
    15 line     |
                |
    ]])
  end)

  it("falls back to standard behavior when view can't be recovered", function()
    local screen = Screen.new(5, 8)
    command('edit ' .. file1)
    feed('7GzbG')
    api.nvim_buf_set_lines(0, 0, 2, true, {})
    -- Move to line 7, and set it as the last line visible on the view with zb, meaning to recover
    -- the view it needs to put the cursor 7 lines from the top line. Then go to the end of the
    -- file, delete 2 lines before line 7, meaning the jump/mark is moved 2 lines up to line 5.
    -- Therefore when trying to jump back to it it's not possible to set a 7 line offset from the
    -- mark position to the top line, since there's only 5 lines from the mark position to line 0.
    -- Therefore falls back to standard behavior which is centering the view/line.
    feed('<C-o>')
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
