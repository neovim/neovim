local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local feed_command, eq, clear, eval, feed, expect, source =
  helpers.feed_command, helpers.eq, helpers.clear, helpers.eval, helpers.feed,
  helpers.expect, helpers.source
local command = helpers.command
local ok = helpers.ok
local rmdir = helpers.rmdir

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
    rmdir(swapdir)
    lfs.mkdir(swapdir)
  end)
  after_each(function()
    command('%bwipeout!')
    rmdir(swapdir)
  end)

  it("saves to custom 'directory' and (R)ecovers (issue #1836)", function()
    local testfile = 'testfile_recover_spec'
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

    --TODO(justinmk): this is an ugly hack to force `helpers` to support
    --multiple sessions.
    local nvim2 = helpers.spawn({helpers.nvim_prog, '-u', 'NONE', '-i', 'NONE', '--embed'},
                                true)
    helpers.set_session(nvim2)

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
