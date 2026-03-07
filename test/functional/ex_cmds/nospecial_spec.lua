local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq, command, fn = t.eq, n.command, n.fn
local matches = t.matches
local clear = n.clear

describe(':nospecial', function()
  before_each(function()
    clear()
  end)

  it('opens file with literal pipe in name', function()
    local fname = 'a|b.txt'
    fn.writefile({ 'hello' }, fname)

    command('nospecial edit ' .. fname)
    matches('a|b%.txt$', fn.bufname('%'))
    eq('hello', fn.getline(1))

    local bufname = fn.bufname('%')
    eq(nil, bufname:match('^a$'))

    fn.delete(fname)
  end)

  it('does not expand % as current filename', function()
    -- :edit % -> expands to :edit a.txt
    fn.writefile({ 'hello' }, 'a.txt')
    command('edit a.txt')
    eq('a.txt', fn.bufname('%'):match('[^/]+$'))

    -- :nospecial edit % -> file named '%'
    fn.writefile({ 'world' }, '%')
    command('nospecial edit %')
    matches('%%$', fn.bufname('%'))

    fn.delete('a.txt')
    fn.delete('%')
  end)

  it('does not treat " as a comment', function()
    command('colorscheme default " comment')

    -- :nospecial colorscheme default " comment -> 'default " comment' as name → E185
    local result, err = pcall(command, 'nospecial colorscheme default " comment')
    eq(false, result)
    matches('E185', err)
  end)
end)
