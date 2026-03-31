local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local eval = n.eval
local feed = n.feed
local clear = n.clear
local fn = n.fn
local api = n.api
local command = n.command
local exc_exec = n.exc_exec
local pcall_err = t.pcall_err
local exec_capture = n.exec_capture

before_each(clear)

local function changedtick()
  local ct = api.nvim_buf_get_changedtick(0)
  eq(ct, api.nvim_buf_get_var(0, 'changedtick'))
  eq(ct, api.nvim_buf_get_var(0, 'changedtick'))
  eq(ct, eval('b:changedtick'))
  eq(ct, eval('b:["changedtick"]'))
  eq(ct, eval('b:.changedtick'))
  eq(ct, fn.getbufvar('%', 'changedtick'))
  eq(ct, fn.getbufvar('%', '').changedtick)
  eq(ct, eval('b:').changedtick)
  return ct
end

describe('b:changedtick', function()
  -- Ported tests from Vim-8.0.333
  it('increments', function() -- Test_changedtick_increments
    -- New buffer has an empty line, tick starts at 2
    eq(2, changedtick())
    fn.setline(1, 'hello')
    eq(3, changedtick())
    eq(0, exc_exec('undo'))
    -- Somehow undo counts as two changes
    eq(5, changedtick())
  end)
  it('is present in b: dict', function()
    eq(2, changedtick())
    command('let d = b:')
    eq(2, api.nvim_get_var('d').changedtick)
  end)
  it('increments at bdel', function()
    command('new')
    eq(2, changedtick())
    local bnr = api.nvim_buf_get_number(0)
    eq(2, bnr)
    command('bdel')
    eq(3, fn.getbufvar(bnr, 'changedtick'))
    eq(1, api.nvim_buf_get_number(0))
  end)
  it('fails to be changed by user', function()
    local ct = changedtick()
    local ctn = ct + 100500
    eq(0, exc_exec('let d = b:'))
    eq(
      'Vim(let):E46: Cannot change read-only variable "b:changedtick"',
      pcall_err(command, 'let b:changedtick = ' .. ctn)
    )
    eq(
      'Vim(let):E46: Cannot change read-only variable "b:["changedtick"]"',
      pcall_err(command, 'let b:["changedtick"] = ' .. ctn)
    )
    eq(
      'Vim(let):E46: Cannot change read-only variable "b:.changedtick"',
      pcall_err(command, 'let b:.changedtick = ' .. ctn)
    )
    eq(
      'Vim(let):E46: Cannot change read-only variable "d.changedtick"',
      pcall_err(command, 'let d.changedtick = ' .. ctn)
    )
    eq('Key is read-only: changedtick', pcall_err(api.nvim_buf_set_var, 0, 'changedtick', ctn))

    eq(
      'Vim(unlet):E795: Cannot delete variable b:changedtick',
      pcall_err(command, 'unlet b:changedtick')
    )
    eq(
      'Vim(unlet):E46: Cannot change read-only variable "b:.changedtick"',
      pcall_err(command, 'unlet b:.changedtick')
    )
    eq(
      'Vim(unlet):E46: Cannot change read-only variable "b:["changedtick"]"',
      pcall_err(command, 'unlet b:["changedtick"]')
    )
    eq(
      'Vim(unlet):E46: Cannot change read-only variable "d.changedtick"',
      pcall_err(command, 'unlet d.changedtick')
    )
    eq('Key is read-only: changedtick', pcall_err(api.nvim_buf_del_var, 0, 'changedtick'))
    eq(ct, changedtick())

    eq(
      'Vim(let):E46: Cannot change read-only variable "b:["changedtick"]"',
      pcall_err(command, 'let b:["changedtick"] += ' .. ctn)
    )
    eq(
      'Vim(let):E46: Cannot change read-only variable "b:["changedtick"]"',
      pcall_err(command, 'let b:["changedtick"] -= ' .. ctn)
    )
    eq(
      'Vim(let):E46: Cannot change read-only variable "b:["changedtick"]"',
      pcall_err(command, 'let b:["changedtick"] .= ' .. ctn)
    )

    eq(ct, changedtick())

    fn.setline(1, 'hello')

    eq(ct + 1, changedtick())
  end)
  it('is listed in :let output', function()
    eq('b:changedtick         #2', exec_capture(':let b:'))
  end)
  it('fails to unlock b:changedtick', function()
    eq(0, exc_exec('let d = b:'))
    eq(0, fn.islocked('b:changedtick'))
    eq(0, fn.islocked('d.changedtick'))
    eq(
      'Vim(unlockvar):E940: Cannot lock or unlock variable b:changedtick',
      pcall_err(command, 'unlockvar b:changedtick')
    )
    eq(
      'Vim(unlockvar):E46: Cannot change read-only variable "d.changedtick"',
      pcall_err(command, 'unlockvar d.changedtick')
    )
    eq(0, fn.islocked('b:changedtick'))
    eq(0, fn.islocked('d.changedtick'))
    eq(
      'Vim(lockvar):E940: Cannot lock or unlock variable b:changedtick',
      pcall_err(command, 'lockvar b:changedtick')
    )
    eq(
      'Vim(lockvar):E46: Cannot change read-only variable "d.changedtick"',
      pcall_err(command, 'lockvar d.changedtick')
    )
    eq(0, fn.islocked('b:changedtick'))
    eq(0, fn.islocked('d.changedtick'))
  end)
  it('is being completed', function()
    feed(':echo b:<Tab><Home>let cmdline="<End>"<CR>')
    eq('echo b:changedtick', api.nvim_get_var('cmdline'))
  end)
  it('cannot be changed by filter() or map()', function()
    eq(2, changedtick())
    eq(
      'Vim(call):E795: Cannot delete variable filter() argument',
      pcall_err(command, 'call filter(b:, 0)')
    )
    eq(
      'Vim(call):E742: Cannot change value of map() argument',
      pcall_err(command, 'call map(b:, 0)')
    )
    eq(
      'Vim(call):E742: Cannot change value of map() argument',
      pcall_err(command, 'call map(b:, "v:val")')
    )
    eq(2, changedtick())
  end)
  it('cannot be remove()d', function()
    eq(2, changedtick())
    eq(
      'Vim(call):E795: Cannot delete variable remove() argument',
      pcall_err(command, 'call remove(b:, "changedtick")')
    )
    eq(2, changedtick())
  end)
  it('does not inherit VAR_FIXED when copying dict over', function()
    eq(2, changedtick())
    eq('', exec_capture('let d1 = copy(b:)|let d1.changedtick = 42'))
    eq('', exec_capture('let d2 = copy(b:)|unlet d2.changedtick'))
    eq(2, changedtick())
  end)
end)
