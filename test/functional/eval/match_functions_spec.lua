local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = helpers.eq
local clear = helpers.clear
local funcs = helpers.funcs
local command = helpers.command
local exc_exec = helpers.exc_exec
local expect_err = helpers.expect_err

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
    expect_err('E28: No such highlight group name: 1', funcs.setmatches,
               {{group=1, pattern=2, id=3, priority=4}})
    eq({}, funcs.getmatches())
    expect_err('E28: No such highlight group name: 1', funcs.setmatches,
               {{group=1, pos1={2}, pos2={6}, id=3, priority=4, conceal=5}})
    eq({}, funcs.getmatches())
  end)
end)

describe('matchadd()', function()
  it('correctly works when first two arguments and conceal are numbers at once',
  function()
    command('hi def link 1 PreProc')
    eq(4, funcs.matchadd(1, 2, 3, 4, {conceal=5}))
    eq({{
      group='1',
      pattern='2',
      priority=3,
      id=4,
      conceal='5',
    }}, funcs.getmatches())
  end)
end)

describe('matchaddpos()', function()
  it('errors out on invalid input', function()
    command('hi clear PreProc')
    eq('Vim(let):E5030: Empty list at position 0',
       exc_exec('let val = matchaddpos("PreProc", [[]])'))
    eq('Vim(let):E5030: Empty list at position 1',
       exc_exec('let val = matchaddpos("PreProc", [1, v:_null_list])'))
    eq('Vim(let):E5031: List or number required at position 1',
       exc_exec('let val = matchaddpos("PreProc", [1, v:_null_dict])'))
  end)
  it('works with 0 lnum', function()
    command('hi clear PreProc')
    eq(4, funcs.matchaddpos('PreProc', {1}, 3, 4))
    eq({{
      group='PreProc',
      pos1 = {1},
      priority=3,
      id=4,
    }}, funcs.getmatches())
    funcs.matchdelete(4)
    eq(4, funcs.matchaddpos('PreProc', {{0}, 1}, 3, 4))
    eq({{
      group='PreProc',
      pos1 = {1},
      priority=3,
      id=4,
    }}, funcs.getmatches())
    funcs.matchdelete(4)
    eq(4, funcs.matchaddpos('PreProc', {0, 1}, 3, 4))
    eq({{
      group='PreProc',
      pos1 = {1},
      priority=3,
      id=4,
    }}, funcs.getmatches())
  end)
  it('works with negative numbers', function()
    command('hi clear PreProc')
    eq(4, funcs.matchaddpos('PreProc', {-10, 1}, 3, 4))
    eq({{
      group='PreProc',
      pos1 = {1},
      priority=3,
      id=4,
    }}, funcs.getmatches())
    funcs.matchdelete(4)
    eq(4, funcs.matchaddpos('PreProc', {{-10}, 1}, 3, 4))
    eq({{
      group='PreProc',
      pos1 = {1},
      priority=3,
      id=4,
    }}, funcs.getmatches())
    funcs.matchdelete(4)
    eq(4, funcs.matchaddpos('PreProc', {{2, -1}, 1}, 3, 4))
    eq({{
      group='PreProc',
      pos1 = {1},
      priority=3,
      id=4,
    }}, funcs.getmatches())
    funcs.matchdelete(4)
    eq(4, funcs.matchaddpos('PreProc', {{2, 0, -1}, 1}, 3, 4))
    eq({{
      group='PreProc',
      pos1 = {1},
      priority=3,
      id=4,
    }}, funcs.getmatches())
  end)
  it('works with zero length', function()
    local screen = Screen.new(40, 5)
    screen:attach()
    funcs.setline(1, 'abcdef')
    command('hi PreProc guifg=Red')
    eq(4, funcs.matchaddpos('PreProc', {{1, 2, 0}}, 3, 4))
    eq({{
      group='PreProc',
      pos1 = {1, 2, 0},
      priority=3,
      id=4,
    }}, funcs.getmatches())
    screen:expect([[
      ^a{1:b}cdef                                  |
      {2:~                                       }|
      {2:~                                       }|
      {2:~                                       }|
                                              |
    ]], {[1] = {foreground = Screen.colors.Red}, [2] = {bold = true, foreground = Screen.colors.Blue1}})
  end)
end)
