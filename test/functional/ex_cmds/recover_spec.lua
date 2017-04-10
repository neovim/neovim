-- Tests for :recover

local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local feed_command, eq, clear, eval, feed, expect, source =
  helpers.feed_command, helpers.eq, helpers.clear, helpers.eval, helpers.feed,
  helpers.expect, helpers.source

if helpers.pending_win32(pending) then return end

describe(':recover', function()
  before_each(clear)

  it('fails if given a non-existent swapfile', function()
    local swapname = 'bogus-swapfile'
    feed_command('recover '..swapname) -- This should not segfault. #2117
    eq('E305: No swap file found for '..swapname, eval('v:errmsg'))
  end)

end)

describe(':preserve', function()
  local swapdir = lfs.currentdir()..'/testdir_recover_spec'
  before_each(function()
    clear()
    helpers.rmdir(swapdir)
    lfs.mkdir(swapdir)
  end)
  after_each(function()
    helpers.rmdir(swapdir)
  end)

  it("saves to custom 'directory' and (R)ecovers (issue #1836)", function()
    local testfile = 'testfile_recover_spec'
    -- Note: `set swapfile` *must* go after `set directory`: otherwise it may
    -- attempt to create a swapfile in different directory.
    local init = [[
      set directory^=]]..swapdir..[[//
      set swapfile fileformat=unix undolevels=-1
    ]]

    source(init)
    feed_command('set swapfile fileformat=unix undolevels=-1')
    -- Put swapdir at the start of the 'directory' list. #1836
    feed_command('set directory^='..swapdir..'//')
    feed_command('edit '..testfile)
    feed('isometext<esc>')
    feed_command('preserve')
    source('redir => g:swapname | swapname | redir END')

    local swappath1 = eval('g:swapname')

    --TODO(justinmk): this is an ugly hack to force `helpers` to support
    --multiple sessions.
    local nvim2 = helpers.spawn({helpers.nvim_prog, '-u', 'NONE', '-i', 'NONE', '--embed'},
                                true)
    helpers.set_session(nvim2)

    source(init)

    -- Use the "SwapExists" event to choose the (R)ecover choice at the dialog.
    feed_command('autocmd SwapExists * let v:swapchoice = "r"')
    feed_command('silent edit '..testfile)
    source('redir => g:swapname | swapname | redir END')

    local swappath2 = eval('g:swapname')

    -- swapfile from session 1 should end in .swp
    assert(testfile..'.swp' == string.match(swappath1, '[^%%]+$'))

    -- swapfile from session 2 should end in .swo
    assert(testfile..'.swo' == string.match(swappath2, '[^%%]+$'))

    expect('sometext')
  end)

end)
