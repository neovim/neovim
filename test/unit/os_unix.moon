{:cimport, :eq, :ffi, :lib, :cstr} = require 'test.unit.helpers'

-- os = cimport './src/os_unix.h'
os = lib
ffi.cdef [[
enum BOOLEAN {
  TRUE = 1, FALSE = 0
};
int mch_isdir(char_u * name);
int is_executable(char_u *name);
int mch_can_exe(char_u *name);
]]

{:TRUE, :FALSE} = lib

describe 'os_unix function', ->
  setup ->
    lfs.mkdir 'unit-test-directory'
    lfs.touch 'unit-test-directory/test.file'

    -- Since the tests are executed, they are called by an executable. We use
    -- that executable for several asserts.
    export absolute_executable = arg[0]

    -- Split absolute_executable into a directory and the actual file name for
    -- later usage.
    export directory, executable_name = if (string.find absolute_executable, '/')
      string.match(absolute_executable, '^(.*)/(.*)$')
    else
      string.match(absolute_executable, '^(.*)\\(.*)$')

  teardown ->
    lfs.rmdir 'unit-test-directory'

  describe 'mch_isdir', ->
    mch_isdir = (name) ->
      name = cstr (string.len name), name
      os.mch_isdir(name)

    it 'returns false if an empty string is given', ->
      eq FALSE, (mch_isdir '')

    it 'returns false if a nonexisting directory is given', ->
      eq FALSE, (mch_isdir 'non-existing-directory')

    it 'returns false if an existing file is given', ->
      eq FALSE, (mch_isdir 'non-existing-directory/test.file')

    it 'returns true if the current directory is given', ->
      eq TRUE, (mch_isdir '.')

    it 'returns true if the parent directory is given', ->
      eq TRUE, (mch_isdir '..')

    it 'returns true if an arbitrary directory is given', ->
      eq TRUE, (mch_isdir 'unit-test-directory')

  describe 'is_executable', ->
    is_executable = (name) ->
      name = cstr (string.len name), name
      os.is_executable name

    it 'returns false when given a directory', ->
      eq FALSE, (is_executable 'unit-test-directory')

    it 'returns false when the given file does not exists', ->
      eq FALSE, (is_executable 'does-not-exist.file')

    it 'returns true when given an executable regular file', ->
      eq TRUE, (is_executable absolute_executable)

    it 'returns false when given a regular file without executable bit set', ->
      -- This is a critical test since Windows does not have any executable
      -- bit. Thus is_executable returns TRUE on every regular file on
      -- Windows and this test will fail.
      eq FALSE, (is_executable 'unit-test-directory/test.file')

  describe 'mch_can_exe', ->
    mch_can_exe = (name) ->
      name = cstr (string.len name), name
      os.mch_can_exe name

    it 'returns false when given a directory', ->
      eq FALSE, (mch_can_exe './unit-test-directory')

    it 'returns false when the given file does not exists', ->
      eq FALSE, (mch_can_exe 'does-not-exist.file')

    it 'returns true when given an executable inside $PATH', ->
      eq TRUE, (mch_can_exe executable_name)

    it 'returns true when given an executable relative to the current dir', ->
      old_dir = lfs.currentdir!
      lfs.chdir directory
      relative_executable = './' .. executable_name
      eq TRUE, (mch_can_exe relative_executable)
      lfs.chdir old_dir
