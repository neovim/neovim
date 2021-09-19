local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local funcs = helpers.funcs
local feed = helpers.feed
local exec_capture = helpers.exec_capture
local write_file = helpers.write_file

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
