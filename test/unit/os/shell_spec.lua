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
  './src/nvim/os/event.h',
  './src/nvim/misc1.h'
)
local ffi, eq, neq = helpers.ffi, helpers.eq, helpers.neq
local intern = helpers.internalize
local to_cstr = helpers.to_cstr
local NULL = ffi.cast('void *', 0)

describe('shell functions', function()
  setup(function()
    shell.event_early_init()
    shell.event_init()
    -- os_system() can't work when the p_sh and p_shcf variables are unset
    shell.p_sh = to_cstr('/bin/bash')
    shell.p_shcf = to_cstr('-c')
  end)

  teardown(function()
    shell.event_teardown()
  end)

  local function os_system(cmd, input)
    local input_or = input and to_cstr(input) or NULL
    local input_len = (input ~= nil) and string.len(input) or 0
    local output = ffi.new('char *[1]')
    local nread = ffi.new('size_t[1]')

    local status = shell.os_system(to_cstr(cmd), input_or, input_len, output, nread)

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
  end)
end)
