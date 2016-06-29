local lfs = require('lfs')
local helpers = require('test.unit.helpers')

local ffi = helpers.ffi
local cimport = helpers.cimport
local to_cstr = helpers.to_cstr
local neq = helpers.neq
local eq = helpers.eq

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
  
  it('does not write an undofile when the buffer has no valid undofile name', function()
    -- TODO(christopher.waldon.dev@gmail.com): Figure out how to test this.
    -- it's hard because u_get_undo_file_name() would need to return null
  end)

  it('writes the undofile with the same permissions as the original file', function()
    -- Create Test file and set permissions
    test_file_name = "./test.file"
    test_permission_file = io.open(test_file_name, "w")
    test_permission_file:write("testing permissions")
    test_permission_file:close()
    test_permissions = lfs.attributes(test_file_name).permissions

    -- Create vim buffer
    local c_file = to_cstr(test_file_name)
    file_buffer = buffer.buflist_new(c_file, c_file, 1, buffer.BLN_LISTED)
    file_buffer.b_u_numhead = 1 -- Pretend that the buffer has been changed

    u_write_undo(nil, false, file_buffer, hash)
    
    -- Find out the correct name of the undofile
    undo_file_name = ffi.string(undo.u_get_undo_file_name(file_buffer.b_ffname, false))

    -- Find out the permissions of the new file
    permissions = lfs.attributes(undo_file_name).permissions
    eq(test_permissions, permissions)

    -- delete the file now that we're done with it.
    success, err = os.remove(test_file_name)
    if not success then
      print(err)  -- inform tester if undofile fails to delete
    end
    success, err = os.remove(undo_file_name)
    if not success then
      print(err)  -- inform tester if undofile fails to delete
    end
  end)

  it('writes an undofile only readable by the user if the buffer is unnamed', function()
    correct_permissions = "rw-------"
    undo_file_name = "test.undo"
  
    -- Create vim buffer
    file_buffer = buffer.buflist_new(nil, nil, 1, buffer.BLN_LISTED)
    file_buffer.b_u_numhead = 1 -- Pretend that the buffer has been changed

    u_write_undo(undo_file_name, false, file_buffer, hash)
    
    -- Find out the permissions of the new file
    permissions = lfs.attributes(undo_file_name).permissions
    eq(correct_permissions, permissions)

    -- delete the file now that we're done with it.
    success, err = os.remove(undo_file_name)
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
    file_buffer.b_u_numhead = 0 -- Mark it as if there is no undo information
    u_write_undo(nil, false, file_buffer, hash)
    correct_name = ffi.string(undo.u_get_undo_file_name(file_buffer.b_ffname, false))
    undo_file = io.open(correct_name, "r")
    
    eq(undo_file, nil)
  end)
end)
