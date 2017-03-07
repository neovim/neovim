-- Tests for folding.
local Screen = require('test.functional.ui.screen')

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, execute, expect_any, command =
  helpers.feed, helpers.insert, helpers.execute, helpers.expect_any,
  helpers.command

describe('foldchars', function()
  local screen

  before_each(function()
    helpers.clear()

    screen = Screen.new(20, 11)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.WebGray},
      [2] = {foreground = Screen.colors.DarkBlue, background = Screen.colors.LightGrey},
      [3] = {bold = true, foreground = Screen.colors.Blue1}
    })
  end)
  after_each(function()
    screen:detach()
  end)

  it('api', function()
    insert([[
      1
      2
      3
      4
      5
      6
      7
      8
      last
      ]])
    execute("set foldcolumn=2")


    -- TODO check
	-- :highlight Folded guibg=grey guifg=blue
	-- :highlight FoldColumn guibg=darkgrey guifg=white
    -- set foldminlines
    -- test with fillchars
    -- test with minimum size of folds 
    command("call nvim_fold_create(nvim_get_current_win(), 1, 4)")
    command("call nvim_fold_create(nvim_get_current_win(), 1, 3)")
    command("call nvim_fold_create(nvim_get_current_win(), 1, 2)")
    command("%foldopen!")
    command("call nvim_fold_create(nvim_get_current_win(), 6, line('$'))")
    command("call nvim_fold_create(nvim_get_current_win(), 7, line('$'))")
    feed("gg")

    expected = [[
      {1:--}^1                 |
      {1:|^}2                 |
      {1:|^}3                 |
      {1:^ }4                 |
      {1:  }5                 |
      {1:+ }{2:+--  5 lines: 6---}|
      {1:  }{3:~                 }|
      {1:  }{3:~                 }|
      {1:  }{3:~                 }|
      {1:  }{3:~                 }|
      :set foldcolumn=2   |
    ]]
    screen:expect(expected)
      -- 1 => FoldColumn


    command("set fillchars+=foldopen:▾,foldsep:│,foldclose:▸,foldend:^")
    -- screen:snapshot_util()
    -- foldchars = {
    -- 'open': '▾'
    -- '|': '│'
    -- '-': 
    -- }
    screen:expect([[
      {1:▾▾}^1                 |
      {1:│^}2                 |
      {1:│^}3                 |
      {1:^ }4                 |
      {1:  }5                 |
      {1:▸ }{2:+--  5 lines: 6---}|
      {1:  }{3:~                 }|
      {1:  }{3:~                 }|
      {1:  }{3:~                 }|
      {1:  }{3:~                 }|
      :set foldcolumn=2   |
    ]])

  end)

  -- TODO
  -- test single column
  --
  it("set foldminlines", function()
    insert([[
      1
      2
      3
      4
      5
      6
      7
      8
      last
      ]])
      local limit = 4
      local i = 0
      --   command("set foldminlines="..limit)
      -- TODO echo that one nvim_get_current_win(),
        while i < limit + 2 do
          command("call nvim_fold_create(nvim_get_current_win(), 1, 4)")
        end
    screen:try_resize(20, 10)

  end)

  -- it("foldmethod=indent", function()
  --   screen:try_resize(20, 8)
  --   execute('set fdm=indent sw=2')
  --   insert([[
  --   aa
  --     bb
  --       cc
  --   last
  --   ]])
  --   execute('call append("$", "foldlevel line3=" . foldlevel(3))')
  --   execute('call append("$", foldlevel(2))')
  --   feed('zR')

  --   helpers.wait()
  --   screen:expect([[
  --     aa                  |
  --       bb                |
  --         cc              |
  --     last                |
  --     ^                    |
  --     foldlevel line3=2   |
  --     1                   |
  --                         |
  --   ]])
  -- end)

  -- it("foldmethod=syntax", function()
  --   screen:try_resize(35, 15)
  --   insert([[
  --     1 aa
  --     2 bb
  --     3 cc
  --     4 dd {{{
  --     5 ee {{{ }}}
  --     6 ff }}}
  --     7 gg
  --     8 hh
  --     9 ii
  --     a jj
  --     b kk
  --     last]])
  --   execute('set fdm=syntax fdl=0')
  --   execute('syn region Hup start="dd" end="ii" fold contains=Fd1,Fd2,Fd3')
  --   execute('syn region Fd1 start="ee" end="ff" fold contained')
  --   execute('syn region Fd2 start="gg" end="hh" fold contained')
  --   execute('syn region Fd3 start="commentstart" end="commentend" fold contained')
  --   feed('Gzk')
  --   execute('call append("$", "folding " . getline("."))')
  --   feed('k')
  --   execute('call append("$", getline("."))')
  --   feed('jAcommentstart  <esc>Acommentend<esc>')
  --   execute('set fdl=1')
  --   feed('3j')
  --   execute('call append("$", getline("."))')
  --   execute('set fdl=0')
  --   feed('zO<C-L>j') -- <C-L> redraws screen
  --   execute('call append("$", getline("."))')
  --   execute('set fdl=0')
  --   expect_any([[
  --     folding 9 ii
  --     3 cc
  --     9 ii
  --     a jj]])
  -- end)

  -- it("foldmethod=expression", function()
  --   insert([[
  --     1 aa
  --     2 bb
  --     3 cc
  --     4 dd {{{
  --     5 ee {{{ }}}
  --     6 ff }}}
  --     7 gg
  --     8 hh
  --     9 ii
  --     a jj
  --     b kk
  --     last ]])

  --   execute([[
  --   fun Flvl()
  --    let l = getline(v:lnum)
  --    if l =~ "bb$"
  --      return 2
  --    elseif l =~ "gg$"
  --      return "s1"
  --    elseif l =~ "ii$"
  --      return ">2"
  --    elseif l =~ "kk$"
  --      return "0"
  --    endif
  --    return "="
  --   endfun
  --   ]])
  --   execute('set fdm=expr fde=Flvl()')
  --   execute('/bb$')
  --   execute('call append("$", "expr " . foldlevel("."))')
  --   execute('/hh$')
  --   execute('call append("$", foldlevel("."))')
  --   execute('/ii$')
  --   execute('call append("$", foldlevel("."))')
  --   execute('/kk$')
  --   execute('call append("$", foldlevel("."))')

  --   expect_any([[
  --     expr 2
  --     1
  --     2
  --     0]])
  -- end)

  -- it('can be opened after :move', function()
  --   -- luacheck: ignore
  --   screen:try_resize(35, 8)
  --   insert([[
  --     Test fdm=indent and :move bug END
  --     line2
  --     	Test fdm=indent START
  --     	line3
  --     	line4]])
  --   execute('set noai nosta ')
  --   execute('set fdm=indent')
  --   execute('1m1')
  --   feed('2jzc')
  --   execute('m0')
  --   feed('zR')

  --   expect_any([[
  --     	Test fdm=indent START
  --     	line3
  --     	line4
  --     Test fdm=indent and :move bug END
  --     line2]])
  -- end)
end)
