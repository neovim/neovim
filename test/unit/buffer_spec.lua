local helpers = require("test.unit.helpers")

local to_cstr = helpers.to_cstr
local eq      = helpers.eq

local buffer = helpers.cimport("./src/nvim/buffer.h")
local window = helpers.cimport("./src/nvim/window.h")
local option = helpers.cimport("./src/nvim/option.h")

describe('buffer functions', function()

  local buflist_new = function(file, flags)
    local c_file = to_cstr(file)
    return buffer.buflist_new(c_file, c_file, 1, flags)
  end

  local close_buffer = function(win, buf, action, abort_if_last)
    return buffer.close_buffer(win, buf, action, abort_if_last)
  end

  local path1 = 'test_file_path'
  local path2 = 'file_path_test'
  local path3 = 'path_test_file'

  before_each(function()
    -- create the files
    io.open(path1, 'w').close()
    io.open(path2, 'w').close()
    io.open(path3, 'w').close()
  end)

  after_each(function()
    os.remove(path1)
    os.remove(path2)
    os.remove(path3)
  end)

  describe('buf_valid', function()

    it('should view NULL as an invalid buffer', function()
      eq(0, buffer.buf_valid(NULL))
    end)

    it('should view an open buffer as valid', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      eq(1, buffer.buf_valid(buf))
    end)

    it('should view a closed and hidden buffer as valid', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      close_buffer(NULL, buf, 0, 0)

      eq(1, buffer.buf_valid(buf))
    end)

    it('should view a closed and unloaded buffer as valid', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      close_buffer(NULL, buf, buffer.DOBUF_UNLOAD, 0)

      eq(1, buffer.buf_valid(buf))
    end)

    it('should view a closed and wiped buffer as invalid', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      close_buffer(NULL, buf, buffer.DOBUF_WIPE, 0)

      eq(0, buffer.buf_valid(buf))
    end)
  end)


  describe('buflist_findpat', function()

    local ALLOW_UNLISTED = 1
    local ONLY_LISTED    = 0

    local buflist_findpat = function(pat, allow_unlisted)
      return buffer.buflist_findpat(to_cstr(pat), NULL, allow_unlisted, 0, 0)
    end

    it('should find exact matches', function()
      local buf = buflist_new(path1, buffer.BLN_LISTED)

      eq(buf.b_fnum, buflist_findpat(path1, ONLY_LISTED))

      close_buffer(NULL, buf, buffer.DOBUF_WIPE, 0)
    end)

    it('should prefer to match the start of a file path', function()
      local buf1 = buflist_new(path1, buffer.BLN_LISTED)
      local buf2 = buflist_new(path2, buffer.BLN_LISTED)
      local buf3 = buflist_new(path3, buffer.BLN_LISTED)

      eq(buf1.b_fnum, buflist_findpat("test", ONLY_LISTED))
      eq(buf2.b_fnum, buflist_findpat("file", ONLY_LISTED))
      eq(buf3.b_fnum, buflist_findpat("path", ONLY_LISTED))

      close_buffer(NULL, buf1, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf2, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf3, buffer.DOBUF_WIPE, 0)
    end)

    it('should prefer to match the end of a file over the middle', function()
      --{ Given: Two buffers, where 'test' appears in both
      --  And: 'test' appears at the end of buf3 but in the middle of buf2
      local buf2 = buflist_new(path2, buffer.BLN_LISTED)
      local buf3 = buflist_new(path3, buffer.BLN_LISTED)

      -- Then: buf2 is the buffer that is found
      eq(buf2.b_fnum, buflist_findpat("test", ONLY_LISTED))
      --}

      --{ When: We close buf2
      close_buffer(NULL, buf2, buffer.DOBUF_WIPE, 0)

      -- And: Open buf1, which has 'file' in the middle of its name
      local buf1 = buflist_new(path1, buffer.BLN_LISTED)

      -- Then: buf3 is found since 'file' appears at the end of the name
      eq(buf3.b_fnum, buflist_findpat("file", ONLY_LISTED))
      --}

      close_buffer(NULL, buf1, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf3, buffer.DOBUF_WIPE, 0)
    end)

    it('should match a unique fragment of a file path', function()
      local buf1 = buflist_new(path1, buffer.BLN_LISTED)
      local buf2 = buflist_new(path2, buffer.BLN_LISTED)
      local buf3 = buflist_new(path3, buffer.BLN_LISTED)

      eq(buf3.b_fnum, buflist_findpat("_test_", ONLY_LISTED))

      close_buffer(NULL, buf1, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf2, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf3, buffer.DOBUF_WIPE, 0)
    end)

    it('should include / ignore unlisted buffers based on the flag.', function()
      --{ Given: A buffer
      local buf3 = buflist_new(path3, buffer.BLN_LISTED)

      -- Then: We should find the buffer when it is given a unique pattern
      eq(buf3.b_fnum, buflist_findpat("_test_", ONLY_LISTED))
      --}

      --{ When: We unlist the buffer
      close_buffer(NULL, buf3, buffer.DOBUF_DEL, 0)

      -- Then: It should not find the buffer when searching only listed buffers
      eq(-1, buflist_findpat("_test_", ONLY_LISTED))

      -- And: It should find the buffer when including unlisted buffers
      eq(buf3.b_fnum, buflist_findpat("_test_", ALLOW_UNLISTED))
      --}

      --{ When: We wipe the buffer
      close_buffer(NULL, buf3, buffer.DOBUF_WIPE, 0)

      -- Then: It should not find the buffer at all
      eq(-1, buflist_findpat("_test_", ONLY_LISTED))
      eq(-1, buflist_findpat("_test_", ALLOW_UNLISTED))
      --}
    end)

    it('should prefer listed buffers to unlisted buffers.', function()
      --{ Given: Two buffers that match a pattern
      local buf1 = buflist_new(path1, buffer.BLN_LISTED)
      local buf2 = buflist_new(path2, buffer.BLN_LISTED)

      -- Then: The first buffer is preferred when both are listed
      eq(buf1.b_fnum, buflist_findpat("test", ONLY_LISTED))
      --}

      --{ When: The first buffer is unlisted
      close_buffer(NULL, buf1, buffer.DOBUF_DEL, 0)

      -- Then: The second buffer is preferred because
      --       unlisted buffers are not allowed
      eq(buf2.b_fnum, buflist_findpat("test", ONLY_LISTED))
      --}

      --{ When: We allow unlisted buffers
      -- Then: The second buffer is still preferred
      --       because listed buffers are preferred to unlisted
      eq(buf2.b_fnum, buflist_findpat("test", ALLOW_UNLISTED))
      --}

      --{ When: We unlist the second buffer
      close_buffer(NULL, buf2, buffer.DOBUF_DEL, 0)

      -- Then: The first buffer is preferred again
      --       because buf1 matches better which takes precedence
      --       when both buffers have the same listing status.
      eq(buf1.b_fnum, buflist_findpat("test", ALLOW_UNLISTED))

      -- And: Neither buffer is returned when ignoring unlisted
      eq(-1, buflist_findpat("test", ONLY_LISTED))
      --}

      close_buffer(NULL, buf1, buffer.DOBUF_WIPE, 0)
      close_buffer(NULL, buf2, buffer.DOBUF_WIPE, 0)
    end)
  end)
end)
