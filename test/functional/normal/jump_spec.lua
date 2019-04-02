local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local funcs = helpers.funcs
local feed = helpers.feed
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
