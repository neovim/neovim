local t = require('test.functional.testutil')(after_each)
local Screen = require('test.functional.ui.screen')

local eq = t.eq
local clear = t.clear
local fn = t.fn
local command = t.command
local exc_exec = t.exc_exec

before_each(clear)

describe('setmatches()', function()
  it('correctly handles case when both group and pattern entries are numbers', function()
    command('hi def link 1 PreProc')
    eq(0, fn.setmatches({ { group = 1, pattern = 2, id = 3, priority = 4 } }))
    eq({
      {
        group = '1',
        pattern = '2',
        id = 3,
        priority = 4,
      },
    }, fn.getmatches())
    eq(0, fn.setmatches({ { group = 1, pattern = 2, id = 3, priority = 4, conceal = 5 } }))
    eq({
      {
        group = '1',
        pattern = '2',
        id = 3,
        priority = 4,
        conceal = '5',
      },
    }, fn.getmatches())
    eq(
      0,
      fn.setmatches({
        { group = 1, pos1 = { 2 }, pos2 = { 6 }, id = 3, priority = 4, conceal = 5 },
      })
    )
    eq({
      {
        group = '1',
        pos1 = { 2 },
        pos2 = { 6 },
        id = 3,
        priority = 4,
        conceal = '5',
      },
    }, fn.getmatches())
  end)

  it('does not fail if highlight group is not defined', function()
    eq(0, fn.setmatches { { group = 1, pattern = 2, id = 3, priority = 4 } })
    eq({ { group = '1', pattern = '2', id = 3, priority = 4 } }, fn.getmatches())
    eq(
      0,
      fn.setmatches {
        { group = 1, pos1 = { 2 }, pos2 = { 6 }, id = 3, priority = 4, conceal = 5 },
      }
    )
    eq(
      { { group = '1', pos1 = { 2 }, pos2 = { 6 }, id = 3, priority = 4, conceal = '5' } },
      fn.getmatches()
    )
  end)
end)

describe('matchadd()', function()
  it('correctly works when first two arguments and conceal are numbers at once', function()
    command('hi def link 1 PreProc')
    eq(4, fn.matchadd(1, 2, 3, 4, { conceal = 5 }))
    eq({
      {
        group = '1',
        pattern = '2',
        priority = 3,
        id = 4,
        conceal = '5',
      },
    }, fn.getmatches())
  end)
end)

describe('matchaddpos()', function()
  it('errors out on invalid input', function()
    command('hi clear PreProc')
    eq(
      'Vim(let):E5030: Empty list at position 0',
      exc_exec('let val = matchaddpos("PreProc", [[]])')
    )
    eq(
      'Vim(let):E5030: Empty list at position 1',
      exc_exec('let val = matchaddpos("PreProc", [1, v:_null_list])')
    )
    eq(
      'Vim(let):E5031: List or number required at position 1',
      exc_exec('let val = matchaddpos("PreProc", [1, v:_null_dict])')
    )
  end)
  it('works with 0 lnum', function()
    command('hi clear PreProc')
    eq(4, fn.matchaddpos('PreProc', { 1 }, 3, 4))
    eq({
      {
        group = 'PreProc',
        pos1 = { 1 },
        priority = 3,
        id = 4,
      },
    }, fn.getmatches())
    fn.matchdelete(4)
    eq(4, fn.matchaddpos('PreProc', { { 0 }, 1 }, 3, 4))
    eq({
      {
        group = 'PreProc',
        pos1 = { 1 },
        priority = 3,
        id = 4,
      },
    }, fn.getmatches())
    fn.matchdelete(4)
    eq(4, fn.matchaddpos('PreProc', { 0, 1 }, 3, 4))
    eq({
      {
        group = 'PreProc',
        pos1 = { 1 },
        priority = 3,
        id = 4,
      },
    }, fn.getmatches())
  end)
  it('works with negative numbers', function()
    command('hi clear PreProc')
    eq(4, fn.matchaddpos('PreProc', { -10, 1 }, 3, 4))
    eq({
      {
        group = 'PreProc',
        pos1 = { 1 },
        priority = 3,
        id = 4,
      },
    }, fn.getmatches())
    fn.matchdelete(4)
    eq(4, fn.matchaddpos('PreProc', { { -10 }, 1 }, 3, 4))
    eq({
      {
        group = 'PreProc',
        pos1 = { 1 },
        priority = 3,
        id = 4,
      },
    }, fn.getmatches())
    fn.matchdelete(4)
    eq(4, fn.matchaddpos('PreProc', { { 2, -1 }, 1 }, 3, 4))
    eq({
      {
        group = 'PreProc',
        pos1 = { 1 },
        priority = 3,
        id = 4,
      },
    }, fn.getmatches())
    fn.matchdelete(4)
    eq(4, fn.matchaddpos('PreProc', { { 2, 0, -1 }, 1 }, 3, 4))
    eq({
      {
        group = 'PreProc',
        pos1 = { 1 },
        priority = 3,
        id = 4,
      },
    }, fn.getmatches())
  end)
  it('works with zero length', function()
    local screen = Screen.new(40, 5)
    screen:attach()
    fn.setline(1, 'abcdef')
    command('hi PreProc guifg=Red')
    eq(4, fn.matchaddpos('PreProc', { { 1, 2, 0 } }, 3, 4))
    eq({
      {
        group = 'PreProc',
        pos1 = { 1, 2, 0 },
        priority = 3,
        id = 4,
      },
    }, fn.getmatches())
    screen:expect(
      [[
      ^a{1:b}cdef                                  |
      {2:~                                       }|*3
                                              |
    ]],
      {
        [1] = { foreground = Screen.colors.Red },
        [2] = { bold = true, foreground = Screen.colors.Blue1 },
      }
    )
  end)
end)
