local helpers = require('test.functional.helpers')(after_each)
local setpos = helpers.funcs.setpos
local getpos = helpers.funcs.getpos
local insert = helpers.insert
local clear = helpers.clear
local command = helpers.command
local eval = helpers.eval
local eq = helpers.eq
local exc_exec = helpers.exc_exec


describe('setpos() function', function()
  before_each(function()
    clear()
    insert([[
    First line of text
    Second line of text
    Third line of text]])
    command('new')
    insert([[
    Line of text 1
    Line of text 2
    Line of text 3]])
  end)
  it('can set the current cursor position', function()
    setpos(".", {0, 2, 1, 0})
    eq(getpos("."), {0, 2, 1, 0})
    setpos(".", {2, 1, 1, 0})
    eq(getpos("."), {0, 1, 1, 0})
    local ret = exc_exec('call setpos(".", [1, 1, 1, 0])')
    eq(0, ret)
  end)
  it('can set lowercase marks in the current buffer', function()
    setpos("'d", {0, 2, 1, 0})
    eq(getpos("'d"), {0, 2, 1, 0})
    command('undo')
    command('call setpos("\'d", [2, 3, 1, 0])')
    eq(getpos("'d"), {0, 3, 1, 0})
  end)
  it('can set lowercase marks in other buffers', function()
    local retval = setpos("'d", {1, 2, 1, 0})
    eq(0, retval)
    setpos("'d", {1, 2, 1, 0})
    eq(getpos("'d"), {0, 0, 0, 0})
    command('wincmd w')
    eq(eval('bufnr("%")'), 1)
    eq(getpos("'d"), {0, 2, 1, 0})
  end)
  it("fails when setting a mark in a buffer that doesn't exist", function()
    local retval = setpos("'d", {3, 2, 1, 0})
    eq(-1, retval)
    eq(getpos("'d"), {0, 0, 0, 0})
    retval = setpos("'D", {3, 2, 1, 0})
    eq(-1, retval)
    eq(getpos("'D"), {0, 0, 0, 0})
  end)
  it('can set uppercase marks', function()
    setpos("'D", {2, 2, 3, 0})
    eq(getpos("'D"), {2, 2, 3, 0})
    -- Can set a mark in another buffer
    setpos("'D", {1, 2, 2, 0})
    eq(getpos("'D"), {1, 2, 2, 0})
  end)
end)
