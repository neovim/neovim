-- Only run these tests when FFI is available
if not pcall(require, 'ffi') then
    return
end

local helpers = require('test.functional.helpers')(after_each)
local eq = helpers.eq
local exec_lua = helpers.exec_lua
local clear = helpers.clear

before_each(clear)

describe('ffi.cdef', function()
  describe('curwin_col_off', function()
    it('works', function()
      eq(12, exec_lua[[
        local ffi = require('ffi')

        ffi.cdef('int curwin_col_off(void);')

        vim.cmd('set number numberwidth=4 signcolumn=yes:4')

        return ffi.C.curwin_col_off()
      ]])
    end)
  end)
  describe('build_stl_str_hl', function()
    it('works', function()
      eq(20, exec_lua[=[
        local ffi = require('ffi')

        ffi.cdef[[
          typedef unsigned char char_u;
          typedef struct window_S win_T;
          typedef struct {} stl_hlrec_t;
          typedef struct {} StlClickRecord;

          extern win_T *curwin;

          int build_stl_str_hl(
            win_T *wp,
            char_u *out,
            size_t outlen,
            char_u *fmt,
            int use_sandbox,
            char_u fillchar,
            int maxwidth,
            stl_hlrec_t **hltab,
            StlClickRecord **tabtab
          );
        ]]

        return ffi.C.build_stl_str_hl(
          ffi.C.curwin,
          ffi.new('char_u[1024]'),
          1024,
          ffi.cast('char_u*', 'StatusLineOfLength20'),
          0,
          0,
          0,
          nil,
          nil
        )
      ]=])
    end)
  end)
end)
