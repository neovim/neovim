local helpers = require('test.functional.helpers')(after_each)

local eq = helpers.eq
local clear = helpers.clear
local funcs = helpers.funcs
local command = helpers.command

before_each(clear)

describe('setmatches()', function()
  it('correctly handles case when both group and pattern entries are numbers',
  function()
    command('hi def link 1 PreProc')
    eq(0, funcs.setmatches({{group=1, pattern=2, id=3, priority=4}}))
    eq({{
      group='1',
      pattern='2',
      id=3,
      priority=4,
    }}, funcs.getmatches())
    eq(0, funcs.setmatches({{group=1, pattern=2, id=3, priority=4, conceal=5}}))
    eq({{
      group='1',
      pattern='2',
      id=3,
      priority=4,
      conceal='5',
    }}, funcs.getmatches())
    eq(0, funcs.setmatches({{group=1, pos1={2}, pos2={6}, id=3, priority=4, conceal=5}}))
    eq({{
      group='1',
      pos1={2},
      pos2={6},
      id=3,
      priority=4,
      conceal='5',
    }}, funcs.getmatches())
  end)

  it('fails with -1 if highlight group is not defined', function()
    eq(-1, funcs.setmatches({{group=1, pattern=2, id=3, priority=4}}))
    eq({}, funcs.getmatches())
    eq(-1, funcs.setmatches({{group=1, pos1={2}, pos2={6}, id=3, priority=4, conceal=5}}))
    eq({}, funcs.getmatches())
  end)
end)
