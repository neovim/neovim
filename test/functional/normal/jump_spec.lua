local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local curbuf_contents = helpers.curbuf_contents
local eq = helpers.eq
local funcs = helpers.funcs
local feed = helpers.feed
local redir_exec = helpers.redir_exec
local write_file = helpers.write_file

local ensure_empty_jumplist = function()
  funcs.execute('clearjumps')
  eq('\n jump line  col file/text\n>', funcs.execute('jumps'))
end

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

  it('adds an entry when * moves the cursor to "first keyword after" in-line #9874', function()
    -- The cursor will start outside a word boundary so * will move the cursor
    -- to "the first keyword after the cursor" and update the jumplist. The
    -- keyword is unique but that doesn't matter here.

    write_file(fname1, ' unique', true)
    command('args '..fname1)

    eq(' unique', curbuf_contents(), 'ensure leading whitespace')

    -- Explicitly move to (0, 0) because of 'nostartofline'.
    feed('0')

    ensure_empty_jumplist()

    feed('*')

    eq(
      '\n jump line  col file/text\n   1     1    0 unique\n>',
      funcs.execute('jumps'))
  end)

  it('adds an entry when * moves the cursor to next match in-line #9874', function()
    -- The cursor will start at the start of a word boundary. The keyword
    -- occurs multiple times in the same line so the cursor will move to the
    -- next occurrence and update the jumplist.

    write_file(fname1, 'dup dup')
    command('args '..fname1)

    eq('dup dup', curbuf_contents(), 'ensure no leading whitespace')

    ensure_empty_jumplist()

    feed('*')

    eq(
      '\n jump line  col file/text\n   1     1    0 dup dup\n>',
      funcs.execute('jumps'))
  end)

  it('adds an entry when * moves the cursor to next match in other line #9874', function()
    -- The cursor will start at the start of a word boundary. The keyword
    -- occurs multiple times in different lines so the cursor will move to the
    -- next occurrence and update the jumplist.

    write_file(fname1, 'dup\ndup')
    command('args '..fname1)

    eq('dup\ndup', curbuf_contents(), 'ensure no leading whitespace')

    ensure_empty_jumplist()

    feed('*')

    eq(
      '\n jump line  col file/text\n   1     1    0 dup\n>',
      funcs.execute('jumps'))
  end)

  it('has regression for: adds an entry when * does not move the cursor #9874', function()
    -- The cursor will start at the start of a word boundary. The keyword is
    -- unique so the cursor stays in place and fails to update the jumplist.
    -- (Actually the jumplist does update, the entry just gets erased).

    write_file(fname1, 'unique')
    command('args '..fname1)

    eq('unique', curbuf_contents(), 'ensure no leading whitespace')

    ensure_empty_jumplist()

    feed('*')

    local regression = function()
      eq(
        '\n jump line  col file/text\n   1     1    0 unique\n>',
        funcs.execute('jumps'))
    end
    assert.has_error(regression)
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

    eq(   '\n'
       .. ' jump line  col file/text\n'
       .. '   4   102    0 \n'
       .. '   3     1    0 Line 1\n'
       .. '   2    10    0 Line 10\n'
       .. '   1    20    0 Line 20\n'
       .. '>  0    30    0 Line 30\n'
       .. '   1    40    0 Line 40\n'
       .. '   2    50    0 Line 50',
       redir_exec('jumps'))

    feed('90gg')

    eq(   '\n'
       .. ' jump line  col file/text\n'
       .. '   5   102    0 \n'
       .. '   4     1    0 Line 1\n'
       .. '   3    10    0 Line 10\n'
       .. '   2    20    0 Line 20\n'
       .. '   1    30    0 Line 30\n'
       .. '>',
       redir_exec('jumps'))
  end)

  it('does not add the same location twice adjacently', function()
    feed('60gg')
    feed('60gg')

    eq(   '\n'
       .. ' jump line  col file/text\n'
       .. '   7   102    0 \n'
       .. '   6     1    0 Line 1\n'
       .. '   5    10    0 Line 10\n'
       .. '   4    20    0 Line 20\n'
       .. '   3    30    0 Line 30\n'
       .. '   2    40    0 Line 40\n'
       .. '   1    50    0 Line 50\n'
       .. '>',
       redir_exec('jumps'))
  end)

  it('does add the same location twice nonadjacently', function()
    feed('10gg')
    feed('20gg')

    eq(   '\n'
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
       redir_exec('jumps'))
  end)
end)
