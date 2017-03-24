local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local insert = helpers.insert
local feed = helpers.feed
local expect = helpers.expect
local execute = helpers.execute
local funcs = helpers.funcs
local foldlevel, foldclosedend = funcs.foldlevel, funcs.foldclosedend
local eq = helpers.eq

describe('Folds', function()
  clear()
  before_each(function() execute('enew!') end)
  it('manual folding adjusts with filter', function()
    insert([[
    1
    2
    3
    4
    5
    6
    7
    8
    9
    10
    11
    12
    13
    14
    15
    16
    17
    18
    19
    20]])
    execute('4,$fold', '%foldopen', '10,$fold', '%foldopen')
    execute('1,8! cat')
    feed('5ggzdzMGdd')
    expect([[
    1
    2
    3
    4
    5
    6
    7
    8
    9]])
  end)
  describe('adjusting folds after :move', function()
    local function manually_fold_indent()
      -- setting foldmethod twice is a trick to get vim to set the folds for me
      execute('set foldmethod=indent', 'set foldmethod=manual')
      -- Ensure that all folds will get closed (makes it easier to test the
      -- length of folds).
      execute('set foldminlines=0')
      -- Start with all folds open (so :move ranges aren't affected by closed
      -- folds).
      execute('%foldopen!')
    end

    local function get_folds()
      local rettab = {}
      for i = 1, funcs.line('$') do
        table.insert(rettab, foldlevel(i))
      end
      return rettab
    end

    local function test_move_indent(insert_string, move_command)
      -- This test is easy because we just need to ensure that the resulting
      -- fold is the same as calculated when creating folds from scratch.
      insert(insert_string)
      execute(move_command)
      local after_move_folds = get_folds()
      -- Doesn't change anything, but does call foldUpdateAll()
      execute('set foldminlines=0')
      eq(after_move_folds, get_folds())
      -- Set up the buffer with insert_string for the manual fold testing.
      execute('enew!')
      insert(insert_string)
      manually_fold_indent()
      execute(move_command)
    end

    it('neither closes nor corrupts folds', function()
      test_move_indent([[
a
	a
	a
	a
	a
	a
a
	a
	a
		a
	a
	a
a
	a
	a
	a
	a
	a]], '7,12m0')
      expect([[
a
	a
	a
		a
	a
	a
a
	a
	a
	a
	a
	a
a
	a
	a
	a
	a
	a]])
      -- lines are not closed, folds are correct
      for i = 1,funcs.line('$') do
        eq(-1, funcs.foldclosed(i))
        if i == 1 or i == 7 or i == 13 then
          eq(0, foldlevel(i))
        elseif i == 4 then
          eq(2, foldlevel(i))
        else
          eq(1, foldlevel(i))
        end
      end
      -- folds are not corrupted
      feed('zM')
      eq(6, foldclosedend(2))
      eq(12, foldclosedend(8))
      eq(18, foldclosedend(14))
    end)
    it("doesn't split a fold when the move is within it", function()
      test_move_indent([[
a
	a
	a
		a
		a
		a
		a
	a
	a
a]], '5m6')
      eq({0, 1, 1, 2, 2, 2, 2, 1, 1, 0}, get_folds())
    end)
    it('truncates folds that end in the moved range', function()
      test_move_indent([[
a
	a
		a
		a
		a
a
a]], '4,5m6')
      eq({0, 1, 2, 0, 0, 0, 0}, get_folds())
    end)
    it('moves folds that start between moved range and destination', function()
      test_move_indent([[
a
	a
	a
	a
	a
a
a
	a
		a
	a
a
a
	a]], '3,4m$')
      eq({0, 1, 1, 0, 0, 1, 2, 1, 0, 0, 1, 0, 0}, get_folds())
    end)
    it('does not affect folds outside changed lines', function()
      test_move_indent([[
	a
	a
	a
a
a
a
	a
	a
	a]], '4m5')
      eq({1, 1, 1, 0, 0, 0, 1, 1, 1}, get_folds())
    end)
    it('moves and truncates folds that start in moved range', function()
      test_move_indent([[
a
	a
		a
		a
		a
a
a
a
a
a]], '1,3m7')
      eq({0, 0, 0, 0, 0, 1, 2, 0, 0, 0}, get_folds())
    end)
    it('breaks a fold when moving text into it', function()
      test_move_indent([[
a
	a
		a
		a
		a
a
a]], '$m4')
      eq({0, 1, 2, 2, 0, 0, 0}, get_folds())
    end)
    it('adjusts correctly when moving a range backwards', function()
      test_move_indent([[
a
	a
		a
		a
a]], '2,3m0')
      eq({1, 2, 0, 0, 0}, get_folds())
    end)
  end)
end)
