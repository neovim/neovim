local helpers = require('test.unit.helpers')(after_each)
local itp = helpers.gen_itp(it)

local cimport = helpers.cimport
local eq = helpers.eq
local neq = helpers.neq
local ffi = helpers.ffi
local cstr = helpers.cstr
local to_cstr = helpers.to_cstr
local NULL = helpers.NULL
local OK = 0

require('lfs')

local cimp = cimport('./src/nvim/os/os.h')

describe('env.c', function()
  local function os_env_exists(name)
    return cimp.os_env_exists(to_cstr(name))
  end

  local function os_setenv(name, value, override)
    return cimp.os_setenv(to_cstr(name), to_cstr(value), override)
  end

  local function os_unsetenv(name)
    return cimp.os_unsetenv(to_cstr(name))
  end

  local function os_getenv(name)
    local rval = cimp.os_getenv(to_cstr(name))
    if rval ~= NULL then
      return ffi.string(rval)
    else
      return NULL
    end
  end

  itp('os_env_exists', function()
    eq(false, os_env_exists(''))
    eq(false, os_env_exists('      '))
    eq(false, os_env_exists('\t'))
    eq(false, os_env_exists('\n'))
    eq(false, os_env_exists('AaあB <= very weird name...'))

    local varname = 'NVIM_UNIT_TEST_os_env_exists'
    eq(false, os_env_exists(varname))
    eq(OK, os_setenv(varname, 'foo bar baz ...', 1))
    eq(true, os_env_exists(varname))
  end)

  describe('os_setenv', function()
    itp('sets an env var and returns success', function()
      local name = 'NVIM_UNIT_TEST_SETENV_1N'
      local value = 'NVIM_UNIT_TEST_SETENV_1V'
      eq(nil, os.getenv(name))
      eq(OK, os_setenv(name, value, 1))
      eq(value, os.getenv(name))

      -- Set empty, then set non-empty, then retrieve.
      eq(OK, os_setenv(name, '', 1))
      eq('', os.getenv(name))
      eq(OK, os_setenv(name, 'non-empty', 1))
      eq('non-empty', os.getenv(name))
    end)

    itp("`overwrite` behavior", function()
      local name = 'NVIM_UNIT_TEST_SETENV_2N'
      local value = 'NVIM_UNIT_TEST_SETENV_2V'
      local value_updated = 'NVIM_UNIT_TEST_SETENV_2V_UPDATED'
      eq(OK, os_setenv(name, value, 0))
      eq(value, os.getenv(name))
      eq(OK, os_setenv(name, value_updated, 0))
      eq(value, os.getenv(name))
      eq(OK, os_setenv(name, value_updated, 1))
      eq(value_updated, os.getenv(name))
    end)
  end)

  describe('os_setenv_append_path', function()
    itp('appends /foo/bar to $PATH', function()
      local original_path = os.getenv('PATH')
      eq(true, cimp.os_setenv_append_path(to_cstr('/foo/bar/baz')))
      eq(original_path..':/foo/bar', os.getenv('PATH'))
    end)

    itp('returns false if `fname` is not absolute', function()
      local original_path = os.getenv('PATH')
      eq(false, cimp.os_setenv_append_path(to_cstr('foo/bar/baz')))
      eq(original_path, os.getenv('PATH'))
    end)
  end)

  describe('os_shell_is_cmdexe', function()
    itp('returns true for expected names', function()
      eq(true, cimp.os_shell_is_cmdexe(to_cstr('cmd.exe')))
      eq(true, cimp.os_shell_is_cmdexe(to_cstr('cmd')))
      eq(true, cimp.os_shell_is_cmdexe(to_cstr('CMD.EXE')))
      eq(true, cimp.os_shell_is_cmdexe(to_cstr('CMD')))

      os_setenv('COMSPEC', '/foo/bar/cmd.exe', 0)
      eq(true, cimp.os_shell_is_cmdexe(to_cstr('$COMSPEC')))
      os_setenv('COMSPEC', [[C:\system32\cmd.exe]], 0)
      eq(true, cimp.os_shell_is_cmdexe(to_cstr('$COMSPEC')))
    end)
    itp('returns false for unexpected names', function()
      eq(false, cimp.os_shell_is_cmdexe(to_cstr('')))
      eq(false, cimp.os_shell_is_cmdexe(to_cstr('powershell')))
      eq(false, cimp.os_shell_is_cmdexe(to_cstr(' cmd.exe ')))
      eq(false, cimp.os_shell_is_cmdexe(to_cstr('cm')))
      eq(false, cimp.os_shell_is_cmdexe(to_cstr('md')))
      eq(false, cimp.os_shell_is_cmdexe(to_cstr('cmd.ex')))

      os_setenv('COMSPEC', '/foo/bar/cmd', 0)
      eq(false, cimp.os_shell_is_cmdexe(to_cstr('$COMSPEC')))
    end)
  end)

  describe('os_getenv', function()
    itp('reads an env var', function()
      local name = 'NVIM_UNIT_TEST_GETENV_1N'
      local value = 'NVIM_UNIT_TEST_GETENV_1V'
      eq(NULL, os_getenv(name))
      -- Use os_setenv because Lua dosen't have setenv.
      os_setenv(name, value, 1)
      eq(value, os_getenv(name))

      -- Get a big value.
      local bigval = ('x'):rep(256)
      eq(OK, os_setenv(name, bigval, 1))
      eq(bigval, os_getenv(name))

      -- Set non-empty, then set empty.
      eq(OK, os_setenv(name, 'non-empty', 1))
      eq('non-empty', os_getenv(name))
      eq(OK, os_setenv(name, '', 1))
      eq(NULL, os_getenv(name))
    end)

    itp('returns NULL if the env var is not found', function()
      eq(NULL, os_getenv('NVIM_UNIT_TEST_GETENV_NOTFOUND'))
    end)
  end)

  itp('os_unsetenv', function()
    local name = 'TEST_UNSETENV'
    local value = 'TESTVALUE'
    os_setenv(name, value, 1)
    eq(OK, os_unsetenv(name))
    neq(os_getenv(name), value)
    -- Depending on the platform the var might be unset or set as ''
    assert.True(os_getenv(name) == nil or os_getenv(name) == '')
    if os_getenv(name) == nil then
      eq(false, os_env_exists(name))
    end
  end)

  describe('os_getenvname_at_index', function()
    itp('returns names of environment variables', function()
      local test_name = 'NVIM_UNIT_TEST_GETENVNAME_AT_INDEX_1N'
      local test_value = 'NVIM_UNIT_TEST_GETENVNAME_AT_INDEX_1V'
      os_setenv(test_name, test_value, 1)
      local i = 0
      local names = { }
      local found_name = false
      local name = cimp.os_getenvname_at_index(i)
      while name ~= NULL do
        table.insert(names, ffi.string(name))
        if (ffi.string(name)) == test_name then
          found_name = true
        end
        i = i + 1
        name = cimp.os_getenvname_at_index(i)
      end
      eq(true, (table.getn(names)) > 0)
      eq(true, found_name)
    end)

    itp('returns NULL if the index is out of bounds', function()
      local huge = ffi.new('size_t', 10000)
      local maxuint32 = ffi.new('size_t', 4294967295)
      eq(NULL, cimp.os_getenvname_at_index(huge))
      eq(NULL, cimp.os_getenvname_at_index(maxuint32))

      if ffi.abi('64bit') then
        -- couldn't use a bigger number because it gets converted to
        -- double somewere, should be big enough anyway
        -- maxuint64 = ffi.new 'size_t', 18446744073709551615
        local maxuint64 = ffi.new('size_t', 18446744073709000000)
        eq(NULL, cimp.os_getenvname_at_index(maxuint64))
      end
    end)
  end)

  describe('os_get_pid', function()
    itp('returns the process ID', function()
      local stat_file = io.open('/proc/self/stat')
      if stat_file then
        local stat_str = stat_file:read('*l')
        stat_file:close()
        local pid = tonumber((stat_str:match('%d+')))
        eq(pid, tonumber(cimp.os_get_pid()))
      else
        -- /proc is not available on all systems, test if pid is nonzero.
        eq(true, (cimp.os_get_pid() > 0))
      end
    end)
  end)

  describe('os_get_hostname', function()
    itp('returns the hostname', function()
      local handle = io.popen('hostname')
      local hostname = handle:read('*l')
      handle:close()
      local hostname_buf = cstr(255, '')
      cimp.os_get_hostname(hostname_buf, 255)
      eq(hostname, (ffi.string(hostname_buf)))
    end)
  end)

  describe('expand_env_esc', function()
    itp('expands environment variables', function()
      local name = 'NVIM_UNIT_TEST_EXPAND_ENV_ESCN'
      local value = 'NVIM_UNIT_TEST_EXPAND_ENV_ESCV'
      os_setenv(name, value, 1)
      -- TODO(bobtwinkles) This only tests Unix expansions. There should be a
      -- test for Windows as well
      local input1 = to_cstr('$NVIM_UNIT_TEST_EXPAND_ENV_ESCN/test')
      local input2 = to_cstr('${NVIM_UNIT_TEST_EXPAND_ENV_ESCN}/test')
      local output_buff1 = cstr(255, '')
      local output_buff2 = cstr(255, '')
      local output_expected = 'NVIM_UNIT_TEST_EXPAND_ENV_ESCV/test'
      cimp.expand_env_esc(input1, output_buff1, 255, false, true, NULL)
      cimp.expand_env_esc(input2, output_buff2, 255, false, true, NULL)
      eq(output_expected, ffi.string(output_buff1))
      eq(output_expected, ffi.string(output_buff2))
    end)

    itp('expands ~ once when `one` is true', function()
      local input = '~/foo ~ foo'
      local homedir = cstr(255, '')
      cimp.expand_env_esc(to_cstr('~'), homedir, 255, false, true, NULL)
      local output_expected = ffi.string(homedir) .. "/foo ~ foo"
      local output = cstr(255, '')
      cimp.expand_env_esc(to_cstr(input), output, 255, false, true, NULL)
      eq(ffi.string(output), ffi.string(output_expected))
    end)

    itp('expands ~ every time when `one` is false', function()
      local input = to_cstr('~/foo ~ foo')
      local dst = cstr(255, '')
      cimp.expand_env_esc(to_cstr('~'), dst, 255, false, true, NULL)
      local homedir = ffi.string(dst)
      local output_expected = homedir .. "/foo " .. homedir .. " foo"
      local output = cstr(255, '')
      cimp.expand_env_esc(input, output, 255, false, false, NULL)
      eq(output_expected, ffi.string(output))
    end)

    itp('does not crash #3725', function()
      local name_out = ffi.new('char[100]')
      cimp.os_get_user_name(name_out, 100)
      local curuser = ffi.string(name_out)

      local src = to_cstr("~"..curuser.."/Vcs/django-rest-framework/rest_framework/renderers.py")
      local dst = cstr(256, "~"..curuser)
      cimp.expand_env_esc(src, dst, 256, false, false, NULL)
      local len = string.len(ffi.string(dst))
      assert.True(len > 56)
      assert.True(len < 256)
    end)

    itp('respects `dstlen` without expansion', function()
      local input = to_cstr('this is a very long thing that will not fit')
      -- The buffer is long enough to actually contain the full input in case the
      -- test fails, but we don't tell expand_env_esc that
      local output = cstr(255, '')
      cimp.expand_env_esc(input, output, 5, false, true, NULL)
      -- Make sure the first few characters are copied properly and that there is a
      -- terminating null character
      for i=0,3 do
        eq(input[i], output[i])
      end
      eq(0, output[4])
    end)

    itp('respects `dstlen` with expansion', function()
      local varname = to_cstr('NVIM_UNIT_TEST_EXPAND_ENV_ESC_DSTLENN')
      local varval = to_cstr('NVIM_UNIT_TEST_EXPAND_ENV_ESC_DSTLENV')
      cimp.os_setenv(varname, varval, 1)
      -- TODO(bobtwinkles) This test uses unix-specific environment variable accessing,
      -- should have some alternative for windows
      local input = to_cstr('$NVIM_UNIT_TEST_EXPAND_ENV_ESC_DSTLENN/even more stuff')
      -- The buffer is long enough to actually contain the full input in case the
      -- test fails, but we don't tell expand_env_esc that
      local output = cstr(255, '')
      cimp.expand_env_esc(input, output, 5, false, true, NULL)
      -- Make sure the first few characters are copied properly and that there is a
      -- terminating null character
      -- expand_env_esc SHOULD NOT expand the variable if there is not enough space to
      -- contain the result
      for i=0,3 do
        eq(output[i], input[i])
      end
      eq(output[4], 0)
    end)
  end)
end)
