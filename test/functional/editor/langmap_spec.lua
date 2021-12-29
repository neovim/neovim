local helpers = require('test.functional.helpers')(after_each)

local eq, neq, call = helpers.eq, helpers.neq, helpers.call
local eval, feed, clear = helpers.eval, helpers.feed, helpers.clear
local command, insert, expect = helpers.command, helpers.insert, helpers.expect
local feed_command = helpers.feed_command
local curwin = helpers.curwin

describe("'langmap'", function()
  before_each(function()
    clear()
    insert('iii www')
    command('set langmap=iw,wi')
    feed('gg0')
  end)

  it("converts keys in normal mode", function()
    feed('ix')
    expect('iii ww')
    feed('whello<esc>')
    expect('iii helloww')
  end)
  it("gives characters that are mapped by :nmap.", function()
    command('map i 0x')
    feed('w')
    expect('ii www')
  end)
  describe("'langnoremap' option.", function()
    before_each(function()
      command('nmapclear')
    end)
    it("'langnoremap' is by default ON", function()
      eq(eval('&langnoremap'), 1)
    end)
    it("Results of maps are not converted when 'langnoremap' ON.",
    function()
      command('nmap x i')
      feed('xdl<esc>')
      expect('dliii www')
    end)
    it("applies when deciding whether to map recursively", function()
      command('nmap l i')
      command('nmap w j')
      feed('ll')
      expect('liii www')
    end)
    it("does not stop applying 'langmap' on first character of a mapping",
    function()
      command('1t1')
      command('1t1')
      command('goto 1')
      command('nmap w j')
      feed('iiahello')
      expect([[
      iii www
      iii www
      ihelloii www]])
    end)
    it("Results of maps are converted when 'langnoremap' OFF.",
    function()
      command('set nolangnoremap')
      command('nmap x i')
      feed('xdl<esc>')
      expect('iii ww')
    end)
  end)
  -- e.g. CTRL-W_j  ,  mj , 'j and "jp
  it('conversions are applied to keys in middle of command',
  function()
    -- Works in middle of window command
    feed('<C-w>s')
    local origwin = curwin()
    feed('<C-w>i')
    neq(curwin(), origwin)
    -- Works when setting a mark
    feed('yy3p3gg0mwgg0mi')
    eq(call('getpos', "'i"), {0, 3, 1, 0})
    eq(call('getpos', "'w"), {0, 1, 1, 0})
    feed('3dd')
    -- Works when moving to a mark
    feed("'i")
    eq(call('getpos', '.'), {0, 1, 1, 0})
    -- Works when selecting a register
    feed('qillqqwhhq')
    eq(eval('@i'), 'hh')
    eq(eval('@w'), 'll')
    feed('a<C-r>i<esc>')
    expect('illii www')
    feed('"ip')
    expect('illllii www')
    -- Works with i_CTRL-O
    feed('0a<C-O>ihi<esc>')
    expect('illllii hiwww')
  end)

  describe('exceptions', function()
    -- All "command characters" that 'langmap' does not apply to.
    -- These tests consist of those places where some subset of ASCII
    -- characters define certain commands, yet 'langmap' is not applied to
    -- them.
    -- n.b. I think these shouldn't be exceptions.
    it(':s///c confirmation', function()
      command('set langmap=yn,ny')
      feed('qa')
      feed_command('s/i/w/gc')
      feed('yynq')
      expect('wwi www')
      feed('u@a')
      expect('wwi www')
      eq(eval('@a'), ':s/i/w/gc\ryyn')
    end)
    it('insert-mode CTRL-G', function()
      command('set langmap=jk,kj')
      command('d')
      insert([[
      hello
      hello
      hello]])
      expect([[
      hello
      hello
      hello]])
      feed('qa')
      feed('gg3|ahello<C-G>jx<esc>')
      feed('q')
      expect([[
      helhellolo
      helxlo
      hello]])
      eq(eval('@a'), 'gg3|ahellojx')
    end)
    it('command-line CTRL-\\', function()
      command('set langmap=en,ne')
      feed(':<C-\\>e\'hello\'\r<C-B>put ="<C-E>"<CR>')
      expect([[
      iii www
      hello]])
    end)
    it('command-line CTRL-R', function()
      helpers.source([[
        let i_value = 0
        let j_value = 0
        call setreg('i', 'i_value')
        call setreg('j', 'j_value')
        set langmap=ij,ji
      ]])
      feed(':let <C-R>i=1<CR>')
      eq(eval('i_value'), 1)
      eq(eval('j_value'), 0)
    end)
    -- it('-- More -- prompt', function()
    --   -- The 'b' 'j' 'd' 'f' commands at the -- More -- prompt
    -- end)
    it('ask yes/no after backwards range', function()
      command('set langmap=yn,ny')
      feed('dd')
      insert([[
      hello
      there
      these
      are
      some
      lines
      ]])
      feed_command('4,2d')
      feed('n')
      expect([[
      hello
      there
      these
      are
      some
      lines
      ]])
    end)
    it('prompt for number', function()
      command('set langmap=12,21')
      helpers.source([[
        let gotten_one = 0
        function Map()
          let answer = inputlist(['a', '1.', '2.', '3.'])
          if answer == 1
            let g:gotten_one = 1
          endif
        endfunction
        nnoremap x :call Map()<CR>
      ]])
      feed('x1<CR>')
      eq(eval('gotten_one'), 1)
      command('let g:gotten_one = 0')
      feed_command('call Map()')
      feed('1<CR>')
      eq(eval('gotten_one'), 1)
    end)
  end)
  it('conversions are not applied during setreg()',
  function()
    call('setreg', 'i', 'ww')
    eq(eval('@i'), 'ww')
  end)
  it('conversions not applied in insert mode', function()
    feed('aiiiwww')
    expect('iiiiwwwii www')
  end)
  it('conversions not applied in search mode', function()
    feed('/iii<cr>x')
    expect('ii www')
  end)
  it('conversions not applied in cmdline mode', function()
    feed(':call append(1, "iii")<cr>')
    expect([[
    iii www
    iii]])
  end)

  local function testrecording(command_string, expect_string, setup_function)
    if setup_function then setup_function() end
    feed('qa' .. command_string .. 'q')
    expect(expect_string)
    eq(helpers.funcs.nvim_replace_termcodes(command_string, true, true, true),
      eval('@a'))
    if setup_function then setup_function() end
    -- n.b. may need nvim_replace_termcodes() here.
    feed('@a')
    expect(expect_string)
  end

  local function local_setup()
    -- Can't use `insert` as it uses `i` and we've swapped the meaning of that
    -- with the `langmap` setting.
    command('%d')
    command("put ='hello'")
    command('1d')
  end

  it('does not affect recording special keys', function()
    testrecording('A<BS><esc>', 'hell', local_setup)
    testrecording('>><lt><lt>', 'hello', local_setup)
    command('nnoremap \\ x')
    testrecording('\\', 'ello', local_setup)
    testrecording('A<C-V><BS><esc>', 'hello<BS>', local_setup)
  end)
  pending('Translates modified keys correctly', function()
    command('nnoremap <M-i> x')
    command('nnoremap <M-w> l')
    testrecording('<M-w>', 'ello', local_setup)
    testrecording('<M-i>x', 'hllo', local_setup)
  end)
  pending('handles multi-byte characters', function()
    command('set langmap=ïx')
    testrecording('ï', 'ello', local_setup)
    -- The test below checks that what's recorded is correct.
    -- It doesn't check the behaviour, as in order to cause some behaviour we
    -- need to map the multi-byte character, and there is a known bug
    -- preventing this from working (see the test below).
    command('set langmap=xï')
    testrecording('x', 'hello', local_setup)
  end)
  pending('handles multibyte mappings', function()
    -- See this vim issue for the problem, may as well add a test.
    -- https://github.com/vim/vim/issues/297
    command('set langmap=ïx')
    command('nnoremap x diw')
    testrecording('ï', '', local_setup)
    command('set nolangnoremap')
    command('set langmap=xï')
    command('nnoremap ï ix<esc>')
    testrecording('x', 'xhello', local_setup)
  end)
  -- This test is to ensure the behaviour doesn't change from what's already
  -- around. I (hardenedapple) personally think this behaviour should be
  -- changed.
  it('treats control modified keys as characters', function()
    command('nnoremap <C-w> iw<esc>')
    command('nnoremap <C-i> ii<esc>')
    testrecording('<C-w>', 'whello', local_setup)
    testrecording('<C-i>', 'ihello', local_setup)
  end)

end)
