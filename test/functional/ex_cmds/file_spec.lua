local t = require('test.functional.testutil')()
local clear = t.clear
local command = t.command
local eq = t.eq
local fn = t.fn
local rmdir = t.rmdir
local mkdir = t.mkdir

describe(':file', function()
  local swapdir = vim.uv.cwd() .. '/Xtest-file_spec'
  before_each(function()
    clear()
    rmdir(swapdir)
    mkdir(swapdir)
  end)
  after_each(function()
    command('%bwipeout!')
    rmdir(swapdir)
  end)

  it('rename does not lose swapfile #6487', function()
    local testfile = 'test-file_spec'
    local testfile_renamed = testfile .. '-renamed'
    -- Note: `set swapfile` *must* go after `set directory`: otherwise it may
    -- attempt to create a swapfile in different directory.
    command('set directory^=' .. swapdir .. '//')
    command('set swapfile fileformat=unix undolevels=-1')

    command('edit! ' .. testfile)
    -- Before #6487 this gave "E301: Oops, lost the swap file !!!" on Windows.
    command('file ' .. testfile_renamed)
    eq(testfile_renamed .. '.swp', string.match(fn.execute('swapname'), '[^%%]+$'))
  end)
end)
