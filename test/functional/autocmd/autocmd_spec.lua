local helpers = require('test.functional.helpers')(after_each)
local Screen = require('test.functional.ui.screen')

local assert_visible = helpers.assert_visible
local dedent = helpers.dedent
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed
local clear = helpers.clear
local meths = helpers.meths
local pcall_err = helpers.pcall_err
local funcs = helpers.funcs
local expect = helpers.expect
local command = helpers.command
local exc_exec = helpers.exc_exec
local curbufmeths = helpers.curbufmeths
local source = helpers.source

describe('autocmd', function()
  before_each(clear)

  it(':tabnew, :split, :close events order, <afile>', function()
    local expected = {
      {'WinLeave', ''},
      {'TabLeave', ''},
      {'WinEnter', ''},
      {'TabNew', 'testfile1'},    -- :tabnew
      {'TabEnter', ''},
      {'BufLeave', ''},
      {'BufEnter', 'testfile1'},  -- :split
      {'WinLeave', 'testfile1'},
      {'WinEnter', 'testfile1'},
      {'WinLeave', 'testfile1'},
      {'WinClosed', '1002'},      -- :close, WinClosed <afile> = window-id
      {'WinEnter', 'testfile1'},
      {'WinLeave', 'testfile1'},  -- :bdelete
      {'WinEnter', 'testfile1'},
      {'BufLeave', 'testfile1'},
      {'BufEnter', 'testfile2'},
      {'WinClosed', '1000'},
    }
    command('let g:evs = []')
    command('autocmd BufEnter * :call add(g:evs, ["BufEnter", expand("<afile>")])')
    command('autocmd BufLeave * :call add(g:evs, ["BufLeave", expand("<afile>")])')
    command('autocmd TabEnter * :call add(g:evs, ["TabEnter", expand("<afile>")])')
    command('autocmd TabLeave * :call add(g:evs, ["TabLeave", expand("<afile>")])')
    command('autocmd TabNew   * :call add(g:evs, ["TabNew", expand("<afile>")])')
    command('autocmd WinEnter * :call add(g:evs, ["WinEnter", expand("<afile>")])')
    command('autocmd WinLeave * :call add(g:evs, ["WinLeave", expand("<afile>")])')
    command('autocmd WinClosed * :call add(g:evs, ["WinClosed", expand("<afile>")])')
    command('tabnew testfile1')
    command('split')
    command('close')
    command('new testfile2')
    command('bdelete 1')
    eq(expected, eval('g:evs'))
  end)

  it('WinClosed is non-recursive', function()
    command('let g:triggered = 0')
    command('autocmd WinClosed * :let g:triggered+=1 | :bdelete 2')
    command('new testfile2')
    command('new testfile3')

    -- All 3 buffers are visible.
    assert_visible(1, true)
    assert_visible(2, true)
    assert_visible(3, true)

    -- Trigger WinClosed, which also deletes buffer/window 2.
    command('bdelete 1')

    -- Buffers 1 and 2 were closed but WinClosed was triggered only once.
    eq(1, eval('g:triggered'))
    assert_visible(1, false)
    assert_visible(2, false)
    assert_visible(3, true)
  end)

  it('WinClosed from a different tabpage', function()
    command('let g:evs = []')
    command('edit tesfile1')
    command('autocmd WinClosed <buffer> :call add(g:evs, ["WinClosed", expand("<abuf>")])')
    local buf1 = eval("bufnr('%')")
    command('new')
    local buf2 = eval("bufnr('%')")
    command('autocmd WinClosed <buffer> :call add(g:evs, ["WinClosed", expand("<abuf>")])'
      -- Attempt recursion.
      ..' | bdelete '..buf2)
    command('tabedit testfile2')
    command('tabedit testfile3')
    command('bdelete '..buf2)
    -- Non-recursive: only triggered once.
    eq({
      {'WinClosed', '2'},
    }, eval('g:evs'))
    command('bdelete '..buf1)
    eq({
      {'WinClosed', '2'},
      {'WinClosed', '1'},
    }, eval('g:evs'))
  end)

  it('WinClosed from root directory', function()
    command('cd /')
    command('let g:evs = []')
    command('autocmd WinClosed * :call add(g:evs, ["WinClosed", expand("<afile>")])')
    command('new')
    command('close')
    eq({
      {'WinClosed', '1001'},
    }, eval('g:evs'))
  end)

  it('v:vim_did_enter is 1 after VimEnter', function()
    eq(1, eval('v:vim_did_enter'))
  end)

  describe('BufLeave autocommand', function()
    it('can wipe out the buffer created by :edit which triggered autocmd',
    function()
      meths.set_option('hidden', true)
      curbufmeths.set_lines(0, 1, false, {
        'start of test file xx',
        'end of test file xx'})

      command('autocmd BufLeave * bwipeout yy')
      eq('Vim(edit):E143: Autocommands unexpectedly deleted new buffer yy',
         exc_exec('edit yy'))

      expect([[
        start of test file xx
        end of test file xx]])
    end)
  end)

  it('++once', function()  -- :help autocmd-once
    --
    -- ":autocmd ... ++once" executes its handler once, then removes the handler.
    --
    local expected = {
      'Many1',
      'Once1',
      'Once2',
      'Many2',
      'Once3',
      'Many1',
      'Many2',
      'Many1',
      'Many2',
    }
    command('let g:foo = []')
    command('autocmd TabNew * :call add(g:foo, "Many1")')
    command('autocmd TabNew * ++once :call add(g:foo, "Once1")')
    command('autocmd TabNew * ++once :call add(g:foo, "Once2")')
    command('autocmd TabNew * :call add(g:foo, "Many2")')
    command('autocmd TabNew * ++once :call add(g:foo, "Once3")')
    eq(dedent([[

       --- Autocommands ---
       TabNew
           *         :call add(g:foo, "Many1")
                     :call add(g:foo, "Once1")
                     :call add(g:foo, "Once2")
                     :call add(g:foo, "Many2")
                     :call add(g:foo, "Once3")]]),
       funcs.execute('autocmd Tabnew'))
    command('tabnew')
    command('tabnew')
    command('tabnew')
    eq(expected, eval('g:foo'))
    eq(dedent([[

       --- Autocommands ---
       TabNew
           *         :call add(g:foo, "Many1")
                     :call add(g:foo, "Many2")]]),
       funcs.execute('autocmd Tabnew'))

    --
    -- ":autocmd ... ++once" handlers can be deleted.
    --
    expected = {}
    command('let g:foo = []')
    command('autocmd TabNew * ++once :call add(g:foo, "Once1")')
    command('autocmd! TabNew')
    command('tabnew')
    eq(expected, eval('g:foo'))

    --
    -- ":autocmd ... <buffer> ++once ++nested"
    --
    expected = {
      'OptionSet-Once',
      'CursorMoved-Once',
    }
    command('let g:foo = []')
    command('autocmd OptionSet binary ++nested ++once :call add(g:foo, "OptionSet-Once")')
    command('autocmd CursorMoved <buffer> ++once ++nested setlocal binary|:call add(g:foo, "CursorMoved-Once")')
    command("put ='foo bar baz'")
    feed('0llhlh')
    eq(expected, eval('g:foo'))

    --
    -- :autocmd should not show empty section after ++once handlers expire.
    --
    expected = {
      'Once1',
      'Once2',
    }
    command('let g:foo = []')
    command('autocmd! TabNew')  -- Clear all TabNew handlers.
    command('autocmd TabNew * ++once :call add(g:foo, "Once1")')
    command('autocmd TabNew * ++once :call add(g:foo, "Once2")')
    command('tabnew')
    eq(expected, eval('g:foo'))
    eq(dedent([[

       --- Autocommands ---]]),
       funcs.execute('autocmd Tabnew'))
  end)

  it('internal `aucmd_win` window', function()
    -- Nvim uses a special internal window `aucmd_win` to execute certain
    -- actions for an invisible buffer (:help E813).
    -- Check redrawing and API accesses to this window.

    local screen = Screen.new(50, 10)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
      [2] = {background = Screen.colors.LightMagenta},
      [3] = {background = Screen.colors.LightMagenta, bold = true, foreground = Screen.colors.Blue1},
    })

    source([[
      function! Doit()
        let g:winid = nvim_get_current_win()
        redraw!
        echo getchar()
        " API functions work when aucmd_win is in scope
        let g:had_value = has_key(w:, "testvar")
        call nvim_win_set_var(g:winid, "testvar", 7)
        let g:test = w:testvar
      endfunction
      set hidden
      " add dummy text to not discard the buffer
      call setline(1,"bb")
      autocmd User <buffer> call Doit()
    ]])
    screen:expect([[
      ^bb                                                |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
                                                        |
    ]])

    feed(":enew | doautoall User<cr>")
    screen:expect([[
      {2:bb                                                }|
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      ^:enew | doautoall User                            |
    ]])

    feed('<cr>')
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      13                                                |
    ]])
    eq(7, eval('g:test'))

    -- API calls are blocked when aucmd_win is not in scope
    eq('Vim(call):E5555: API call: Invalid window id: 1001',
      pcall_err(command, "call nvim_set_current_win(g:winid)"))

    -- second time aucmd_win is needed, a different code path is invoked
    -- to reuse the same window, so check again
    command("let g:test = v:null")
    command("let g:had_value = v:null")
    feed(":doautoall User<cr>")
    screen:expect([[
      {2:bb                                                }|
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
      {3:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      ^:doautoall User                                   |
    ]])

    feed('<cr>')
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      {1:~                                                 }|
      13                                                |
    ]])
    -- win vars in aucmd_win should have been reset
    eq(0, eval('g:had_value'))
    eq(7, eval('g:test'))

    eq('Vim(call):E5555: API call: Invalid window id: 1001',
      pcall_err(command, "call nvim_set_current_win(g:winid)"))
  end)

  it(':doautocmd does not warn "No matching autocommands" #10689', function()
    local screen = Screen.new(32, 3)
    screen:attach()
    screen:set_default_attr_ids({
      [1] = {bold = true, foreground = Screen.colors.Blue1},
    })

    feed(':doautocmd User Foo<cr>')
    screen:expect{grid=[[
      ^                                |
      {1:~                               }|
      :doautocmd User Foo             |
    ]]}
    feed(':autocmd! SessionLoadPost<cr>')
    feed(':doautocmd SessionLoadPost<cr>')
    screen:expect{grid=[[
      ^                                |
      {1:~                               }|
      :doautocmd SessionLoadPost      |
    ]]}
  end)
end)
