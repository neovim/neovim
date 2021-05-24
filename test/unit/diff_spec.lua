local ffi = require('ffi')
local io = require('io')
local lfs = require('lfs')
local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)

local cimport = helpers.cimport
local eq      = helpers.eq
local to_cstr = helpers.to_cstr

local diff = cimport('./src/nvim/diff.h')

local function new_Diff2Hunk(lstart_orig, count_orig, lstart_dest, count_dest)
  local hunk = ffi.new('Diff2Hunk')
  hunk.lstart_orig = lstart_orig
  hunk.count_orig = count_orig
  hunk.lstart_dest = lstart_dest
  hunk.count_dest = count_dest
  return hunk
end

local function eq_Diff2Hunk(hunkl, hunkr)
  eq(hunkl.lstart_orig, hunkr.lstart_orig)
  eq(hunkl.count_orig, hunkr.count_orig)
  eq(hunkl.lstart_dest, hunkr.lstart_dest)
  eq(hunkl.count_dest, hunkr.count_dest)
end

describe('diff.c', function()
  local unit_test_directory_name = 'unit-test-directory'
  before_each(function()
    lfs.mkdir(unit_test_directory_name);
  end)

  after_each(function()
    lfs.rmdir(unit_test_directory_name)
  end)

  describe('diff_parse', function()
    itp('parses an external ed-style diff', function()
      local diff_file_name = unit_test_directory_name .. '/' .. 'ext-ed.diff'
      local diff_file = io.open(diff_file_name, 'w')
      diff_file:write('0a1\n')
      diff_file:write('> 1r\n')
      diff_file:write('1d1\n')
      diff_file:write('< 1l\n')
      diff_file:write('2,3c2,3\n')
      diff_file:write('< 2l\n')
      diff_file:write('< 3l\n')
      diff_file:write('> 2r\n')
      diff_file:write('> 3r\n')
      io.close(diff_file)

      local input = ffi.new('diffout_T')
      input.dout_fname = to_cstr(diff_file_name)
      local output = ffi.new('Diff2Hunk*[1]')
      local result = diff.diff_parse(input, output)
      eq(true, result)
      eq(3, diff.diff2_hunk_list_length(output[0]))
      eq_Diff2Hunk(new_Diff2Hunk(1, 0, 1, 1), output[0])
      eq_Diff2Hunk(new_Diff2Hunk(1, 1, 2, 0), output[0].next)
      eq_Diff2Hunk(new_Diff2Hunk(2, 2, 2, 2), output[0].next.next)

      diff.diff2_hunk_list_dealloc(output[0])
      os.remove(diff_file_name)
    end)

    itp('parses an external unified-style diff', function()
      local diff_file_name = unit_test_directory_name .. '/' .. 'ext-unif.diff'
      local diff_file = io.open(diff_file_name, 'w')
      diff_file:write('--- a	2021-05-16 11:51:41.739056110 +0200\n')
      diff_file:write('+++ b	2021-05-16 11:51:44.372400145 +0200\n')
      diff_file:write('@@ -1 +1 @@\n')
      diff_file:write('-a\n')
      diff_file:write('+b\n')
      io.close(diff_file)

      local input = ffi.new('diffout_T')
      input.dout_fname = to_cstr(diff_file_name)
      local output = ffi.new('Diff2Hunk*[1]')
      local result = diff.diff_parse(input, output)
      eq(true, result)
      eq(1, diff.diff2_hunk_list_length(output[0]))
      eq_Diff2Hunk(new_Diff2Hunk(1, 1, 1, 1), output[0])

      diff.diff2_hunk_list_dealloc(output[0])
      os.remove(diff_file_name)
    end)
    itp('returns false when it can\'t read the file', function()
      local input = ffi.new('diffout_T')
      input.dout_fname = to_cstr('does_not_exist')
      local output = ffi.new('Diff2Hunk*[1]')
      local result = diff.diff_parse(input, output)
      eq(false, result)
    end)
  end)
end)
