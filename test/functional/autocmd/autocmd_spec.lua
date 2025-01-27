local t = require('test.testutil')
local n = require('test.functional.testnvim')()
local Screen = require('test.functional.ui.screen')

local assert_visible = n.assert_visible
local assert_alive = n.assert_alive
local dedent = t.dedent
local eq = t.eq
local neq = t.neq
local eval = n.eval
local feed = n.feed
local clear = n.clear
local matches = t.matches
local api = n.api
local pcall_err = t.pcall_err
local fn = n.fn
local expect = n.expect
local command = n.command
local exc_exec = n.exc_exec
local exec_lua = n.exec_lua
local retry = t.retry
local source = n.source

describe('autocmd', function()
  before_each(clear)

  it(':tabnew, :split, :close events order, <afile>', function()
    local expected = {
      { 'WinLeave', '' },
      { 'TabLeave', '' },
      { 'WinEnter', '' },
      { 'TabNew', 'testfile1' }, -- :tabnew
      { 'TabEnter', '' },
      { 'BufLeave', '' },
      { 'BufEnter', 'testfile1' }, -- :split
      { 'WinLeave', 'testfile1' },
      { 'WinEnter', 'testfile1' },
      { 'WinLeave', 'testfile1' },
      { 'WinClosed', '1002' }, -- :close, WinClosed <afile> = window-id
      { 'WinEnter', 'testfile1' },
      { 'WinLeave', 'testfile1' }, -- :bdelete
      { 'WinEnter', 'testfile1' },
      { 'BufLeave', 'testfile1' },
      { 'BufEnter', 'testfile2' },
      { 'WinClosed', '1000' },
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

  it('first edit causes BufUnload on NoName', function()
    local expected = {
      { 'BufUnload', '' },
      { 'BufDelete', '' },
      { 'BufWipeout', '' },
      { 'BufEnter', 'testfile1' },
    }
    command('let g:evs = []')
    command('autocmd BufEnter * :call add(g:evs, ["BufEnter", expand("<afile>")])')
    command('autocmd BufDelete * :call add(g:evs, ["BufDelete", expand("<afile>")])')
    command('autocmd BufLeave * :call add(g:evs, ["BufLeave", expand("<afile>")])')
    command('autocmd BufUnload * :call add(g:evs, ["BufUnload", expand("<afile>")])')
    command('autocmd BufWipeout * :call add(g:evs, ["BufWipeout", expand("<afile>")])')
    command('edit testfile1')
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
    command(
      'autocmd WinClosed <buffer> :call add(g:evs, ["WinClosed", expand("<abuf>")])'
        -- Attempt recursion.
        .. ' | bdelete '
        .. buf2
    )
    command('tabedit testfile2')
    command('tabedit testfile3')
    command('bdelete ' .. buf2)
    -- Non-recursive: only triggered once.
    eq({
      { 'WinClosed', '2' },
    }, eval('g:evs'))
    command('bdelete ' .. buf1)
    eq({
      { 'WinClosed', '2' },
      { 'WinClosed', '1' },
    }, eval('g:evs'))
  end)

  it('WinClosed from root directory', function()
    command('cd /')
    command('let g:evs = []')
    command('autocmd WinClosed * :call add(g:evs, ["WinClosed", expand("<afile>")])')
    command('new')
    command('close')
    eq({
      { 'WinClosed', '1001' },
    }, eval('g:evs'))
  end)

  it('v:vim_did_enter is 1 after VimEnter', function()
    eq(1, eval('v:vim_did_enter'))
  end)

  describe('BufLeave autocommand', function()
    it('can wipe out the buffer created by :edit which triggered autocmd', function()
      api.nvim_set_option_value('hidden', true, {})
      api.nvim_buf_set_lines(0, 0, 1, false, {
        'start of test file xx',
        'end of test file xx',
      })

      command('autocmd BufLeave * bwipeout yy')
      eq('Vim(edit):E143: Autocommands unexpectedly deleted new buffer yy', exc_exec('edit yy'))

      expect([[
        start of test file xx
        end of test file xx]])
    end)
  end)

  it('++once', function() -- :help autocmd-once
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
    eq(
      dedent([[

       --- Autocommands ---
       TabNew
           *         :call add(g:foo, "Many1")
                     :call add(g:foo, "Once1")
                     :call add(g:foo, "Once2")
                     :call add(g:foo, "Many2")
                     :call add(g:foo, "Once3")]]),
      fn.execute('autocmd Tabnew')
    )
    command('tabnew')
    command('tabnew')
    command('tabnew')
    eq(expected, eval('g:foo'))
    eq(
      dedent([[

       --- Autocommands ---
       TabNew
           *         :call add(g:foo, "Many1")
                     :call add(g:foo, "Many2")]]),
      fn.execute('autocmd Tabnew')
    )

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
    command(
      'autocmd CursorMoved <buffer> ++once ++nested setlocal binary|:call add(g:foo, "CursorMoved-Once")'
    )
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
    command('autocmd! TabNew') -- Clear all TabNew handlers.
    command('autocmd TabNew * ++once :call add(g:foo, "Once1")')
    command('autocmd TabNew * ++once :call add(g:foo, "Once2")')
    command('tabnew')
    eq(expected, eval('g:foo'))
    eq(
      dedent([[

       --- Autocommands ---]]),
      fn.execute('autocmd Tabnew')
    )
  end)

  it('internal `aucmd_win` window', function()
    -- Nvim uses a special internal window `aucmd_win` to execute certain
    -- actions for an invisible buffer (:help E813).
    -- Check redrawing and API accesses to this window.

    local screen = Screen.new(50, 10)

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
      {1:~                                                 }|*8
                                                        |
    ]])

    feed(':enew | doautoall User<cr>')
    screen:expect([[
      {4:bb                                                }|
      {11:~                                                 }|*4
      {1:~                                                 }|*4
      ^:enew | doautoall User                            |
    ]])

    feed('<cr>')
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*8
      13                                                |
    ]])
    eq(7, eval('g:test'))

    -- API calls are blocked when aucmd_win is not in scope
    eq(
      'Vim(call):E5555: API call: Invalid window id: 1001',
      pcall_err(command, 'call nvim_set_current_win(g:winid)')
    )

    -- second time aucmd_win is needed, a different code path is invoked
    -- to reuse the same window, so check again
    command('let g:test = v:null')
    command('let g:had_value = v:null')
    feed(':doautoall User<cr>')
    screen:expect([[
      {4:bb                                                }|
      {11:~                                                 }|*4
      {1:~                                                 }|*4
      ^:doautoall User                                   |
    ]])

    feed('<cr>')
    screen:expect([[
      ^                                                  |
      {1:~                                                 }|*8
      13                                                |
    ]])
    -- win vars in aucmd_win should have been reset
    eq(0, eval('g:had_value'))
    eq(7, eval('g:test'))

    eq(
      'Vim(call):E5555: API call: Invalid window id: 1001',
      pcall_err(command, 'call nvim_set_current_win(g:winid)')
    )
  end)

  it('`aucmd_win` cannot be changed into a normal window #13699', function()
    local screen = Screen.new(50, 10)

    -- Create specific layout and ensure it's left unchanged.
    -- Use vim._with on a hidden buffer so aucmd_win is used.
    exec_lua [[
      vim.cmd "wincmd s | wincmd _"
      _G.buf = vim.api.nvim_create_buf(true, true)
      vim._with({buf = _G.buf}, function() vim.cmd "wincmd J" end)
    ]]
    screen:expect [[
      ^                                                  |
      {1:~                                                 }|*5
      {3:[No Name]                                         }|
                                                        |
      {2:[No Name]                                         }|
                                                        |
    ]]
    -- This used to crash after making aucmd_win a normal window via the above.
    exec_lua [[
      vim.cmd "tabnew | tabclose # | wincmd s | wincmd _"
      vim._with({buf = _G.buf}, function() vim.cmd "wincmd K" end)
    ]]
    assert_alive()
    screen:expect_unchanged()

    -- Also check with win_splitmove().
    exec_lua [[
      vim._with({buf = _G.buf}, function()
        vim.fn.win_splitmove(vim.fn.winnr(), vim.fn.win_getid(1))
      end)
    ]]
    screen:expect_unchanged()

    -- Also check with nvim_win_set_config().
    matches(
      '^Failed to move window %d+ into split$',
      pcall_err(
        exec_lua,
        [[
          vim._with({buf = _G.buf}, function()
            vim.api.nvim_win_set_config(0, {
              vertical = true,
              win = vim.fn.win_getid(1)
            })
          end)
        ]]
      )
    )
    screen:expect_unchanged()

    -- Ensure splitting still works from inside the aucmd_win.
    exec_lua [[vim._with({buf = _G.buf}, function() vim.cmd "split" end)]]
    screen:expect [[
      ^                                                  |
      {1:~                                                 }|
      {3:[No Name]                                         }|
                                                        |
      {1:~                                                 }|
      {2:[Scratch]                                         }|
                                                        |
      {1:~                                                 }|
      {2:[No Name]                                         }|
                                                        |
    ]]

    -- After all of our messing around, aucmd_win should still be floating.
    -- Use :only to ensure _G.buf is hidden again (so the aucmd_win is used).
    eq(
      'editor',
      exec_lua [[
        vim.cmd "only"
        vim._with({buf = _G.buf}, function()
          _G.config = vim.api.nvim_win_get_config(0)
        end)
        return _G.config.relative
      ]]
    )
  end)

  describe('closing last non-floating window in tab from `aucmd_win`', function()
    before_each(function()
      command('edit Xa.txt')
      command('tabnew Xb.txt')
      command('autocmd BufAdd Xa.txt 1close')
    end)

    it('gives E814 when there are no other floating windows', function()
      eq(
        'BufAdd Autocommands for "Xa.txt": Vim(close):E814: Cannot close window, only autocmd window would remain',
        pcall_err(command, 'doautoall BufAdd')
      )
    end)

    it('gives E814 when there are other floating windows', function()
      api.nvim_open_win(
        0,
        true,
        { width = 10, height = 10, relative = 'editor', row = 10, col = 10 }
      )
      eq(
        'BufAdd Autocommands for "Xa.txt": Vim(close):E814: Cannot close window, only autocmd window would remain',
        pcall_err(command, 'doautoall BufAdd')
      )
    end)
  end)

  it('closing `aucmd_win` using API gives E813', function()
    exec_lua([[
      vim.cmd('tabnew')
      _G.buf = vim.api.nvim_create_buf(true, true)
    ]])
    matches(
      'Vim:E813: Cannot close autocmd window$',
      pcall_err(
        exec_lua,
        [[
          vim._with({buf = _G.buf}, function()
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_close(win, true)
          end)
        ]]
      )
    )
    matches(
      'Vim:E813: Cannot close autocmd window$',
      pcall_err(
        exec_lua,
        [[
          vim._with({buf = _G.buf}, function()
            local win = vim.api.nvim_get_current_win()
            vim.cmd('tabnext')
            vim.api.nvim_win_close(win, true)
          end)
        ]]
      )
    )
    matches(
      'Vim:E813: Cannot close autocmd window$',
      pcall_err(
        exec_lua,
        [[
          vim._with({buf = _G.buf}, function()
            local win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_hide(win)
          end)
        ]]
      )
    )
    matches(
      'Vim:E813: Cannot close autocmd window$',
      pcall_err(
        exec_lua,
        [[
          vim._with({buf = _G.buf}, function()
            local win = vim.api.nvim_get_current_win()
            vim.cmd('tabnext')
            vim.api.nvim_win_hide(win)
          end)
        ]]
      )
    )
  end)

  it(':doautocmd does not warn "No matching autocommands" #10689', function()
    local screen = Screen.new(32, 3)

    feed(':doautocmd User Foo<cr>')
    screen:expect {
      grid = [[
      ^                                |
      {1:~                               }|
      :doautocmd User Foo             |
    ]],
    }
    feed(':autocmd! SessionLoadPost<cr>')
    feed(':doautocmd SessionLoadPost<cr>')
    screen:expect {
      grid = [[
      ^                                |
      {1:~                               }|
      :doautocmd SessionLoadPost      |
    ]],
    }
  end)

  describe('v:event is readonly #18063', function()
    it('during ChanOpen event', function()
      command('autocmd ChanOpen * let v:event.info.id = 0')
      fn.jobstart({ 'cat' })
      retry(nil, nil, function()
        eq('E46: Cannot change read-only variable "v:event.info"', api.nvim_get_vvar('errmsg'))
      end)
    end)

    it('during ChanOpen event', function()
      command('autocmd ChanInfo * let v:event.info.id = 0')
      api.nvim_set_client_info('foo', {}, 'remote', {}, {})
      retry(nil, nil, function()
        eq('E46: Cannot change read-only variable "v:event.info"', api.nvim_get_vvar('errmsg'))
      end)
    end)

    it('during RecordingLeave event', function()
      command([[autocmd RecordingLeave * let v:event.regname = '']])
      eq(
        'RecordingLeave Autocommands for "*": Vim(let):E46: Cannot change read-only variable "v:event.regname"',
        pcall_err(command, 'normal! qqq')
      )
    end)

    it('during TermClose event', function()
      command('autocmd TermClose * let v:event.status = 0')
      command('terminal')
      eq(
        'TermClose Autocommands for "*": Vim(let):E46: Cannot change read-only variable "v:event.status"',
        pcall_err(command, 'bdelete!')
      )
    end)
  end)

  describe('old_tests', function()
    it('vimscript: WinNew ++once', function()
      source [[
        " Without ++once WinNew triggers twice
        let g:did_split = 0
        augroup Testing
          au!
          au WinNew * let g:did_split += 1
        augroup END
        split
        split
        call assert_equal(2, g:did_split)
        call assert_true(exists('#WinNew'))
        close
        close

        " With ++once WinNew triggers once
        let g:did_split = 0
        augroup Testing
          au!
          au WinNew * ++once let g:did_split += 1
        augroup END
        split
        split
        call assert_equal(1, g:did_split)
        call assert_false(exists('#WinNew'))
        close
        close

        call assert_fails('au WinNew * ++once ++once echo bad', 'E983:')
      ]]

      api.nvim_set_var('did_split', 0)

      source [[
        augroup Testing
          au!
          au WinNew * let g:did_split += 1
        augroup END

        split
        split
      ]]

      eq(2, api.nvim_get_var('did_split'))
      eq(1, fn.exists('#WinNew'))

      -- Now with once
      api.nvim_set_var('did_split', 0)

      source [[
        augroup Testing
          au!
          au WinNew * ++once let g:did_split += 1
        augroup END

        split
        split
      ]]

      eq(1, api.nvim_get_var('did_split'))
      eq(0, fn.exists('#WinNew'))

      -- call assert_fails('au WinNew * ++once ++once echo bad', 'E983:')
      local ok, msg = pcall(
        source,
        [[
        au WinNew * ++once ++once echo bad
      ]]
      )

      eq(false, ok)
      eq(true, not not string.find(msg, 'E983:'))
    end)

    it('should have autocmds in filetypedetect group', function()
      source [[filetype on]]
      neq({}, api.nvim_get_autocmds { group = 'filetypedetect' })
    end)

    it('should allow comma-separated patterns', function()
      source [[
        augroup TestingPatterns
          au!
          autocmd BufReadCmd *.shada,*.shada.tmp.[a-z] echo 'hello'
          autocmd BufReadCmd *.shada,*.shada.tmp.[a-z] echo 'hello'
        augroup END
      ]]

      eq(4, #api.nvim_get_autocmds { event = 'BufReadCmd', group = 'TestingPatterns' })
    end)
  end)

  it('no use-after-free when adding autocommands from a callback', function()
    exec_lua [[
      vim.cmd "autocmd! TabNew"
      vim.g.count = 0
      vim.api.nvim_create_autocmd('TabNew', {
        callback = function()
          vim.g.count = vim.g.count + 1
          for _ = 1, 100 do
            vim.cmd "autocmd TabNew * let g:count += 1"
          end
          return true
        end,
      })
      vim.cmd "tabnew"
    ]]
    eq(1, eval('g:count')) -- Added autocommands should not be executed
  end)

  it('no crash when clearing a group inside a callback #23355', function()
    exec_lua [[
      vim.cmd "autocmd! TabNew"
      local group = vim.api.nvim_create_augroup('Test', {})
      local id
      id = vim.api.nvim_create_autocmd('TabNew', {
        group = group,
        callback = function()
          vim.api.nvim_del_autocmd(id)
          vim.api.nvim_create_augroup('Test', { clear = true })
        end,
      })
      vim.cmd "tabnew"
    ]]
  end)
end)
