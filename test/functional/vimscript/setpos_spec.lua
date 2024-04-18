local t = require('test.functional.testutil')()
local setpos = t.fn.setpos
local getpos = t.fn.getpos
local insert = t.insert
local clear = t.clear
local command = t.command
local eval = t.eval
local eq = t.eq
local exc_exec = t.exc_exec

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
    setpos('.', { 0, 2, 1, 0 })
    eq({ 0, 2, 1, 0 }, getpos('.'))
    setpos('.', { 2, 1, 1, 0 })
    eq({ 0, 1, 1, 0 }, getpos('.'))
    local ret = exc_exec('call setpos(".", [1, 1, 1, 0])')
    eq(0, ret)
  end)
  it('can set lowercase marks in the current buffer', function()
    setpos("'d", { 0, 2, 1, 0 })
    eq({ 0, 2, 1, 0 }, getpos("'d"))
    command('undo')
    command('call setpos("\'d", [2, 3, 1, 0])')
    eq({ 0, 3, 1, 0 }, getpos("'d"))
  end)
  it('can set lowercase marks in other buffers', function()
    local retval = setpos("'d", { 1, 2, 1, 0 })
    eq(0, retval)
    setpos("'d", { 1, 2, 1, 0 })
    eq({ 0, 0, 0, 0 }, getpos("'d"))
    command('wincmd w')
    eq(1, eval('bufnr("%")'))
    eq({ 0, 2, 1, 0 }, getpos("'d"))
  end)
  it("fails when setting a mark in a buffer that doesn't exist", function()
    local retval = setpos("'d", { 3, 2, 1, 0 })
    eq(-1, retval)
    eq({ 0, 0, 0, 0 }, getpos("'d"))
    retval = setpos("'D", { 3, 2, 1, 0 })
    eq(-1, retval)
    eq({ 0, 0, 0, 0 }, getpos("'D"))
  end)
  it('can set uppercase marks', function()
    setpos("'D", { 2, 2, 3, 0 })
    eq({ 2, 2, 3, 0 }, getpos("'D"))
    -- Can set a mark in another buffer
    setpos("'D", { 1, 2, 2, 0 })
    eq({ 1, 2, 2, 0 }, getpos("'D"))
  end)
end)
