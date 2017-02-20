local helpers = require('test.functional.helpers')(after_each)

local curbufmeths = helpers.curbufmeths
local clear = helpers.clear
local eq = helpers.eq
local neq = helpers.neq
local eval = helpers.eval
local feed = helpers.feed
local funcs = helpers.funcs
local meths = helpers.meths
local command = helpers.command
local exc_exec = helpers.exc_exec
local redir_exec = helpers.redir_exec

before_each(clear)

local function preinc(t, v) t.value = t.value + (v or 1) return t.value end

local function changedtick()
  local ct = curbufmeths.get_changedtick()
  eq(ct, curbufmeths.get_var('changedtick'))
  eq(ct, curbufmeths.get_var('changedtick'))
  eq(ct, eval('b:changedtick'))
  eq(ct, eval('b:["changedtick"]'))
  eq(ct, eval('b:.changedtick'))
  eq(ct, funcs.getbufvar('%', 'changedtick'))
  eq(ct, funcs.getbufvar('%', '').changedtick)
  eq(ct, eval('b:').changedtick)
  return ct
end

describe('b:changedtick', function()
  -- Ported tests from Vim-8.0.333
  it('increments', function()  -- Test_changedtick_increments
    -- New buffer has an empty line, tick starts at 2
    eq(2, changedtick())
    funcs.setline(1, 'hello')
    eq(3, changedtick())
    eq(0, exc_exec('undo'))
    -- Somehow undo counts as two changes
    eq(5, changedtick())
  end)
  it('is present in b: dictionary', function()
    eq(2, changedtick())
    command('let d = b:')
    eq(2, meths.get_var('d').changedtick)
  end)
  it('increments at bdel', function()
    command('new')
    eq(2, changedtick())
    local bnr = curbufmeths.get_number()
    eq(2, bnr)
    command('bdel')
    eq(3, funcs.getbufvar(bnr, 'changedtick'))
    eq(1, curbufmeths.get_number())
  end)
  it('fails to be changed by user', function()
    local ct = changedtick()
    local ctn = ct + 100500
    eq(0, exc_exec('let d = b:'))
    eq('\nE46: Cannot change read-only variable "b:changedtick"',
       redir_exec('let b:changedtick = ' .. ctn))
    eq('\nE46: Cannot change read-only variable "b:["changedtick"] = '..ctn..'"',
       redir_exec('let b:["changedtick"] = ' .. ctn))
    eq('\nE46: Cannot change read-only variable "b:.changedtick = '..ctn..'"',
       redir_exec('let b:.changedtick = ' .. ctn))
    eq('\nE46: Cannot change read-only variable "d.changedtick = '..ctn..'"',
       redir_exec('let d.changedtick = ' .. ctn))
    -- FIXME
    -- eq({fales, ''},
       -- {pcall(curbufmeths.set_var, 'changedtick', ctn)})

    eq('\nE795: Cannot delete variable b:changedtick',
       redir_exec('unlet b:changedtick'))
    eq('\nE46: Cannot change read-only variable "b:.changedtick"',
       redir_exec('unlet b:.changedtick'))
    eq('\nE46: Cannot change read-only variable "b:["changedtick"]"',
       redir_exec('unlet b:["changedtick"]'))
    eq('\nE46: Cannot change read-only variable "d.changedtick"',
       redir_exec('unlet d.changedtick'))
    -- FIXME
    -- eq({},
       -- {pcall(curbufmeths.del_var, 'changedtick')})
    eq(ct, changedtick())

    eq('\nE46: Cannot change read-only variable "b:["changedtick"] += '..ctn..'"',
       redir_exec('let b:["changedtick"] += ' .. ctn))
    eq('\nE46: Cannot change read-only variable "b:["changedtick"] -= '..ctn..'"',
       redir_exec('let b:["changedtick"] -= ' .. ctn))
    eq('\nE46: Cannot change read-only variable "b:["changedtick"] .= '..ctn..'"',
       redir_exec('let b:["changedtick"] .= ' .. ctn))

    eq(ct, changedtick())

    funcs.setline(1, 'hello')

    eq(ct + 1, changedtick())
  end)
  it('is listed in :let output', function()
    eq('\nb:changedtick         #2',
       redir_exec(':let b:'))
  end)
  it('fails to unlock b:changedtick', function()
    -- Note:
    -- - unlocking VAR_FIXED variables is not an error.
    -- - neither VAR_FIXED variables are reported as locked by islocked().
    -- So test mostly checks that b:changedtick status does not change.
    eq(0, exc_exec('let d = b:'))
    eq(1, funcs.islocked('b:changedtick'))
    neq(1, funcs.islocked('d.changedtick'))
    eq('\nE46: Cannot change read-only variable "b:changedtick"',
       redir_exec('unlockvar b:changedtick'))
    eq('\nE46: Cannot change read-only variable "d.changedtick"',
       redir_exec('unlockvar d.changedtick'))
    eq(1, funcs.islocked('b:changedtick'))
    neq(1, funcs.islocked('d.changedtick'))
  end)
  it('is being completed', function()
    feed(':echo b:<Tab><Home>let cmdline="<End>"<CR>')
    eq('echo b:changedtick', meths.get_var('cmdline'))
  end)
end)
