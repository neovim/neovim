local Screen = require('test.functional.ui.screen')
local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local eq, eval, expect, source =
  helpers.eq, helpers.eval, helpers.expect, helpers.source
local clear = helpers.clear
local command = helpers.command
local expect_err = helpers.expect_err
local feed = helpers.feed
local nvim_prog = helpers.nvim_prog
local ok = helpers.ok
local rmdir = helpers.rmdir
local set_session = helpers.set_session
local spawn = helpers.spawn
local nvim_async = helpers.nvim_async
local expect_msg_seq = helpers.expect_msg_seq

describe(':recover', function()
  before_each(clear)

  it('fails if given a non-existent swapfile', function()
    local swapname = 'bogus_swapfile'
    local swapname2 = 'bogus_swapfile.swp'
    expect_err('E305: No swap file found for '..swapname,
               command, 'recover '..swapname)  -- Should not segfault. #2117
    -- Also check filename ending with ".swp". #9504
    expect_err('Vim%(recover%):E306: Cannot open '..swapname2,
               command, 'recover '..swapname2)  -- Should not segfault. #2117
    eq(2, eval('1+1'))  -- Still alive?
  end)

end)

describe(':preserve', function()
  local swapdir = lfs.currentdir()..'/Xtest_recover_dir'
  before_each(function()
    clear()
    rmdir(swapdir)
    lfs.mkdir(swapdir)
  end)
  after_each(function()
    command('%bwipeout!')
    rmdir(swapdir)
  end)

  it("saves to custom 'directory' and (R)ecovers #1836", function()
    local testfile = 'Xtest_recover_file1'
    -- Put swapdir at the start of the 'directory' list. #1836
    -- Note: `set swapfile` *must* go after `set directory`: otherwise it may
    -- attempt to create a swapfile in different directory.
    local init = [[
      set directory^=]]..swapdir:gsub([[\]], [[\\]])..[[//
      set swapfile fileformat=unix undolevels=-1
    ]]

    source(init)
    command('edit! '..testfile)
    feed('isometext<esc>')
    command('preserve')
    source('redir => g:swapname | silent swapname | redir END')

    local swappath1 = eval('g:swapname')

    -- Start another Nvim instance.
    local nvim2 = spawn({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--embed'},
                                true)
    set_session(nvim2)

    source(init)

    -- Use the "SwapExists" event to choose the (R)ecover choice at the dialog.
    command('autocmd SwapExists * let v:swapchoice = "r"')
    command('silent edit! '..testfile)
    source('redir => g:swapname | silent swapname | redir END')

    local swappath2 = eval('g:swapname')

    expect('sometext')
    -- swapfile from session 1 should end in .swp
    eq(testfile..'.swp', string.match(swappath1, '[^%%]+$'))
    -- swapfile from session 2 should end in .swo
    eq(testfile..'.swo', string.match(swappath2, '[^%%]+$'))
    -- Verify that :swapname was not truncated (:help 'shortmess').
    ok(nil == string.find(swappath1, '%.%.%.'))
    ok(nil == string.find(swappath2, '%.%.%.'))
  end)

end)

describe('swapfile detection', function()
  local swapdir = lfs.currentdir()..'/Xtest_swapdialog_dir'
  before_each(function()
    clear()
    rmdir(swapdir)
    lfs.mkdir(swapdir)
  end)
  after_each(function()
    command('%bwipeout!')
    rmdir(swapdir)
  end)

  it('always show swapfile dialog #8840 #9027', function()
    local testfile = 'Xtest_swapdialog_file1'
    -- Put swapdir at the start of the 'directory' list. #1836
    -- Note: `set swapfile` *must* go after `set directory`: otherwise it may
    -- attempt to create a swapfile in different directory.
    local init = [[
      set directory^=]]..swapdir:gsub([[\]], [[\\]])..[[//
      set swapfile fileformat=unix undolevels=-1 hidden
    ]]

    local expected_no_dialog = '^'..(' '):rep(256)..'|\n'
    for _=1,37 do
      expected_no_dialog = expected_no_dialog..'~'..(' '):rep(255)..'|\n'
    end
    expected_no_dialog = expected_no_dialog..testfile..(' '):rep(216)..'0,0-1          All|\n'
    expected_no_dialog = expected_no_dialog..(' '):rep(256)..'|\n'

    source(init)
    command('edit! '..testfile)
    feed('isometext<esc>')
    command('preserve')

    -- Start another Nvim instance.
    local nvim2 = spawn({nvim_prog, '-u', 'NONE', '-i', 'NONE', '--embed'},
                        true)
    set_session(nvim2)
    local screen2 = Screen.new(256, 40)
    screen2:attach()
    source(init)

    -- With shortmess+=F
    command('set shortmess+=F')
    feed(':edit '..testfile..'<CR>')
    screen2:expect{any=[[E325: ATTENTION.*]]..'\n'..[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    screen2:expect(expected_no_dialog)

    -- With :silent and shortmess+=F
    feed(':silent edit %<CR>')
    screen2:expect{any=[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    screen2:expect(expected_no_dialog)

    -- With :silent! and shortmess+=F
    feed(':silent! edit %<CR>')
    screen2:expect{any=[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    screen2:expect(expected_no_dialog)

    -- With API (via eval/VimL) call and shortmess+=F
    feed(':call nvim_command("edit %")<CR>')
    screen2:expect{any=[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    feed('<c-c>')
    screen2:expect(expected_no_dialog)

    -- With API call and shortmess+=F
    nvim_async('command', 'edit %')
    screen2:expect{any=[[Found a swap file by the name ".*]]
                       ..[[Xtest_swapdialog_dir[/\].*]]..testfile..[[%.swp"]]}
    feed('e')  -- Chose "Edit" at the swap dialog.
    expect_msg_seq({
      ignore={'redraw'},
      seqs={
        { {'notification', 'nvim_error_event', {0, 'Vim(edit):E325: ATTENTION'}},
        }
      }
    })
    feed('<cr>')
  end)
end)
