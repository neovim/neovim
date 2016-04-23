-- not all operating systems support the system()-tests, as of yet.
local allowed_os = {
  Linux = true,
  OSX = true,
  BSD = true,
  POSIX = true
}

if allowed_os[jit.os] ~= true then
  return
end

local helpers = require('test.unit.helpers')
local shell = helpers.cimport(
  './src/nvim/os/shell.h',
  './src/nvim/option_defs.h',
  './src/nvim/main.h',
  './src/nvim/misc1.h',
  './src/nvim/memory.h'
)
local ffi, eq = helpers.ffi, helpers.eq
local intern = helpers.internalize
local to_cstr = helpers.to_cstr
local NULL = ffi.cast('void *', 0)

describe('shell functions', function()
  setup(function()
    shell.event_init()
    -- os_system() can't work when the p_sh and p_shcf variables are unset
    shell.p_sh = to_cstr('/bin/bash')
    shell.p_shcf = to_cstr('-c')
  end)

  teardown(function()
    shell.event_teardown()
  end)

  local function shell_build_argv(cmd, extra_args)
    local res = shell.shell_build_argv(
        cmd and to_cstr(cmd),
        extra_args and to_cstr(extra_args))
    local argc = 0
    local ret = {}
    -- Explicitly free everything, so if it is not in allocated memory it will
    -- crash.
    while res[argc] ~= nil do
      ret[#ret + 1] = ffi.string(res[argc])
      shell.xfree(res[argc])
      argc = argc + 1
    end
    shell.xfree(res)
    return ret
  end

  local function os_system(cmd, input)
    local input_or = input and to_cstr(input) or NULL
    local input_len = (input ~= nil) and string.len(input) or 0
    local output = ffi.new('char *[1]')
    local nread = ffi.new('size_t[1]')

    local argv = ffi.cast('char**',
                          shell.shell_build_argv(to_cstr(cmd), nil))
    local status = shell.os_system(argv, input_or, input_len, output, nread)

    return status, intern(output[0], nread[0])
  end

  describe('os_system', function()
    it('can echo some output (shell builtin)', function()
      local cmd, text = 'echo -n', 'some text'
      local status, output = os_system(cmd .. ' ' .. text)
      eq(text, output)
      eq(0, status)
    end)

    it('can deal with empty output', function()
      local cmd = 'echo -n'
      local status, output = os_system(cmd)
      eq('', output)
      eq(0, status)
    end)

    it('can pass input on stdin', function()
      local cmd, input = 'cat -', 'some text\nsome other text'
      local status, output = os_system(cmd, input)
      eq(input, output)
      eq(0, status)
    end)

    it ('returns non-zero exit code', function()
      local status = os_system('exit 2')
      eq(2, status)
    end)
  end)

  describe('shell_build_argv', function()
    local saved_opts = {}

    setup(function()
      saved_opts.p_sh = shell.p_sh
      saved_opts.p_shcf = shell.p_shcf
    end)

    teardown(function()
      shell.p_sh = saved_opts.p_sh
      shell.p_shcf = saved_opts.p_shcf
    end)

    it('works with NULL arguments', function()
      eq({'/bin/bash'}, shell_build_argv(nil, nil))
    end)

    it('works with cmd', function()
      eq({'/bin/bash', '-c', 'abc  def'}, shell_build_argv('abc  def', nil))
    end)

    it('works with extra_args', function()
      eq({'/bin/bash', 'ghi  jkl'}, shell_build_argv(nil, 'ghi  jkl'))
    end)

    it('works with cmd and extra_args', function()
      eq({'/bin/bash', 'ghi  jkl', '-c', 'abc  def'}, shell_build_argv('abc  def', 'ghi  jkl'))
    end)

    it('splits and unquotes &shell and &shellcmdflag', function()
      shell.p_sh = to_cstr('/Program" "Files/zsh -f')
      shell.p_shcf = to_cstr('-x -o "sh word split" "-"c')
      eq({'/Program Files/zsh', '-f',
          'ghi  jkl',
          '-x', '-o', 'sh word split',
          '-c', 'abc  def'},
         shell_build_argv('abc  def', 'ghi  jkl'))
    end)
  end)
end)
