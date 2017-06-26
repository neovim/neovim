local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local insert = helpers.insert
local feed = helpers.feed
local expect = helpers.expect
local feed_command = helpers.feed_command
local funcs = helpers.funcs
local foldlevel = funcs.foldlevel
local foldclosedend = funcs.foldclosedend
local eq = helpers.eq

describe('Folds', function()
  local tempfname = 'Xtest-fold.txt'
  clear()
  before_each(function() feed_command('enew!') end)
  after_each(function() os.remove(tempfname) end)
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
    feed_command('4,$fold', '%foldopen', '10,$fold', '%foldopen')
    feed_command('1,8! cat')
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
      feed_command('set foldmethod=indent', 'set foldmethod=manual')
      -- Ensure that all folds will get closed (makes it easier to test the
      -- length of folds).
      feed_command('set foldminlines=0')
      -- Start with all folds open (so :move ranges aren't affected by closed
      -- folds).
      feed_command('%foldopen!')
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
      feed_command(move_command)
      local after_move_folds = get_folds()
      -- Doesn't change anything, but does call foldUpdateAll()
      feed_command('set foldminlines=0')
      eq(after_move_folds, get_folds())
      -- Set up the buffer with insert_string for the manual fold testing.
      feed_command('enew!')
      insert(insert_string)
      manually_fold_indent()
      feed_command(move_command)
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
    it('handles shifting all remaining folds', function()
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
a]], '13m7')
      eq({1, 2, 2, 2, 1, 2, 2, 1, 1, 1, 2, 2, 2, 1, 0}, get_folds())
    end)
  end)
  it('updates correctly on :read', function()
    -- luacheck: ignore 621
    helpers.write_file(tempfname, [[
    a


    	a]])
    insert([[
    	a
    	a
    	a
    	a
    ]])
    feed_command('set foldmethod=indent', '2', '%foldopen')
    feed_command('read ' .. tempfname)
    -- Just to check we have the correct file text.
    expect([[
    	a
    	a
    a


    	a
    	a
    	a
    ]])
    for i = 1,2 do
      eq(1, funcs.foldlevel(i))
    end
    for i = 3,5 do
      eq(0, funcs.foldlevel(i))
    end
    for i = 6,8 do
      eq(1, funcs.foldlevel(i))
    end
  end)
  it('combines folds when removing separating space', function()
    -- luacheck: ignore 621
    insert([[
    	a
    	a
    a
    a
    a
    	a
    	a
    	a
    ]])
    feed_command('set foldmethod=indent', '3,5d')
    eq(5, funcs.foldclosedend(1))
  end)
  it("doesn't combine folds that have a specified end", function()
    insert([[
    {{{
    }}}



    {{{

    }}}
    ]])
    feed_command('set foldmethod=marker', '3,5d', '%foldclose')
    eq(2, funcs.foldclosedend(1))
  end)
  it('splits folds according to >N and <N with foldexpr', function()
    helpers.source([[
    function TestFoldExpr(lnum)
      let thisline = getline(a:lnum)
      if thisline == 'a'
        return 1
      elseif thisline == 'b'
        return 0
      elseif thisline == 'c'
        return '<1'
      elseif thisline == 'd'
        return '>1'
      endif
      return 0
    endfunction
    ]])
    helpers.write_file(tempfname, [[
    b
    b
    a
    a
    d
    a
    a
    c]])
    insert([[
    a
    a
    a
    a
    a
    a
    ]])
    feed_command('set foldmethod=expr', 'set foldexpr=TestFoldExpr(v:lnum)', '2', 'foldopen')
    feed_command('read ' .. tempfname, '%foldclose')
    eq(2, funcs.foldclosedend(1))
    eq(0, funcs.foldlevel(3))
    eq(0, funcs.foldlevel(4))
    eq(6, funcs.foldclosedend(5))
    eq(10, funcs.foldclosedend(7))
    eq(14, funcs.foldclosedend(11))
  end)
end)
