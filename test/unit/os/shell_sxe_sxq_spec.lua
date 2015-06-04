-- not all operating systems support the system()-tests, as of yet.
local allowed_os = {
  Linux = true,
  OSX = true,
  BSD = true,
  POSIX = true,
  WINDOWS = true
}

if allowed_os[jit.os] ~= true then
  return
end

local helpers = require('test.unit.helpers')
local shell = helpers.cimport(
  './src/nvim/os/shell.h',
  './src/nvim/option_defs.h'
)
local ffi, eq, neq = helpers.ffi, helpers.eq, helpers.neq
local to_cstr = helpers.to_cstr

describe('shell functions', function()
  setup(function()
    shell.p_sh = to_cstr('/bin/bash')
    shell.p_shcf = to_cstr('-c')
    shell.p_sxq = to_cstr('(')
    shell.p_sxe = to_cstr('"&|<>()@^')
  end)

  it('applies shellxescape', function()
    local argv = ffi.cast('char**',
                        shell.shell_build_argv(to_cstr('echo &|<>()@^'), nil))
    eq(ffi.string(argv[0]), '/bin/bash')
    eq(ffi.string(argv[1]), '-c')
    eq(ffi.string(argv[2]), '(echo ^&^|^<^>^(^)^@^^)')
    eq(nil, argv[3])
  end)

  teardown(function()
    shell.p_sxq = to_cstr('')
    shell.p_sxe = to_cstr('')
  end)
end)
