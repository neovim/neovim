local lfs = require('lfs')
local helpers = require('test.unit.helpers')

local ffi = helpers.ffi
local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local neq = helpers.neq

cimport('./src/nvim/ex_cmds_defs.h')
cimport('./src/nvim/buffer_defs.h')
local options = cimport('./src/nvim/option_defs.h')
local vim = cimport('./src/nvim/vim.h')
local undo = cimport('./src/nvim/undo.h')
local buffer = cimport('./src/nvim/buffer.h')

describe('u_write_undo', function()
  setup(function()
    lfs.mkdir('unit-test-directory')
    lfs.chdir('unit-test-directory')
    old_p_udir = options.p_udir  -- save the old value of p_udir (undodir)
    options.p_udir = to_cstr(lfs.currentdir())  -- set p_udir to be the test dir
  end)
  
  teardown(function()
    lfs.chdir('..')
    success, err = lfs.rmdir('unit-test-directory')
    if not success then
      print(err)  -- inform tester if directory fails to delete
    end
    options.p_udir = old_p_udir  --restore old p_udir
  end)

  before_each(function()
    -- create a new buffer
    local c_file = to_cstr('../test/unit/undo_spec.lua')
    file_buffer = buffer.buflist_new(c_file, c_file, 1, buffer.BLN_LISTED)
    file_buffer.b_u_numhead = 1 -- Pretend that the buffer has been changed

    -- TODO(christopher.waldon.dev@gmail.com): replace the 32 with UNDO_HASH_SIZE
    -- requires refactor of UNDO_HASH_SIZE into constant/enum for ffi
    --
    -- compute a hash for this undofile
    hash = ffi.new('char_u[32]')
    undo.u_compute_hash(hash)
  end)

  -- Lua wrapper for u_write_undo
  local function u_write_undo(name, forceit, buf, hash)
    if name ~= nil then
      name = to_cstr(name)
    end
  
    return undo.u_write_undo(name, forceit, buf, hash)
  end

  it('writes an undo file to undodir given a buffer and hash', function()
    u_write_undo(nil, false, file_buffer, hash)
    correct_name = ffi.string(undo.u_get_undo_file_name(file_buffer.b_ffname, false))
    undo_file = io.open(correct_name, "r")
    
    neq(undo_file, nil)
    success, err = os.remove(correct_name)  -- delete the file now that we're done with it.
    if not success then
      print(err)  -- inform tester if undofile fails to delete
    end
  end)
  
  it('writes a correctly-named undo file to undodir given a name, buffer, and hash', function()
    correct_name = "undofile.test"
    u_write_undo(correct_name, false, file_buffer, hash)
    undo_file = io.open(correct_name, "r")
    
    neq(undo_file, nil)
    success, err = os.remove(correct_name)  -- delete the file now that we're done with it.
    if not success then
      print(err)  -- inform tester if undofile fails to delete
    end
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
