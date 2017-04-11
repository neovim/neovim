local helpers = require('test.functional.helpers')(after_each)
local lfs = require('lfs')
local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local funcs = helpers.funcs
local rmdir = helpers.rmdir

describe(':file', function()
  local swapdir = lfs.currentdir()..'/Xtest-file_spec'
  before_each(function()
    clear()
    rmdir(swapdir)
    lfs.mkdir(swapdir)
  end)
  after_each(function()
    command('%bwipeout!')
    rmdir(swapdir)
  end)

  it("rename does not lose swapfile #6487", function()
    local testfile = 'test-file_spec'
    local testfile_renamed = testfile..'-renamed'
    -- Note: `set swapfile` *must* go after `set directory`: otherwise it may
    -- attempt to create a swapfile in different directory.
    command('set directory^='..swapdir..'//')
    command('set swapfile fileformat=unix undolevels=-1')

    command('edit! '..testfile)
    -- Before #6487 this gave "E301: Oops, lost the swap file !!!" on Windows.
    command('file '..testfile_renamed)
    eq(testfile_renamed..'.swp',
       string.match(funcs.execute('swapname'), '[^%%]+$'))
  end)
end)
