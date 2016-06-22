local lfs = require('lfs')
local helpers = require('test.unit.helpers')

local cimport = helpers.cimport
local to_cstr = helpers.to_cstr

local undo = cimport('./src/nvim/undo.h')

describe('u_write_undo', function()
  setup(function()
    -- TODO: check whether the global undodir needs to be configured here somehow
    lfs.mkdir('unit-test-directory')
  end)
  
  teardown(function()
    lfs.rmdir('unit-test-directory')
  end)

  before_each(function()
    -- create a new buffer
    -- TODO: mock creating a buffer
  end)

  -- Lua wrapper for u_write_undo
  local function u_write_undo(name, forceit, buf, hash)
    name = to_cstr(name)
    -- TODO: find out whether the other arguments need special handling
    return undo.u_write_undo(name, forceit, buf, hash)
  end

  it('writes an undo file given the name of that undo file', function()
    -- TODO: write test
  end)
  
  it('infers undo file name from buffer', function()
    -- TODO: write test
  end)
  
  it('forces writing undo file for :wundo! command', function()
    -- TODO: write test
  end)
  
  it('overwrites an existing undo file', function()
    -- TODO: write test
  end)
  
  it('does not overwrite an existing file that isn\'t an undo file', function()
    -- TODO: write test
  end)
  
  it('does not overwrite an existing file that has the wrong permissions', function()
    -- TODO: write test
  end)
  
  it('does not write an undo file if there is no undo information for the buffer', function()
    -- TODO: write test
  end)
end)
