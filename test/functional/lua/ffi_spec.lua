local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local eq = t.eq
local exec_lua = n.exec_lua
local clear = n.clear

before_each(clear)

describe('ffi.cdef', function()
  it('can use Neovim core functions', function()
    if not exec_lua("return pcall(require, 'ffi')") then
      pending('missing LuaJIT FFI')
    end

    eq(
      12,
      exec_lua [=[
      local ffi = require('ffi')

      ffi.cdef [[
        typedef struct window_S win_T;
        int win_col_off(win_T *wp);
        extern win_T *curwin;
      ]]

      vim.cmd('set number numberwidth=4 signcolumn=yes:4')

      return ffi.C.win_col_off(ffi.C.curwin)
    ]=]
    )

    eq(
      20,
      exec_lua [=[
      local ffi = require('ffi')

      ffi.cdef[[
        typedef struct {} stl_hlrec_t;
        typedef struct {} StlClickRecord;
        typedef struct {} statuscol_T;
        typedef struct {} Error;

        win_T *find_window_by_handle(int Window, Error *err);

        int build_stl_str_hl(
          win_T *wp,
          char *out,
          size_t outlen,
          char *fmt,
          int opt_idx,
          int opt_scope,
          int fillchar,
          int maxwidth,
          stl_hlrec_t **hltab,
          StlClickRecord **tabtab,
          statuscol_T *scp
        );
      ]]

      return ffi.C.build_stl_str_hl(
        ffi.C.find_window_by_handle(0, ffi.new('Error')),
        ffi.new('char[1024]'),
        1024,
        ffi.cast('char*', 'StatusLineOfLength20'),
        -1,
        0,
        0,
        0,
        nil,
        nil,
        nil
      )
    ]=]
    )

    -- Check that extern symbols are exported and accessible
    eq(
      true,
      exec_lua [[
      local ffi = require('ffi')

      ffi.cdef('uint64_t display_tick;')

      return ffi.C.display_tick >= 0
    ]]
    )
  end)
end)
