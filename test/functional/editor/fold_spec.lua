local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local insert = helpers.insert
local feed = helpers.feed
local expect = helpers.expect
local command = helpers.command
local funcs = helpers.funcs
local eq = helpers.eq
local neq = helpers.neq

describe('Folds', function()
  local tempfname = 'Xtest-fold.txt'

  setup(clear)
  before_each(function() command('bwipe! | new') end)
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
    command('4,$fold')
    command('%foldopen')
    command('10,$fold')
    command('%foldopen')
    command('1,8! cat')
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
      command('setlocal foldmethod=indent')
      command('setlocal foldmethod=manual')
      -- Ensure that all folds will get closed (makes it easier to test the
      -- length of folds).
      command('setlocal foldminlines=0')
      -- Start with all folds open (so :move ranges aren't affected by closed
      -- folds).
      command('%foldopen!')
    end

    local function get_folds()
      local rettab = {}
      for i = 1, funcs.line('$') do
        table.insert(rettab, funcs.foldlevel(i))
      end
      return rettab
    end

    local function test_move_indent(insert_string, move_command)
      -- This test is easy because we just need to ensure that the resulting
      -- fold is the same as calculated when creating folds from scratch.
      insert(insert_string)
      command(move_command)
      local after_move_folds = get_folds()
      -- Doesn't change anything, but does call foldUpdateAll()
      command('setlocal foldminlines=0')
      eq(after_move_folds, get_folds())
      -- Set up the buffer with insert_string for the manual fold testing.
      command('enew!')
      insert(insert_string)
      manually_fold_indent()
      command(move_command)
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
          eq(0, funcs.foldlevel(i))
        elseif i == 4 then
          eq(2, funcs.foldlevel(i))
        else
          eq(1, funcs.foldlevel(i))
        end
      end
      -- folds are not corrupted
      feed('zM')
      eq(6, funcs.foldclosedend(2))
      eq(12, funcs.foldclosedend(8))
      eq(18, funcs.foldclosedend(14))
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
    command('setlocal foldmethod=indent')
    command('2')
    command('%foldopen')
    command('read ' .. tempfname)
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
    command('setlocal foldmethod=indent')
    command('3,5d')
    eq(5, funcs.foldclosedend(1))
  end)

  it("doesn't combine folds that have a specified end", function()
    insert([[
    {{{
    }}}



    {{{

    }}}
    ]])
    command('setlocal foldmethod=marker')
    command('3,5d')
    command('%foldclose')
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
    command('setlocal foldmethod=expr foldexpr=TestFoldExpr(v:lnum)')
    command('2')
    command('foldopen')
    command('read ' .. tempfname)
    command('%foldclose')
    eq(2, funcs.foldclosedend(1))
    eq(0, funcs.foldlevel(3))
    eq(0, funcs.foldlevel(4))
    eq(6, funcs.foldclosedend(5))
    eq(10, funcs.foldclosedend(7))
    eq(14, funcs.foldclosedend(11))
  end)

  it('no folds remain if :delete makes buffer empty #19671', function()
    command('setlocal foldmethod=manual')
    funcs.setline(1, {'foo', 'bar', 'baz'})
    command('2,3fold')
    command('%delete')
    eq(0, funcs.foldlevel(1))
  end)

  it('multibyte fold markers work #20438', function()
    command('setlocal foldmethod=marker foldmarker=«,» commentstring=/*%s*/')
    insert([[
      bbbbb
      bbbbb
      bbbbb]])
    feed('zfgg')
    expect([[
      bbbbb/*«*/
      bbbbb
      bbbbb/*»*/]])
    eq(1, funcs.foldlevel(1))
  end)

  it('updates correctly with indent method and visual blockwise insertion #22898', function()
    insert([[
    a
    b
    ]])
    command('setlocal foldmethod=indent shiftwidth=2')
    feed('gg0<C-v>jI  <Esc>') -- indent both lines using visual blockwise mode
    eq(1, funcs.foldlevel(1))
    eq(1, funcs.foldlevel(2))
  end)

  it("doesn't open folds with indent method when inserting lower foldlevel line", function()
    insert([[
      insert an unindented line under this line
      keep the lines under this line folded
        keep this line folded 1
        keep this line folded 2
    ]])
    command('set foldmethod=indent shiftwidth=2 noautoindent')
    eq(1, funcs.foldlevel(1))
    eq(1, funcs.foldlevel(2))
    eq(2, funcs.foldlevel(3))
    eq(2, funcs.foldlevel(4))

    feed('zo') -- open the outer fold
    neq(-1, funcs.foldclosed(3)) -- make sure the inner fold is not open

    feed('gg0oa<Esc>') -- insert unindented line

    eq(1, funcs.foldlevel(1)) --|  insert an unindented line under this line
    eq(0, funcs.foldlevel(2)) --|a
    eq(1, funcs.foldlevel(3)) --|  keep the lines under this line folded
    eq(2, funcs.foldlevel(4)) --|    keep this line folded 1
    eq(2, funcs.foldlevel(5)) --|    keep this line folded 2

    neq(-1, funcs.foldclosed(4)) -- make sure the inner fold is still not open
  end)
end)
