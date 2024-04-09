local t = require('test.unit.testutil')
local itp = t.gen_itp(it)
local uv = vim.uv
local child_call_once = t.child_call_once
local sleep = uv.sleep

local ffi = t.ffi
local cimport = t.cimport
local to_cstr = t.to_cstr
local neq = t.neq
local eq = t.eq
local mkdir = t.mkdir

local options = cimport('./src/nvim/option_vars.h')
local undo = cimport('./src/nvim/undo.h')
local buffer = cimport('./src/nvim/buffer.h')

local old_p_udir = nil

-- Values expected by tests. Set in the setup function and destroyed in teardown
local file_buffer = nil
local buffer_hash = nil

child_call_once(function()
  if old_p_udir == nil then
    old_p_udir = options.p_udir -- save the old value of p_udir (undodir)
  end

  -- create a new buffer
  local c_file = to_cstr('Xtest-unit-undo')
  file_buffer = buffer.buflist_new(c_file, c_file, 1, buffer.BLN_LISTED)
  file_buffer.b_u_numhead = 1 -- Pretend that the buffer has been changed

  -- TODO(christopher.waldon.dev@gmail.com): replace the 32 with UNDO_HASH_SIZE
  -- requires refactor of UNDO_HASH_SIZE into constant/enum for ffi
  --
  -- compute a hash for this undofile
  buffer_hash = ffi.new('char[32]')
  undo.u_compute_hash(file_buffer, buffer_hash)
end)

describe('u_write_undo', function()
  setup(function()
    mkdir('unit-test-directory')
    uv.chdir('unit-test-directory')
    options.p_udir = to_cstr(uv.cwd()) -- set p_udir to be the test dir
  end)

  teardown(function()
    uv.chdir('..')
    local success, err = uv.fs_rmdir('unit-test-directory')
    if not success then
      print(err) -- inform tester if directory fails to delete
    end
    options.p_udir = old_p_udir --restore old p_udir
  end)

  -- Lua wrapper for u_write_undo
  local function u_write_undo(name, forceit, buf, buf_hash)
    if name ~= nil then
      name = to_cstr(name)
    end

    return undo.u_write_undo(name, forceit, buf, buf_hash)
  end

  itp('writes an undo file to undodir given a buffer and hash', function()
    u_write_undo(nil, false, file_buffer, buffer_hash)
    local correct_name = ffi.string(undo.u_get_undo_file_name(file_buffer.b_ffname, false))
    local undo_file = io.open(correct_name, 'r')

    neq(undo_file, nil)
    local success, err = os.remove(correct_name) -- delete the file now that we're done with it.
    if not success then
      print(err) -- inform tester if undofile fails to delete
    end
  end)

  itp('writes a correctly-named undo file to undodir given a name, buffer, and hash', function()
    local correct_name = 'undofile.test'
    u_write_undo(correct_name, false, file_buffer, buffer_hash)
    local undo_file = io.open(correct_name, 'r')

    neq(undo_file, nil)
    local success, err = os.remove(correct_name) -- delete the file now that we're done with it.
    if not success then
      print(err) -- inform tester if undofile fails to delete
    end
  end)

  itp('does not write an undofile when the buffer has no valid undofile name', function()
    -- TODO(christopher.waldon.dev@gmail.com): Figure out how to test this.
    -- it's hard because u_get_undo_file_name() would need to return null
  end)

  itp('writes the undofile with the same permissions as the original file', function()
    -- Create Test file and set permissions
    local test_file_name = './test.file'
    local test_permission_file = io.open(test_file_name, 'w')
    test_permission_file:write('testing permissions')
    test_permission_file:close()
    local test_permissions = uv.fs_stat(test_file_name).mode

    -- Create vim buffer
    local c_file = to_cstr(test_file_name)
    file_buffer = buffer.buflist_new(c_file, c_file, 1, buffer.BLN_LISTED)
    file_buffer.b_u_numhead = 1 -- Pretend that the buffer has been changed

    u_write_undo(nil, false, file_buffer, buffer_hash)

    -- Find out the correct name of the undofile
    local undo_file_name = ffi.string(undo.u_get_undo_file_name(file_buffer.b_ffname, false))

    -- Find out the permissions of the new file
    local permissions = uv.fs_stat(undo_file_name).mode
    eq(test_permissions, permissions)

    -- delete the file now that we're done with it.
    local success, err = os.remove(test_file_name)
    if not success then
      print(err) -- inform tester if undofile fails to delete
    end
    success, err = os.remove(undo_file_name)
    if not success then
      print(err) -- inform tester if undofile fails to delete
    end
  end)

  itp('writes an undofile only readable by the user if the buffer is unnamed', function()
    local correct_permissions = 33152
    local undo_file_name = 'test.undo'

    -- Create vim buffer
    file_buffer = buffer.buflist_new(nil, nil, 1, buffer.BLN_LISTED)
    file_buffer.b_u_numhead = 1 -- Pretend that the buffer has been changed

    u_write_undo(undo_file_name, false, file_buffer, buffer_hash)

    -- Find out the permissions of the new file
    local permissions = uv.fs_stat(undo_file_name).mode
    eq(correct_permissions, permissions)

    -- delete the file now that we're done with it.
    local success, err = os.remove(undo_file_name)
    if not success then
      print(err) -- inform tester if undofile fails to delete
    end
  end)

  itp('forces writing undo file for :wundo! command', function()
    local file_contents = 'testing permissions'
    -- Write a text file where the undofile should go
    local correct_name = ffi.string(undo.u_get_undo_file_name(file_buffer.b_ffname, false))
    t.write_file(correct_name, file_contents, true, false)

    -- Call with `forceit`.
    u_write_undo(correct_name, true, file_buffer, buffer_hash)

    local undo_file_contents = t.read_file(correct_name)

    neq(file_contents, undo_file_contents)
    local success, deletion_err = os.remove(correct_name) -- delete the file now that we're done with it.
    if not success then
      print(deletion_err) -- inform tester if undofile fails to delete
    end
  end)

  itp('overwrites an existing undo file', function()
    u_write_undo(nil, false, file_buffer, buffer_hash)
    local correct_name = ffi.string(undo.u_get_undo_file_name(file_buffer.b_ffname, false))

    local file_last_modified = uv.fs_stat(correct_name).mtime.sec

    sleep(1000) -- Ensure difference in timestamps.
    file_buffer.b_u_numhead = 1 -- Mark it as if there are changes
    u_write_undo(nil, false, file_buffer, buffer_hash)

    local file_last_modified_2 = uv.fs_stat(correct_name).mtime.sec

    -- print(file_last_modified, file_last_modified_2)
    neq(file_last_modified, file_last_modified_2)
    local success, err = os.remove(correct_name) -- delete the file now that we're done with it.
    if not success then
      print(err) -- inform tester if undofile fails to delete
    end
  end)

  itp('does not overwrite an existing file that is not an undo file', function()
    -- TODO: write test
  end)

  itp('does not overwrite an existing file that has the wrong permissions', function()
    -- TODO: write test
  end)

  itp('does not write an undo file if there is no undo information for the buffer', function()
    file_buffer.b_u_numhead = 0 -- Mark it as if there is no undo information
    local correct_name = ffi.string(undo.u_get_undo_file_name(file_buffer.b_ffname, false))

    local existing_file = io.open(correct_name, 'r')
    if existing_file then
      existing_file:close()
      os.remove(correct_name)
    end
    u_write_undo(nil, false, file_buffer, buffer_hash)
    local undo_file = io.open(correct_name, 'r')

    eq(undo_file, nil)
  end)
end)
